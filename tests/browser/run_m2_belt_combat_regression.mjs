import { createRequire } from "node:module";
import { mkdir, readFile, writeFile } from "node:fs/promises";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const require = createRequire(import.meta.url);
const playwright = require(process.env.PLAYWRIGHT_MODULE_PATH || "playwright");
const [
  browserName = "chromium",
  targetUrl = "http://127.0.0.1:8074/",
  outputRoot = "output/playwright/m2-belt-combat-spike",
] = process.argv.slice(2);
const browserType = playwright[browserName];
if (!browserType) throw new Error(`Unsupported browser: ${browserName}`);

const scriptDirectory = dirname(fileURLToPath(import.meta.url));
const matrix = JSON.parse(
  await readFile(resolve(scriptDirectory, "../m2_belt_combat_matrix.json"), "utf8"),
);
const destination = resolve(outputRoot, browserName);
await mkdir(destination, { recursive: true });

const assert = (condition, message) => {
  if (!condition) throw new Error(message);
};
const closeTo = (actual, expected, tolerance = 1.5) =>
  Math.abs(Number(actual) - Number(expected)) <= tolerance;
const safeName = (value) => value.replace(/[^a-z0-9_-]+/gi, "-").toLowerCase();
const state = (page) => page.evaluate(() => window.__forgeBeltCombat?.state?.() || {});
const controls = (page) => page.evaluate(() => window.__forgeBeltCombat?.controls?.() || {});
const forgeState = (page) =>
  page.evaluate(() => window.__forgeM1B1Test?.state?.() || {});

async function forgeCommand(page, name, payload = {}) {
  const dispatched = await page.evaluate(
    ({ commandName, commandPayload }) => {
      if (typeof window.__forgeGodotQaCallback !== "function") return false;
      window.__forgeGodotQaCallback(commandName, JSON.stringify(commandPayload));
      return true;
    },
    { commandName: name, commandPayload: payload },
  );
  assert(dispatched, `Forge QA command bridge unavailable for ${name}`);
}

function seriousConsoleEntries(entries) {
  const known = (entry) =>
    entry.text.includes("GPU stall due to ReadPixels") ||
    entry.text.includes("CONTEXT_LOST_WEBGL") ||
    entry.text.includes("glBlitFramebuffer") ||
    entry.text.includes("WEBGL_polygon_mode") ||
    entry.text ===
      "window.styleMedia is a deprecated draft version of window.matchMedia API, and it will be removed in the future.";
  return entries.filter(
    (entry) => ["error", "warning"].includes(entry.type) && !known(entry),
  );
}

async function waitForState(page, label, clauses, timeout = 20_000) {
  try {
    await page.waitForFunction(
      ({ expected }) => {
        const snapshot = window.__forgeBeltCombat?.state?.();
        if (!snapshot) return false;
        const read = (path) =>
          path.split(".").reduce((value, key) => value?.[key], snapshot);
        return expected.every(({ path, operator, value }) => {
          const actual = read(path);
          switch (operator) {
            case "equals": return actual === value;
            case "not_equals": return actual !== value;
            case "greater_than": return Number(actual) > Number(value);
            case "less_than": return Number(actual) < Number(value);
            case "at_least": return Number(actual) >= Number(value);
            case "one_of": return value.includes(actual);
            case "truthy": return Boolean(actual);
            case "falsy": return !actual;
            default: return false;
          }
        });
      },
      { expected: clauses },
      { timeout },
    );
  } catch (error) {
    throw new Error(
      `Timed out waiting for ${label}: ${JSON.stringify(await state(page).catch(() => ({})))}`,
      { cause: error },
    );
  }
  return state(page);
}

async function waitForEvent(page, kind, afterSequence = 0, timeout = 20_000) {
  try {
    await page.waitForFunction(
      ({ eventKind, sequence }) => {
        const events = window.__forgeBeltCombat?.state?.().combat_events || [];
        return events.some(
          (event) => event.kind === eventKind && Number(event.sequence) > sequence,
        );
      },
      { eventKind: kind, sequence: afterSequence },
      { timeout },
    );
  } catch (error) {
    throw new Error(
      `Timed out waiting for event ${kind}: ${JSON.stringify(await state(page).catch(() => ({})))}`,
      { cause: error },
    );
  }
  const snapshot = await state(page);
  return snapshot.combat_events.findLast(
    (event) => event.kind === kind && Number(event.sequence) > afterSequence,
  );
}

async function command(page, name, payload = {}) {
  const dispatched = await page.evaluate(
    ({ commandName, commandPayload }) => {
      if (typeof window.__forgeBeltCombat?.command !== "function") return false;
      window.__forgeBeltCombat.command(commandName, commandPayload);
      return true;
    },
    { commandName: name, commandPayload: payload },
  );
  assert(dispatched, `Belt QA command bridge unavailable for ${name}`);
}

async function settleViewportPaint(page) {
  await page.evaluate(
    () =>
      new Promise((resolve) => {
        requestAnimationFrame(() => requestAnimationFrame(resolve));
      }),
  );
  await page.waitForTimeout(browserName === "webkit" ? 400 : 100);
}

async function tapRect(page, rect, label) {
  assert(rect?.width > 0 && rect?.height > 0, `${label} is not actionable`);
  await page.touchscreen.tap(rect.x + rect.width / 2, rect.y + rect.height / 2);
}

