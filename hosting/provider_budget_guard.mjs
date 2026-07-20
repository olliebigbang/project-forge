export const APPROVED_M1B1_PROVIDER_BUDGET_USD = 5;
// Reserve the full Haiku 4.5 context-window input ceiling plus our fixed
// 256-token output ceiling at the approved $1/M input and $5/M output rates.
// The application sends much less, but this worst-case reservation makes the
// pre-invocation decision independent of tokenizer drift or provider overhead.
export const PROVIDER_REQUEST_RESERVATION_MICRO_USD = 201_280;
export const PROVIDER_PRICING_REVISION = "haiku45-1in-5out-2025-10";

export const PROVIDER_BUDGET_SCHEMA_SQL = Object.freeze([
  `CREATE TABLE IF NOT EXISTS forge_provider_budget (
    budget_key TEXT NOT NULL PRIMARY KEY,
    limit_microusd INTEGER NOT NULL CHECK (limit_microusd > 0),
    spent_microusd INTEGER NOT NULL DEFAULT 0 CHECK (spent_microusd >= 0),
    reserved_microusd INTEGER NOT NULL DEFAULT 0 CHECK (reserved_microusd >= 0),
    locked INTEGER NOT NULL DEFAULT 0 CHECK (locked IN (0, 1)),
    updated_at INTEGER NOT NULL
  )`,
  `CREATE TABLE IF NOT EXISTS forge_provider_charges (
    budget_key TEXT NOT NULL,
    namespace TEXT NOT NULL,
    request_id TEXT NOT NULL,
    provider TEXT NOT NULL,
    model TEXT NOT NULL,
    status TEXT NOT NULL CHECK (status IN ('reserved', 'settled', 'conservative', 'released')),
    reservation_microusd INTEGER NOT NULL CHECK (reservation_microusd > 0),
    actual_microusd INTEGER,
    input_tokens INTEGER,
    output_tokens INTEGER,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL,
    PRIMARY KEY (budget_key, namespace, request_id)
  )`,
  `CREATE INDEX IF NOT EXISTS forge_provider_charges_status_idx
    ON forge_provider_charges (budget_key, status)`,
]);

