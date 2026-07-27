import { spawn } from "node:child_process";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const [
  browser = "chromium",
  port = "8074",
  output = "output/playwright/m2-belt-combat-spike",
] = process.argv.slice(2);
const repository = resolve(dirname(fileURLToPath(import.meta.url)), "../..");
const target = `http://127.0.0.1:${port}/`;

const server = spawn(
  process.execPath,
  [
    resolve(repository, "scripts/serve_web.mjs"),
    "--root",
    resolve(repository, "build/web"),
    "--port",
    port,
  ],
  { cwd: repository, stdio: ["ignore", "pipe", "pipe"] },
);

async function waitUntilReady() {
  const deadline = Date.now() + 15_000;
  let lastError;
  while (Date.now() < deadline) {
    if (server.exitCode !== null) {
      throw new Error(`Web server exited before readiness (${server.exitCode})`);
    }
    try {
      const response = await fetch(target, { cache: "no-store" });
      if (response.ok) return;
      lastError = new Error(`HTTP ${response.status}`);
    } catch (error) {
      lastError = error;
    }
    await new Promise((resolvePoll) => setTimeout(resolvePoll, 50));
  }
  throw new Error(`Web server did not become ready: ${lastError?.message || "unknown error"}`);
}

try {
  await waitUntilReady();
  const test = spawn(
    process.execPath,
    [
      resolve(repository, "tests/browser/run_m2_belt_combat_regression.mjs"),
      browser,
      target,
      output,
    ],
    { cwd: repository, env: process.env, stdio: "inherit" },
  );
  const exitCode = await new Promise((resolveExit, reject) => {
    test.once("error", reject);
    test.once("exit", (code) => resolveExit(code ?? 1));
  });
  if (exitCode !== 0) process.exitCode = exitCode;
} finally {
  server.kill();
}
