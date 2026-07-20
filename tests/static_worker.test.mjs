import assert from "node:assert/strict";
import test from "node:test";
import worker from "../hosting/static_worker.mjs";

function environment(calls) {
  return {
    // Local deterministic interpretation is test-only and must be explicit;
    // production Sites configuration is pinned to Anthropic.
    WEAPON_AI_PROVIDER: "deterministic",
    ASSETS: {
      async fetch(request) {
        calls.push(new URL(request.url).pathname);
        return new Response("asset", {
          status: 200,
          headers: { "content-type": "text/html; charset=utf-8" },
        });
      },
    },
  };
}

test("rewrites the site root to the Godot index", async () => {
  const calls = [];
  const response = await worker.fetch(new Request("https://forge.example/"), environment(calls));
  assert.deepEqual(calls, ["/index.html"]);
  assert.equal(response.status, 200);
  assert.equal(await response.text(), "asset");
});

test("adds WebAssembly isolation and revalidates stable Godot runtime names", async () => {
  const calls = [];
  const response = await worker.fetch(new Request("https://forge.example/index.wasm"), environment(calls));
  assert.deepEqual(calls, ["/index.wasm"]);
  assert.equal(response.headers.get("cross-origin-opener-policy"), "same-origin");
  assert.equal(response.headers.get("cross-origin-embedder-policy"), "require-corp");
  assert.equal(response.headers.get("x-content-type-options"), "nosniff");
  assert.equal(response.headers.get("cache-control"), "no-cache, must-revalidate");
});

test("does not cache the HTML entry point", async () => {
  const response = await worker.fetch(
    new Request("https://forge.example/index.html"),
    environment([]),
  );
  assert.equal(response.headers.get("cache-control"), "no-store");
});

test("routes same-origin weapon compilation through the server boundary", async () => {
  const payload = {
    description: "a returning ice umbrella",
    drawing_summary: { stroke_count: 2, point_count: 18, aspect_ratio: 1.8, coverage: 0.3 },
    locale: "en",
    request_id: "worker-route-1",
    supported_attack_patterns: ["melee_slash", "straight_projectile", "boomerang", "area_blast", "piercing"],
    supported_elements: ["normal", "fire", "ice", "electric"],
    supported_abilities: ["none", "knockback_burst", "chain_arc", "return_strike", "splash_wave", "shield_break"],
    maximum_power_score: 100,
  };
  const response = await worker.fetch(new Request("https://forge.example/api/compile-weapon", {
    method: "POST",
    headers: {
      "content-type": "application/json",
      origin: "https://forge.example",
      "x-forge-session": "88888888888888888888888888888888",
    },
    body: JSON.stringify(payload),
  }), environment([]));
  assert.equal(response.status, 200);
  assert.equal(response.headers.get("cross-origin-opener-policy"), "same-origin");
  assert.equal(response.headers.get("cache-control"), "no-store");
  const body = await response.json();
  assert.equal(body.weapon_spec.attack_pattern, "boomerang");
  assert.equal(body.weapon_spec.element, "ice");
  assert.equal(body.runtime_valid, true);
});
