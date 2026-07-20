import assert from "node:assert/strict";
import test from "node:test";
import {
  ANTHROPIC_INTENT_SCHEMA,
  ANTHROPIC_MAX_OUTPUT_TOKENS,
  ANTHROPIC_MAX_RESPONSE_BYTES,
  ANTHROPIC_MESSAGES_URL,
  ANTHROPIC_MODEL,
  ANTHROPIC_VERSION,
  AnthropicWeaponAdapter,
  calculateAnthropicUsageCost,
} from "../hosting/anthropic_weapon_adapter.mjs";
import { ALLOW_LISTS, MAX_POWER } from "../hosting/weapon_contract.mjs";
import {
  compileWeapon,
  resolveAdapter,
} from "../hosting/weapon_interpreter.mjs";

const TEST_KEY = "sk-ant-test-do-not-log";

function interpreterPayload() {
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
    request_id: "anthropic-adapter-test",
    supported_attack_patterns: [...ALLOW_LISTS.attack_pattern],
    supported_elements: [...ALLOW_LISTS.element],
    supported_abilities: [...ALLOW_LISTS.special_ability],
    maximum_power_score: MAX_POWER,
  };
}

function semanticIntent() {
  return {
    attack_pattern: "boomerang",
    element: "ice",
    special_ability: "return_strike",
    status_effect: "freeze",
    drawback: "slow_recovery",
    confidence: "high",
  };
}

function providerMessage(overrides = {}) {
  return {
    id: "msg_test_123",
    type: "message",
    role: "assistant",
    model: ANTHROPIC_MODEL,
    stop_reason: "end_turn",
    content: [{ type: "text", text: JSON.stringify(semanticIntent()) }],
    usage: { input_tokens: 100, output_tokens: 20 },
    ...overrides,
  };
}

function jsonResponse(payload, status = 200) {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { "content-type": "application/json" },
  });
}

test("native Messages request pins Haiku 4.5 and Anthropic Structured Outputs", async () => {
  const calls = [];
  const adapter = new AnthropicWeaponAdapter({
    apiKey: TEST_KEY,
    model: ANTHROPIC_MODEL,
    async fetchImpl(url, init) {
      calls.push({ url, init });
      return jsonResponse(providerMessage());
    },
  });
  const result = await adapter.interpret(interpreterPayload());
  assert.equal(calls.length, 1);
  assert.equal(calls[0].url, ANTHROPIC_MESSAGES_URL);
  assert.equal(calls[0].init.method, "POST");
  assert.equal(calls[0].init.headers["anthropic-version"], ANTHROPIC_VERSION);
  assert.equal(calls[0].init.headers["x-api-key"], TEST_KEY);
  assert.equal(calls[0].init.headers["anthropic-beta"], undefined);

  const body = JSON.parse(calls[0].init.body);
  assert.equal(body.model, ANTHROPIC_MODEL);
  assert.equal(body.max_tokens, ANTHROPIC_MAX_OUTPUT_TOKENS);
  assert.equal(body.temperature, 0);
  assert.deepEqual(body.output_config, {
    format: { type: "json_schema", schema: ANTHROPIC_INTENT_SCHEMA },
  });
  assert.equal(body.tools, undefined);
  assert.equal(body.thinking, undefined);
  assert.equal(body.container, undefined);
  assert.equal(calls[0].init.body.includes(TEST_KEY), false);
  assert.equal(body.messages.length, 1);
  assert.equal(body.messages[0].role, "user");
  assert.deepEqual(result.intent, {
    attack_pattern: "boomerang",
    element: "ice",
    special_ability: "return_strike",
    status_effect: "freeze",
    drawback: "slow_recovery",
  });
  assert.equal(result.confidence, 0.9);
  assert.deepEqual(result.estimated_cost, { amount: 0.0002, currency: "USD" });
  assert.deepEqual(adapter.billingSnapshot(), {
    disposition: "measured",
    actualMicroUsd: 200,
    usage: {
      input_tokens: 100,
      output_tokens: 20,
      cache_creation_input_tokens: 0,
      cache_read_input_tokens: 0,
      cache_creation_5m_input_tokens: 0,
      cache_creation_1h_input_tokens: 0,
    },
  });
});