const SQL = Object.freeze({
  insertBudget: `INSERT OR IGNORE INTO forge_provider_budget
    (budget_key, limit_microusd, spent_microusd, reserved_microusd, locked, updated_at)
    VALUES (?, ?, 0, 0, 0, ?)`,
  selectBudget: `SELECT limit_microusd, spent_microusd, reserved_microusd, locked
    FROM forge_provider_budget WHERE budget_key = ?`,
  selectCharge: `SELECT status, reservation_microusd, actual_microusd
    FROM forge_provider_charges
    WHERE budget_key = ? AND namespace = ? AND request_id = ?`,
  reserveBudget: `UPDATE forge_provider_budget
    SET reserved_microusd = reserved_microusd + ?, updated_at = ?
    WHERE budget_key = ? AND limit_microusd = ? AND locked = 0
      AND spent_microusd + reserved_microusd + ? <= limit_microusd
    RETURNING limit_microusd, spent_microusd, reserved_microusd, locked`,
  insertCharge: `INSERT INTO forge_provider_charges
    (budget_key, namespace, request_id, provider, model, status,
     reservation_microusd, actual_microusd, input_tokens, output_tokens,
     created_at, updated_at)
    SELECT ?, ?, ?, ?, ?, 'reserved', ?, NULL, NULL, NULL, ?, ?
    WHERE changes() = 1`,
  settleBudget: `UPDATE forge_provider_budget
    SET reserved_microusd = reserved_microusd - ?,
        spent_microusd = spent_microusd + ?, updated_at = ?
    WHERE budget_key = ? AND locked = 0 AND reserved_microusd >= ?
      AND spent_microusd + ? <= limit_microusd
    RETURNING limit_microusd, spent_microusd, reserved_microusd, locked`,
  settleCharge: `UPDATE forge_provider_charges
    SET status = ?, actual_microusd = ?, input_tokens = ?, output_tokens = ?, updated_at = ?
    WHERE budget_key = ? AND namespace = ? AND request_id = ? AND status = 'reserved'
      AND changes() = 1
    RETURNING status`,
  releaseBudget: `UPDATE forge_provider_budget
    SET reserved_microusd = reserved_microusd - ?, updated_at = ?
    WHERE budget_key = ? AND reserved_microusd >= ?
    RETURNING limit_microusd, spent_microusd, reserved_microusd, locked`,
  releaseCharge: `UPDATE forge_provider_charges
    SET status = 'released', actual_microusd = 0, updated_at = ?
    WHERE budget_key = ? AND namespace = ? AND request_id = ? AND status = 'reserved'
      AND changes() = 1
    RETURNING status`,
  lockBudget: `UPDATE forge_provider_budget SET locked = 1, updated_at = ?
    WHERE budget_key = ? RETURNING locked`,
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

function safeInteger(value, fallback = 0) {
  const parsed = Number(value);
  return Number.isSafeInteger(parsed) && parsed >= 0 ? parsed : fallback;
}

export function providerBudgetConfig(env = {}, provider, model) {
  const amountUsd = Number(env.M1B1_PROVIDER_BUDGET_USD);
  if (
    !Number.isFinite(amountUsd) ||
    amountUsd <= 0 ||
    amountUsd > APPROVED_M1B1_PROVIDER_BUDGET_USD
  ) {
    throw new Error("M1B1 provider budget is missing or exceeds the approved limit.");
  }
  const limitMicroUsd = Math.floor(amountUsd * 1_000_000);
  if (limitMicroUsd < PROVIDER_REQUEST_RESERVATION_MICRO_USD) {
    throw new Error("M1B1 provider budget is smaller than one safe reservation.");
  }
  const safeProvider = String(provider ?? "").trim().toLowerCase();
  const safeModel = String(model ?? "").trim();
  if (!/^[a-z0-9_-]+$/u.test(safeProvider) || !/^[A-Za-z0-9._:-]+$/u.test(safeModel)) {
    throw new Error("Provider budget identity is invalid.");
  }
  return {
    budgetKey: `m1b1-lifetime:${safeProvider}:${safeModel}:${PROVIDER_PRICING_REVISION}`,
    limitMicroUsd,
    reservationMicroUsd: PROVIDER_REQUEST_RESERVATION_MICRO_USD,
    provider: safeProvider,
    model: safeModel,
  };
}

export async function lockProviderBudget(db, config, now = Date.now()) {
  const result = await db.prepare(SQL.lockBudget).bind(now, config.budgetKey).run();
  return firstResultRow(result)?.locked === 1 || changedRows(result) === 1;
}

export async function initializeProviderBudgetGuard(db) {
  for (const statement of PROVIDER_BUDGET_SCHEMA_SQL) {
    await db.prepare(statement).run();
  }
}

export async function ensureProviderBudgetGuard(db) {
  let initialization = initializationByDatabase.get(db);
  if (!initialization) {
    initialization = initializeProviderBudgetGuard(db).catch((error) => {
      initializationByDatabase.delete(db);
      throw error;
    });
    initializationByDatabase.set(db, initialization);
  }
  await initialization;
}

async function readBudget(db, budgetKey) {
  return db.prepare(SQL.selectBudget).bind(budgetKey).first();
}

async function readCharge(db, config, namespace, requestId) {
  return db.prepare(SQL.selectCharge).bind(
    config.budgetKey,
    namespace,
    requestId,
  ).first();
}

export async function reserveProviderBudget(
  db,
  config,
  namespace,
  requestId,
  now = Date.now(),
) {
  await ensureProviderBudgetGuard(db);
  await db.prepare(SQL.insertBudget).bind(
    config.budgetKey,
    config.limitMicroUsd,
    now,
  ).run();
  const existingCharge = await readCharge(db, config, namespace, requestId);
  if (existingCharge) return { state: "previous_attempt" };
  const budget = await readBudget(db, config.budgetKey);
  if (!budget || safeInteger(budget.limit_microusd) !== config.limitMicroUsd) {
    return { state: "configuration_mismatch" };
  }
  if (safeInteger(budget.locked) === 1) return { state: "locked" };

  const results = await db.batch([
    db.prepare(SQL.reserveBudget).bind(
      config.reservationMicroUsd,
      now,
      config.budgetKey,
      config.limitMicroUsd,
      config.reservationMicroUsd,
    ),
    db.prepare(SQL.insertCharge).bind(
      config.budgetKey,
      namespace,
      requestId,
      config.provider,
      config.model,
      config.reservationMicroUsd,
      now,
      now,
    ),
  ]).catch(async (error) => {
    // The batch is transactional on D1. A uniqueness race is treated as an
    // unknown prior attempt; every other failure remains fail-closed.
    if (String(error?.message ?? "").toLowerCase().includes("unique")) return null;
    throw error;
  });
  if (!results) return { state: "previous_attempt" };
  const updated = firstResultRow(results[0]);
  if (!updated || changedRows(results[1]) !== 1) return { state: "exhausted" };
  return {
    state: "reserved",
    reservationMicroUsd: config.reservationMicroUsd,
    remainingMicroUsd: safeInteger(updated.limit_microusd) -
      safeInteger(updated.spent_microusd) - safeInteger(updated.reserved_microusd),
  };
}

async function settle(
  db,
  config,
  namespace,
  requestId,
  actualMicroUsd,
  usage,
  status,
  now,
) {
  const charge = await readCharge(db, config, namespace, requestId);
  if (!charge || charge.status !== "reserved") return { state: "missing_reservation" };
  const reservation = safeInteger(charge.reservation_microusd);
  if (actualMicroUsd > reservation) {
    await db.prepare(SQL.lockBudget).bind(now, config.budgetKey).run();
    return { state: "reservation_breach" };
  }
  const results = await db.batch([
    db.prepare(SQL.settleBudget).bind(
      reservation,
      actualMicroUsd,
      now,
      config.budgetKey,
      reservation,
      actualMicroUsd,
    ),
    db.prepare(SQL.settleCharge).bind(
      status,
      actualMicroUsd,
      safeInteger(usage?.input_tokens),
      safeInteger(usage?.output_tokens),
      now,
      config.budgetKey,
      namespace,
      requestId,
    ),
  ]);
  if (!firstResultRow(results[0]) || !firstResultRow(results[1])) {
    return { state: "settlement_failed" };
  }
  return { state: status, actualMicroUsd };
}

export async function settleProviderBudget(
  db,
  config,
  namespace,
  requestId,
  actualMicroUsd,
  usage,
  now = Date.now(),
) {
  const safeActual = safeInteger(actualMicroUsd, Number.MAX_SAFE_INTEGER);
  return settle(db, config, namespace, requestId, safeActual, usage, "settled", now);
}

export async function commitConservativeProviderBudget(
  db,
  config,
  namespace,
  requestId,
  now = Date.now(),
) {
  return settle(
    db,
    config,
    namespace,
    requestId,
    config.reservationMicroUsd,
    null,
    "conservative",
    now,
  );
}

export async function releaseProviderBudget(
  db,
  config,
  namespace,
  requestId,
  now = Date.now(),
) {
  const charge = await readCharge(db, config, namespace, requestId);
  if (!charge || charge.status !== "reserved") return { state: "missing_reservation" };
  const reservation = safeInteger(charge.reservation_microusd);
  const results = await db.batch([
    db.prepare(SQL.releaseBudget).bind(
      reservation,
      now,
      config.budgetKey,
      reservation,
    ),
    db.prepare(SQL.releaseCharge).bind(
      now,
      config.budgetKey,
      namespace,
      requestId,
    ),
  ]);
  if (!firstResultRow(results[0]) || !firstResultRow(results[1])) {
    return { state: "release_failed" };
  }
  return { state: "released", actualMicroUsd: 0 };
}

export async function providerBudgetSnapshot(db, config) {
  const row = await readBudget(db, config.budgetKey);
  if (!row) return null;
  return {
    limitMicroUsd: safeInteger(row.limit_microusd),
    spentMicroUsd: safeInteger(row.spent_microusd),
    reservedMicroUsd: safeInteger(row.reserved_microusd),
    locked: safeInteger(row.locked) === 1,
  };
}
