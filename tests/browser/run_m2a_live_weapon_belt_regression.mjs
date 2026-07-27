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

async function tapRect(page, rect, label) {
  assert(rect?.width > 0 && rect?.height > 0, `${label} is not actionable`);
  await page.touchscreen.tap(
    rect.x + rect.width / 2,
    rect.y + rect.height / 2,
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
  suite: "M2A live WeaponSpec belt route provider-free regression",
  browser: browserName,
  target: targetUrl,
  provider_policy: "NO PROVIDER CALLS",
  captured_at: new Date().toISOString(),
  live_cases: [],
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
      const expected = {
        description: confirmation.description,
        drawing_count: confirmation.drawing_count,
        spec: confirmation.spec,
        corrections: confirmation.result?.corrections || [],
        budget: confirmation.result?.power_budget || {},
        geometry: confirmation.geometry_profile,
      };
      await tapRect(
        page,
        (await forgeControls(page)).confirm,
        `${liveCase.id} CONFIRM`,
      );
      const belt = await waitForLiveBelt(page);
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
        belt.stroke_signature?.stroke_count === expected.drawing_count &&
          belt.stroke_signature?.point_count > 0 &&
          /^[a-f0-9]{64}$/.test(belt.stroke_signature?.sha256 || ""),
        `${liveCase.id}: original-stroke signature is incomplete`,
      );
      const controls = await beltControls(page);
      assertFixtureControlsHidden(controls, liveCase.id);
      for (const action of ["joystick", "attack", "retry", "reforge"]) {
        assertRect(controls[action], viewport, `${liveCase.id} ${action}`);
      }

      await beltCommand(page, "pause_enemies", { enabled: false });
      const attackCount = belt.accepted_attack_count;
      await beltCommand(page, "attack");
      await page.waitForFunction(
        ({ previousCount }) => {
          const current = window.__forgeBeltCombat?.state?.();
          return (
            Number(current?.accepted_attack_count) === previousCount + 1 &&
            (current?.combat_events || []).some(
              (event) => event.kind === "attack_committed",
            )
          );
        },
        { previousCount: attackCount },
        { timeout: 20_000 },
      );
      await page.waitForFunction(
        () => {
          const current = window.__forgeBeltCombat?.state?.();
          return (
            current?.active_transient_count === 0 &&
            current?.cleanup?.player_attack_active === false &&
            current?.cleanup?.held_visible === true
          );
        },
        null,
        { timeout: 20_000 },
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
        retry_identity_preserved: true,
        reforge_description: restored.description,
        reforge_drawing_count: restored.drawing_count,
      };
    },
  );
  report.live_cases.push(evidence);
}

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
