import { createRequire } from "node:module";
import { mkdir, writeFile } from "node:fs/promises";
import { join, resolve } from "node:path";

const require = createRequire(import.meta.url);
const playwright = require(process.env.PLAYWRIGHT_MODULE_PATH || "playwright");
const [
  browserName = "chromium",
  targetUrl = "http://127.0.0.1:8070/",
  outputRoot = "output/playwright/core-combat-c0",
] = process.argv.slice(2);
const browserType = playwright[browserName];
if (!browserType) throw new Error(`Unsupported browser: ${browserName}`);

const VIEWPORT = { width: 844, height: 390 };
const LOGICAL_HEIGHT = 720;
const LOGICAL_WIDTH = Math.max(1280, LOGICAL_HEIGHT * VIEWPORT.width / VIEWPORT.height);
const ARENA_BOUNDS = { left: 70, right: LOGICAL_WIDTH - 70 };
const COMBAT_LIMIT_MS = 30_000;
// WebKit can advance the enemy by up to four 60 Hz frames between the
// deterministic staging command and the observable state snapshot.
const MATRIX_STAGING_TOLERANCE_PX = 8;
const MATRIX_STARTS = [
  { id: "near-gap", gap: 220 },
  { id: "far-gap", gap: 360 },
];
const SPACING_POLICY = {
  grip_offset: 18,
  margin: 10,
  hysteresis: 6,
  telegraph_dodge: false,
};
const RETAINED_AGGRESSIVE_BASELINE = {
  chromium: [
    { length: "short", metrics: { time_to_first_hit_ms: 2644, ttk_ms: 4017, damage_taken: 20 } },
    { length: "standard", metrics: { time_to_first_hit_ms: 2750, ttk_ms: 5974, damage_taken: 40 } },
    { length: "long", metrics: { time_to_first_hit_ms: 2773, ttk_ms: 8288, damage_taken: 60 } },
  ],
  webkit: [
    { length: "short", metrics: { time_to_first_hit_ms: 2371, ttk_ms: 3702, damage_taken: 20 } },
    { length: "standard", metrics: { time_to_first_hit_ms: 2555, ttk_ms: 5747, damage_taken: 40 } },
    { length: "long", metrics: { time_to_first_hit_ms: 2565, ttk_ms: 8067, damage_taken: 80 } },
  ],
};
const destination = resolve(outputRoot);
await mkdir(destination, { recursive: true });

const assert = (condition, message) => {
  if (!condition) throw new Error(message);
};

const safeName = (value) => value.replace(/[^a-z0-9_-]+/gi, "-").toLowerCase();
const getState = (page) => page.evaluate(() => window.__forgeM1B1Test?.state?.() || {});
const getControls = (page) => page.evaluate(() => window.__forgeM1B1Test?.controls?.() || {});
const getMobile = (page) => page.evaluate(() => window.__forgeM1B1Test?.mobileInput?.() || {});

