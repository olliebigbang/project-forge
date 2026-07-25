import { spawn } from "node:child_process";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const [
  browserName = "chromium",
  port = "8070",
  output = "output/playwright/core-combat-c0",
] = process.argv.slice(2);
const repository = resolve(dirname(fileURLToPath(import.meta.url)), "../..");
const target = `http://127.0.0.1:${port}/`;
const server = spawn(
  process.execPath,
  [resolve(repository, "scripts/serve_web.mjs"), "--root", resolve(repository, "build/web"), "--port", port],
  { cwd: repository, stdio: ["ignore", "pipe", "pipe"] },
);

const ready = new Promise((resolveReady, rejectReady) => {
  let outputText = "";
  const deadline = setTimeout(
    () => rejectReady(new Error(`Web server readiness timed out: ${outputText}`)),
    15_000,
  );
  server.stdout.on("data", (chunk) => {
    outputText += chunk.toString();
    if (outputText.includes("Project Forge Web preview:")) {
      clearTimeout(deadline);
      resolveReady();
    }
  });
  server.stderr.on("data", (chunk) => {
    outputText += chunk.toString();
  });
  server.once("error", (error) => {
    clearTimeout(deadline);
    rejectReady(error);
  });
  server.once("exit", (code) => {
    if (code !== null) {
      clearTimeout(deadline);
      rejectReady(new Error(`Web server exited before readiness (${code}): ${outputText}`));
    }
  });
});

try {
  await ready;
  const test = spawn(
    process.execPath,
    [resolve(repository, "tests/browser/run_core_combat_c0_regression.mjs"), browserName, target, output],
    { cwd: repository, env: process.env, stdio: "inherit" },
  );
  const exitCode = await new Promise((resolveExit, rejectExit) => {
    test.once("error", rejectExit);
    test.once("exit", (code) => resolveExit(code ?? 1));
  });
  if (exitCode !== 0) process.exitCode = exitCode;
} finally {
  server.kill();
}
