import { createRequire } from "node:module";
import { mkdir, writeFile } from "node:fs/promises";
import { resolve } from "node:path";

const require = createRequire(import.meta.url);
const playwright = require(process.env.PLAYWRIGHT_MODULE_PATH || "playwright");
const [
  browserName = "chromium",
  targetUrl = "http://127.0.0.1:8070/",
  outputRoot = "output/playwright/iphone-input-blocker",
] = process.argv.slice(2);
const browserType = playwright[browserName];
if (!browserType) throw new Error(`Unsupported browser: ${browserName}`);

const VIEWPORT = { width: 844, height: 390 };
const destination = resolve(outputRoot);
await mkdir(destination, { recursive: true });

const assert = (condition, message) => {
  if (!condition) throw new Error(message);
};
const state = (page) => page.evaluate(() => window.__forgeM1B1Test?.state?.() || {});
const controls = (page) => page.evaluate(() => window.__forgeM1B1Test?.controls?.() || {});
const mobile = (page) => page.evaluate(() => window.__forgeM1B1Test?.mobileInput?.() || {});

async function waitFor(page, label, predicate, timeout = 15_000) {
  try {
    await page.waitForFunction(
      ({ source }) => {
        const current = window.__forgeM1B1Test?.state?.();
        return current && Function("current", `return (${source})(current);`)(current);
      },
      { source: predicate.toString() },
      { timeout },
    );
  } catch (error) {
    throw new Error(`${label}: ${JSON.stringify(await state(page))}`, { cause: error });
  }
  return state(page);
}

async function waitForGrowth(page, label, requirements, timeout = 15_000) {
  try {
    await page.waitForFunction(
      ({ expected }) => {
        const current = window.__forgeM1B1Test?.state?.();
        if (!current) return false;
        return expected.every(({ path, value }) => {
          const actual = path.split(".").reduce((entry, key) => entry?.[key], current);
          return Number(actual) > Number(value);
        });
      },
      { expected: requirements },
      { timeout },
    );
  } catch (error) {
    throw new Error(`${label}: ${JSON.stringify(await state(page))}`, { cause: error });
  }
  return state(page);
}

async function send(page, command, payload = {}) {
  const accepted = await page.evaluate(
    ({ name, value }) => {
      if (typeof window.__forgeGodotQaCallback !== "function") return false;
      window.__forgeGodotQaCallback(name, JSON.stringify(value));
      return true;
    },
    { name: command, value: payload },
  );
  assert(accepted, `QA bridge rejected ${command}`);
}

async function tap(page, name) {
  const rect = (await controls(page))[name];
  assert(rect?.width > 0 && rect?.height > 0, `${name} is not actionable`);
  await page.touchscreen.tap(rect.x + rect.width / 2, rect.y + rect.height / 2);
  return rect;
}

const browser = await browserType.launch({ headless: true });
const context = await browser.newContext({
  ...playwright.devices["iPhone 15"],
  viewport: VIEWPORT,
  screen: VIEWPORT,
});
const page = await context.newPage();
const consoleEntries = [];
page.on("console", (message) => consoleEntries.push({ type: message.type(), text: message.text() }));
page.on("pageerror", (error) => consoleEntries.push({ type: "error", text: error.message }));
await page.route("**/api/compile-weapon", (route) => route.abort("blockedbyclient"));

const url = new URL(targetUrl);
url.searchParams.set("qa", "m1b1");
url.searchParams.set("c0", "1");
const report = {
  suite: "iPhone input and viewport blocker regression",
  browser: browserName,
  target: url.href,
  viewport: VIEWPORT,
  provider_calls: 0,
  touch_after_hit: {},
  simultaneous_move_attack: {},
  viewport_restore: {},
  chinese_input: {},
  console_errors: [],
};

