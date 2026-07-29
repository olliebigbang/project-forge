import { createRequire } from "node:module";
import { mkdir, writeFile } from "node:fs/promises";
import { join, resolve } from "node:path";

const require = createRequire(import.meta.url);
const playwright = require(process.env.PLAYWRIGHT_MODULE_PATH || "playwright");
const [
  browserName = "chromium",
  targetUrl = "http://127.0.0.1:8076/",
  outputRoot = "output/playwright/m2a-live-weapon-belt",
] = process.argv.slice(2);
const browserType = playwright[browserName];
if (!browserType) throw new Error(`Unsupported browser: ${browserName}`);

const destination = resolve(outputRoot, browserName);
await mkdir(destination, { recursive: true });

const assert = (condition, message) => {
  if (!condition) throw new Error(message);
};
const deepEqual = (left, right) => JSON.stringify(left) === JSON.stringify(right);
const safeName = (value) => value.replace(/[^a-z0-9_-]+/gi, "-").toLowerCase();
const forgeState = (page) =>
  page.evaluate(() => window.__forgeM1B1Test?.state?.() || {});
const forgeControls = (page) =>
  page.evaluate(() => window.__forgeM1B1Test?.controls?.() || {});
const beltState = (page) =>
  page.evaluate(() => window.__forgeBeltCombat?.state?.() || {});
const beltControls = (page) =>
  page.evaluate(() => window.__forgeBeltCombat?.controls?.() || {});
const vector = (value = {}) => ({
  x: Number(value?.x || 0),
  y: Number(value?.y || 0),
});
const vectorLength = (value) =>
  Math.hypot(Number(value?.x || 0), Number(value?.y || 0));
const normalizedVector = (value) => {
  const candidate = vector(value);
  const length = vectorLength(candidate);
  return length > 0.0001
    ? { x: candidate.x / length, y: candidate.y / length }
    : { x: 0, y: 0 };
};
const dot = (left, right) =>
  Number(left?.x || 0) * Number(right?.x || 0) +
  Number(left?.y || 0) * Number(right?.y || 0);

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

async function forgeCommand(page, name, payload = {}) {
  const dispatched = await page.evaluate(
    ({ commandName, commandPayload }) => {
      if (typeof window.__forgeGodotQaCallback !== "function") return false;
      window.__forgeGodotQaCallback(
        commandName,
        JSON.stringify(commandPayload),
      );
      return true;
    },
    { commandName: name, commandPayload: payload },
  );
  assert(dispatched, `Forge QA command bridge unavailable for ${name}`);
}

