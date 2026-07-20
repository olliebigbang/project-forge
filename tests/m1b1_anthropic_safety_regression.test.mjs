import assert from "node:assert/strict";
import { DatabaseSync } from "node:sqlite";
import test from "node:test";
import {
  ANTHROPIC_MODEL,
  AnthropicWeaponAdapter,
} from "../hosting/anthropic_weapon_adapter.mjs";
import {
  PROVIDER_REQUEST_RESERVATION_MICRO_USD,
  providerBudgetConfig,
  providerBudgetSnapshot,
  reserveProviderBudget,
  settleProviderBudget,
} from "../hosting/provider_budget_guard.mjs";
import { ALLOW_LISTS, MAX_POWER } from "../hosting/weapon_contract.mjs";
import { handleCompileWeapon } from "../hosting/weapon_interpreter.mjs";

const SECRET_MARKER = "sk-ant-qa-secret-must-never-leak";
const RAW_MARKER = "RAW_PROVIDER_BODY_MUST_NEVER_LEAK";

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

function payload(requestId) {
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

function request(requestId) {
  return new Request("https://forge.example/api/compile-weapon", {
    method: "POST",
    headers: {
      "content-type": "application/json",
      origin: "https://forge.example",
      "cf-connecting-ip": "203.0.113.88",
      "x-forge-session": "0123456789abcdef0123456789abcdef",
    },
    body: JSON.stringify(payload(requestId)),
  });
}

function providerMessage(overrides = {}) {
  return {
    id: "msg_qa_123",
    type: "message",
    role: "assistant",
    model: ANTHROPIC_MODEL,
    stop_reason: "end_turn",
    content: [{
      type: "text",
      text: JSON.stringify({
        attack_pattern: "boomerang",
        element: "ice",
        special_ability: "return_strike",
        status_effect: "freeze",
        drawback: "slow_recovery",
        confidence: "high",
      }),
    }],
    usage: { input_tokens: 100, output_tokens: 20 },
    ...overrides,
  };
}

function jsonResponse(body, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json" },
  });
}

async function runCase(requestId, fetchImpl) {
  const database = new DatabaseSync(":memory:");
  const db = new SqliteD1Binding(database);
  let calls = 0;
  const adapter = new AnthropicWeaponAdapter({
    apiKey: SECRET_MARKER,
    model: ANTHROPIC_MODEL,
    async fetchImpl(...args) {
      calls += 1;
      return fetchImpl(...args);
    },
  });
  const logs = [];
  const originalInfo = console.info;
  console.info = (...values) => logs.push(values.join(" "));
  try {
    const response = await handleCompileWeapon(
      request(requestId),
      {
        DB: db,
        WEAPON_INTERPRETER_REQUIRE_DURABLE_GUARD: "true",
        M1B1_PROVIDER_BUDGET_USD: "5",
      },
      { adapter },
    );
    const result = await response.json();
    const config = providerBudgetConfig(
      { M1B1_PROVIDER_BUDGET_USD: "5" },
      "anthropic",
      ANTHROPIC_MODEL,
    );
    const snapshot = await providerBudgetSnapshot(db, config);
    const requestRows = database.prepare(
      "SELECT result_json FROM forge_request_ledger",
    ).all();
    const chargeRows = database.prepare(
      "SELECT provider, model, status, reservation_microusd, actual_microusd, input_tokens, output_tokens FROM forge_provider_charges",
    ).all();
    return { calls, result, snapshot, requestRows, chargeRows, logs };
  } finally {
    console.info = originalInfo;
    database.close();
  }
}

function assertNoRawLeak(evidence) {
  const text = JSON.stringify(evidence);
  assert.equal(text.includes(SECRET_MARKER), false);
  assert.equal(text.includes(RAW_MARKER), false);
}