try {
  await page.goto(url.href, { waitUntil: "domcontentloaded", timeout: 30_000 });
  await page.waitForFunction(
    () =>
      typeof window.__forgeM1B1Test?.state === "function" &&
      typeof window.__forgeGodotQaCallback === "function",
    null,
    { timeout: 20_000 },
  );
  await waitFor(page, "initial forge", (current) => current.screen === "forge" && current.phase === "idle");

  await send(page, "c0_start_fixture", { length: "standard" });
  await waitFor(page, "combat active", (current) =>
    current.screen === "combat" && current.round_state === "active");
  const firstHit = await waitFor(page, "first non-lethal hit", (current) =>
    current.player_health === 80 && current.enemy_phase === "recovery");
  assert(firstHit.attack_button_disabled === false, "ATTACK disabled after non-lethal hit");
  assert(firstHit.player_combat?.combat_enabled === true, "combat gate closed after non-lethal hit");
  const firstIntent = firstHit.ui_attack_intent_count;
  const firstAttack = firstHit.player_attack_count;
  await tap(page, "attack");
  const firstCounter = await waitForGrowth(page, "touch counterattack", [
    { path: "ui_attack_intent_count", value: firstIntent },
    { path: "player_attack_count", value: firstAttack },
  ], 5_000);
  report.touch_after_hit = {
    player_health: firstHit.player_health,
    ui_intent_before: firstIntent,
    ui_intent_after: firstCounter.ui_attack_intent_count,
    attack_count_before: firstAttack,
    attack_count_after: firstCounter.player_attack_count,
    outcome: firstCounter.held_visual?.last_attack_request_outcome,
  };

  const secondHit = await waitFor(page, "second non-lethal hit", (current) =>
    current.player_health === 60 && current.enemy_phase === "recovery", 12_000);
  const moveRect = (await controls(page)).left;
  const attackRect = (await controls(page)).attack;
  assert(moveRect?.width > 0 && attackRect?.width > 0, "move/attack controls unavailable");
  const secondIntent = secondHit.ui_attack_intent_count;
  const secondAttack = secondHit.player_attack_count;
  await page.mouse.move(moveRect.x + moveRect.width / 2, moveRect.y + moveRect.height / 2);
  await page.mouse.down();
  await page.touchscreen.tap(
    attackRect.x + attackRect.width / 2,
    attackRect.y + attackRect.height / 2,
  );
  const simultaneous = await waitForGrowth(page, "move plus touch ATTACK", [
    { path: "ui_attack_intent_count", value: secondIntent },
    { path: "player_attack_count", value: secondAttack },
  ], 5_000);
  await page.mouse.up();
  report.simultaneous_move_attack = {
    player_health: secondHit.player_health,
    ui_intent_before: secondIntent,
    ui_intent_after: simultaneous.ui_attack_intent_count,
    attack_count_before: secondAttack,
    attack_count_after: simultaneous.player_attack_count,
    outcome: simultaneous.held_visual?.last_attack_request_outcome,
  };

  await page.reload({ waitUntil: "domcontentloaded" });
  await page.waitForFunction(
    () => typeof window.__forgeM1B1Test?.mobileInput === "function",
    null,
    { timeout: 20_000 },
  );
  await waitFor(page, "forge after reload", (current) => current.screen === "forge" && current.phase === "idle");
  const baseline = await mobile(page);
  const input = page.locator("#forge-description-input");
  await page.touchscreen.tap(
    baseline.inputRect.x + baseline.inputRect.width / 2,
    baseline.inputRect.y + baseline.inputRect.height / 2,
  );
  await input.fill("冰冻手榴弹");
  await waitFor(page, "Chinese Description sync", (current) => current.description === "冰冻手榴弹");
  report.chinese_input = {
    dom_value: await input.inputValue(),
    godot_state_value: (await state(page)).description,
  };

  await page.evaluate(() => window.__forgeM1B1Test.setVisualViewport({
    width: 844,
    height: 190,
    offsetLeft: 0,
    offsetTop: 92,
    innerWidth: 844,
    innerHeight: 390,
    scale: 1,
  }));
  await page.waitForFunction(() => window.__forgeM1B1Test.mobileInput().metrics.keyboardOpen === true);
  await page.locator("#forge-description-done").click();
  await page.evaluate(() => window.__forgeM1B1Test.setVisualViewport({
    width: 844,
    height: 390,
    offsetLeft: 0,
    offsetTop: 0,
    innerWidth: 844,
    innerHeight: 390,
    scale: 1,
  }));
  await page.waitForFunction(() =>
    window.__forgeM1B1Test.mobileInput().metrics.textEntryActive === false);
  const restored = await mobile(page);
  const bottom = restored.metrics.canvasRect.y + restored.metrics.canvasRect.height;
  assert(Math.abs(restored.metrics.canvasRect.height - 390) <= 2, "Canvas kept stale keyboard/toolbar height");
  assert(Math.abs(bottom - 390) <= 2, "Canvas bottom does not meet Visual Viewport bottom");
  report.viewport_restore = {
    canvas_rect: restored.metrics.canvasRect,
    visible_height: restored.metrics.height,
    black_strip_px: Math.max(restored.metrics.height - bottom, 0),
    text_entry_active: restored.metrics.textEntryActive,
  };

  const known = (entry) =>
    entry.text.includes("CONTEXT_LOST_WEBGL") ||
    entry.text.includes("GPU stall due to ReadPixels") ||
    entry.text.includes("glBlitFramebuffer") ||
    entry.text.includes("WEBGL_polygon_mode");
  report.console_errors = consoleEntries.filter(
    (entry) => ["error", "warning"].includes(entry.type) && !known(entry),
  );
  assert(report.console_errors.length === 0, `application console failures: ${JSON.stringify(report.console_errors)}`);
  await writeFile(
    resolve(destination, `${browserName}-report.json`),
    JSON.stringify(report, null, 2),
  );
  process.stdout.write(`${JSON.stringify(report, null, 2)}\n`);
} catch (error) {
  await page.screenshot({
    path: resolve(destination, `${browserName}-failure.png`),
    fullPage: true,
  }).catch(() => {});
  await writeFile(
    resolve(destination, `${browserName}-failure.json`),
    JSON.stringify({
      message: error instanceof Error ? error.message : String(error),
      state: await state(page).catch(() => ({})),
      mobile: await mobile(page).catch(() => ({})),
      console: consoleEntries,
    }, null, 2),
  );
  throw error;
} finally {
  await context.close();
  await browser.close();
}