async function beltCommand(page, name, payload = {}) {
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

async function openForge(page, developer = false) {
  const url = new URL(targetUrl);
  url.searchParams.set("qa", "m1b1");
  if (developer) url.searchParams.set("dev", "1");
  await page.goto(url.href, {
    waitUntil: "domcontentloaded",
    timeout: 30_000,
  });
  await page.waitForFunction(
    () =>
      typeof window.__forgeM1B1Test?.state === "function" &&
      typeof window.__forgeM1B1Test?.controls === "function" &&
      typeof window.__forgeGodotQaCallback === "function" &&
      window.__forgeM1B1Test.state().screen === "forge",
    null,
    { timeout: 20_000 },
  );
  return forgeState(page);
}

async function waitForConfirmation(page) {
  await page.waitForFunction(
    () => {
      const current = window.__forgeM1B1Test?.state?.();
      return (
        current?.screen === "confirmation" &&
        current?.phase === "result" &&
        current?.runtime_valid === true &&
        current?.spec?.attack_pattern
      );
    },
    null,
    { timeout: 20_000 },
  );
  return forgeState(page);
}

async function waitForLiveBelt(page) {
  await page.waitForFunction(
    () => {
      const current = window.__forgeBeltCombat?.state?.();
      return (
        current?.screen === "belt_combat" &&
        current?.round_state === "active" &&
        current?.combat_route === "belt_live" &&
        current?.equipment_source === "live" &&
        current?.route_payload_consumed === true
      );
    },
    null,
    { timeout: 20_000 },
  );
  return beltState(page);
}

async function waitForBeltCondition(
  page,
  label,
  predicate,
  expected = {},
  timeout = 20_000,
) {
  const handle = await page.waitForFunction(
    ({ source, expectedValue }) => {
      const current = window.__forgeBeltCombat?.state?.();
      if (!current) return false;
      // The predicate is test-owned source, not application or provider data.
      const matched = Function(
        "current",
        "expected",
        `return (${source})(current, expected);`,
      )(current, expectedValue);
      return matched ? current : false;
    },
    { source: predicate.toString(), expectedValue: expected },
    { timeout },
  );
  const matchedState = await handle.jsonValue();
  await handle.dispose();
  return matchedState;
}

async function tapRect(page, rect, label) {
  assert(rect?.width > 0 && rect?.height > 0, `${label} is not actionable`);
  await page.touchscreen.tap(
    rect.x + rect.width / 2,
    rect.y + rect.height / 2,
  );
}

async function tapDodgeForOutcome(page, label, expectedOutcome) {
  const before = await beltState(page);
  const beforeSequence = Number(before.event_sequence || 0);
  const expectedOutcomes = Array.isArray(expectedOutcome)
    ? expectedOutcome
    : [expectedOutcome];
  const controls = await beltControls(page);
  assertRect(controls.dodge, await page.viewportSize(), `${label} DODGE`);
  await tapRect(page, controls.dodge, `${label} DODGE`);
  return waitForBeltCondition(
    page,
    label,
    (current, expected) =>
      (current?.combat_events || []).some(
        (event) =>
          event.kind === "dodge_request" &&
          Number(event.sequence) > expected.beforeSequence &&
          expected.expectedOutcomes.includes(event.outcome),
      ),
    { beforeSequence, expectedOutcomes },
    5_000,
  );
}

async function waitForDodgeReady(page, label) {
  return waitForBeltCondition(
    page,
    label,
    (current) =>
      current?.round_state === "active" &&
      current?.player?.dodge?.active === false &&
      Number(current?.player?.dodge?.cooldown_remaining || 0) <= 0.001,
    {},
    5_000,
  );
}

function assertRect(rect, viewport, label) {
  assert(
    rect?.width >= 43.5 && rect?.height >= 43.5,
    `${label} is below the 44 CSS px touch target`,
  );
  assert(
    rect.x >= -1 &&
      rect.y >= -1 &&
      rect.x + rect.width <= viewport.width + 1 &&
      rect.y + rect.height <= viewport.height + 1,
    `${label} escaped ${viewport.width}x${viewport.height}: ${JSON.stringify(rect)}`,
  );
}

async function drawForgeStroke(page) {
  const canvas = (await forgeControls(page)).canvas;
  assert(canvas?.width > 0 && canvas?.height > 0, "drawing canvas is hidden");
  const points = [
    {
      x: canvas.x + canvas.width * 0.18,
      y: canvas.y + canvas.height * 0.62,
    },
    {
      x: canvas.x + canvas.width * 0.38,
      y: canvas.y + canvas.height * 0.34,
    },
    {
      x: canvas.x + canvas.width * 0.58,
      y: canvas.y + canvas.height * 0.66,
    },
    {
      x: canvas.x + canvas.width * 0.80,
      y: canvas.y + canvas.height * 0.38,
    },
  ];
  if (browserName === "chromium") {
    const cdp = await page.context().newCDPSession(page);
    await cdp.send("Input.dispatchTouchEvent", {
      type: "touchStart",
      touchPoints: [
        { ...points[0], radiusX: 4, radiusY: 4, force: 1, id: 1 },
      ],
    });
    for (const point of points.slice(1)) {
      await cdp.send("Input.dispatchTouchEvent", {
        type: "touchMove",
        touchPoints: [
          { ...point, radiusX: 4, radiusY: 4, force: 1, id: 1 },
        ],
      });
    }
    await cdp.send("Input.dispatchTouchEvent", {
      type: "touchEnd",
      touchPoints: [],
    });
    await cdp.detach();
  } else {
    await page.mouse.move(points[0].x, points[0].y);
    await page.mouse.down();
    for (const point of points.slice(1)) {
      await page.mouse.move(point.x, point.y, { steps: 4 });
    }
    await page.mouse.up();
  }
  await page.waitForFunction(
    () => Number(window.__forgeM1B1Test?.state?.().drawing_count) > 0,
    null,
    { timeout: 10_000 },
  );
}

function assertFixtureControlsHidden(controls, label) {
  for (const [id, rect] of Object.entries(controls.weapons || {})) {
    assert(
      Number(rect?.width || 0) === 0 && Number(rect?.height || 0) === 0,
      `${label}: normal player exposed weapon fixture ${id}`,
    );
  }
  for (const [id, rect] of Object.entries(controls.encounters || {})) {
    assert(
      Number(rect?.width || 0) === 0 && Number(rect?.height || 0) === 0,
      `${label}: normal player exposed encounter fixture ${id}`,
    );
  }
}

async function stageDirectionalAttack(page, pattern, horizontalSign) {
  await beltCommand(page, "pause_enemies", { enabled: false });
  const initial = await beltState(page);
  const arena = initial.arena_bounds;
  const playerPosition = {
    x: Number(arena.x) + Number(arena.width) * 0.5,
    y: Number(arena.y) + Number(arena.height) * 0.58,
  };
  const targetDistance =
    pattern === "melee_slash" ? 80 : pattern === "area_blast" ? 180 : 260;

  await beltCommand(page, "set_player", playerPosition);
  await beltCommand(page, "move", { x: horizontalSign, y: 0 });
  await waitForBeltCondition(
    page,
    `${pattern} ${horizontalSign < 0 ? "left" : "right"} facing`,
    (current, expected) =>
      Math.sign(Number(current?.player?.facing || 0)) ===
      Number(expected.horizontalSign),
    { horizontalSign },
  );
  await beltCommand(page, "move", { x: 0, y: 0 });
  await beltCommand(page, "set_player", playerPosition);

  const staged = await beltState(page);
  assert(staged.enemies?.length > 0, `${pattern}: no live target to stage`);
  const target = staged.enemies[0];
  const targetPosition = {
    x: playerPosition.x + horizontalSign * targetDistance,
    y: playerPosition.y,
  };
  await beltCommand(page, "set_enemy", {
    id: target.id,
    ...targetPosition,
    simulation_enabled: false,
  });
  if (pattern === "straight_projectile") {
    for (const [index, extra] of staged.enemies.slice(1).entries()) {
      await beltCommand(page, "set_enemy", {
        id: extra.id,
        x:
          playerPosition.x +
          horizontalSign * (targetDistance + 80 + index * 20),
        y: playerPosition.y,
        simulation_enabled: false,
      });
    }
  }
  return waitForBeltCondition(
    page,
    `${pattern} ${horizontalSign < 0 ? "left" : "right"} target lock`,
    (current, expected) => {
      const enemy = current?.enemies?.find(
        (entry) => entry.id === String(expected.targetId),
      );
      return (
        Math.abs(
          Number(current?.player?.position?.x) - expected.playerPosition.x,
        ) <=
          1.5 &&
        Math.abs(
          Number(current?.player?.position?.y) - expected.playerPosition.y,
        ) <=
          1.5 &&
        Math.abs(Number(enemy?.position?.x) - expected.targetPosition.x) <=
          1.5 &&
        Math.abs(Number(enemy?.position?.y) - expected.targetPosition.y) <=
          1.5 &&
        Math.sign(Number(current?.player?.facing || 0)) ===
          Number(expected.horizontalSign) &&
        String(current?.player?.assist_target || "") ===
          String(expected.targetId)
      );
    },
    {
      targetId: target.id,
      playerPosition,
      targetPosition,
      horizontalSign,
    },
  );
}

async function runDirectionalAttack(
  page,
  liveCase,
  horizontalSign,
  screenshotPath = "",
) {
  const side = horizontalSign < 0 ? "left" : "right";
  let staged = await stageDirectionalAttack(
    page,
    liveCase.pattern,
    horizontalSign,
  );
  if (liveCase.pattern === "straight_projectile") {
    const stagedPlayerPosition = {
      x: Number(staged.player?.position?.x),
      y: Number(staged.player?.position?.y),
    };
    await beltCommand(page, "move", { x: -horizontalSign, y: 0 });
    await waitForBeltCondition(
      page,
      `${liveCase.id} ${side} stale opposite facing`,
      (current, expected) =>
        Math.sign(Number(current?.player?.facing || 0)) ===
        -Number(expected.horizontalSign),
      { horizontalSign },
    );
    await beltCommand(page, "move", { x: 0, y: 0 });
    // A loaded CI runner can take long enough to observe the stale facing that
    // the held movement walks outside target-assist range. Restore the staged
    // position after releasing movement, then wait for the exact scenario the
    // regression owns: stale opposite facing, zero input, and all live targets
    // still behind but inside the normal assist envelope.
    await beltCommand(page, "set_player", stagedPlayerPosition);
    staged = await waitForBeltCondition(
      page,
      `${liveCase.id} ${side} stable opposite-facing target setup`,
      (current, expected) => {
        const playerPosition = current?.player?.position || {};
        const liveTargets = (current?.enemies || []).filter(
          (enemy) => Number(enemy?.health || 0) > 0,
        );
        return (
          Math.abs(Number(playerPosition.x) - expected.playerPosition.x) <=
            1.5 &&
          Math.abs(Number(playerPosition.y) - expected.playerPosition.y) <=
            1.5 &&
          Number(current?.player?.touch_move?.x || 0) === 0 &&
          Number(current?.player?.touch_move?.y || 0) === 0 &&
          Math.sign(Number(current?.player?.facing || 0)) ===
            -Number(expected.horizontalSign) &&
          String(current?.player?.assist_target || "") === "" &&
          liveTargets.length > 0 &&
          liveTargets.every((enemy) => {
            const offsetX =
              Number(enemy?.position?.x) - Number(playerPosition.x);
            const offsetY =
              Number(enemy?.position?.y) - Number(playerPosition.y);
            return (
              Math.sign(offsetX) === Number(expected.horizontalSign) &&
              Math.hypot(offsetX, offsetY) <= 520
            );
          })
        );
      },
      { horizontalSign, playerPosition: stagedPlayerPosition },
    );
  }
  const beforeSequence = Number(staged.event_sequence);
  const beforeCount = Number(staged.accepted_attack_count);
  await beltCommand(page, "attack");

  const committedState = await waitForBeltCondition(
    page,
    `${liveCase.id} ${side} attack commit`,
    (current, expected) =>
      Number(current?.accepted_attack_count) === expected.beforeCount + 1 &&
      (current?.combat_events || []).some(
        (event) =>
          event.kind === "attack_committed" &&
          Number(event.sequence) > expected.beforeSequence,
      ),
    { beforeCount, beforeSequence },
  );
  const committed = committedState.combat_events.findLast(
    (event) =>
      event.kind === "attack_committed" &&
      Number(event.sequence) > beforeSequence,
  );
  const committedDirection = normalizedVector(committed?.direction);
  assert(
    Math.sign(committedDirection.x) === horizontalSign,
    `${liveCase.id} ${side}: committed direction was ${JSON.stringify(committedDirection)}`,
  );

  const heldForward = normalizedVector(
    committedState.player?.weapon_visual_forward,
  );
  const heldAudit = committedState.player?.held_visual_audit || {};
  const auditedForward = normalizedVector(heldAudit.final_visual_forward);
  assert(
    dot(heldForward, committedDirection) > 0.72 &&
      dot(auditedForward, committedDirection) > 0.72,
    `${liveCase.id} ${side}: held ink did not follow frozen direction ` +
      `${JSON.stringify({ heldForward, auditedForward, committedDirection })}`,
  );
  assert(
    Number(heldAudit.ink_forward_sign || 0) ===
        Number(committedState.geometry_profile?.ink_forward_sign || 0) &&
      heldAudit.source_signature === committedState.stroke_signature?.sha256 &&
      heldAudit.source_strokes_preserved === true,
    `${liveCase.id} ${side}: held ink orientation audit lost source identity`,
  );
  assert(
    Math.sign(Number(committedState.player?.weapon_visual_position?.x || 0)) ===
      horizontalSign,
    `${liveCase.id} ${side}: held grip stayed on the wrong side`,
  );

  let visibleState;
  let outboundPosition;
  let impactPosition = null;
  if (liveCase.pattern === "melee_slash") {
    visibleState = (committedState.transients || []).some(
      (entry) => entry.kind === "slash",
    )
      ? committedState
      : await waitForBeltCondition(
          page,
          `${liveCase.id} ${side} slash visual`,
          (current) =>
            (current?.transients || []).some(
              (entry) => entry.kind === "slash",
            ),
        );
    const slash = visibleState.transients.find(
      (entry) => entry.kind === "slash",
    );
    const slashDirection = normalizedVector(slash?.direction);
    assert(
      dot(slashDirection, committedDirection) > 0.999,
      `${liveCase.id} ${side}: slash arc direction drifted`,
    );
  } else {
    visibleState = (committedState.projectiles || []).some(
      (projectile) => projectile.returning === false,
    )
      ? committedState
      : await waitForBeltCondition(
          page,
          `${liveCase.id} ${side} outbound projectile`,
          (current, expected) =>
            (current?.projectiles || []).some(
              (projectile) => projectile.returning === false,
            ) ||
            (current?.combat_events || []).some(
              (event) =>
                event.kind === "projectile_finished" &&
                Number(event.sequence) > expected.beforeSequence,
            ),
          { beforeSequence },
        );
    const liveProjectile = visibleState.projectiles.find(
      (entry) => entry.returning === false,
    );
    const finishedProjectile = visibleState.combat_events.findLast(
      (event) =>
        event.kind === "projectile_finished" &&
        Number(event.sequence) > beforeSequence,
    )?.final_state;
    const projectile = liveProjectile || finishedProjectile;
    const outboundSamples = (projectile?.path_samples || []).filter(
      (sample) => sample.returning === false,
    );
    const projectileDirection =
      outboundSamples.length >= 2
        ? normalizedVector({
            x: Number(outboundSamples[1].x) - Number(outboundSamples[0].x),
            y: Number(outboundSamples[1].y) - Number(outboundSamples[0].y),
          })
        : normalizedVector(projectile?.direction);
    assert(
      Math.sign(projectileDirection.x) === horizontalSign &&
        dot(projectileDirection, committedDirection) > 0.90,
      `${liveCase.id} ${side}: outbound visual direction drifted ` +
        `${JSON.stringify({ projectileDirection, committedDirection })}`,
    );
    outboundPosition = vector(
      outboundSamples.length >= 2 ? outboundSamples[1] : projectile?.position,
    );
    assert(
      Math.sign(
        outboundPosition.x - Number(visibleState.player?.position?.x || 0),
      ) === horizontalSign,
      `${liveCase.id} ${side}: projectile rendered on the wrong outbound side`,
    );
  }

  if (liveCase.pattern === "area_blast") {
    const impact = await waitForBeltCondition(
      page,
      `${liveCase.id} ${side} impact`,
      (current, expected) =>
        (current?.combat_events || []).some(
          (event) =>
            event.kind === "area_impact" &&
            Number(event.sequence) > expected.beforeSequence,
        ) && (current?.blasts || []).length > 0,
      { beforeSequence },
    );
    const impactEvent = impact.combat_events.findLast(
      (event) =>
        event.kind === "area_impact" &&
        Number(event.sequence) > beforeSequence,
    );
    impactPosition = { x: Number(impactEvent.x), y: Number(impactEvent.y) };
    assert(
      Math.sign(
        impactPosition.x - Number(staged.player?.position?.x || 0),
      ) === horizontalSign,
      `${liveCase.id} ${side}: symmetric blast landed on the wrong side`,
    );
    visibleState = impact;
  }

  if (screenshotPath) {
    await page.screenshot({ path: screenshotPath });
  }
  const settled = await waitForBeltCondition(
    page,
    `${liveCase.id} ${side} cleanup`,
    (current) =>
      Number(current?.active_transient_count) === 0 &&
      current?.cleanup?.player_attack_active === false &&
      current?.cleanup?.held_visible === true,
    {},
    30_000,
  );
  return {
    side,
    committed_direction: committedDirection,
    held_forward: heldForward,
    ink_forward_sign: Number(heldAudit.ink_forward_sign),
    held_source_signature: heldAudit.source_signature,
    held_local_position: committedState.player?.weapon_visual_position,
    outbound_position: outboundPosition,
    impact_position: impactPosition,
    cleanup: settled.cleanup,
    screenshot: screenshotPath || null,
  };
}

const viewports = [
  { width: 844, height: 390 },
  { width: 852, height: 393 },
  { width: 915, height: 412 },
];
const liveCases = [
  { id: "melee-normal", pattern: "melee_slash", element: "normal" },
  { id: "bow-ice", pattern: "straight_projectile", element: "ice" },
  { id: "boomerang-electric", pattern: "boomerang", element: "electric" },
  { id: "grenade-fire", pattern: "area_blast", element: "fire" },
  { id: "piercing-normal", pattern: "piercing", element: "normal" },
];

const report = {
  suite: "M2A route + M2B playable loop provider-free regression",
  browser: browserName,
  target: targetUrl,
  provider_policy: "NO PROVIDER CALLS",
  captured_at: new Date().toISOString(),
  live_cases: [],
  dodge_touch_regression: {},
  unicode_transport: {},
  invalid_route: {},
  one_shot_reload: {},
  side_view_regression: {},
  console_errors: [],
};

const launchOptions = { headless: true };
if (process.env.M1B1_QA_BROWSER_EXECUTABLE) {
  launchOptions.executablePath = process.env.M1B1_QA_BROWSER_EXECUTABLE;
}
const browser = await browserType.launch(launchOptions);

async function runIsolated(caseName, viewport, body) {
  const context = await browser.newContext({
    ...playwright.devices["iPhone 15"],
    viewport,
    screen: viewport,
    hasTouch: true,
  });
  await context.tracing.start({
    screenshots: true,
    snapshots: true,
    sources: true,
  });
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
    assert(
      providerCalls.length === 0,
      `${caseName}: provider route was called ${JSON.stringify(providerCalls)}`,
    );
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
          forge_state: await forgeState(page).catch(() => ({})),
          belt_state: await beltState(page).catch(() => ({})),
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

for (let index = 0; index < liveCases.length; index += 1) {
  const liveCase = liveCases[index];
  const viewport = viewports[index % viewports.length];
  const evidence = await runIsolated(
    liveCase.id,
    viewport,
    async (page) => {
      await openForge(page);
      await forgeCommand(page, "m2a_live_route_fixture", {
        pattern: liveCase.pattern,
        element: liveCase.element,
        confirm: false,
      });
      const confirmation = await waitForConfirmation(page);
      assert(
        confirmation.developer_mode === false &&
          confirmation.selector_visible === false,
        `${liveCase.id}: normal confirmation exposed developer selector`,
      );
      assert(
        confirmation.spec.attack_pattern === liveCase.pattern &&
          confirmation.spec.element === liveCase.element,
        `${liveCase.id}: deterministic confirmation identity drifted`,
      );
      let expectedInkForwardSign = Number(
        confirmation.geometry_profile?.ink_forward_sign || 1,
      );
      if (liveCase.pattern === "straight_projectile") {
        assert(
          expectedInkForwardSign === 1,
          `${liveCase.id}: fixture did not start AS DRAWN`,
        );
        await tapRect(
          page,
          (await forgeControls(page)).flip_drawing,
          `${liveCase.id} FLIP DRAWING`,
        );
        const flipped = await page.waitForFunction(
          () => {
            const current = window.__forgeM1B1Test?.state?.();
            return Number(current?.geometry_profile?.ink_forward_sign || 0) === -1
              ? current
              : false;
          },
          null,
          { timeout: 10_000 },
        );
        const flippedState = await flipped.jsonValue();
        await flipped.dispose();
        expectedInkForwardSign = -1;
        assert(
          String(flippedState.review_details || "").includes("FLIPPED"),
          `${liveCase.id}: confirmation did not expose FLIPPED orientation`,
        );
      }
      const expected = {
        description: confirmation.description,
        drawing_count: confirmation.drawing_count,
        spec: confirmation.spec,
        corrections: confirmation.result?.corrections || [],
        budget: confirmation.result?.power_budget || {},
        geometry:
          liveCase.pattern === "straight_projectile"
            ? (await forgeState(page)).geometry_profile
            : confirmation.geometry_profile,
        ink_forward_sign: expectedInkForwardSign,
      };
      await tapRect(
        page,
        (await forgeControls(page)).confirm,
        `${liveCase.id} CONFIRM`,
      );
      const belt = await waitForLiveBelt(page);
      await beltCommand(page, "pause_enemies", { enabled: false });
      assert(
        belt.developer_test_mode === false,
        `${liveCase.id}: live route entered Developer/Test presentation`,
      );
      assert(
        deepEqual(belt.weapon_spec, expected.spec),
        `${liveCase.id}: exact WeaponSpec changed at the scene boundary`,
      );
      assert(
        deepEqual(belt.weapon_corrections, expected.corrections),
        `${liveCase.id}: repair reasons changed at the scene boundary`,
      );
      if (Object.keys(expected.budget).length > 0) {
        assert(
          deepEqual(belt.weapon_budget, expected.budget),
          `${liveCase.id}: PowerBudget changed at the scene boundary`,
        );
      }
      assert(
        deepEqual(belt.geometry_profile, expected.geometry),
        `${liveCase.id}: DrawingGeometryProfile changed at the scene boundary`,
      );
      assert(
        Number(belt.geometry_profile?.ink_forward_sign || 0) ===
          expected.ink_forward_sign,
        `${liveCase.id}: authored ink forward sign was lost at the belt boundary`,
      );
      assert(
        belt.stroke_signature?.stroke_count === expected.drawing_count &&
          belt.stroke_signature?.point_count > 0 &&
          /^[a-f0-9]{64}$/.test(belt.stroke_signature?.sha256 || ""),
        `${liveCase.id}: original-stroke signature is incomplete`,
      );
      const controls = await beltControls(page);
      assertFixtureControlsHidden(controls, liveCase.id);
      for (const action of [
        "joystick",
        "attack",
        "dodge",
        "ward",
        "retry",
        "reforge",
      ]) {
        assertRect(controls[action], viewport, `${liveCase.id} ${action}`);
      }
      assert(
        belt.encounter === "playable" &&
          belt.enemies?.length === 2 &&
          belt.enemies.some((enemy) => enemy.kind === "bruiser") &&
          belt.enemies.some((enemy) => enemy.kind === "charger"),
        `${liveCase.id}: normal route did not enter the two-archetype playable room`,
      );

      if (index === 0) {
        await page.screenshot({
          path: join(
            destination,
            `${browserName}-m2b-playable-room-844x390.png`,
          ),
        });
        const startingHealth = Number(belt.player?.health);
        await beltCommand(page, "move", { x: 1, y: 0 });
        const firstDodge = await tapDodgeForOutcome(
          page,
          "M2B first real-touch DODGE",
          "accepted",
        );
        assert(
          firstDodge.player?.dodge?.last_request_outcome === "accepted" &&
            Number(firstDodge.player?.dodge?.cooldown_remaining || 0) > 0,
          "M2B first touchscreen tap was not authoritatively accepted",
        );
        await waitForDodgeReady(page, "M2B first DODGE cooldown reset");

        const repeatedDodgeEvidence = [];
        for (let attempt = 1; attempt <= 20; attempt += 1) {
          const accepted = await tapDodgeForOutcome(
            page,
            `M2B repeated real-touch DODGE ${attempt}/20`,
            "accepted",
          );
          repeatedDodgeEvidence.push({
            attempt,
            event_sequence: accepted.event_sequence,
            cooldown_seconds: Number(
              accepted.player?.dodge?.cooldown_seconds || 0,
            ),
          });
          await waitForDodgeReady(
            page,
            `M2B repeated DODGE ${attempt}/20 reset`,
          );
          assertRect(
            (await beltControls(page)).dodge,
            viewport,
            `M2B repeated DODGE ${attempt}/20 reset control`,
          );
        }
        await beltCommand(page, "dodge_then_force_enemy_strike", {
          id: "bruiser",
          x: 1,
          y: 0,
        });
        await waitForBeltCondition(
          page,
          "M2B authoritative dodge negates strike",
          (current, expected) =>
            Number(current?.player?.health) === expected.startingHealth &&
            (current?.combat_events || []).some(
              (event) =>
                event.kind === "enemy_strike_resolved" &&
                event.outcome === "dodged",
            ),
          { startingHealth },
        );
        report.dodge_touch_regression = {
          first_touch_accepted: true,
          cooldown_rejection: "covered by deterministic Godot regression",
          consecutive_ready_reuses: repeatedDodgeEvidence.length,
          attempts: repeatedDodgeEvidence,
        };
        await beltCommand(page, "move", { x: 0, y: 0 });
        await beltCommand(page, "retry");
        await waitForBeltCondition(
          page,
          "M2B retry before ward",
          (current) =>
            current?.round_state === "active" &&
            Number(current?.player?.ward?.charges) === 1,
        );
        await beltCommand(page, "pause_enemies", { enabled: false });
        await beltCommand(page, "ward_then_force_enemy_strike", {
          id: "bruiser",
        });
        await waitForBeltCondition(
          page,
          "M2B ward negates and staggers",
          (current) => {
            const bruiser = current?.enemies?.find(
              (enemy) => enemy.id === "bruiser",
            );
            return (
              Number(current?.player?.ward?.charges) === 0 &&
              current?.player?.ward?.active === false &&
              (current?.combat_events || []).some(
                (event) =>
                  event.kind === "ward_request" &&
                  event.outcome === "accepted",
              ) &&
              bruiser?.phase === "recover" &&
              Number(bruiser?.stagger_remaining) > 0 &&
              (current?.combat_events || []).some(
                (event) =>
                  event.kind === "enemy_strike_resolved" &&
                  event.outcome === "warded",
              )
            );
          },
        );
        await page.screenshot({
          path: join(destination, `${browserName}-m2b-ward-success.png`),
        });
        await beltCommand(page, "retry");
        await beltCommand(page, "pause_enemies", { enabled: false });
        await beltCommand(page, "defeat_all");
        await waitForBeltCondition(
          page,
          "M2B victory reward gate",
          (current) => current?.round_state === "victory",
        );
        await page.screenshot({
          path: join(destination, `${browserName}-m2b-victory-reward.png`),
        });
        const rewardControls = await beltControls(page);
        assertRect(
          rewardControls.reward_ward_plus,
          viewport,
          "M2B WARD+ reward",
        );
        assertRect(
          rewardControls.reward_dodge_plus,
          viewport,
          "M2B DODGE+ reward",
        );
        await beltCommand(page, "reward", { id: "ward_plus" });
        await waitForBeltCondition(
          page,
          "M2B one-attempt reward",
          (current) =>
            current?.round_state === "active" &&
            current?.active_attempt_reward === "ward_plus" &&
            Number(current?.player?.ward?.charges) === 2,
        );
        const postReward = await beltState(page);
        assert(
          deepEqual(postReward.weapon_spec, expected.spec),
          "M2B reward changed routed WeaponSpec",
        );
        await beltCommand(page, "retry");
        await waitForBeltCondition(
          page,
          "M2B reward expires",
          (current) =>
            current?.round_state === "active" &&
            current?.active_attempt_reward === "" &&
            Number(current?.player?.ward?.charges) === 1,
        );
      }

      const rightDirection = await runDirectionalAttack(
        page,
        liveCase,
        1,
      );

      const beforeRetry = await beltState(page);
      await beltCommand(page, "retry");
      await page.waitForFunction(
        ({ generation }) => {
          const current = window.__forgeBeltCombat?.state?.();
          return (
            current?.round_state === "active" &&
            Number(current?.round_generation) > generation &&
            current?.active_transient_count === 0
          );
        },
        { generation: beforeRetry.round_generation },
        { timeout: 20_000 },
      );
      const retry = await beltState(page);
      assert(
        deepEqual(retry.weapon_spec, belt.weapon_spec) &&
          deepEqual(retry.geometry_profile, belt.geometry_profile) &&
          deepEqual(retry.stroke_signature, belt.stroke_signature),
        `${liveCase.id}: Retry changed live payload identity`,
      );

      const leftScreenshot = join(
        destination,
        `${browserName}-${safeName(liveCase.id)}-left-facing.png`,
      );
      const leftDirection = await runDirectionalAttack(
        page,
        liveCase,
        -1,
        leftScreenshot,
      );

      await beltCommand(page, "reforge");
      await page.waitForFunction(
        ({ description, drawingCount }) => {
          const current = window.__forgeM1B1Test?.state?.();
          return (
            current?.screen === "forge" &&
            current?.description === description &&
            Number(current?.drawing_count) === Number(drawingCount)
          );
        },
        {
          description: expected.description,
          drawingCount: expected.drawing_count,
        },
        { timeout: 20_000 },
      );
      const restored = await forgeState(page);
      assert(
        restored.spec && Object.keys(restored.spec).length === 0,
        `${liveCase.id}: Reforge equipped a fallback or stale pending spec`,
      );
      return {
        id: liveCase.id,
        viewport,
        attack_pattern: belt.weapon_spec.attack_pattern,
        element: belt.weapon_spec.element,
        power_score: belt.weapon_spec.power_score,
        corrections: belt.weapon_corrections,
        stroke_signature: belt.stroke_signature,
        geometry_profile: belt.geometry_profile,
        route_payload_consumed: belt.route_payload_consumed,
        fixture_controls_hidden: true,
        attack_committed: true,
        directionality: {
          right: rightDirection,
          left: leftDirection,
        },
        retry_identity_preserved: true,
        reforge_description: restored.description,
        reforge_drawing_count: restored.drawing_count,
      };
    },
  );
  report.live_cases.push(evidence);
}

report.unicode_transport = await runIsolated(
  "unicode-request-in-flight",
  viewports[0],
  async (page) => {
    await openForge(page);
    await page.unroute("**/api/compile-weapon");
    let releaseRequest;
    const requestGate = new Promise((resolveGate) => {
      releaseRequest = resolveGate;
    });
    await page.route("**/api/compile-weapon", async (route) => {
      await requestGate;
      const payload = route.request().postDataJSON();
      await route.fulfill({
        status: 200,
        contentType: "application/json",
        headers: { "Cache-Control": "no-store" },
        body: JSON.stringify({
          success: false,
          provider_invoked: false,
          request_id: payload.request_id,
          weapon_spec: null,
          interpretation_summary:
            "QA transport fixture completed without a provider call.",
          confidence: 0,
          corrections: [],
          fallback_reason: "backend_unavailable",
          provider_metadata: {
            provider: "none",
            model: "none",
            attempts: 0,
          },
          latency_ms: 0,
          estimated_cost: "UNKNOWN",
        }),
      });
    });

    const description = "冰冻手榴弹";
    const input = page.locator("#forge-description-input");
    await input.fill(description);
    await page.waitForFunction(
      (expected) =>
        window.__forgeM1B1Test?.state?.().description === expected,
      description,
      { timeout: 10_000 },
    );
    await drawForgeStroke(page);

    const outgoingRequest = page.waitForRequest(
      (request) =>
        request.url().includes("/api/compile-weapon") &&
        request.method() === "POST",
      { timeout: 15_000 },
    );
    await tapRect(
      page,
      (await forgeControls(page)).forge,
      "Unicode FORGE",
    );
    const request = await outgoingRequest;
    const postedBody = request.postDataJSON();
    const loading = await page.waitForFunction(
      (expected) => {
        const current = window.__forgeM1B1Test?.state?.();
        return (
          current?.screen === "forge" &&
          current?.phase === "loading" &&
          current?.in_flight === true &&
          current?.description === expected &&
          current?.request_snapshot?.description === expected
        )
          ? current
          : false;
      },
      description,
      { timeout: 15_000 },
    );
    const loadingState = await loading.jsonValue();
    const inputPresentation = await input.evaluate((element) => ({
      value: element.value,
      visible: Boolean(element.offsetParent),
      display: getComputedStyle(element).display,
      visibility: getComputedStyle(element).visibility,
      fontSize: getComputedStyle(element).fontSize,
    }));

    assert(
      inputPresentation.value === description,
      "Unicode: native HTML input value changed during the request",
    );
    assert(
      loadingState.description === description,
      "Unicode: Godot draft changed during the request",
    );
    assert(
      loadingState.request_snapshot?.description === description,
      "Unicode: frozen request snapshot changed",
    );
    assert(
      postedBody.description === description,
      "Unicode: same-origin request body changed",
    );
    assert(
      postedBody.request_id === loadingState.request_snapshot?.request_id,
      "Unicode: request ID differs from the visible frozen snapshot",
    );
    assert(
      inputPresentation.visible === false,
      "Unicode: native overlay remained above the disabled Godot input",
    );
    const status = String(loadingState.message || "");
    assert(
      status.includes("DESCRIPTION SAVED") &&
        !status.includes(description) &&
        !status.includes("�") &&
        !status.includes("鈥"),
      `Unicode: loading status echoed unsafe glyphs ${JSON.stringify(status)}`,
    );
    const screenshot = join(
      destination,
      `${browserName}-unicode-request-in-flight.png`,
    );
    await page.screenshot({ path: screenshot });

    releaseRequest();
    await page.waitForFunction(
      () => window.__forgeM1B1Test?.state?.().in_flight === false,
      null,
      { timeout: 15_000 },
    );
    return {
      description,
      html_input_value: inputPresentation.value,
      html_overlay_hidden_in_flight: !inputPresentation.visible,
      godot_draft: loadingState.description,
      request_snapshot_description:
        loadingState.request_snapshot?.description,
      posted_description: postedBody.description,
      request_id: postedBody.request_id,
      status,
      screenshot,
      provider_calls: 0,
    };
  },
);

report.one_shot_reload = await runIsolated(
  "one-shot-refresh",
  viewports[0],
  async (page) => {
    await openForge(page);
    await forgeCommand(page, "m2a_live_route_fixture", {
      pattern: "straight_projectile",
      element: "ice",
      confirm: true,
    });
    const belt = await waitForLiveBelt(page);
    await page.reload({ waitUntil: "domcontentloaded", timeout: 30_000 });
    await page.waitForFunction(
      () =>
        window.__forgeM1B1Test?.state?.().screen === "forge" &&
        typeof window.__forgeBeltCombat === "undefined",
      null,
      { timeout: 20_000 },
    );
    const afterReload = await forgeState(page);
    assert(
      afterReload.spec && Object.keys(afterReload.spec).length === 0,
      "refresh replayed or retained the consumed live weapon",
    );
    return {
      consumed_before_reload: belt.route_payload_consumed,
      screen_after_reload: afterReload.screen,
      replayed: false,
    };
  },
);

report.invalid_route = await runIsolated(
  "invalid-route-fail-closed",
  viewports[1],
  async (page) => {
    await openForge(page);
    await forgeCommand(page, "m2a_live_route_fixture", {
      pattern: "area_blast",
      element: "fire",
      confirm: false,
    });
    const before = await waitForConfirmation(page);
    await forgeCommand(page, "m2a_invalid_live_route");
    await page.waitForFunction(
      ({ description, drawingCount }) => {
        const current = window.__forgeM1B1Test?.state?.();
        return (
          current?.screen === "forge" &&
          current?.description === description &&
          Number(current?.drawing_count) === Number(drawingCount) &&
          String(current?.message || "").includes("could not start safely")
        );
      },
      {
        description: before.description,
        drawingCount: before.drawing_count,
      },
      { timeout: 20_000 },
    );
    const recovered = await forgeState(page);
    assert(
      recovered.spec && Object.keys(recovered.spec).length === 0,
      "invalid route equipped a fallback, fixture, or stale WeaponSpec",
    );
    return {
      failed_closed: true,
      restored_description: recovered.description,
      restored_drawing_count: recovered.drawing_count,
      message: recovered.message,
    };
  },
);

report.side_view_regression = await runIsolated(
  "explicit-side-view-regression",
  viewports[2],
  async (page) => {
    await openForge(page, true);
    await forgeCommand(page, "m2a_live_route_fixture", {
      pattern: "melee_slash",
      element: "normal",
      confirm: false,
    });
    await waitForConfirmation(page);
    await forgeCommand(page, "developer_mode", { enabled: true });
    await page.waitForFunction(
      () => window.__forgeM1B1Test?.state?.().developer_mode === true,
      null,
      { timeout: 20_000 },
    );
    await tapRect(
      page,
      (await forgeControls(page)).confirm,
      "explicit side-view CONFIRM",
    );
    await page.waitForFunction(
      () => {
        const current = window.__forgeM1B1Test?.state?.();
        return (
          current?.screen === "combat" &&
          current?.combat_route === "side_view_regression" &&
          current?.side_view_route_explicit === true
        );
      },
      null,
      { timeout: 20_000 },
    );
    const sideView = await forgeState(page);
    assert(
      typeof (await page.evaluate(() => window.__forgeBeltCombat)) ===
        "undefined",
      "explicit side-view route unexpectedly installed belt combat",
    );
    return {
      route: sideView.combat_route,
      explicit: sideView.side_view_route_explicit,
      screen: sideView.screen,
      weapon_pattern: sideView.held_visual?.attack_pattern,
    };
  },
);

try {
  assert(report.live_cases.length === 5, "five live attack patterns did not run");
  assert(
    new Set(report.live_cases.map((entry) => entry.element)).size === 4,
    "four live elements did not run",
  );
  assert(
    report.dodge_touch_regression?.consecutive_ready_reuses >= 20,
    "DODGE did not survive 20 consecutive real-touch cooldown cycles",
  );
  assert(report.console_errors.length === 0, "application console errors recorded");
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
