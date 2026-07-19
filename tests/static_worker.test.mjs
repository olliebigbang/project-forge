import assert from "node:assert/strict";
import test from "node:test";
import worker from "../hosting/static_worker.mjs";

function environment(calls) {
  return {
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

test("adds WebAssembly isolation and cache headers", async () => {
  const calls = [];
  const response = await worker.fetch(new Request("https://forge.example/index.wasm"), environment(calls));
  assert.deepEqual(calls, ["/index.wasm"]);
  assert.equal(response.headers.get("cross-origin-opener-policy"), "same-origin");
  assert.equal(response.headers.get("cross-origin-embedder-policy"), "require-corp");
  assert.equal(response.headers.get("x-content-type-options"), "nosniff");
  assert.match(response.headers.get("cache-control"), /max-age=3600/);
});