function rectsOverlap(left, right, padding = 0.5) {
  return !(
    left.x + left.width <= right.x + padding ||
    right.x + right.width <= left.x + padding ||
    left.y + left.height <= right.y + padding ||
    right.y + right.height <= left.y + padding
  );
}

function assertLayout(snapshot, viewport, label) {
  const layout = snapshot.layout || {};
  const selectionEntries = [
    ...Object.entries(layout.encounters || {}).map(([id, rect]) => [`encounter:${id}`, rect]),
    ...Object.entries(layout.weapons || {}).map(([id, rect]) => [`weapon:${id}`, rect]),
  ];
  const actionEntries = ["joystick", "attack", "retry", "reforge"].map(
    (id) => [id, layout[id]],
  );
  for (const [id, rect] of [...selectionEntries, ...actionEntries]) {
    assert(
      rect?.width >= 43.5 && rect?.height >= 43.5,
      `${label}: ${id} is below the 44 CSS px target (allowing subpixel serialization)`,
    );
    assert(
      rect.x >= -1 &&
        rect.y >= -1 &&
        rect.x + rect.width <= viewport.width + 1 &&
        rect.y + rect.height <= viewport.height + 1,
      `${label}: ${id} escaped viewport ${JSON.stringify(rect)}`,
    );
  }
  for (let leftIndex = 0; leftIndex < selectionEntries.length; leftIndex += 1) {
    for (let rightIndex = leftIndex + 1; rightIndex < selectionEntries.length; rightIndex += 1) {
      const [leftId, leftRect] = selectionEntries[leftIndex];
      const [rightId, rightRect] = selectionEntries[rightIndex];
      assert(
        !rectsOverlap(leftRect, rightRect),
        `${label}: ${leftId} overlaps ${rightId}`,
      );
    }
  }
  for (let leftIndex = 0; leftIndex < actionEntries.length; leftIndex += 1) {
    for (let rightIndex = leftIndex + 1; rightIndex < actionEntries.length; rightIndex += 1) {
      const [leftId, leftRect] = actionEntries[leftIndex];
      const [rightId, rightRect] = actionEntries[rightIndex];
      assert(
        !rectsOverlap(leftRect, rightRect),
        `${label}: ${leftId} overlaps ${rightId}`,
      );
    }
  }
  assert(
    !rectsOverlap(layout.joystick, layout.attack),
    `${label}: joystick overlaps ATTACK`,
  );
}

async function dispatchDomTouch(page, type, touches, changedTouches) {
  await page.evaluate(
    ({ eventType, active, changed }) => {
      const target = document.querySelector("canvas");
      if (!target) throw new Error("Godot Canvas missing");
      const touchInit = (point) => ({
        identifier: point.id,
        target,
        clientX: point.x,
        clientY: point.y,
        screenX: point.x,
        screenY: point.y,
        pageX: point.x,
        pageY: point.y,
        radiusX: 8,
        radiusY: 8,
        force: 1,
      });
      let event;
      try {
        const makeTouch = (point) => new Touch(touchInit(point));
        const activeTouches = active.map(makeTouch);
        const changedTouchList = changed.map(makeTouch);
        event = new TouchEvent(eventType, {
          bubbles: true,
          cancelable: true,
          composed: true,
          touches: activeTouches,
          targetTouches: activeTouches,
          changedTouches: changedTouchList,
        });
      } catch {
        // Playwright WebKit exposes TouchEvent but deliberately makes Touch
        // non-constructible. Emscripten consumes the standard coordinate
        // fields, so define those lists on a cancellable Event.
        const activeTouches = active.map(touchInit);
        const changedTouchList = changed.map(touchInit);
        event = new Event(eventType, {
          bubbles: true,
          cancelable: true,
          composed: true,
        });
        Object.defineProperties(event, {
          touches: { value: activeTouches },
          targetTouches: { value: activeTouches },
          changedTouches: { value: changedTouchList },
        });
      }
      target.dispatchEvent(event);
    },
    { eventType: type, active: touches, changed: changedTouches },
  );
}

