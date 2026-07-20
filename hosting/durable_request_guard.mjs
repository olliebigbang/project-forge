export const DURABLE_GUARD_LIMITS = Object.freeze({
  rate_window_ms: 60 * 1000,
  rate_retention_ms: 2 * 60 * 1000,
  inflight_lease_ms: 45 * 1000,
  result_ttl_ms: 5 * 60 * 1000,
  poll_interval_ms: 50,
});

export const D1_SCHEMA_SQL = Object.freeze([
  `CREATE TABLE IF NOT EXISTS forge_request_ledger (
    namespace TEXT NOT NULL,
    request_id TEXT NOT NULL,
    fingerprint TEXT NOT NULL,
    owner_token TEXT NOT NULL,
    status TEXT NOT NULL CHECK (status IN ('inflight', 'complete')),
    result_json TEXT,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL,
    expires_at INTEGER NOT NULL,
    PRIMARY KEY (namespace, request_id)
  )`,
  `CREATE INDEX IF NOT EXISTS forge_request_ledger_expiry_idx
    ON forge_request_ledger (expires_at)`,
  `CREATE TABLE IF NOT EXISTS forge_rate_windows (
    scope TEXT NOT NULL,
    window_start INTEGER NOT NULL,
    request_count INTEGER NOT NULL DEFAULT 0,
    expires_at INTEGER NOT NULL,
    PRIMARY KEY (scope, window_start)
  )`,
  `CREATE INDEX IF NOT EXISTS forge_rate_windows_expiry_idx
    ON forge_rate_windows (expires_at)`,
]);

const SQL = Object.freeze({
  deleteExpiredRates: "DELETE FROM forge_rate_windows WHERE expires_at <= ?",
  consumeRate: `INSERT INTO forge_rate_windows
    (scope, window_start, request_count, expires_at) VALUES (?, ?, 1, ?)
    ON CONFLICT(scope, window_start) DO UPDATE SET
      request_count = request_count + 1,
      expires_at = excluded.expires_at
    RETURNING request_count`,
  deleteExpiredRequests: "DELETE FROM forge_request_ledger WHERE expires_at <= ?",
  insertRequest: `INSERT OR IGNORE INTO forge_request_ledger
    (namespace, request_id, fingerprint, owner_token, status, result_json,
     created_at, updated_at, expires_at)
    VALUES (?, ?, ?, ?, 'inflight', NULL, ?, ?, ?)`,
  selectRequest: `SELECT fingerprint, owner_token, status, result_json, expires_at
    FROM forge_request_ledger WHERE namespace = ? AND request_id = ?`,
  reclaimRequest: `UPDATE forge_request_ledger
    SET fingerprint = ?, owner_token = ?, status = 'inflight', result_json = NULL,
        updated_at = ?, expires_at = ?
    WHERE namespace = ? AND request_id = ?
      AND (expires_at <= ? OR (status = 'complete' AND result_json IS NULL))`,
  completeRequest: `UPDATE forge_request_ledger
    SET status = 'complete', result_json = ?, updated_at = ?, expires_at = ?
    WHERE namespace = ? AND request_id = ? AND fingerprint = ?
      AND owner_token = ? AND status = 'inflight'`,
  releaseRequest: `DELETE FROM forge_request_ledger
    WHERE namespace = ? AND request_id = ? AND fingerprint = ?
      AND owner_token = ? AND status = 'inflight'`,
});
const initializationByDatabase = new WeakMap();

function changedRows(result) {
  return Number(result?.meta?.changes ?? result?.changes ?? 0);
}

function firstResultRow(result) {
  if (Array.isArray(result?.results)) return result.results[0] ?? null;
  if (Array.isArray(result?.result)) return result.result[0] ?? null;
  return null;
}

function randomOwnerToken() {
  const bytes = new Uint8Array(16);
  if (!globalThis.crypto?.getRandomValues) {
    throw new Error("A cryptographic random source is required for the D1 request lease.");
  }
  globalThis.crypto.getRandomValues(bytes);
  return [...bytes].map((value) => value.toString(16).padStart(2, "0")).join("");
}

function parseStoredResult(value) {
  if (typeof value !== "string" || value.length === 0) return null;
  try {
    const parsed = JSON.parse(value);
    return parsed && typeof parsed === "object" && !Array.isArray(parsed) ? parsed : null;
  } catch {
    return null;
  }
}

function wait(delayMs) {
  return new Promise((resolve) => setTimeout(resolve, delayMs));
}

export function hasDurableRequestGuard(env = {}) {
  return Boolean(
    env.DB &&
    typeof env.DB.prepare === "function" &&
    typeof env.DB.batch === "function",
  );
}

export async function initializeDurableRequestGuard(db) {
  for (const statement of D1_SCHEMA_SQL) {
    await db.prepare(statement).run();
  }
}

export async function ensureDurableRequestGuard(db) {
  let initialization = initializationByDatabase.get(db);
  if (!initialization) {
    initialization = initializeDurableRequestGuard(db).catch((error) => {
      initializationByDatabase.delete(db);
      throw error;
    });
    initializationByDatabase.set(db, initialization);
  }
  await initialization;
}