test("refusal and max_tokens settle measured usage but never retain provider text", async (context) => {
  for (const [stopReason, fallbackReason] of [
    ["refusal", "provider_refusal"],
    ["max_tokens", "provider_output_truncated"],
  ]) {
    await context.test(stopReason, async () => {
      const evidence = await runCase(`qa-${stopReason}`, async () => jsonResponse(providerMessage({
        stop_reason: stopReason,
        content: [{ type: "text", text: `${RAW_MARKER}:${SECRET_MARKER}` }],
      })));
      assert.equal(evidence.calls, 1);
      assert.equal(evidence.result.fallback_reason, fallbackReason);
      assert.deepEqual(evidence.result.estimated_cost, { amount: 0.0002, currency: "USD" });
      assert.equal(evidence.snapshot.spentMicroUsd, 200);
      assert.equal(evidence.snapshot.reservedMicroUsd, 0);
      assert.equal(evidence.chargeRows[0].status, "settled");
      assertNoRawLeak(evidence);
    });
  }
});

test("malformed successful response with unknown usage commits the full reservation", async () => {
  const evidence = await runCase("qa-invalid-usage", async () => jsonResponse(providerMessage({
    usage: {},
    content: [{ type: "text", text: RAW_MARKER }],
  })));
  assert.equal(evidence.calls, 1);
  assert.equal(evidence.result.fallback_reason, "invalid_provider_usage");
  assert.equal(evidence.snapshot.spentMicroUsd, PROVIDER_REQUEST_RESERVATION_MICRO_USD);
  assert.equal(evidence.snapshot.reservedMicroUsd, 0);
  assert.equal(evidence.chargeRows[0].status, "conservative");
  assertNoRawLeak(evidence);
});

test("wrong served model is billed once and cannot become gameplay data", async () => {
  const evidence = await runCase("qa-wrong-model", async () => jsonResponse(providerMessage({
    model: "claude-sonnet-4-5-20250929",
    content: [{ type: "text", text: RAW_MARKER }],
  })));
  assert.equal(evidence.calls, 1);
  assert.equal(evidence.result.fallback_reason, "provider_model_mismatch");
  assert.equal(evidence.snapshot.spentMicroUsd, 200);
  assert.equal(evidence.chargeRows[0].status, "settled");
  assertNoRawLeak(evidence);
});

test("ambiguous Anthropic HTTP failures retain the conservative reservation", async (context) => {
  for (const status of [429, 500, 504, 529]) {
    await context.test(`HTTP ${status}`, async () => {
      const evidence = await runCase(`qa-http-${status}`, async () => jsonResponse({
        type: "error",
        error: { type: "hostile_error", message: `${RAW_MARKER}:${SECRET_MARKER}` },
      }, status));
      assert.equal(evidence.calls, 1);
      assert.equal(evidence.snapshot.spentMicroUsd, PROVIDER_REQUEST_RESERVATION_MICRO_USD);
      assert.equal(evidence.snapshot.reservedMicroUsd, 0);
      assert.equal(evidence.chargeRows[0].status, "conservative");
      assertNoRawLeak(evidence);
    });
  }
});

test("usage above the reservation locks the lifetime budget", async () => {
  const database = new DatabaseSync(":memory:");
  const db = new SqliteD1Binding(database);
  try {
    const config = providerBudgetConfig(
      { M1B1_PROVIDER_BUDGET_USD: "5" },
      "anthropic",
      ANTHROPIC_MODEL,
    );
    assert.equal((await reserveProviderBudget(db, config, "session", "breach")).state, "reserved");
    assert.equal((await settleProviderBudget(
      db,
      config,
      "session",
      "breach",
      PROVIDER_REQUEST_RESERVATION_MICRO_USD + 1,
      { input_tokens: 200_001, output_tokens: 256 },
    )).state, "reservation_breach");
    const snapshot = await providerBudgetSnapshot(db, config);
    assert.equal(snapshot.locked, true);
    assert.equal(snapshot.reservedMicroUsd, PROVIDER_REQUEST_RESERVATION_MICRO_USD);
    assert.equal((await reserveProviderBudget(db, config, "session", "after-breach")).state, "locked");
  } finally {
    database.close();
  }
});
