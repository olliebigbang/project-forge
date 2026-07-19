import assert from "node:assert/strict";
import test from "node:test";

test("reconstructs the requested WASM response from two ordered chunks", async () => {
  const originalWindow = globalThis.window;
  const originalLocation = globalThis.location;
  const originalFetch = globalThis.fetch;
  const calls = [];

  globalThis.window = globalThis;
  globalThis.location = new URL("https://forge.example/");
  globalThis.fetch = async (input) => {
    const path = new URL(String(input)).pathname;
    calls.push(path);
    if (path.endsWith(".part0")) return new Response(Uint8Array.from([0x00, 0x61]));
    if (path.endsWith(".part1")) return new Response(Uint8Array.from([0x73, 0x6d]));
    throw new Error(`Unexpected URL ${path}`);
  };

  try {
    await import(`../hosting/wasm_chunk_loader.js?test=${Date.now()}`);
    const response = await globalThis.fetch("https://forge.example/index.wasm");
    assert.deepEqual(calls, ["/index.wasm.part0", "/index.wasm.part1"]);
    assert.equal(response.headers.get("content-type"), "application/wasm");
    assert.deepEqual(Array.from(new Uint8Array(await response.arrayBuffer())), [0x00, 0x61, 0x73, 0x6d]);
  } finally {
    globalThis.fetch = originalFetch;
    globalThis.window = originalWindow;
    globalThis.location = originalLocation;
  }
});

