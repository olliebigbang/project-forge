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

// Lifetime application-layer provider budget. The key includes the milestone,
// provider, immutable model snapshot and pricing revision so a future pricing
// change cannot silently reuse this ledger.
export const forgeProviderBudget = {
  primaryKey: ["budget_key"],
  columns: {
    budget_key: "TEXT NOT NULL",
    limit_microusd: "INTEGER NOT NULL CHECK (limit_microusd > 0)",
    spent_microusd: "INTEGER NOT NULL DEFAULT 0 CHECK (spent_microusd >= 0)",
    reserved_microusd: "INTEGER NOT NULL DEFAULT 0 CHECK (reserved_microusd >= 0)",
    locked: "INTEGER NOT NULL DEFAULT 0 CHECK (locked IN (0, 1))",
    updated_at: "INTEGER NOT NULL",
  },
} as const;

export const forgeProviderCharges = {
  primaryKey: ["budget_key", "namespace", "request_id"],
  columns: {
    budget_key: "TEXT NOT NULL",
    namespace: "TEXT NOT NULL",
    request_id: "TEXT NOT NULL",
    provider: "TEXT NOT NULL",
    model: "TEXT NOT NULL",
    status: "TEXT NOT NULL CHECK (status IN ('reserved', 'settled', 'conservative', 'released'))",
    reservation_microusd: "INTEGER NOT NULL CHECK (reservation_microusd > 0)",
    actual_microusd: "INTEGER",
    input_tokens: "INTEGER",
    output_tokens: "INTEGER",
    created_at: "INTEGER NOT NULL",
    updated_at: "INTEGER NOT NULL",
  },
} as const;