async function exerciseConcurrentTouch(page, label) {
  await command(page, "fixture", { id: "moving" });
  await command(page, "weapon", { pattern: "straight_projectile" });
  await command(page, "pause_enemies", { enabled: false });
  const initial = await waitForState(page, `${label} fixture`, [
    { path: "fixture", operator: "equals", value: "moving" },
    { path: "weapon_pattern", operator: "equals", value: "straight_projectile" },
  ]);
  const ui = await controls(page);
  const joystick = ui.joystick;
  const attack = ui.attack;
  assert(joystick?.width >= 44 && joystick?.height >= 44, `${label}: joystick rect missing`);
  const center = {
    id: 1,
    x: joystick.x + joystick.width / 2,
    y: joystick.y + joystick.height / 2,
  };
  const diagonal = {
    id: 1,
    x: center.x + joystick.width * 0.31,
    y: center.y - joystick.height * 0.27,
  };
  const attackPoint = {
    id: 2,
    x: attack.x + attack.width / 2,
    y: attack.y + attack.height / 2,
  };

  await dispatchDomTouch(page, "touchstart", [center], [center]);
  await dispatchDomTouch(page, "touchmove", [diagonal], [diagonal]);
  const moved = await waitForState(page, `${label} diagonal joystick`, [
    { path: "touch.x", operator: "greater_than", value: 0.25 },
    { path: "touch.y", operator: "less_than", value: -0.20 },
  ]);
  await page.waitForFunction(
    ({ x, y }) => {
      const player = window.__forgeBeltCombat?.state?.().player;
      return (
        Math.abs(Number(player?.position?.x) - x) > 2 &&
        Math.abs(Number(player?.position?.y) - y) > 2
      );
    },
    { x: initial.player.position.x, y: initial.player.position.y },
    { timeout: 10_000 },
  );
  const positionBeforeAttack = (await state(page)).player.position;
  const sequenceBefore = moved.event_sequence;
  await dispatchDomTouch(
    page,
    "touchstart",
    [diagonal, attackPoint],
    [attackPoint],
  );
  await waitForEvent(page, "attack_committed", sequenceBefore);
  const concurrent = await state(page);
  assert(
    concurrent.touch.x > 0.25 && concurrent.touch.y < -0.20,
    `${label}: ATTACK cancelled joystick vector`,
  );
  await page.waitForFunction(
    ({ x, y }) => {
      const snapshot = window.__forgeBeltCombat?.state?.();
      return (
        snapshot?.touch?.x > 0.25 &&
        snapshot?.touch?.y < -0.20 &&
        (Math.abs(Number(snapshot?.player?.position?.x) - x) > 2 ||
          Math.abs(Number(snapshot?.player?.position?.y) - y) > 2)
      );
    },
    { x: positionBeforeAttack.x, y: positionBeforeAttack.y },
    { timeout: 10_000 },
  );
  await dispatchDomTouch(page, "touchend", [diagonal], [attackPoint]);
  const positionAfterAttackRelease = (await state(page)).player.position;
  await page.waitForFunction(
    ({ x, y }) => {
      const snapshot = window.__forgeBeltCombat?.state?.();
      return (
        snapshot?.touch?.x > 0.25 &&
        (Math.abs(Number(snapshot?.player?.position?.x) - x) > 2 ||
          Math.abs(Number(snapshot?.player?.position?.y) - y) > 2)
      );
    },
    { x: positionAfterAttackRelease.x, y: positionAfterAttackRelease.y },
    { timeout: 10_000 },
  );
  await dispatchDomTouch(page, "touchend", [], [diagonal]);
  const released = await waitForState(page, `${label} joystick release`, [
    { path: "touch.x", operator: "equals", value: 0 },
    { path: "touch.y", operator: "equals", value: 0 },
  ]);
  return {
    joystick_rect: joystick,
    diagonal_vector: moved.touch,
    attack_count: released.accepted_attack_count,
    movement_continued_with_attack: true,
    movement_continued_after_attack_release: true,
    release_zeroed: true,
  };
}

const report = {
  suite: "M2 Belt Combat Spike provider-free browser regression",
  browser: browserName,
  target: targetUrl,
  provider_claim: "NO PROVIDER CALLS - compile/provider routes are blocked and counted",
  device_claim:
    "AUTOMATED BROWSER EMULATION ONLY - M2B-19 physical iPhone comparison remains TO VALIDATE",
  captured_at: new Date().toISOString(),
  entry: {},
  viewports: [],
  fixtures: [],
  weapons: [],
  lifecycle: {},
  simulation_equivalence: {},
  console_errors: [],
};

const browser = await browserType.launch({ headless: true });

async function runIsolatedCase(caseName, viewport, body) {
  const context = await browser.newContext({
    ...playwright.devices["iPhone 15"],
    viewport,
    screen: viewport,
    hasTouch: true,
  });
  await context.tracing.start({ screenshots: true, snapshots: true, sources: true });
  const page = await context.newPage();
  const providerCalls = [];
  const consoleEntries = [];
  page.on("console", (message) =>
    consoleEntries.push({ type: message.type(), text: message.text() }),
  );
  page.on("pageerror", (error) =>
    consoleEntries.push({ type: "error", text: error.message }),
  );
  for (const routePattern of ["**/api/compile-weapon", "**/v1/messages"]) {
    await page.route(routePattern, async (route) => {
      providerCalls.push(route.request().url());
      await route.abort("blockedbyclient");
    });
  }
  try {
    const result = await body(page);
    assert(providerCalls.length === 0, `${caseName}: provider route called`);
    const serious = seriousConsoleEntries(consoleEntries);
    assert(
      serious.length === 0,
      `${caseName}: application console failures ${JSON.stringify(serious)}`,
    );
    report.console_errors.push(...serious);
    await context.tracing.stop();
    await context.close();
    return result;
  } catch (error) {
    const id = safeName(caseName);
    await page
      .screenshot({
        path: join(destination, `${browserName}-${id}-failure.png`),
        fullPage: true,
      })
      .catch(() => {});
    await context.tracing
      .stop({ path: join(destination, `${browserName}-${id}-trace.zip`) })
      .catch(() => {});
    await writeFile(
      join(destination, `${browserName}-${id}-failure.json`),
      JSON.stringify(
        {
          case: caseName,
          message: error instanceof Error ? error.message : String(error),
          stack: error instanceof Error ? error.stack : "",
          state: await state(page).catch(() => ({})),
          provider_calls: providerCalls,
          console: consoleEntries,
        },
        null,
        2,
      ),
    );
    await context.close();
    throw error;
  }
}

async function openBelt(page) {
  const url = new URL(targetUrl);
  url.searchParams.set("qa", "m2belt");
  await page.goto(url.href, { waitUntil: "domcontentloaded", timeout: 30_000 });
  await page.waitForFunction(
    () =>
      typeof window.__forgeBeltCombat?.state === "function" &&
      typeof window.__forgeBeltCombat?.controls === "function" &&
      typeof window.__forgeBeltCombat?.command === "function",
    null,
    { timeout: 20_000 },
  );
  return waitForState(page, "belt route", [
    { path: "screen", operator: "equals", value: "belt_combat" },
    { path: "round_state", operator: "equals", value: "active" },
  ]);
}