test("provider fetch is invoked as a function without binding the adapter as this", async () => {
  let invocationThis = "not-called";
  async function strictFetch() {
    invocationThis = this;
    if (this !== undefined) throw new TypeError("Illegal invocation");
    return jsonResponse(providerMessage());
  }
  const adapter = new AnthropicWeaponAdapter({
    apiKey: TEST_KEY,
    model: ANTHROPIC_MODEL,
    fetchImpl: strictFetch,
  });

  const result = await adapter.interpret(interpreterPayload());

  assert.equal(invocationThis, undefined);
  assert.equal(result.intent.attack_pattern, "boomerang");
  assert.equal(adapter.billingSnapshot().disposition, "measured");
});

test("usage pricing is exact, rounded up in the durable micro-USD ledger", () => {
  const priced = calculateAnthropicUsageCost({
    input_tokens: 10,
    output_tokens: 2,
    cache_read_input_tokens: 3,
    cache_creation_input_tokens: 2,
    cache_creation: {
      ephemeral_5m_input_tokens: 1,
      ephemeral_1h_input_tokens: 1,
    },
  });
  assert.equal(priced.microUsd, 24);
  assert.equal(priced.amountUsd, 0.00002355);
  assert.throws(
    () => calculateAnthropicUsageCost({ output_tokens: 1 }),
    (error) => error.code === "invalid_provider_usage",
  );
  assert.throws(
    () => calculateAnthropicUsageCost({
      input_tokens: 1,
      output_tokens: 1,
      cache_creation_input_tokens: 2,
      cache_creation: { ephemeral_5m_input_tokens: 1 },
    }),
    (error) => error.code === "invalid_provider_usage",
  );
});

test("refusal and max_tokens are billed but their content is never compiled", async (t) => {
  for (const [stopReason, expectedCode] of [
    ["refusal", "provider_refusal"],
    ["max_tokens", "provider_output_truncated"],
  ]) {
    await t.test(stopReason, async () => {
      const adapter = new AnthropicWeaponAdapter({
        apiKey: TEST_KEY,
        model: ANTHROPIC_MODEL,
        fetchImpl: async () => jsonResponse(providerMessage({
          stop_reason: stopReason,
          content: [{ type: "text", text: "not trusted" }],
        })),
      });
      await assert.rejects(
        adapter.interpret(interpreterPayload()),
        (error) => error.code === expectedCode,
      );
      assert.equal(adapter.billingSnapshot().disposition, "measured");
      assert.equal(adapter.billingSnapshot().actualMicroUsd, 200);
    });
  }
});

test("HTTP, network and wrapper-retry paths make exactly one native provider call", async (t) => {
  await t.test("HTTP 429", async () => {
    let calls = 0;
    const adapter = new AnthropicWeaponAdapter({
      apiKey: TEST_KEY,
      model: ANTHROPIC_MODEL,
      fetchImpl: async () => {
        calls += 1;
        return jsonResponse({ error: { message: TEST_KEY } }, 429);
      },
    });
    const result = await compileWeapon(interpreterPayload(), {
      adapter,
      maximumAttempts: 2,
    });
    assert.equal(calls, 1);
    assert.equal(result.provider_metadata.attempts, 1);
    assert.equal(result.fallback_reason, "provider_rate_limited");
    assert.equal(adapter.billingSnapshot().disposition, "unknown");
    assert.equal(JSON.stringify(result).includes(TEST_KEY), false);
  });

  await t.test("network failure", async () => {
    let calls = 0;
    const adapter = new AnthropicWeaponAdapter({
      apiKey: TEST_KEY,
      model: ANTHROPIC_MODEL,
      fetchImpl: async () => {
        calls += 1;
        throw new Error(`network ${TEST_KEY}`);
      },
    });
    const result = await compileWeapon(interpreterPayload(), {
      adapter,
      maximumAttempts: 2,
    });
    assert.equal(calls, 1);
    assert.equal(result.fallback_reason, "network_unavailable");
    assert.equal(adapter.billingSnapshot().disposition, "unknown");
    assert.equal(JSON.stringify(result).includes(TEST_KEY), false);
  });
});

