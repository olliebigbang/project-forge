import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { DatabaseSync } from "node:sqlite";
import test from "node:test";
import {
  DURABLE_GUARD_LIMITS,
  beginDurableRequest,
  completeDurableRequest,
  consumeDurableRateLimits,
  ensureDurableRequestGuard,
  releaseDurableRequest,
  waitForDurableResult,
} from "../hosting/durable_request_guard.mjs";
import { ALLOW_LISTS, MAX_POWER } from "../hosting/weapon_contract.mjs";
import {
  INGRESS_LIMITS,
  handleCompileWeapon,
} from "../hosting/weapon_interpreter.mjs";

class SqliteD1Statement {
  constructor(binding, sql, values = []) {
    this.binding = binding;
    this.sql = sql;
    this.statement = binding.database.prepare(sql);
    this.values = values;
  }

  bind(...values) {
    return new SqliteD1Statement(this.binding, this.sql, values);
  }

  runSync() {
    if (/\bRETURNING\b/iu.test(this.sql)) {
      const results = this.statement.all(...this.values);
      return { success: true, results, meta: { changes: results.length } };
    }
    const result = this.statement.run(...this.values);
    return { success: true, results: [], meta: { changes: Number(result.changes) } };
  }

  async run() {
    return this.runSync();
  }

  async first() {
    return this.statement.get(...this.values) ?? null;
  }
}

class SqliteD1Binding {
  constructor(database) {
    this.database = database;
  }

  prepare(sql) {
    return new SqliteD1Statement(this, sql);
  }

  async batch(statements) {
    this.database.exec("BEGIN IMMEDIATE");
    try {
      const results = statements.map((statement) => statement.runSync());
      this.database.exec("COMMIT");
      return results;
    } catch (error) {
      this.database.exec("ROLLBACK");
      throw error;
    }
  }
}

class SharedD1Store {
  constructor() {
    this.database = new DatabaseSync(":memory:");
  }

  binding() {
    return new SqliteD1Binding(this.database);
  }

  close() {
    this.database.close();
  }
}

function interpreterPayload(requestId = "durable-request") {
  return {
    description: "a returning ice umbrella",
    drawing_summary: {
      stroke_count: 3,
      point_count: 24,
      aspect_ratio: 1.8,
      coverage: 0.28,
      dominant_direction: "horizontal",
    },
    locale: "en",
    request_id: requestId,
    supported_attack_patterns: [...ALLOW_LISTS.attack_pattern],
    supported_elements: [...ALLOW_LISTS.element],
    supported_abilities: [...ALLOW_LISTS.special_ability],
    maximum_power_score: MAX_POWER,
  };
}

function interpreterRequest(payload, session = "0123456789abcdef0123456789abcdef") {
  return new Request("https://forge.example/api/compile-weapon", {
    method: "POST",
    headers: {
      "content-type": "application/json",
      origin: "https://forge.example",
      "cf-connecting-ip": "203.0.113.42",
      "x-forge-session": session,
    },
    body: JSON.stringify(payload),
  });
}

test("runtime D1 schema and checked-in migration create the durable guard tables", async (context) => {
  const runtimeStore = new SharedD1Store();
  context.after(() => runtimeStore.close());
  await ensureDurableRequestGuard(runtimeStore.binding());
  const runtimeTables = runtimeStore.database.prepare(
    "SELECT name FROM sqlite_master WHERE type = 'table' ORDER BY name",
  ).all().map((row) => row.name);
  assert.deepEqual(runtimeTables, ["forge_rate_windows", "forge_request_ledger"]);

  const migrationStore = new SharedD1Store();
  context.after(() => migrationStore.close());
  const migration = await readFile(
    new URL("../drizzle/0000_m1b1_request_guard.sql", import.meta.url),
    "utf8",
  );
  for (const statement of migration.split("--> statement-breakpoint")) {
    if (statement.trim()) migrationStore.database.exec(statement);
  }
  const migrationTables = migrationStore.database.prepare(
    "SELECT name FROM sqlite_master WHERE type = 'table' ORDER BY name",
  ).all().map((row) => row.name);
  assert.deepEqual(migrationTables, runtimeTables);
});