report.entry = await runIsolatedCase(
  "explicit-prototype-entry",
  { width: 844, height: 390 },
  async (page) => {
    const defaultUrl = new URL(targetUrl);
    defaultUrl.searchParams.set("qa", "m1b1");
    await page.goto(defaultUrl.href, { waitUntil: "domcontentloaded", timeout: 30_000 });
    await page.waitForFunction(
      () => typeof window.__forgeM1B1Test?.state === "function",
      null,
      { timeout: 20_000 },
    );
    await page.waitForFunction(
      () => window.__forgeM1B1Test?.state?.().screen === "forge",
      null,
      { timeout: 20_000 },
    );
    assert(
      typeof (await page.evaluate(() => window.__forgeBeltCombat)) === "undefined",
      "default route unexpectedly installed belt prototype",
    );
    await forgeCommand(page, "c0_start_fixture", { length: "standard" });
    await page.waitForFunction(
      () => window.__forgeM1B1Test?.state?.().screen === "combat",
      null,
      { timeout: 20_000 },
    );
    await forgeCommand(page, "c0_reforge");
    await page.waitForFunction(
      () => {
        const snapshot = window.__forgeM1B1Test?.state?.();
        return (
          snapshot?.screen === "forge" &&
          Number(snapshot?.drawing_count) > 0 &&
          String(snapshot?.description || "").length > 0
        );
      },
      null,
      { timeout: 20_000 },
    );
    const preservedBefore = await forgeState(page);
    await forgeCommand(page, "belt_spike_enter");
    await page.waitForFunction(
      () =>
        window.__forgeBeltCombat?.state?.().screen === "belt_combat" &&
        window.__forgeBeltCombat?.state?.().round_state === "active",
      null,
      { timeout: 20_000 },
    );
    await command(page, "reforge");
    await page.waitForFunction(
      ({ description, drawingCount }) => {
        const snapshot = window.__forgeM1B1Test?.state?.();
        return (
          snapshot?.screen === "forge" &&
          snapshot?.description === description &&
          Number(snapshot?.drawing_count) === Number(drawingCount)
        );
      },
      {
        description: preservedBefore.description,
        drawingCount: preservedBefore.drawing_count,
      },
      { timeout: 20_000 },
    );
    const preservedAfter = await forgeState(page);
    await openBelt(page);
    const screenshot = join(destination, `${browserName}-explicit-belt-entry.png`);
    await page.screenshot({ path: screenshot });
    return {
      default_route: "forge",
      explicit_route: "?qa=m2belt",
      explicit_screen: "belt_combat",
      forge_input_continuity: {
        description: preservedAfter.description,
        drawing_count: preservedAfter.drawing_count,
        preserved: true,
      },
      screenshot,
    };
  },
);

for (const viewport of matrix.viewports) {
  const result = await runIsolatedCase(
    `viewport-${viewport.width}x${viewport.height}`,
    { width: viewport.width, height: viewport.height },
    async (page) => {
      const initial = await openBelt(page);
      assert(!initial.viewport.portrait, `${viewport.id}: landscape detected as portrait`);
      assert(initial.viewport.compact, `${viewport.id}: compact layout was not selected`);
      assert(initial.y_sort_enabled, `${viewport.id}: battlefield Y sort is disabled`);
      assertLayout(initial, viewport, viewport.id);
      const landscapeScreenshot = join(
        destination,
        `${browserName}-${viewport.width}x${viewport.height}.png`,
      );
      await page.screenshot({ path: landscapeScreenshot });

      const touchEvidence =
        viewport.width === 844
          ? await exerciseConcurrentTouch(page, viewport.id)
          : { covered_by: "844x390 real multi-touch case" };

      await page.setViewportSize({ width: viewport.height, height: viewport.width });
      const portrait = await waitForState(page, `${viewport.id} portrait gate`, [
        { path: "viewport.portrait", operator: "equals", value: true },
        { path: "player.combat_enabled", operator: "equals", value: false },
        { path: "touch.x", operator: "equals", value: 0 },
        { path: "touch.y", operator: "equals", value: 0 },
      ]);
      await settleViewportPaint(page);
      let portraitCaptureMode = "live viewport transition";
      if (browserName === "webkit") {
        // Playwright WebKit's headless WebGL surface is black after an in-place
        // viewport resize even while the game state continues to update. Keep
        // the live transition assertions above, then reload at the same size
        // to collect independent visual evidence. Physical Safari remains the
        // authority for the combined transition-and-render gate.
        await page.reload({ waitUntil: "domcontentloaded" });
        await waitForState(page, `${viewport.id} portrait fresh render`, [
          { path: "viewport.portrait", operator: "equals", value: true },
          { path: "player.combat_enabled", operator: "equals", value: false },
        ]);
        await settleViewportPaint(page);
        portraitCaptureMode = "fresh WebKit render after live state transition";
      }
      const portraitScreenshot = join(
        destination,
        `${browserName}-${viewport.width}x${viewport.height}-portrait.png`,
      );
      await page.screenshot({ path: portraitScreenshot });
      assert(portrait.viewport.portrait, `${viewport.id}: portrait gate absent`);

      await page.setViewportSize({ width: viewport.width, height: viewport.height });
      const restored = await waitForState(page, `${viewport.id} landscape restore`, [
        { path: "viewport.portrait", operator: "equals", value: false },
        { path: "player.combat_enabled", operator: "equals", value: true },
      ]);
      await settleViewportPaint(page);
      assertLayout(restored, viewport, `${viewport.id} restored`);
      return {
        id: viewport.id,
        viewport: { width: viewport.width, height: viewport.height },
        complete_room: true,
        developer_controls_inside_and_non_overlapping: true,
        y_sort_enabled: restored.y_sort_enabled,
        portrait_gate: true,
        portrait_capture_mode: portraitCaptureMode,
        landscape_restored: true,
        touch: touchEvidence,
        screenshots: [landscapeScreenshot, portraitScreenshot],
      };
    },
  );
  report.viewports.push(result);
}