export async function consumeDurableRateLimits(
  db,
  sessionScope,
  networkScope,
  sessionLimit,
  networkLimit,
  now = Date.now(),
) {
  const windowStart = Math.floor(now / DURABLE_GUARD_LIMITS.rate_window_ms) *
    DURABLE_GUARD_LIMITS.rate_window_ms;
  const expiresAt = windowStart + DURABLE_GUARD_LIMITS.rate_retention_ms;
  const results = await db.batch([
    db.prepare(SQL.deleteExpiredRates).bind(now),
    db.prepare(SQL.consumeRate).bind(sessionScope, windowStart, expiresAt),
    db.prepare(SQL.consumeRate).bind(networkScope, windowStart, expiresAt),
  ]);
  const sessionRow = firstResultRow(results?.[1]);
  const networkRow = firstResultRow(results?.[2]);
  const sessionCount = Number(sessionRow?.request_count ?? Number.POSITIVE_INFINITY);
  const networkCount = Number(networkRow?.request_count ?? Number.POSITIVE_INFINITY);
  return {
    allowed: sessionCount <= sessionLimit && networkCount <= networkLimit,
    sessionCount,
    networkCount,
    retryAfter: Math.max(1, Math.ceil(
      (windowStart + DURABLE_GUARD_LIMITS.rate_window_ms - now) / 1000,
    )),
  };
}

async function readRequest(db, namespace, requestId) {
  return db.prepare(SQL.selectRequest).bind(namespace, requestId).first();
}

export async function beginDurableRequest(
  db,
  namespace,
  requestId,
  fingerprint,
  now = Date.now(),
) {
  // Completed replays and abandoned in-flight leases are both short-lived.
  // Removing every expired row prevents crashed worker operations with unique
  // request IDs from accumulating indefinitely.
  await db.prepare(SQL.deleteExpiredRequests).bind(now).run();
  const ownerToken = randomOwnerToken();
  const expiresAt = now + DURABLE_GUARD_LIMITS.inflight_lease_ms;
  const inserted = await db.prepare(SQL.insertRequest).bind(
    namespace,
    requestId,
    fingerprint,
    ownerToken,
    now,
    now,
    expiresAt,
  ).run();
  if (changedRows(inserted) === 1) return { state: "owner", ownerToken };

  let row = await readRequest(db, namespace, requestId);
  if (!row) return { state: "unavailable" };
  if (row.fingerprint !== fingerprint) return { state: "conflict" };
  if (row.status === "complete" && Number(row.expires_at) > now) {
    const result = parseStoredResult(row.result_json);
    if (result) return { state: "complete", result };
  }
  if (row.status === "inflight" && Number(row.expires_at) > now) {
    return { state: "inflight" };
  }

  const reclaimed = await db.prepare(SQL.reclaimRequest).bind(
    fingerprint,
    ownerToken,
    now,
    expiresAt,
    namespace,
    requestId,
    now,
  ).run();
  if (changedRows(reclaimed) === 1) return { state: "owner", ownerToken };
  row = await readRequest(db, namespace, requestId);
  if (!row) return { state: "unavailable" };
  if (row.fingerprint !== fingerprint) return { state: "conflict" };
  if (row.status === "complete") {
    const result = parseStoredResult(row.result_json);
    if (result) return { state: "complete", result };
  }
  return { state: "inflight" };
}

export async function waitForDurableResult(
  db,
  namespace,
  requestId,
  fingerprint,
  maximumWaitMs,
) {
  const deadline = Date.now() + maximumWaitMs;
  while (Date.now() < deadline) {
    await wait(DURABLE_GUARD_LIMITS.poll_interval_ms);
    const row = await readRequest(db, namespace, requestId);
    if (!row) return { state: "unavailable" };
    if (row.fingerprint !== fingerprint) return { state: "conflict" };
    if (row.status === "complete") {
      const result = parseStoredResult(row.result_json);
      if (result) return { state: "complete", result };
    }
    if (Number(row.expires_at) <= Date.now()) return { state: "expired" };
  }
  return { state: "timeout" };
}

export async function completeDurableRequest(
  db,
  namespace,
  requestId,
  fingerprint,
  ownerToken,
  result,
  now = Date.now(),
) {
  const stored = JSON.stringify(result);
  const completed = await db.prepare(SQL.completeRequest).bind(
    stored,
    now,
    now + DURABLE_GUARD_LIMITS.result_ttl_ms,
    namespace,
    requestId,
    fingerprint,
    ownerToken,
  ).run();
  return changedRows(completed) === 1;
}

export async function releaseDurableRequest(
  db,
  namespace,
  requestId,
  fingerprint,
  ownerToken,
) {
  const released = await db.prepare(SQL.releaseRequest).bind(
    namespace,
    requestId,
    fingerprint,
    ownerToken,
  ).run();
  return changedRows(released) === 1;
}