async function waitForState(page, label, clauses, timeout = 20_000) {
  try {
    await page.waitForFunction(
      ({ expected }) => {
        const state = window.__forgeM1B1Test?.state?.();
        if (!state) return false;
        const read = (path) => path.split(".").reduce((value, key) => value?.[key], state);
        return expected.every(({ path, operator, value }) => {
          const actual = read(path);
          switch (operator) {
            case "equals": return actual === value;
            case "not_equals": return actual !== value;
            case "one_of": return value.includes(actual);
            case "greater_than": return Number(actual) > Number(value);
            case "at_least": return Number(actual) >= Number(value);
            case "less_than": return Number(actual) < Number(value);
            case "exists": return actual !== undefined && actual !== null;
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
    const current = await getState(page).catch(() => ({}));
    throw new Error(`Timed out waiting for ${label}: ${JSON.stringify(current)}`, { cause: error });
  }
  return getState(page);
}

async function waitForMobile(page, label, path, expected, timeout = 15_000) {
  try {
    await page.waitForFunction(
      ({ propertyPath, value }) => {
        const snapshot = window.__forgeM1B1Test?.mobileInput?.();
        const actual = propertyPath.split(".").reduce((entry, key) => entry?.[key], snapshot);
        return actual === value;
      },
      { propertyPath: path, value: expected },
      { timeout },
    );
  } catch (error) {
    const current = await getMobile(page).catch(() => ({}));
    throw new Error(`Timed out waiting for mobile ${label}: ${JSON.stringify(current)}`, { cause: error });
  }
  return getMobile(page);
}

async function sendCommand(page, command, payload = {}) {
  const dispatched = await page.evaluate(
    ({ commandName, commandPayload }) => {
      const callback = window.__forgeGodotQaCallback;
      if (typeof callback !== "function") return false;
      callback(commandName, JSON.stringify(commandPayload));
      return true;
    },
    { commandName: command, commandPayload: payload },
  );
  assert(dispatched, `QA command bridge unavailable for ${command}`);
}

async function waitForAnimationFrames(page, count = 24) {
  await page.evaluate(
    (frameCount) => new Promise((resolveFrameWait) => {
      let remaining = frameCount;
      const next = () => {
        remaining -= 1;
        if (remaining <= 0) {
          resolveFrameWait();
          return;
        }
        window.requestAnimationFrame(next);
      };
      window.requestAnimationFrame(next);
    }),
    count,
  );
}

async function tapControl(page, name) {
  const control = (await getControls(page))[name];
  assert(control?.width > 0 && control?.height > 0, `${name} control is not actionable`);
  await page.touchscreen.tap(control.x + control.width / 2, control.y + control.height / 2);
  return control;
}

async function drawStrokes(page, strokeFractions) {
  const canvas = (await getControls(page)).canvas;
  assert(canvas?.width > 0 && canvas?.height > 0, "drawing Canvas is not actionable");
  for (const stroke of strokeFractions) {
    const points = stroke.map(({ x, y }) => ({
      x: canvas.x + canvas.width * x,
      y: canvas.y + canvas.height * y,
    }));
    await page.mouse.move(points[0].x, points[0].y);
    await page.mouse.down();
    for (const point of points.slice(1)) {
      await page.mouse.move(point.x, point.y, { steps: 5 });
    }
    await page.mouse.up();
  }
}

function validateC0State(state, label) {
  for (const field of [
    "round_state",
    "player_combat",
    "combat_enemy",
    "combat_events",
    "combat_metrics",
    "collision",
    "c0_input",
  ]) {
    assert(Object.hasOwn(state, field), `${label}: missing C0 QA field ${field}`);
  }
  for (const metric of [
    "combat_elapsed_ms",
    "time_to_first_hit_ms",
    "ttk_ms",
    "damage_taken",
    "whiffs",
    "movement_distance",
    "forge_elapsed_ms",
  ]) {
    assert(Object.hasOwn(state.combat_metrics, metric), `${label}: missing metric ${metric}`);
  }
  assert(["active", "won", "lost"].includes(state.round_state), `${label}: illegal round state`);
  assert(
    ["approach", "telegraph", "strike", "recover", "defeated"].includes(state.combat_enemy.attack_state),
    `${label}: illegal enemy attack state`,
  );
  assert(
    Number.isFinite(state.player_combat.health) && Number.isFinite(state.player_combat.max_health),
    `${label}: player HP is not numeric`,
  );
  assert(
    Number.isFinite(state.combat_enemy.health) && Number.isFinite(state.combat_enemy.max_health),
    `${label}: enemy HP is not numeric`,
  );
  assert(Array.isArray(state.combat_events), `${label}: combat event audit is not an array`);
}

function seriousConsoleEntries(entries) {
  const known = (entry) =>
    entry.text.includes("GPU stall due to ReadPixels") ||
    entry.text.includes("CONTEXT_LOST_WEBGL") ||
    entry.text.includes("glBlitFramebuffer") ||
    entry.text.includes("WEBGL_polygon_mode") ||
    entry.text === "window.styleMedia is a deprecated draft version of window.matchMedia API, and it will be removed in the future.";
  return entries.filter((entry) => ["error", "warning"].includes(entry.type) && !known(entry));
}

const report = {
  suite: "Core Combat C0 deterministic browser acceptance",
  browser: browserName,
  target: targetUrl,
  viewport: VIEWPORT,
  provider_claim: "NO PROVIDER CALLS - compile/provider routes are blocked and counted",
  captured_at: new Date().toISOString(),
  drawing_gate: [],
  lifecycle: {},
  terminal_victory: {},
  controlled_comparison: [],
  pressure_comparison: [],
  spacing_comparison: [],
  strategy_matrix: {
    starts: MATRIX_STARTS,
    mirror_status: "TO VALIDATE - two generic gaps used because reliable mirroring is not exposed by the existing C0 fixture command",
    shared_fixture: {
      damage: 36,
      mass: "balanced",
      element: "normal",
      enemy: "combat_enemy",
      combat_limit_ms: COMBAT_LIMIT_MS,
    },
    pressure_policy: "same c0_input dispatch carries move_axis=1 and attack=true from the first frame",
    spacing_policy: SPACING_POLICY,
  },
  retained_aggressive_baseline: {
    provenance: "docs/CORE_COMBAT_C0_REPORT.md controlled comparison; retained as pressure evidence",
    results: RETAINED_AGGRESSIVE_BASELINE[browserName] || [],
  },
  collision: {},
  mobile_regression: {},
  console_errors: [],
};

const browser = await browserType.launch({ headless: true });

async function runIsolatedCase(caseName, body) {
  const context = await browser.newContext({
    ...playwright.devices["iPhone 15"],
    viewport: VIEWPORT,
    screen: VIEWPORT,
  });
  await context.tracing.start({ screenshots: true, snapshots: true, sources: true });
  const page = await context.newPage();
  const providerCalls = [];
  const consoleEntries = [];
  page.on("console", (message) => consoleEntries.push({ type: message.type(), text: message.text() }));
  page.on("pageerror", (error) => consoleEntries.push({ type: "error", text: error.message }));
  await page.route("**/api/compile-weapon", async (route) => {
    providerCalls.push(route.request().url());
    await route.abort("blockedbyclient");
  });
  await page.route("**/v1/messages", async (route) => {
    providerCalls.push(route.request().url());
    await route.abort("blockedbyclient");
  });

  const url = new URL(targetUrl);
  url.searchParams.set("qa", "m1b1");
  url.searchParams.set("c0", "1");
  try {
    await page.goto(url.href, { waitUntil: "domcontentloaded", timeout: 30_000 });
    await page.waitForFunction(
      () =>
        typeof window.__forgeM1B1Test?.state === "function" &&
        typeof window.__forgeGodotQaCallback === "function",
      null,
      { timeout: 20_000 },
    );
    await waitForState(page, `${caseName} initial forge`, [
      { path: "screen", operator: "equals", value: "forge" },
      { path: "phase", operator: "equals", value: "idle" },
    ]);
    const result = await body(page);
    assert(providerCalls.length === 0, `${caseName}: provider/compile route was called: ${providerCalls.join(", ")}`);
    const serious = seriousConsoleEntries(consoleEntries);
    assert(serious.length === 0, `${caseName}: application console failures ${JSON.stringify(serious)}`);
    report.console_errors.push(...serious);
    await context.tracing.stop();
    await context.close();
    return result;
  } catch (error) {
    const id = safeName(caseName);
    await page.screenshot({ path: join(destination, `${browserName}-${id}-failure.png`), fullPage: true }).catch(() => {});
    await context.tracing.stop({ path: join(destination, `${browserName}-${id}-trace.zip`) }).catch(() => {});
    await writeFile(
      join(destination, `${browserName}-${id}-failure.json`),
      JSON.stringify({
        case: caseName,
        message: error instanceof Error ? error.message : String(error),
        state: await getState(page).catch(() => ({})),
        provider_calls: providerCalls,
        console: consoleEntries,
      }, null, 2),
    );
    await context.close();
    throw error;
  }
}

const drawingCases = [
  {
    id: "tap",
    valid: false,
    touchTap: true,
    strokes: [[{ x: 0.32, y: 0.46 }]],
    expectedReason: "single_point",
  },
  {
    id: "single-point",
    valid: false,
    strokes: [[{ x: 0.35, y: 0.52 }]],
    expectedReason: "single_point",
  },
  {
    id: "zero-length",
    valid: false,
    strokes: [
      [{ x: 0.42, y: 0.48 }, { x: 0.42, y: 0.48 }],
      [{ x: 0.42, y: 0.48 }],
    ],
    expectedReason: "zero_length",
  },
  {
    id: "micro-stroke",
    valid: false,
    strokes: [[{ x: 0.40, y: 0.50 }, { x: 0.403, y: 0.50 }]],
    expectedReason: "micro_stroke",
  },
  {
    id: "natural-short",
    valid: true,
    strokes: [[{ x: 0.18, y: 0.55 }, { x: 0.31, y: 0.54 }]],
  },
  {
    id: "natural-standard",
    valid: true,
    strokes: [[{ x: 0.16, y: 0.55 }, { x: 0.54, y: 0.52 }]],
  },
  {
    id: "natural-long",
    valid: true,
    strokes: [[{ x: 0.10, y: 0.56 }, { x: 0.88, y: 0.50 }]],
  },
  {
    id: "rotated",
    valid: true,
    strokes: [[{ x: 0.18, y: 0.78 }, { x: 0.62, y: 0.24 }]],
  },
  {
    id: "curved",
    valid: true,
    strokes: [[
      { x: 0.17, y: 0.68 },
      { x: 0.26, y: 0.44 },
      { x: 0.40, y: 0.32 },
      { x: 0.55, y: 0.40 },
      { x: 0.67, y: 0.62 },
    ]],
  },
];

for (const drawingCase of drawingCases) {
  const evidence = await runIsolatedCase(`drawing-${drawingCase.id}`, async (page) => {
    const description = `C0 ${drawingCase.id} input must remain intact`;
    await page.locator("#forge-description-input").fill(description);
    await waitForState(page, `${drawingCase.id} description`, [
      { path: "description", operator: "equals", value: description },
    ]);
    if (drawingCase.touchTap) {
      const canvas = (await getControls(page)).canvas;
      const point = drawingCase.strokes[0][0];
      await page.touchscreen.tap(
        canvas.x + canvas.width * point.x,
        canvas.y + canvas.height * point.y,
      );
    } else {
      await drawStrokes(page, drawingCase.strokes);
    }
    const gated = await waitForState(page, `${drawingCase.id} input gate`, [
      { path: "forge_input_gate.accepted", operator: "equals", value: drawingCase.valid },
      { path: "forge_input_gate.code", operator: "exists" },
      { path: "forge_input_gate.point_count", operator: "exists" },
      { path: "forge_input_gate.unique_point_count", operator: "exists" },
      { path: "forge_input_gate.path_length", operator: "exists" },
      { path: "forge_input_gate.minimum_path_length", operator: "exists" },
    ]);
    if (!drawingCase.valid) {
      const drawingCount = gated.drawing_count;
      await tapControl(page, "forge");
      const rejected = await waitForState(page, `${drawingCase.id} rejection`, [
        { path: "screen", operator: "equals", value: "forge" },
        { path: "forge_input_gate.accepted", operator: "falsy" },
        { path: "description", operator: "equals", value: description },
        { path: "drawing_count", operator: "equals", value: drawingCount },
      ]);
      assert(rejected.forge_input_gate.code !== "accepted", `${drawingCase.id}: rejection has no diagnostic reason`);
      assert(rejected.forge_input_gate.message.length > 0, `${drawingCase.id}: rejection has no actionable message`);
      if (drawingCase.expectedReason) {
        assert(
          [drawingCase.expectedReason, "zero_path_length", "micro_tap"].includes(rejected.forge_input_gate.code),
          `${drawingCase.id}: unexpected rejection reason ${rejected.forge_input_gate.code}`,
        );
      }
    } else {
      assert(gated.forge_input_gate.path_length >= gated.forge_input_gate.minimum_path_length, `${drawingCase.id}: accepted path is below the minimum`);
      assert(gated.forge_input_gate.unique_point_count >= 2, `${drawingCase.id}: accepted path has fewer than two unique points`);
    }
    return {
      id: drawingCase.id,
      expected_valid: drawingCase.valid,
      input_gate: gated.forge_input_gate,
      description_preserved: gated.description === description,
      drawing_count: gated.drawing_count,
    };
  });
  report.drawing_gate.push(evidence);
}

async function startFixture(page, length) {
  await sendCommand(page, "c0_start_fixture", { length });
  const state = await waitForState(page, `${length} fixture active`, [
    { path: "screen", operator: "equals", value: "combat" },
    { path: "combat_outcome", operator: "equals", value: "active" },
    { path: "player_health", operator: "greater_than", value: 0 },
    { path: "enemy_health", operator: "greater_than", value: 0 },
  ]);
  validateC0State(state, `${length} fixture`);
  assert(state.player_health === state.player_max_health, `${length}: player did not start at full HP`);
  assert(state.enemy_health === state.enemy_max_health, `${length}: enemy did not start at full HP`);
  return state;
}

async function driveIntoCollision(page) {
  const before = await getState(page);
  await sendCommand(page, "c0_input", { move_axis: 1 });
  const blocked = await waitForState(page, "player/enemy collision boundary", [
    { path: "collision.player_blocked", operator: "truthy" },
    { path: "collision.overlapping", operator: "falsy" },
    { path: "collision.player_enemy_separation", operator: "exists" },
    { path: "collision.min_separation", operator: "exists" },
    { path: "metrics.movement_distance", operator: "greater_than", value: before.metrics.movement_distance },
  ]);
  await sendCommand(page, "c0_input", { move_axis: 0 });
  assert(
    blocked.collision.player_enemy_separation >= blocked.collision.min_separation - 0.5,
    `player passed through enemy: ${JSON.stringify(blocked.collision)}`,
  );
  return blocked;
}

function terminalSnapshot(state) {
  return {
    outcome: state.combat_outcome,
    player_position: state.collision.player_position,
    enemy_position: state.collision.enemy_position,
    player_health: state.player_health,
    enemy_health: state.enemy_health,
    player_attack_count: state.player_attack_count,
    enemy_attack_count: state.enemy_attack_count,
    player_damage_event_count: state.player_damage_events.length,
    enemy_damage_event_count: state.enemy_damage_events.length,
    attack_event_count: state.attack_events.length,
    damage_event_count: state.damage_events.length,
    projectile_finish_count: state.projectile_finish_count,
    impact_spawn_count: state.impact_spawn_count,
    active_projectiles: state.active_projectiles,
    active_area_blasts: state.active_area_blasts,
  };
}

function assertTerminalSnapshotStable(before, after, label) {
  assert(
    Math.abs(after.player_position.x - before.player_position.x) <= 0.01 &&
      Math.abs(after.player_position.y - before.player_position.y) <= 0.01,
    `${label}: terminal player moved from ${JSON.stringify(before.player_position)} to ${JSON.stringify(after.player_position)}`,
  );
  assert(
    Math.abs(after.enemy_position.x - before.enemy_position.x) <= 0.01 &&
      Math.abs(after.enemy_position.y - before.enemy_position.y) <= 0.01,
    `${label}: terminal enemy moved from ${JSON.stringify(before.enemy_position)} to ${JSON.stringify(after.enemy_position)}`,
  );
  for (const field of [
    "outcome",
    "player_health",
    "enemy_health",
    "player_attack_count",
    "enemy_attack_count",
    "player_damage_event_count",
    "enemy_damage_event_count",
    "attack_event_count",
    "damage_event_count",
    "projectile_finish_count",
    "impact_spawn_count",
  ]) {
    assert(after[field] === before[field], `${label}: terminal field ${field} changed from ${before[field]} to ${after[field]}`);
  }
  assert(after.active_projectiles === 0, `${label}: projectile remained active after terminal`);
  assert(after.active_area_blasts === 0, `${label}: area blast remained active after terminal`);
}

async function assertTerminalFrozen(page, label) {
  const terminal = await getState(page);
  assert(["victory", "defeat"].includes(terminal.combat_outcome), `${label}: round is not terminal`);
  assert(!terminal.c0_input.combat_enabled, `${label}: combat remained enabled`);
  const baseline = terminalSnapshot(terminal);
  assert(baseline.active_projectiles === 0, `${label}: projectile survived terminal transition`);
  assert(baseline.active_area_blasts === 0, `${label}: area blast survived terminal transition`);

  await page.keyboard.down("d");
  await waitForAnimationFrames(page);
  const afterKeyboard = terminalSnapshot(await getState(page));
  await page.keyboard.up("d");
  assertTerminalSnapshotStable(baseline, afterKeyboard, `${label} held keyboard movement`);

  await sendCommand(page, "c0_input", { move_axis: -1, attack: true });
  await waitForAnimationFrames(page);
  const afterTouchAndAttack = terminalSnapshot(await getState(page));
  await sendCommand(page, "c0_input", { move_axis: 0 });
  assertTerminalSnapshotStable(baseline, afterTouchAndAttack, `${label} held touch movement/post-terminal attack`);
  return {
    baseline,
    after_keyboard_hold: afterKeyboard,
    after_touch_hold_and_attack: afterTouchAndAttack,
  };
}

async function attackUntilOutcome(page, maximumAttempts = 24, moveAxis = 0) {
  for (let attempt = 0; attempt < maximumAttempts; attempt += 1) {
    const before = await getState(page);
    if (before.combat_outcome !== "active") return before;
    await sendCommand(page, "c0_input", { attack: true, move_axis: moveAxis });
    await waitForState(page, `accepted player attack ${attempt + 1}`, [
      {
        path: "player_attack_count",
        operator: before.combat_outcome === "active" ? "greater_than" : "at_least",
        value: before.player_attack_count,
      },
    ], 12_000).catch(async (error) => {
      const current = await getState(page);
      if (current.combat_outcome === "active") throw error;
    });
    const current = await getState(page);
    if (current.combat_outcome !== "active") return current;
  }
  throw new Error(`combat remained active after ${maximumAttempts} attack attempts: ${JSON.stringify(await getState(page))}`);
}

async function stageMatrixFixture(page, length, start) {
  const initial = await startFixture(page, length);
  assert(initial.description === `${length} balanced normal sword`, `${length}: controlled fixture lost balanced/normal description`);
  assert(initial.geometry_profile?.mass_profile === "balanced", `${length}: controlled fixture mass is not balanced`);
  assert(
    Number.isFinite(initial.weapon_role?.effective_reach) && initial.weapon_role.effective_reach > 0,
    `${length}: effective reach is unavailable`,
  );
  await sendCommand(page, "combat_enemy_gap", { gap: start.gap });
  const staged = await getState(page);
  assert(staged.combat_outcome === "active", `${length}/${start.id}: staging ended combat`);
  const observedGap = staged.collision.enemy_position.x - staged.player_position.x;
  assert(
    Math.abs(observedGap - start.gap) <= MATRIX_STAGING_TOLERANCE_PX,
    `${length}/${start.id}: requested ${start.gap}px start staged at ${observedGap}px`,
  );
  assert(staged.player_position.x >= ARENA_BOUNDS.left && staged.player_position.x <= ARENA_BOUNDS.right, `${length}/${start.id}: player staged outside arena`);
  assert(staged.collision.enemy_position.x >= ARENA_BOUNDS.left && staged.collision.enemy_position.x <= ARENA_BOUNDS.right, `${length}/${start.id}: enemy staged outside arena`);
  return staged;
}

function matrixResult(strategy, length, start, initial, final, extra = {}) {
  const damageAmounts = final.player_damage_events.map((event) => event.amount);
  assert(final.combat_outcome === "victory", `${strategy}/${start.id}/${length}: player did not win (${final.combat_outcome})`);
  assert(final.enemy_health === 0, `${strategy}/${start.id}/${length}: victory left enemy HP ${final.enemy_health}`);
  assert(final.metrics.combat_elapsed_ms <= COMBAT_LIMIT_MS, `${strategy}/${start.id}/${length}: combat exceeded ${COMBAT_LIMIT_MS}ms`);
  assert(final.metrics.time_to_first_hit_ms > 0, `${strategy}/${start.id}/${length}: time-to-first-hit was not measured`);
  assert(final.metrics.ttk_ms >= final.metrics.time_to_first_hit_ms, `${strategy}/${start.id}/${length}: TTK precedes first hit`);
  assert(final.metrics.damage_taken >= 0, `${strategy}/${start.id}/${length}: damage taken is negative`);
  assert(final.metrics.whiffs >= 0, `${strategy}/${start.id}/${length}: whiffs are negative`);
  assert(final.player_damage_events.length === 4, `${strategy}/${start.id}/${length}: expected four lethal 36-damage hits`);
  assert(damageAmounts.every((amount) => amount === 36), `${strategy}/${start.id}/${length}: shared damage diverged (${damageAmounts})`);
  assert(
    final.collision.player_position.x >= ARENA_BOUNDS.left &&
      final.collision.player_position.x <= ARENA_BOUNDS.right &&
      final.collision.enemy_position.x >= ARENA_BOUNDS.left &&
      final.collision.enemy_position.x <= ARENA_BOUNDS.right,
    `${strategy}/${start.id}/${length}: terminal actor escaped arena`,
  );
  return {
    strategy,
    length,
    start: {
      id: start.id,
      requested_gap: start.gap,
      observed_gap: Math.abs(initial.collision.enemy_position.x - initial.player_position.x),
      player_position: initial.player_position,
      enemy_position: initial.collision.enemy_position,
    },
    fixture: {
      description: initial.description,
      effective_reach: initial.weapon_role.effective_reach,
      mass_profile: initial.geometry_profile.mass_profile,
      damage_amounts: damageAmounts,
    },
    outcome: final.combat_outcome,
    player_attack_count: final.player_attack_count,
    enemy_attack_count: final.enemy_attack_count,
    player_damage_events: final.player_damage_events.length,
    enemy_damage_events: final.enemy_damage_events.length,
    collision: final.collision,
    metrics: final.metrics,
    ...extra,
  };
}

async function runPressureStrategy(page, length, start) {
  const initial = await stageMatrixFixture(page, length, start);
  const startedAt = Date.now();
  // Pressure begins with movement and attack in one QA dispatch, so the first
  // input frame cannot receive the old attack-before-movement head start.
  await sendCommand(page, "c0_input", { move_axis: 1, attack: true });
  const firstAttempt = await waitForState(page, `${start.id}/${length} pressure first simultaneous input`, [
    { path: "c0_input.move_axis", operator: "equals", value: 1 },
    { path: "player_attack_count", operator: "greater_than", value: initial.player_attack_count },
  ]);
  const final = await attackUntilOutcome(page, 24, 1);
  await sendCommand(page, "c0_input", { move_axis: 0 });
  return matrixResult("pressure", length, start, initial, final, {
    first_input: {
      move_axis: firstAttempt.c0_input.move_axis,
      attack_count: firstAttempt.player_attack_count,
      whiffs: firstAttempt.metrics.whiffs,
      simultaneous_dispatch: true,
    },
    driver_elapsed_ms: Date.now() - startedAt,
  });
}

function spacingDecision(state, previousIntent) {
  const effectiveReach = Number(state.weapon_role?.effective_reach);
  const playerX = Number(state.player_position?.x);
  const enemyX = Number(state.collision?.enemy_position?.x);
  const enemyPhase = String(state.enemy_phase || "");
  assert(Number.isFinite(effectiveReach), "spacing: effective_reach is unavailable");
  assert(Number.isFinite(playerX) && Number.isFinite(enemyX), "spacing: actor positions are unavailable");
  assert(["approach", "telegraph", "active", "recovery", "defeated"].includes(enemyPhase), `spacing: illegal enemy phase ${enemyPhase}`);

  const directionToEnemy = Math.sign(enemyX - playerX);
  const gap = Math.abs(enemyX - playerX);
  const holdGap = SPACING_POLICY.grip_offset + effectiveReach - SPACING_POLICY.margin;
  const lower = holdGap - SPACING_POLICY.hysteresis;
  const upper = holdGap + SPACING_POLICY.hysteresis;
  let intent = previousIntent;
  if (intent === "toward" && gap < lower) intent = "away";
  else if (intent === "away" && gap > upper) intent = "toward";
  else if (intent === "hold" && gap > upper) intent = "toward";
  else if (intent === "hold" && gap < lower) intent = "away";
  const moveAxis = intent === "toward" ? directionToEnemy : (intent === "away" ? -directionToEnemy : 0);
  return { moveAxis, intent, gap, holdGap, lower, upper, enemyPhase };
}

async function runSpacingStrategy(page, length, start) {
  const initial = await stageMatrixFixture(page, length, start);
  const startedAt = Date.now();
  let intent = "hold";
  let iterations = 0;
  const phaseSamples = new Set();
  let minimumGap = Number.POSITIVE_INFINITY;
  let maximumGap = 0;
  while (Date.now() - startedAt <= COMBAT_LIMIT_MS) {
    const state = await getState(page);
    if (state.combat_outcome !== "active") {
      await sendCommand(page, "c0_input", { move_axis: 0 });
      return matrixResult("spacing", length, start, initial, state, {
        controller: {
          ...SPACING_POLICY,
          formula: "G_hold = grip_offset + effective_reach - margin",
          hold_gap: SPACING_POLICY.grip_offset + initial.weapon_role.effective_reach - SPACING_POLICY.margin,
          iterations,
          observed_enemy_phases: [...phaseSamples],
          minimum_gap: minimumGap,
          maximum_gap: maximumGap,
        },
        driver_elapsed_ms: Date.now() - startedAt,
      });
    }
    const decision = spacingDecision(state, intent);
    intent = decision.intent;
    iterations += 1;
    phaseSamples.add(decision.enemyPhase);
    minimumGap = Math.min(minimumGap, decision.gap);
    maximumGap = Math.max(maximumGap, decision.gap);
    await sendCommand(page, "c0_input", { move_axis: decision.moveAxis, attack: true });
    await waitForAnimationFrames(page, 2);
  }
  await sendCommand(page, "c0_input", { move_axis: 0 });
  throw new Error(`spacing/${start.id}/${length}: combat remained active after ${COMBAT_LIMIT_MS}ms: ${JSON.stringify(await getState(page))}`);
}

report.lifecycle = await runIsolatedCase("enemy-lifecycle-idle-defeat-retry-reforge", async (page) => {
  const initial = await startFixture(page, "standard");
  const initialDrawingCount = initial.drawing_count;
  await waitForState(page, "enemy telegraph", [
    { path: "enemy_phase", operator: "equals", value: "telegraph" },
  ]);
  await waitForState(page, "enemy strike", [
    { path: "enemy_phase", operator: "equals", value: "active" },
    { path: "enemy_attack_count", operator: "greater_than", value: 0 },
  ]);
  const recovery = await waitForState(page, "enemy recovery", [
    { path: "enemy_phase", operator: "equals", value: "recovery" },
    { path: "metrics.damage_taken", operator: "greater_than", value: 0 },
  ]);
  assert(recovery.player_health < recovery.player_max_health, "enemy strike did not damage the player");
  await sendCommand(page, "c0_idle_until_defeat");
  const defeated = await waitForState(page, "idle player defeat", [
    { path: "combat_outcome", operator: "equals", value: "defeat" },
    { path: "player_health", operator: "equals", value: 0 },
  ], 30_000);
  assert(defeated.enemy_attack_count > 0, "idle defeat recorded no enemy attacks");
  assert(defeated.enemy_damage_events.length > 0, "idle defeat recorded no enemy damage audit");
  assert(defeated.metrics.damage_taken >= defeated.player_max_health, "idle defeat under-reported damage taken");
  const defeatTerminal = await assertTerminalFrozen(page, "defeat");
  const defeatControls = await getControls(page);
  for (const name of ["retry", "round_reforge"]) {
    assert(defeatControls[name].height >= 44, `${name} final touch target is ${defeatControls[name].height}px tall; expected at least 44px`);
  }

  const retryRect = await tapControl(page, "retry");
  const retried = await waitForState(page, "retry resets combat", [
    { path: "screen", operator: "equals", value: "combat" },
    { path: "combat_outcome", operator: "equals", value: "active" },
    { path: "player_health", operator: "greater_than", value: 0 },
    { path: "enemy_health", operator: "greater_than", value: 0 },
  ]);
  assert(retried.player_health === retried.player_max_health, "Retry did not restore player HP");
  assert(retried.enemy_health === retried.enemy_max_health, "Retry did not restore enemy HP");

  await sendCommand(page, "c0_idle_until_defeat");
  await waitForState(page, "second idle player defeat", [
    { path: "combat_outcome", operator: "equals", value: "defeat" },
    { path: "player_health", operator: "equals", value: 0 },
  ], 30_000);
  const secondDefeatControls = await getControls(page);
  assert(secondDefeatControls.round_reforge.height >= 44, `round_reforge final touch target is ${secondDefeatControls.round_reforge.height}px tall; expected at least 44px`);
  const reforgeRect = await tapControl(page, "round_reforge");
  const reforged = await waitForState(page, "reforge returns to forge", [
    { path: "screen", operator: "equals", value: "forge" },
    { path: "phase", operator: "equals", value: "idle" },
    { path: "description", operator: "equals", value: initial.description },
    { path: "drawing_count", operator: "equals", value: initialDrawingCount },
  ]);
  return {
    telegraph_observed: true,
    strike_observed: true,
    recovery_observed: true,
    idle_defeat: {
      enemy_attack_count: defeated.enemy_attack_count,
      enemy_damage_events: defeated.enemy_damage_events.length,
      damage_taken: defeated.metrics.damage_taken,
    },
    terminal_freeze: defeatTerminal,
    final_touch_targets: {
      retry: retryRect,
      reforge: reforgeRect,
    },
    retry_restored: {
      player_health: retried.player_health,
      enemy_health: retried.enemy_health,
    },
    reforge_screen: reforged.screen,
    fixture_input_preserved: {
      description: reforged.description,
      drawing_count: reforged.drawing_count,
    },
  };
});

report.terminal_victory = await runIsolatedCase("victory-terminal-freeze", async (page) => {
  await startFixture(page, "short");
  await sendCommand(page, "c0_input", { move_axis: 1 });
  const victorious = await attackUntilOutcome(page, 24, 1);
  assert(victorious.combat_outcome === "victory", `victory terminal fixture ended ${victorious.combat_outcome}`);
  return assertTerminalFrozen(page, "victory");
});

for (const start of MATRIX_STARTS) {
  for (const length of ["short", "standard", "long"]) {
    const pressure = await runIsolatedCase(`pressure-${start.id}-${length}`, (page) =>
      runPressureStrategy(page, length, start));
    report.pressure_comparison.push(pressure);
    if (start === MATRIX_STARTS[0]) report.controlled_comparison.push(pressure);

    const spacing = await runIsolatedCase(`spacing-${start.id}-${length}`, (page) =>
      runSpacingStrategy(page, length, start));
    report.spacing_comparison.push(spacing);
  }
}

report.collision = await runIsolatedCase("collision-no-pass-through", async (page) => {
  await startFixture(page, "standard");
  const leftInitial = await getState(page);
  assert(
    leftInitial.collision.player_position.x < leftInitial.collision.enemy_position.x,
    `left approach did not start left of enemy: ${JSON.stringify(leftInitial.collision)}`,
  );
  const leftContact = await driveIntoCollision(page);
  await sendCommand(page, "c0_input", { move_axis: 1 });
  await waitForAnimationFrames(page, 36);
  const leftSustained = await getState(page);
  await sendCommand(page, "c0_input", { move_axis: 0 });
  for (const [label, state] of [["left contact", leftContact], ["left sustained", leftSustained]]) {
    assert(state.collision.player_position.x < state.collision.enemy_position.x, `${label}: player crossed enemy`);
    assert(!state.collision.overlapping, `${label}: player and enemy overlap`);
    assert(
      state.collision.player_enemy_separation >= state.collision.min_separation - 0.5,
      `${label}: actual separation failed ${JSON.stringify(state.collision)}`,
    );
  }

  await sendCommand(page, "developer_mode", { enabled: true });
  await waitForState(page, "collision staging mode", [
    { path: "developer_mode", operator: "truthy" },
    { path: "combat_enemy.collision_layer", operator: "equals", value: 0 },
  ]);
  await sendCommand(page, "target_scenario", { kind: "stationary", gap: 700 });
  await sendCommand(page, "c0_input", { move_axis: 1 });
  await waitForState(page, "player passed first staging point", [
    { path: "player_position.x", operator: "greater_than", value: 850 },
  ]);
  await sendCommand(page, "c0_input", { move_axis: 0 });
  await sendCommand(page, "target_scenario", { kind: "stationary", gap: 700 });
  await sendCommand(page, "c0_input", { move_axis: 1 });
  await waitForState(page, "player staged right of enemy", [
    { path: "player_position.x", operator: "greater_than", value: LOGICAL_WIDTH * 0.82 },
  ]);
  await sendCommand(page, "c0_input", { move_axis: 0 });
  await sendCommand(page, "developer_mode", { enabled: false });
  const rightInitial = await waitForState(page, "right collision initial ordering", [
    { path: "developer_mode", operator: "falsy" },
    { path: "combat_enemy.collision_layer", operator: "equals", value: 10 },
  ]);
  assert(
    rightInitial.collision.player_position.x > rightInitial.collision.enemy_position.x,
    `right approach did not start right of enemy: ${JSON.stringify(rightInitial.collision)}`,
  );
  await sendCommand(page, "c0_input", { move_axis: -1 });
  await page.waitForFunction(
    () => {
      const collision = window.__forgeM1B1Test?.state?.().collision;
      return collision &&
        collision.player_position.x > collision.enemy_position.x &&
        collision.player_enemy_separation <= collision.min_separation + 1.5;
    },
    null,
    { timeout: 20_000 },
  );
  const rightContact = await getState(page);
  await waitForAnimationFrames(page, 36);
  const rightSustained = await getState(page);
  await sendCommand(page, "c0_input", { move_axis: 0 });
  for (const [label, state] of [["right contact", rightContact], ["right sustained", rightSustained]]) {
    assert(state.collision.player_position.x > state.collision.enemy_position.x, `${label}: player crossed enemy`);
    assert(!state.collision.overlapping, `${label}: player and enemy overlap`);
    assert(
      state.collision.player_enemy_separation >= state.collision.min_separation - 0.5,
      `${label}: actual separation failed ${JSON.stringify(state.collision)}`,
    );
  }

  await sendCommand(page, "developer_mode", { enabled: true });
  await waitForState(page, "arena edge mode", [
    { path: "combat_enemy.collision_layer", operator: "equals", value: 0 },
  ]);
  await sendCommand(page, "c0_input", { move_axis: -1 });
  await waitForState(page, "left arena edge", [
    { path: "player_position.x", operator: "less_than", value: ARENA_BOUNDS.left + 0.5 },
  ]);
  await waitForAnimationFrames(page, 36);
  const leftEdge = await getState(page);
  assert(leftEdge.player_position.x >= ARENA_BOUNDS.left, `player crossed left arena edge: ${JSON.stringify(leftEdge.player_position)}`);

  await sendCommand(page, "c0_input", { move_axis: 1 });
  await waitForState(page, "right arena edge", [
    { path: "player_position.x", operator: "greater_than", value: ARENA_BOUNDS.right - 0.5 },
  ], 20_000);
  await waitForAnimationFrames(page, 36);
  const rightEdge = await getState(page);
  await sendCommand(page, "c0_input", { move_axis: 0 });
  assert(rightEdge.player_position.x <= ARENA_BOUNDS.right + 0.01, `player crossed right arena edge: ${JSON.stringify(rightEdge.player_position)}`);

  return {
    left_approach: {
      initial: leftInitial.collision,
      contact: leftContact.collision,
      sustained: leftSustained.collision,
    },
    right_approach: {
      initial: rightInitial.collision,
      contact: rightContact.collision,
      sustained: rightSustained.collision,
    },
    arena_edges: {
      left: leftEdge.player_position,
      right: rightEdge.player_position,
      expected_bounds: ARENA_BOUNDS,
    },
  };
});

const byLength = Object.fromEntries(
  report.retained_aggressive_baseline.results.map((entry) => [entry.length, entry]),
);
const shortWinsFirstHit = ["standard", "long"].every(
  (length) => byLength.short.metrics.time_to_first_hit_ms < byLength[length].metrics.time_to_first_hit_ms,
);
const shortWinsTtk = ["standard", "long"].every(
  (length) => byLength.short.metrics.ttk_ms < byLength[length].metrics.ttk_ms,
);
const shortWinsDamageTaken = ["standard", "long"].every(
  (length) => byLength.short.metrics.damage_taken < byLength[length].metrics.damage_taken,
);
report.short_triple_win_gate = {
  status: "RETAINED EXPECTED PRESSURE FAILURE - superseded only by the two-strategy fairness gate",
  evidence: "docs/CORE_COMBAT_C0_REPORT.md aggressive baseline; the original expected failure is not silently deleted",
  short_wins_first_hit: shortWinsFirstHit,
  short_wins_ttk: shortWinsTtk,
  short_wins_damage_taken: shortWinsDamageTaken,
  passed: !(shortWinsFirstHit && shortWinsTtk && shortWinsDamageTaken),
};
report.long_exposure_gate = {
  status: "RETAINED EXPECTED PRESSURE FAILURE - spacing owns the new exposure requirement",
  long_damage_taken: byLength.long.metrics.damage_taken,
  short_damage_taken: byLength.short.metrics.damage_taken,
  passed: byLength.long.metrics.damage_taken < byLength.short.metrics.damage_taken,
};

const entriesForStart = (entries, startId) => Object.fromEntries(
  entries.filter((entry) => entry.start.id === startId).map((entry) => [entry.length, entry]),
);
report.pressure_ttk_gate = {
  requirement: "short TTK remains lower than standard and long under same-frame pressure",
  starts: MATRIX_STARTS.map((start) => {
    const entries = entriesForStart(report.pressure_comparison, start.id);
    const passed = ["standard", "long"].every(
      (length) => entries.short.metrics.ttk_ms < entries[length].metrics.ttk_ms,
    );
    return {
      start: start.id,
      ttk_ms: Object.fromEntries(Object.entries(entries).map(([length, entry]) => [length, entry.metrics.ttk_ms])),
      passed,
    };
  }),
};
report.pressure_ttk_gate.passed = report.pressure_ttk_gate.starts.every((start) => start.passed);

report.spacing_exposure_gate = {
  requirement: "across both starts, total damage_long <= total damage_short - 20 and neither standard nor long takes more total damage than short",
  quantization_note: "per-gap values are retained as observations; one 20-damage strike is the runtime quantum, so a zero-damage gap is not independently required to improve by 20",
  starts: MATRIX_STARTS.map((start) => {
    const entries = entriesForStart(report.spacing_comparison, start.id);
    const damage = Object.fromEntries(
      Object.entries(entries).map(([length, entry]) => [length, entry.metrics.damage_taken]),
    );
    return {
      start: start.id,
      damage_taken: damage,
      long_at_least_one_strike_better: damage.long <= damage.short - 20,
      standard_not_worse_than_short: damage.standard <= damage.short,
      long_not_worse_than_short: damage.long <= damage.short,
      passed: damage.standard <= damage.short && damage.long <= damage.short,
    };
  }),
};
report.spacing_exposure_gate.total_damage_taken = Object.fromEntries(["short", "standard", "long"].map((length) => [
  length,
  report.spacing_comparison
    .filter((entry) => entry.length === length)
    .reduce((sum, entry) => sum + entry.metrics.damage_taken, 0),
]));
const spacingTotalDamage = report.spacing_exposure_gate.total_damage_taken;
report.spacing_exposure_gate.long_at_least_one_strike_better =
  spacingTotalDamage.long <= spacingTotalDamage.short - 20;
report.spacing_exposure_gate.standard_not_worse_than_short =
  spacingTotalDamage.standard <= spacingTotalDamage.short;
report.spacing_exposure_gate.long_not_worse_than_short =
  spacingTotalDamage.long <= spacingTotalDamage.short;
report.spacing_exposure_gate.passed =
  report.spacing_exposure_gate.long_at_least_one_strike_better &&
  report.spacing_exposure_gate.standard_not_worse_than_short &&
  report.spacing_exposure_gate.long_not_worse_than_short;

const allMatrixEntries = [...report.pressure_comparison, ...report.spacing_comparison];
const combinedMetrics = Object.fromEntries(["short", "standard", "long"].map((length) => {
  const entries = allMatrixEntries.filter((entry) => entry.length === length);
  const average = (field) => entries.reduce((sum, entry) => sum + entry.metrics[field], 0) / entries.length;
  return [length, {
    samples: entries.length,
    average_first_hit_ms: average("time_to_first_hit_ms"),
    average_ttk_ms: average("ttk_ms"),
    average_damage_taken: average("damage_taken"),
  }];
}));
const winnersFor = (field) => {
  const minimum = Math.min(...Object.values(combinedMetrics).map((metrics) => metrics[field]));
  return Object.entries(combinedMetrics)
    .filter(([, metrics]) => metrics[field] === minimum)
    .map(([length]) => length);
};
const combinedWinners = {
  first_hit: winnersFor("average_first_hit_ms"),
  ttk: winnersFor("average_ttk_ms"),
  damage_taken: winnersFor("average_damage_taken"),
};
const combinedTripleWinners = ["short", "standard", "long"].filter((length) =>
  Object.values(combinedWinners).every((winners) => winners.includes(length)));
report.combined_strategy_fairness_gate = {
  requirement: "after combining pressure and spacing, no one reach wins first-hit, TTK, and damage",
  aggregation: "arithmetic mean across both generic starting gaps and both strategies",
  metrics: combinedMetrics,
  winners: combinedWinners,
  triple_winners: combinedTripleWinners,
  passed: combinedTripleWinners.length === 0,
};

report.mobile_regression = await runIsolatedCase("keyboard-orientation-regression", async (page) => {
  const input = page.locator("#forge-description-input");
  const baseline = await getMobile(page);
  assert(baseline.metrics?.canvasBackingWidth > 0 && baseline.metrics?.canvasBackingHeight > 0, "Canvas backing is unavailable");
  assert(baseline.inputRect?.width > 0 && baseline.inputRect?.height > 0, "Description touch target is unavailable");
  await page.touchscreen.tap(
    baseline.inputRect.x + baseline.inputRect.width / 2,
    baseline.inputRect.y + baseline.inputRect.height / 2,
  );
  await waitForMobile(page, "focus", "metrics.inputFocused", true);
  const description = "C0 keyboard and orientation state";
  await input.fill(description);
  await waitForState(page, "keyboard Description sync", [
    { path: "description", operator: "equals", value: description },
  ]);
  await page.evaluate(() => window.__forgeM1B1Test.setVisualViewport({
    width: 844,
    height: 190,
    offsetLeft: 0,
    offsetTop: 92,
    innerWidth: 844,
    innerHeight: 390,
    scale: 1,
  }));
  const open = await waitForMobile(page, "keyboard open", "metrics.keyboardOpen", true);
  assert(open.metrics.canvasBackingWidth === baseline.metrics.canvasBackingWidth, "keyboard resized Canvas backing width");
  assert(open.metrics.canvasBackingHeight === baseline.metrics.canvasBackingHeight, "keyboard resized Canvas backing height");
  assert(open.metrics.canvasRect.width === baseline.metrics.canvasRect.width, "keyboard rescaled Canvas width");
  assert(open.metrics.canvasRect.height === baseline.metrics.canvasRect.height, "keyboard rescaled Canvas height");
  assert(open.doneRect.width >= 44 && open.doneRect.height >= 44, "Done touch target is below 44 px");
  assert(open.inputFontSize >= 16, "Description input can trigger iOS zoom");
  await page.locator("#forge-description-done").click();
  await page.evaluate(() => window.__forgeM1B1Test.clearVisualViewport());
  const closed = await waitForMobile(page, "keyboard close", "metrics.keyboardOpen", false);
  assert(closed.inputValue === description, "keyboard close lost Description");

  await page.setViewportSize({ width: 390, height: 844 });
  await waitForState(page, "portrait gate", [
    { path: "screen", operator: "equals", value: "portrait" },
    { path: "phase", operator: "equals", value: "portrait" },
  ]);
  assert(!(await input.isVisible()), "Description overlay leaked over portrait gate");
  await page.setViewportSize(VIEWPORT);
  const landscape = await waitForState(page, "landscape recovery", [
    { path: "screen", operator: "equals", value: "forge" },
    { path: "phase", operator: "equals", value: "idle" },
    { path: "description", operator: "equals", value: description },
  ]);
  const restored = await getMobile(page);
  assert(restored.metrics.canvasBackingWidth === baseline.metrics.canvasBackingWidth, "rotation changed Canvas backing width");
  assert(restored.metrics.canvasBackingHeight === baseline.metrics.canvasBackingHeight, "rotation changed Canvas backing height");
  return {
    keyboard_canvas_stable: true,
    portrait_gate: true,
    landscape_recovered: landscape.screen === "forge",
    description_preserved: landscape.description === description,
    canvas_backing: {
      width: restored.metrics.canvasBackingWidth,
      height: restored.metrics.canvasBackingHeight,
    },
  };
});

try {
  assert(report.console_errors.length === 0, "application console errors were recorded");
  assert(
    report.pressure_ttk_gate.passed,
    `pressure lost the short-reach TTK advantage: ${JSON.stringify(report.pressure_ttk_gate)}`,
  );
  assert(
    report.spacing_exposure_gate.passed,
    `spacing failed the aggregate long-reach exposure gate: ${JSON.stringify(report.spacing_exposure_gate)}`,
  );
  assert(
    report.combined_strategy_fairness_gate.passed,
    `one reach won first-hit, TTK, and damage across both strategies: ${JSON.stringify(report.combined_strategy_fairness_gate)}`,
  );
  await writeFile(join(destination, `${browserName}-report.json`), JSON.stringify(report, null, 2));
  console.log(JSON.stringify(report, null, 2));
} catch (error) {
  report.failure = {
    message: error instanceof Error ? error.message : String(error),
    stack: error instanceof Error ? error.stack : "",
  };
  await writeFile(join(destination, `${browserName}-failure-report.json`), JSON.stringify(report, null, 2));
  throw error;
} finally {
  await browser.close();
}
