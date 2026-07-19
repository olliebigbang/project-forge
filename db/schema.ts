// Logical D1 schema for the short-lived M1B1 request guard. Runtime code uses
// prepared statements in hosting/durable_request_guard.mjs; this file keeps the
// durable data shape visible to migration and architecture review.
export const forgeRequestLedger = {
  primaryKey: ["namespace", "request_id"],
  columns: {
    namespace: "TEXT NOT NULL",
    request_id: "TEXT NOT NULL",
    fingerprint: "TEXT NOT NULL",
    owner_token: "TEXT NOT NULL",
    status: "TEXT NOT NULL CHECK (status IN ('inflight', 'complete'))",
    result_json: "TEXT",
    created_at: "INTEGER NOT NULL",
    updated_at: "INTEGER NOT NULL",
    expires_at: "INTEGER NOT NULL",
  },
} as const;

export const forgeRateWindows = {
  primaryKey: ["scope", "window_start"],
  columns: {
    scope: "TEXT NOT NULL",
    window_start: "INTEGER NOT NULL",
    request_count: "INTEGER NOT NULL DEFAULT 0",
    expires_at: "INTEGER NOT NULL",
  },
} as const;