await runIsolatedCase(
  "toolbar-layout",
  { width: 844, height: 390 },
  async (page) => {
    await openBelt(page);
    await page.setViewportSize({ width: 844, height: 343 });
    const toolbar = await waitForState(page, "toolbar compact layout", [
      { path: "viewport.css_width", operator: "equals", value: 844 },
      { path: "viewport.css_height", operator: "equals", value: 343 },
      { path: "viewport.portrait", operator: "equals", value: false },
      { path: "layout.encounters.group.width", operator: "greater_than", value: 43.5 },
      { path: "layout.encounters.group.height", operator: "greater_than", value: 43.5 },
      { path: "layout.joystick.y", operator: "less_than", value: 250 },
    ]);
    await settleViewportPaint(page);
    let toolbarCaptureMode = "live viewport transition";
    if (browserName === "webkit") {
      await page.reload({ waitUntil: "domcontentloaded" });
      await waitForState(page, "toolbar fresh WebKit render", [
        { path: "viewport.css_width", operator: "equals", value: 844 },
        { path: "viewport.css_height", operator: "equals", value: 343 },
        { path: "viewport.portrait", operator: "equals", value: false },
      ]);
      await settleViewportPaint(page);
      toolbarCaptureMode = "fresh WebKit render after live state transition";
    }
    assertLayout(toolbar, { width: 844, height: 343 }, "toolbar layout");
    const screenshot = join(destination, `${browserName}-toolbar-844x343.png`);
    await page.screenshot({ path: screenshot });
    report.toolbar = {
      viewport: { width: 844, height: 343 },
      controls_inside_and_non_overlapping: true,
      capture_mode: toolbarCaptureMode,
      screenshot,
    };
  },
);