test("two worker bindings share one durable owner and replay its exact result", async (context) => {
  const store = new SharedD1Store();
  context.after(() => store.close());
  const firstBinding = store.binding();
  const secondBinding = store.binding();
  await Promise.all([
    ensureDurableRequestGuard(firstBinding),
    ensureDurableRequestGuard(secondBinding),
  ]);

  const first = await beginDurableRequest(firstBinding, "session-a", "request-a", "fingerprint-a");
  const second = await beginDurableRequest(secondBinding, "session-a", "request-a", "fingerprint-a");
  assert.equal(first.state, "owner");
  assert.equal(second.state, "inflight");

  const expected = { request_id: "request-a", weapon_spec: { attack_pattern: "boomerang" } };
  assert.equal(await completeDurableRequest(
    firstBinding,
    "session-a",
    "request-a",
    "fingerprint-a",
    first.ownerToken,
    expected,
  ), true);
  const replay = await waitForDurableResult(
    secondBinding,
    "session-a",
    "request-a",
    "fingerprint-a",
    250,
  );
  assert.equal(replay.state, "complete");
  assert.deepEqual(replay.result, expected);
});

test("durable request IDs reject payload conflicts but remain isolated by session", async (context) => {
  const store = new SharedD1Store();
  context.after(() => store.close());
  const db = store.binding();
  await ensureDurableRequestGuard(db);
  const owner = await beginDurableRequest(db, "session-a", "shared-id", "fingerprint-a");
  assert.equal(owner.state, "owner");
  assert.equal(
    (await beginDurableRequest(db, "session-a", "shared-id", "fingerprint-b")).state,
    "conflict",
  );
  assert.equal(
    (await beginDurableRequest(db, "session-b", "shared-id", "fingerprint-b")).state,
    "owner",
  );
  assert.equal(await releaseDurableRequest(
    db,
    "session-a",
    "shared-id",
    "fingerprint-a",
    owner.ownerToken,
  ), true);
});

test("an expired owner cannot overwrite a reclaimed durable lease", async (context) => {
  const store = new SharedD1Store();
  context.after(() => store.close());
  const db = store.binding();
  await ensureDurableRequestGuard(db);
  const start = 1_800_000_000_000;
  const first = await beginDurableRequest(db, "session", "lease", "fingerprint", start);
  const second = await beginDurableRequest(
    db,
    "session",
    "lease",
    "fingerprint",
    start + DURABLE_GUARD_LIMITS.inflight_lease_ms + 1,
  );
  assert.equal(first.state, "owner");
  assert.equal(second.state, "owner");
  assert.notEqual(second.ownerToken, first.ownerToken);
  assert.equal(await completeDurableRequest(
    db,
    "session",
    "lease",
    "fingerprint",
    first.ownerToken,
    { stale: true },
    start + DURABLE_GUARD_LIMITS.inflight_lease_ms + 2,
  ), false);
  assert.equal(await completeDurableRequest(
    db,
    "session",
    "lease",
    "fingerprint",
    second.ownerToken,
    { stale: false },
    start + DURABLE_GUARD_LIMITS.inflight_lease_ms + 2,
  ), true);
});

test("a later request removes abandoned expired leases", async (context) => {
  const store = new SharedD1Store();
  context.after(() => store.close());
  const db = store.binding();
  await ensureDurableRequestGuard(db);
  const start = 1_800_000_000_000;
  assert.equal(
    (await beginDurableRequest(db, "session", "abandoned", "fingerprint", start)).state,
    "owner",
  );
  assert.equal(
    (await beginDurableRequest(
      db,
      "session",
      "cleanup-trigger",
      "fingerprint",
      start + DURABLE_GUARD_LIMITS.inflight_lease_ms + 1,
    )).state,
    "owner",
  );
  const abandoned = store.database.prepare(
    "SELECT request_id FROM forge_request_ledger WHERE request_id = ?",
  ).get("abandoned");
  assert.equal(abandoned, undefined);
});