test("malformed successful responses fail closed after authoritative usage capture", async (t) => {
  const cases = [
    ["wrong model", { model: "claude-other" }, "provider_model_mismatch", "measured"],
    ["wrong message id", { id: "" }, "invalid_provider_response", "measured"],
    ["multiple blocks", { content: [
      { type: "text", text: JSON.stringify(semanticIntent()) },
      { type: "text", text: "extra" },
    ] }, "invalid_provider_response", "measured"],
    ["unsupported enum", { content: [{
      type: "text",
      text: JSON.stringify({ ...semanticIntent(), element: "void" }),
    }] }, "invalid_provider_response", "measured"],
    ["missing usage", { usage: {} }, "invalid_provider_usage", "unknown"],
  ];
  for (const [name, overrides, code, disposition] of cases) {
    await t.test(name, async () => {
      const adapter = new AnthropicWeaponAdapter({
        apiKey: TEST_KEY,
        model: ANTHROPIC_MODEL,
        fetchImpl: async () => jsonResponse(providerMessage(overrides)),
      });
      await assert.rejects(
        adapter.interpret(interpreterPayload()),
        (error) => error.code === code,
      );
      assert.equal(adapter.billingSnapshot().disposition, disposition);
    });
  }
});

test("successful provider responses are streamed through an explicit byte ceiling", async () => {
  let calls = 0;
  const adapter = new AnthropicWeaponAdapter({
    apiKey: TEST_KEY,
    model: ANTHROPIC_MODEL,
    fetchImpl: async () => {
      calls += 1;
      return new Response("x".repeat(ANTHROPIC_MAX_RESPONSE_BYTES + 1), {
        status: 200,
        headers: { "content-type": "application/json" },
      });
    },
  });
  await assert.rejects(
    adapter.interpret(interpreterPayload()),
    (error) => error.code === "provider_response_too_large",
  );
  assert.equal(calls, 1);
  assert.equal(adapter.billingSnapshot().disposition, "unknown");
});

test("provider resolution allows only the configured Anthropic snapshot", () => {
  const adapter = resolveAdapter({
    WEAPON_AI_PROVIDER: "anthropic",
    WEAPON_AI_MODEL: ANTHROPIC_MODEL,
    ANTHROPIC_API_KEY: TEST_KEY,
  }, { fetchImpl: async () => jsonResponse(providerMessage()) });
  assert.equal(adapter.provider, "anthropic");
  assert.equal(adapter.model, ANTHROPIC_MODEL);
  assert.equal(adapter.maximumAttempts, 1);
  assert.throws(
    () => resolveAdapter({
      WEAPON_AI_PROVIDER: "anthropic",
      WEAPON_AI_MODEL: "claude-sonnet-4-5",
      ANTHROPIC_API_KEY: TEST_KEY,
    }),
    (error) => error.code === "provider_model_mismatch",
  );
  assert.throws(
    () => resolveAdapter({
      WEAPON_AI_PROVIDER: "anthropic",
      WEAPON_AI_MODEL: ANTHROPIC_MODEL,
    }),
    (error) => error.code === "provider_unconfigured",
  );
  assert.throws(
    () => resolveAdapter({ WEAPON_AI_PROVIDER: "openai", WEAPON_AI_MODEL: "anything" }),
    (error) => error.code === "provider_unconfigured",
  );
});