await runIsolatedCase(
  "fixtures-weapons-lifecycle",
  { width: 844, height: 390 },
  async (page) => {
    await openBelt(page);

    for (const fixture of matrix.fixtures) {
      const before = await state(page);
      await command(page, "fixture", { id: fixture });
      const reset = await waitForState(page, `${fixture} fixture reset`, [
        { path: "fixture", operator: "equals", value: fixture },
        { path: "round_state", operator: "equals", value: "active" },
        { path: "active_transient_count", operator: "equals", value: 0 },
        { path: "cleanup.player_attack_active", operator: "equals", value: false },
        { path: "cleanup.held_visible", operator: "equals", value: true },
        { path: "touch.x", operator: "equals", value: 0 },
        { path: "touch.y", operator: "equals", value: 0 },
        { path: "round_generation", operator: "greater_than", value: before.round_generation },
      ]);
      const expectedCount = fixture === "group" ? 3 : 1;
      assert(reset.enemies.length === expectedCount, `${fixture}: wrong enemy count`);
      assert(
        reset.enemies.every((enemy) => enemy.kind === fixture),
        `${fixture}: leaked enemy from another fixture`,
      );
      report.fixtures.push({
        fixture,
        enemy_count: reset.enemies.length,
        independent_reset: true,
        cleanup: reset.cleanup,
      });
    }

    async function stageGroup(pattern, grenadeEllipse = false) {
      await command(page, "fixture", { id: "group" });
      await command(page, "pause_enemies", { enabled: false });
      const snapshot = await waitForState(page, `${pattern} group stage`, [
        { path: "fixture", operator: "equals", value: "group" },
      ]);
      const arena = snapshot.arena_bounds;
      const playerPosition = {
        x: arena.x + Math.min(100, arena.width * 0.12),
        y: arena.y + arena.height * 0.5,
      };
      await command(page, "set_player", playerPosition);
      const projectileLaneY = playerPosition.y - Math.min(52, arena.height * 0.12);
      const positions = grenadeEllipse
        ? [
            { x: playerPosition.x + 200, y: projectileLaneY },
            { x: playerPosition.x + 250, y: projectileLaneY + 18 },
            { x: playerPosition.x + 200, y: Math.min(arena.y + arena.height, projectileLaneY + 130) },
          ]
        : (pattern === "melee_slash" ? [80, 140, 200] : [200, 260, 320]).map((offset) => ({
            x: playerPosition.x + offset,
            y: pattern === "melee_slash" ? playerPosition.y : projectileLaneY,
          }));
      for (let index = 0; index < snapshot.enemies.length; index += 1) {
        await command(page, "set_enemy", {
          id: snapshot.enemies[index].id,
          ...positions[index],
          simulation_enabled: false,
        });
      }
      await command(page, "weapon", { pattern });
      return waitForState(page, `${pattern} equipped`, [
        { path: "weapon_pattern", operator: "equals", value: pattern },
        { path: "player.assist_target", operator: "truthy" },
      ]);
    }

    for (const weaponCase of matrix.weapon_cases) {
      const pattern = weaponCase.attack_pattern;
      const staged = await stageGroup(pattern, pattern === "area_blast");
      const beforeSequence = staged.event_sequence;
      const beforeCount = staged.accepted_attack_count;
      await command(page, "attack");
      if (pattern === "boomerang") {
        await command(page, "attack");
        await command(page, "attack");
      }
      await waitForEvent(page, "attack_committed", beforeSequence);
      let terminalEvent;
      if (pattern === "melee_slash") {
        terminalEvent = await waitForEvent(page, "enemy_damaged", beforeSequence);
      } else if (pattern === "area_blast") {
        await waitForEvent(page, "area_impact", beforeSequence);
        terminalEvent = await waitForEvent(page, "blast_hits", beforeSequence);
        await waitForState(page, "grenade visible ground ellipse", [
          { path: "blasts.0.elapsed", operator: "greater_than", value: 0.25 },
          { path: "blasts.0.damage_applied", operator: "equals", value: true },
        ]);
        const impactScreenshot = join(
          destination,
          `${browserName}-weapon-grenade-impact.png`,
        );
        await page.screenshot({ path: impactScreenshot });
        terminalEvent.visual_evidence = impactScreenshot;
      } else {
        terminalEvent = await waitForEvent(page, "projectile_finished", beforeSequence);
      }
      const settled = await waitForState(page, `${pattern} settled`, [
        { path: "active_transient_count", operator: "equals", value: 0 },
        { path: "cleanup.player_attack_active", operator: "equals", value: false },
        { path: "cleanup.held_visible", operator: "equals", value: true },
      ], 30_000);
      const committed = settled.combat_events.filter(
        (event) => event.kind === "attack_committed" && event.sequence > beforeSequence,
      );
      assert(committed.length === 1, `${pattern}: one input created ${committed.length} commits`);
      const damage = settled.damage_events.filter(
        (event) => event.target !== "player",
      );
      const evidence = {
        id: weaponCase.id,
        pattern,
        role_id: settled.weapon_role.role_id,
        accepted_delta: settled.accepted_attack_count - beforeCount,
        damage,
        terminal_event: terminalEvent,
      };
      if (pattern === "melee_slash") {
        assert(damage.length === 1, "melee did not stop at one body");
        evidence.path_kind = "forward_depth_contact";
        evidence.depth_width = 40;
      } else {
        const finished = settled.combat_events.findLast(
          (event) =>
            event.kind === "projectile_finished" &&
            event.sequence > beforeSequence,
        );
        const finalState = finished?.final_state || {};
        assert(
          Array.isArray(finalState.path_samples) && finalState.path_samples.length >= 2,
          `${pattern}: two-dimensional path samples missing`,
        );
        evidence.path_samples = finalState.path_samples;
        evidence.phase_events = finalState.phase_events || [];
        evidence.hit_records = finalState.hit_records || [];
        if (pattern === "straight_projectile") {
          assert(damage.length === 1, "Bow did not stop at first body");
        }
        if (pattern === "piercing") {
          const hits = settled.combat_events
            .filter(
              (event) =>
                event.kind === "projectile_hit" &&
                event.sequence > beforeSequence,
            )
            .map(({ hit_index, multiplier, amount }) => ({
              hit_index,
              multiplier,
              amount,
            }));
          assert(
            JSON.stringify(hits) ===
              JSON.stringify([
                { hit_index: 1, multiplier: 1, amount: 29 },
                { hit_index: 2, multiplier: 0.7, amount: 20 },
                { hit_index: 3, multiplier: 0.45, amount: 13 },
              ]),
            `Piercing damage schedule drifted ${JSON.stringify(hits)}`,
          );
          assert(
            settled.weapon_role.movement_locked_during_startup,
            "Piercing startup lock contract missing",
          );
        }
        if (pattern === "boomerang") {
          assert(
            settled.accepted_attack_count - beforeCount === 1,
            "Boomerang overlapping activation was accepted",
          );
          assert(
            evidence.phase_events.some((event) => event.phase === "return"),
            "Boomerang return phase was not observed",
          );
        }
        if (pattern === "area_blast") {
          const blast = settled.combat_events.findLast(
            (event) => event.kind === "blast_hits" && event.sequence > beforeSequence,
          );
          assert(blast?.blast_state?.shape === "ground_ellipse", "Grenade ground ellipse missing");
          assert(
            blast.blast_state.radii.x > blast.blast_state.radii.y,
            "Grenade ground ellipse lost depth compression",
          );
          assert(
            settled.combat_events.some(
              (event) => event.kind === "area_impact" && event.sequence > beforeSequence,
            ),
            "Grenade landing phase missing",
          );
          const damagedTargets = [...new Set(damage.map((event) => event.target))];
          assert(
            blast.count === 2 &&
              damagedTargets.length === 2 &&
              !damagedTargets.includes("group_c"),
            `Grenade ellipse target set drifted ${JSON.stringify({ count: blast.count, damagedTargets })}`,
          );
          evidence.ground_ellipse = blast.blast_state;
          evidence.direct_blast_targets = damagedTargets;
        }
      }
      report.weapons.push(evidence);
      await page.screenshot({
        path: join(destination, `${browserName}-weapon-${weaponCase.id}.png`),
      });
    }

    // Bow remains first-body and shield-blocked; Piercing bypasses the same shield.
    async function runShield(pattern) {
      await command(page, "fixture", { id: "shield" });
      const staged = await waitForState(page, `${pattern} shield fixture`, [
        { path: "fixture", operator: "equals", value: "shield" },
        { path: "enemies.0.id", operator: "equals", value: "shield_guard" },
      ]);
      await command(page, "pause_enemies", { enabled: false });
      const arena = staged.arena_bounds;
      const position = { x: arena.x + 100, y: arena.y + arena.height * 0.5 };
      await command(page, "set_player", position);
      await command(page, "set_enemy", {
        id: staged.enemies[0].id,
        x: position.x + 150,
        y: position.y,
        simulation_enabled: false,
      });
      await command(page, "weapon", { pattern });
      await page.waitForFunction(
        ({ expectedPattern, playerPosition, enemyPosition }) => {
          const snapshot = window.__forgeBeltCombat?.state?.();
          const enemy = snapshot?.enemies?.find((entry) => entry.id === "shield_guard");
          return (
            snapshot?.weapon_pattern === expectedPattern &&
            snapshot?.player?.assist_target === "shield_guard" &&
            Math.abs(Number(snapshot?.player?.position?.x) - playerPosition.x) <= 1.5 &&
            Math.abs(Number(snapshot?.player?.position?.y) - playerPosition.y) <= 1.5 &&
            Math.abs(Number(enemy?.position?.x) - enemyPosition.x) <= 1.5 &&
            Math.abs(Number(enemy?.position?.y) - enemyPosition.y) <= 1.5 &&
            enemy?.simulation_enabled === false
          );
        },
        {
          expectedPattern: pattern,
          playerPosition: position,
          enemyPosition: { x: position.x + 150, y: position.y },
        },
        { timeout: 10_000 },
      );
      const before = await state(page);
      await command(page, "attack");
      await waitForEvent(page, "enemy_damaged", before.event_sequence);
      return waitForState(page, `${pattern} shield cleanup`, [
        { path: "active_transient_count", operator: "equals", value: 0 },
        { path: "cleanup.player_attack_active", operator: "equals", value: false },
      ]);
    }
    const bowShield = await runShield("straight_projectile");
    const bowDamage = bowShield.damage_events.find((event) => event.target !== "player");
    assert(
      bowDamage.amount === 6 && bowDamage.note.startsWith("SHIELD BLOCK"),
      "Bow shield block drifted",
    );
    const piercingShield = await runShield("piercing");
    const piercingDamage = piercingShield.damage_events.find((event) => event.target !== "player");
    assert(
      piercingDamage.amount === 29 && piercingDamage.note !== "SHIELD BLOCK",
      "Piercing did not bypass shield",
    );
    report.shield_rules = {
      bow: bowDamage,
      piercing: piercingDamage,
    };

    // Deterministic assist selects the nearest live target and drops a dead target.
    const assistStage = await stageGroup("straight_projectile");
    const nearest = assistStage.enemies[0].id;
    await waitForState(page, "nearest assist", [
      { path: "player.assist_target", operator: "equals", value: nearest },
    ]);
    await command(page, "set_enemy_health", { id: nearest, health: 0 });
    const retargeted = await waitForState(page, "dead target removed from assist", [
      { path: "player.assist_target", operator: "not_equals", value: nearest },
    ]);
    assert(retargeted.player.assist_target, "assist did not choose a remaining live target");
    report.auto_facing = {
      initial_target: nearest,
      retargeted_to: retargeted.player.assist_target,
      dead_target_ignored: true,
    };

    // Boundary clamping and explicit X/Y state.
    const bounds = retargeted.player.movement_bounds;
    await command(page, "set_player", { x: -10000, y: -10000 });
    await page.waitForFunction(
      ({ x, y }) => {
        const position = window.__forgeBeltCombat?.state?.().player?.position;
        return (
          Math.abs(Number(position?.x) - x) <= 1.5 &&
          Math.abs(Number(position?.y) - y) <= 1.5
        );
      },
      { x: bounds.left, y: bounds.top },
      { timeout: 10_000 },
    );
    const topLeft = await state(page);
    assert(
      closeTo(topLeft.player.position.x, bounds.left) &&
        closeTo(topLeft.player.position.y, bounds.top),
      "top-left bounds clamp failed",
    );
    await command(page, "set_player", { x: 10000, y: 10000 });
    await page.waitForFunction(
      ({ x, y }) => {
        const position = window.__forgeBeltCombat?.state?.().player?.position;
        return (
          Math.abs(Number(position?.x) - x) <= 1.5 &&
          Math.abs(Number(position?.y) - y) <= 1.5
        );
      },
      { x: bounds.right, y: bounds.bottom },
      { timeout: 10_000 },
    );
    const bottomRight = await state(page);
    assert(
      closeTo(bottomRight.player.position.x, bounds.right) &&
        closeTo(bottomRight.player.position.y, bounds.bottom),
      "bottom-right bounds clamp failed",
    );
    report.movement = {
      x_y_observed_by_joystick: true,
      bounded_top_left: topLeft.player.position,
      bounded_bottom_right: bottomRight.player.position,
      y_sort_enabled: bottomRight.y_sort_enabled,
    };

    // Terminal state blocks combat, Retry preserves fixture/weapon, Reforge cleans.
    await command(page, "fixture", { id: "moving" });
    await command(page, "weapon", { pattern: "straight_projectile" });
    const terminalFixture = await waitForState(page, "terminal fixture stage", [
      { path: "fixture", operator: "equals", value: "moving" },
      { path: "weapon_pattern", operator: "equals", value: "straight_projectile" },
      { path: "round_state", operator: "equals", value: "active" },
      { path: "player.health", operator: "equals", value: 100 },
    ]);
    await command(page, "damage_player", { amount: 100 });
    const defeat = await waitForState(page, "defeat", [
      { path: "round_state", operator: "equals", value: "defeat" },
      { path: "active_transient_count", operator: "equals", value: 0 },
      { path: "cleanup.player_attack_active", operator: "equals", value: false },
      { path: "touch.x", operator: "equals", value: 0 },
      { path: "touch.y", operator: "equals", value: 0 },
    ]);
    const attacksAtDefeat = defeat.accepted_attack_count;
    await command(page, "attack");
    await page.evaluate(
      () =>
        new Promise((resolveFrames) => {
          let frames = 8;
          const next = () => {
            frames -= 1;
            if (frames === 0) resolveFrames();
            else requestAnimationFrame(next);
          };
          requestAnimationFrame(next);
        }),
    );
    assert((await state(page)).accepted_attack_count === attacksAtDefeat, "defeat accepted damage/attack");
    await tapRect(page, (await controls(page)).retry, "Retry");
    const retry = await waitForState(page, "Retry", [
      { path: "round_state", operator: "equals", value: "active" },
      { path: "fixture", operator: "equals", value: terminalFixture.fixture },
      { path: "weapon_pattern", operator: "equals", value: terminalFixture.weapon_pattern },
      { path: "player.health", operator: "equals", value: 100 },
      { path: "active_transient_count", operator: "equals", value: 0 },
    ]);
    await command(page, "damage_player", { amount: 100 });
    const preReforge = await waitForState(page, "pre-Reforge defeat cleanup", [
      { path: "round_state", operator: "equals", value: "defeat" },
      { path: "active_transient_count", operator: "equals", value: 0 },
      { path: "cleanup.player_attack_active", operator: "equals", value: false },
      { path: "touch.x", operator: "equals", value: 0 },
      { path: "touch.y", operator: "equals", value: 0 },
    ]);
    await command(page, "reforge");
    await page.waitForFunction(
      () => new URLSearchParams(location.search).get("qa") !== "m2belt",
      null,
      { timeout: 20_000 },
    );
    assert(
      new URL(page.url()).searchParams.get("qa") !== "m2belt",
      "Reforge did not leave the explicit prototype route",
    );
    report.lifecycle = {
      defeat_blocks_attacks: true,
      retry_same_fixture: retry.fixture,
      retry_same_weapon: retry.weapon_pattern,
      retry_health: retry.player.health,
      reforge_requested: true,
      reforge_route_removed: true,
      cleanup: preReforge.cleanup,
      forge_input_continuity: {
        description_preserved: true,
        drawing_preserved: true,
        evidence: report.entry.forge_input_continuity,
      },
    };

    // Real browser physics profiles: same staged Bow hit, terminal state and cleanup.
    await openBelt(page);
    const simulationResults = [];
    for (const profile of matrix.simulation_profiles.filter((entry) => !entry.long_frame_seconds)) {
      await command(page, "simulate_profile", { fps: profile.physics_hz });
      const staged = await runShield("straight_projectile");
      await waitForState(page, `${profile.id} cleanup`, [
        { path: "active_transient_count", operator: "equals", value: 0 },
        { path: "cleanup.player_attack_active", operator: "equals", value: false },
      ]);
      simulationResults.push({
        id: profile.id,
        physics_hz: staged.physics_ticks_per_second,
        enemy_damage_events: staged.damage_events.filter((event) => event.target !== "player").length,
        damage: staged.damage_events
          .filter((event) => event.target !== "player")
          .reduce((sum, event) => sum + event.amount, 0),
        terminal_state: staged.round_state,
        active_transients: staged.active_transient_count,
      });
    }
    const digests = simulationResults.map(({ enemy_damage_events, damage, terminal_state, active_transients }) =>
      JSON.stringify({ enemy_damage_events, damage, terminal_state, active_transients }));
    assert(new Set(digests).size === 1, `30/60/120 browser outcomes diverged ${JSON.stringify(simulationResults)}`);
    report.simulation_equivalence = {
      profiles: simulationResults,
      equivalent: true,
      bounded_long_frame:
        "Not asserted through browser wall-clock control. The dedicated Godot suite compares one 0.12s projectile step against twelve 0.01s steps for hit count, damage, terminal state and cleanup.",
    };
  },
);

try {
  assert(report.console_errors.length === 0, "application console errors were recorded");
  assert(report.viewports.length === 3, "three landscape viewports were not executed");
  assert(report.fixtures.length === 3, "three fixtures were not executed");
  assert(report.weapons.length === 5, "five weapon paths were not executed");
  await writeFile(
    join(destination, `${browserName}-report.json`),
    JSON.stringify(report, null, 2),
  );
  console.log(JSON.stringify(report, null, 2));
} catch (error) {
  report.failure = {
    message: error instanceof Error ? error.message : String(error),
    stack: error instanceof Error ? error.stack : "",
  };
  await writeFile(
    join(destination, `${browserName}-failure-report.json`),
    JSON.stringify(report, null, 2),
  );
  throw error;
} finally {
  await browser.close();
}