test("durable session quota is atomic across worker bindings", async (context) => {
  const store = new SharedD1Store();
  context.after(() => store.close());
  const firstBinding = store.binding();
  const secondBinding = store.binding();
  await ensureDurableRequestGuard(firstBinding);
  const now = 1_800_000_000_000;
  const decisions = await Promise.all(
    Array.from({ length: INGRESS_LIMITS.session_requests_per_minute + 1 }, (_, index) =>
      consumeDurableRateLimits(
        index % 2 === 0 ? firstBinding : secondBinding,
        "session:atomic",
        "network:atomic",
        INGRESS_LIMITS.session_requests_per_minute,
        INGRESS_LIMITS.network_requests_per_minute,
        now,
      )),
  );
  assert.equal(decisions.filter((decision) => decision.allowed).length, 8);
  assert.equal(decisions.at(-1).allowed, false);
  assert.equal(decisions.at(-1).sessionCount, 9);
});

test("HTTP handler shares one provider operation across isolated worker bindings", async (context) => {
  const store = new SharedD1Store();
  context.after(() => store.close());
  let providerCalls = 0;
  const adapter = {
    provider: "durable_test",
    model: "shared_operation",
    supportsAbort: true,
    async interpret() {
      providerCalls += 1;
      await new Promise((resolve) => setTimeout(resolve, 80));
      return {
        intent: {
          attack_pattern: "boomerang",
          element: "ice",
          special_ability: "return_strike",
          status_effect: "freeze",
          drawback: "slow_recovery",
        },
        confidence: 0.95,
        estimated_cost: "UNKNOWN",
      };
    },
  };
  const payload = interpreterPayload("cross-isolate");
  const [first, second] = await Promise.all([
    handleCompileWeapon(interpreterRequest(payload), { DB: store.binding() }, { adapter }),
    handleCompileWeapon(interpreterRequest(payload), { DB: store.binding() }, { adapter }),
  ]);
  assert.equal(first.status, 200);
  assert.equal(second.status, 200);
  assert.equal(providerCalls, 1);
  assert.deepEqual(await first.json(), await second.json());
  assert.deepEqual(
    [first, second].map((response) => response.headers.get("x-forge-idempotency-store")),
    ["durable", "durable"],
  );
  assert.ok(
    [first, second].some((response) => response.headers.get("x-forge-idempotent-replay") === "true"),
  );
});

test("a broken durable guard fails closed before a paid adapter call", async () => {
  let providerCalls = 0;
  const brokenDb = {
    prepare() {
      throw new Error("D1 unavailable");
    },
    async batch() {
      throw new Error("D1 unavailable");
    },
  };
  const response = await handleCompileWeapon(
    interpreterRequest(interpreterPayload("guard-failure")),
    { DB: brokenDb },
    {
      adapter: {
        provider: "must_not_run",
        model: "must_not_run",
        async interpret() {
          providerCalls += 1;
          throw new Error("unexpected provider call");
        },
      },
    },
  );
  assert.equal(response.status, 503);
  assert.equal((await response.json()).error, "request_guard_unavailable");
  assert.equal(providerCalls, 0);
});

test("missing and partial D1 cannot downgrade a custom or configured provider to memory", async () => {
  let providerCalls = 0;
  const adapter = {
    provider: "paid_test_provider",
    model: "paid_test_model",
    async interpret() {
      providerCalls += 1;
      throw new Error("provider must not run");
    },
  };
  const missing = await handleCompileWeapon(
    interpreterRequest(interpreterPayload("missing-d1")),
    {},
    { adapter },
  );
  const partial = await handleCompileWeapon(
    interpreterRequest(interpreterPayload("partial-d1")),
    { DB: { prepare() { throw new Error("partial D1"); } } },
    { adapter },
  );
  const configured = await handleCompileWeapon(
    interpreterRequest(interpreterPayload("configured-provider-missing-d1")),
    { WEAPON_AI_PROVIDER: "openai", WEAPON_AI_MODEL: "test-model" },
  );
  const explicitlyRequired = await handleCompileWeapon(
    interpreterRequest(interpreterPayload("explicitly-required-d1")),
    { WEAPON_INTERPRETER_REQUIRE_DURABLE_GUARD: "true" },
  );
  assert.deepEqual(
    [missing.status, partial.status, configured.status, explicitlyRequired.status],
    [503, 503, 503, 503],
  );
  assert.equal(providerCalls, 0);
});
