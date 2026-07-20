import { mkdir, readFile, writeFile } from "node:fs/promises";
import { createRequire } from "node:module";
import { dirname, join, resolve } from "node:path";

const require = createRequire(import.meta.url);
const [
  browserName = "chromium",
  targetUrl = "http://127.0.0.1:8060/",
  outputPath = "",
  mode = "simulated",
] = process.argv.slice(2);
const modulePath = process.env.PLAYWRIGHT_MODULE_PATH || "playwright";
const playwright = require(modulePath);
const browserType = playwright[browserName];

if (!browserType) throw new Error(`Unsupported browser: ${browserName}`);
if (!new Set(["simulated", "fixture-one-call", "live-one-call"]).has(mode)) {
  throw new Error(`Unsupported Anthropic QA mode: ${mode}`);
}
if (
  mode === "live-one-call" &&
  process.env.M1B1_QA_ALLOW_LIVE_PROVIDER !== "one-paid-call"
) {
  throw new Error(
    "Live provider QA is disabled. Set M1B1_QA_ALLOW_LIVE_PROVIDER=one-paid-call " +
      "only after the integrator confirms the Sites secret, D1 guard, and USD 5 cap.",
  );
}

const EXPECTED_PROVIDER = "anthropic";
const EXPECTED_MODEL = "claude-haiku-4-5-20251001";
const PATTERNS = [
  "melee_slash",
  "straight_projectile",
  "boomerang",
  "area_blast",
  "piercing",
];
const MOBILE_VIEWPORTS = [
  { width: 844, height: 390 },
  { width: 852, height: 393 },
  { width: 915, height: 412 },
  { width: 844, height: 343, label: "safari-toolbar-stress" },
];

const profiles = {
  melee_slash: {
    name: "Ink Longline Sketchblade",
    weapon_class: "melee",
    attack_pattern: "melee_slash",
    element: "normal",
    damage: 36,
    attack_speed: 1.0,
    range: 132.0,
    special_ability: "knockback_burst",
    status_effect: "knockback",
    drawback: "slow_recovery",
    visual_material: "forged_metal",
    power_score: 33,
    projectile_speed: 560.0,
    area_radius: 120.0,
    pierce_count: 1,
    return_speed: 680.0,
  },
  straight_projectile: {
    name: "Ink Detailshot Darter",
    weapon_class: "ranged",
    attack_pattern: "straight_projectile",
    element: "normal",
    damage: 26,
    attack_speed: 1.3,
    range: 675.0,
    special_ability: "none",
    status_effect: "none",
    drawback: "low_impact",
    visual_material: "forged_metal",
    power_score: 46,
    projectile_speed: 620.0,
    area_radius: 120.0,
    pierce_count: 1,
    return_speed: 680.0,
  },
  boomerang: {
    name: "Volt Returning Crescent",
    weapon_class: "ranged",
    attack_pattern: "boomerang",
    element: "electric",
    damage: 30,
    attack_speed: 0.95,
    range: 620.0,
    special_ability: "return_strike",
    status_effect: "shock",
    drawback: "self_stagger",
    visual_material: "charged_metal",
    power_score: 74,
    projectile_speed: 520.0,
    area_radius: 120.0,
    pierce_count: 1,
    return_speed: 760.0,
  },
  area_blast: {
    name: "Volt Crowdbreaker Nova",
    weapon_class: "melee",
    attack_pattern: "area_blast",
    element: "electric",
    damage: 34,
    attack_speed: 0.7,
    range: 220.0,
    special_ability: "splash_wave",
    status_effect: "shock",
    drawback: "cooldown_lock",
    visual_material: "charged_metal",
    power_score: 70,
    projectile_speed: 560.0,
    area_radius: 165.0,
    pierce_count: 1,
    return_speed: 680.0,
  },
  piercing: {
    name: "Ink Shieldsplitter Lance",
    weapon_class: "ranged",
    attack_pattern: "piercing",
    element: "normal",
    damage: 29,
    attack_speed: 1.05,
    range: 700.0,
    special_ability: "shield_break",
    status_effect: "none",
    drawback: "narrow_arc",
    visual_material: "forged_metal",
    power_score: 77,
    projectile_speed: 720.0,
    area_radius: 120.0,
    pierce_count: 3,
    return_speed: 680.0,
  },
};

function makeResponse(requestId, plan) {
  const pattern = PATTERNS.includes(plan.pattern) ? plan.pattern : "melee_slash";
  const weaponSpec = structuredClone(profiles[pattern]);
  return {
    request_id: requestId,
    weapon_spec: weaponSpec,
    interpretation_summary:
      plan.summary ||
      `Interpreted as a ${weaponSpec.element} ${pattern.replaceAll("_", " ")}.`,
    confidence: plan.confidence ?? 0.92,
    corrections: plan.corrections || [],
    fallback_reason: plan.fallbackReason || "",
    provider_metadata: {
      provider: EXPECTED_PROVIDER,
      model: EXPECTED_MODEL,
      attempts: plan.attempts ?? 1,
    },
    latency_ms: plan.latencyMs ?? plan.delayMs ?? 0,
    estimated_cost:
      plan.cost === "UNKNOWN"
        ? "UNKNOWN"
        : { amount: plan.cost ?? 0.0002, currency: "USD" },
    schema_valid: true,
    allow_list_valid: true,
    power_valid: true,
    runtime_valid: true,
  };
}

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

const launchOptions = { headless: true };
if (process.env.M1B1_QA_BROWSER_EXECUTABLE) {
  launchOptions.executablePath = process.env.M1B1_QA_BROWSER_EXECUTABLE;
}
const browser = await browserType.launch(launchOptions);
let context;
try {
  const device = playwright.devices["iPhone 15"];
  context = await browser.newContext({
    ...device,
    viewport: { width: 844, height: 390 },
    screen: { width: 844, height: 390 },
  });
  const page = await context.newPage();
  const consoleMessages = [];
  const apiObservations = [];
  const apiResponseSnapshots = [];
  const apiResponseTasks = [];
  const simulatedPlans = [];
  const screenshots = [];
  let simulatedProviderCalls = 0;
  const screenshotRoot = process.env.M1B1_QA_SCREENSHOT_DIR
    ? resolve(process.env.M1B1_QA_SCREENSHOT_DIR)
    : "";
  if (screenshotRoot) await mkdir(screenshotRoot, { recursive: true });
  const capture = async (label) => {
    if (!screenshotRoot) return;
    const path = join(screenshotRoot, `${browserName}-${label}.png`);
    await page.screenshot({ path });
    screenshots.push(path);
  };

  page.on("console", (message) => {
    consoleMessages.push({ type: message.type(), text: message.text() });
  });
  page.on("request", (request) => {
    if (!request.url().includes("/api/compile-weapon")) return;
    const headers = request.headers();
    const body = request.postDataJSON?.() || {};
    apiObservations.push({
      sameOrigin: new URL(request.url()).origin === new URL(targetUrl).origin,
      hasAuthorization: Boolean(headers.authorization || headers["x-api-key"]),
      hasAnthropicVersion: Boolean(headers["anthropic-version"]),
      requestIdShape: /^m1b1-[0-9a-f]{32}$/.test(String(body.request_id || "")),
      hasNumericDrawingSummary:
        body.drawing_summary &&
        Number.isFinite(body.drawing_summary.stroke_count) &&
        Number.isFinite(body.drawing_summary.point_count) &&
        Number.isFinite(body.drawing_summary.aspect_ratio) &&
        Number.isFinite(body.drawing_summary.coverage),
      leakedStrokeGeometry:
        Array.isArray(body.strokes) ||
        Array.isArray(body.points) ||
        Array.isArray(body.drawing_summary?.strokes),
    });
  });
  page.on("response", (response) => {
    if (!response.url().includes("/api/compile-weapon")) return;
    const task = response
      .json()
      .then((body) => {
        const sourceSpec = body?.weapon_spec;
        const weaponSpec =
          sourceSpec && typeof sourceSpec === "object"
            ? Object.fromEntries(Object.entries(sourceSpec).filter(([key]) => key !== "name"))
            : null;
        apiResponseSnapshots.push({
          status: response.status(),
          requestId: String(body?.request_id || ""),
          fallbackReason: String(body?.fallback_reason || ""),
          provider: String(body?.provider_metadata?.provider || ""),
          model: String(body?.provider_metadata?.model || ""),
          attempts: Number(body?.provider_metadata?.attempts ?? -1),
          schemaValid: body?.schema_valid === true,
          allowListValid: body?.allow_list_valid === true,
          runtimeValid: body?.runtime_valid === true,
          weaponSpec,
        });
      })
      .catch((error) => {
        apiResponseSnapshots.push({
          status: response.status(),
          parseError: String(error?.message || error),
        });
      });
    apiResponseTasks.push(task);
  });

  if (mode === "simulated") {
    await page.route("**/api/compile-weapon", async (route) => {
      const plan = simulatedPlans.shift();
      simulatedProviderCalls += 1;
      if (!plan) {
        await route.fulfill({
          status: 503,
          contentType: "application/json",
          body: JSON.stringify({ error: "qa_plan_missing" }),
        });
        return;
      }
      const payload = route.request().postDataJSON();
      if (plan.delayMs) await page.waitForTimeout(plan.delayMs);
      try {
        await route.fulfill({
          status: plan.status || 200,
          contentType: "application/json",
          headers: { "Cache-Control": "no-store" },
          body: JSON.stringify(makeResponse(payload.request_id, plan)),
        });
      } catch (error) {
        // A cancelled Godot HTTPRequest can close the browser request before the
        // scripted late response is fulfilled. This is expected in CANCEL tests.
        if (!String(error?.message || error).toLowerCase().includes("route")) throw error;
      }
    });
  } else if (mode === "fixture-one-call") {
    const fixturePath = String(process.env.M1B1_QA_RESPONSE_FIXTURE ?? "").trim();
    if (!fixturePath) {
      throw new Error("M1B1_QA_RESPONSE_FIXTURE is required in fixture-one-call mode.");
    }
    const fixture = JSON.parse(await readFile(resolve(fixturePath), "utf8"));
    await page.route("**/api/compile-weapon", async (route) => {
      const payload = route.request().postDataJSON();
      simulatedProviderCalls += 1;
      await route.fulfill({
        status: 200,
        contentType: "application/json",
        headers: {
          "Cache-Control": "no-store",
          "Cross-Origin-Opener-Policy": "same-origin",
          "Cross-Origin-Embedder-Policy": "require-corp",
          "Cross-Origin-Resource-Policy": "same-origin",
          "X-Content-Type-Options": "nosniff",
        },
        body: JSON.stringify({ ...fixture, request_id: payload.request_id }),
      });
    });
  }

  const qaUrl = new URL(targetUrl);
  qaUrl.searchParams.set("qa", "m1b1");
  await page.goto(qaUrl.toString(), { waitUntil: "domcontentloaded" });

  const input = page.locator("#forge-description-input");
  const clearDescription = page.locator("#forge-description-clear");
  const sleep = (milliseconds) => page.waitForTimeout(milliseconds);
  const bridgeCall = async (method, ...args) =>
    page.evaluate(
      async ({ method, args }) => {
        const bridge = window.__forgeM1B1Test;
        if (!bridge || typeof bridge[method] !== "function") {
          throw new Error(`M1B1 QA bridge method missing: ${method}`);
        }
        return await bridge[method](...args);
      },
      { method, args },
    );
  const state = () => bridgeCall("state");
  const controls = () => bridgeCall("controls");
  const center = (rect) => {
    assert(rect && rect.width > 0 && rect.height > 0, `Hidden control: ${JSON.stringify(rect)}`);
    return { x: rect.x + rect.width / 2, y: rect.y + rect.height / 2 };
  };
  const tapRect = async (rect) => {
    const point = center(rect);
    await page.touchscreen.tap(point.x, point.y);
  };
  const tapControl = async (name) => {
    const current = await controls();
    assert(current[name], `Missing control: ${name}`);
    await tapRect(current[name]);
  };
  const waitFor = async (predicate, label, timeout = 15000) => {
    const started = Date.now();
    let latest = null;
    while (Date.now() - started < timeout) {
      latest = await state();
      if (predicate(latest)) return latest;
      await sleep(40);
    }
    throw new Error(`Timed out waiting for ${label}: ${JSON.stringify(latest)}`);
  };
  const waitForForge = async () => {
    await page.waitForFunction(
      () =>
        Boolean(
          window.__forgeM1B1Test &&
            typeof window.__forgeM1B1Test.state === "function" &&
            document.querySelector("#forge-description-input")?.offsetParent,
        ),
      null,
      { timeout: 15000 },
    );
    return waitFor(
      (value) => value.screen === "forge" && value.phase === "idle",
      "idle forge",
    );
  };
  const assertInside = (rect, viewport, label) => {
    assert(rect && rect.width > 0 && rect.height > 0, `${label} is hidden`);
    assert(
      rect.x >= -0.5 &&
        rect.y >= -0.5 &&
        rect.x + rect.width <= viewport.width + 0.5 &&
        rect.y + rect.height <= viewport.height + 0.5,
      `${label} outside ${viewport.width}x${viewport.height}: ${JSON.stringify(rect)}`,
    );
  };
  const drawStroke = async () => {
    const canvas = (await controls()).canvas;
    assertInside(canvas, page.viewportSize(), "drawing canvas");
    const points = [
      { x: canvas.x + canvas.width * 0.18, y: canvas.y + canvas.height * 0.65 },
      { x: canvas.x + canvas.width * 0.38, y: canvas.y + canvas.height * 0.38 },
      { x: canvas.x + canvas.width * 0.58, y: canvas.y + canvas.height * 0.68 },
      { x: canvas.x + canvas.width * 0.78, y: canvas.y + canvas.height * 0.36 },
    ];
    if (browserName === "chromium") {
      const cdp = await page.context().newCDPSession(page);
      await cdp.send("Input.dispatchTouchEvent", {
        type: "touchStart",
        touchPoints: [{ ...points[0], radiusX: 4, radiusY: 4, force: 1, id: 1 }],
      });
      for (const point of points.slice(1)) {
        await cdp.send("Input.dispatchTouchEvent", {
          type: "touchMove",
          touchPoints: [{ ...point, radiusX: 4, radiusY: 4, force: 1, id: 1 }],
        });
      }
      await cdp.send("Input.dispatchTouchEvent", { type: "touchEnd", touchPoints: [] });
      await cdp.detach();
    } else {
      // Windows Playwright WebKit has no CDP touch-drag path. This validates
      // canvas ownership with WebKit pointer input; physical finger drawing is
      // still an explicit iPhone gate.
      await page.mouse.move(points[0].x, points[0].y);
      await page.mouse.down();
      for (const point of points.slice(1)) {
        await page.mouse.move(point.x, point.y, { steps: 4 });
      }
      await page.mouse.up();
    }
    await waitFor((value) => value.drawing_count > 0, "drawing stroke");
  };
  const prepareInput = async (description) => {
    const current = await state();
    if (current.description || current.drawing_count) await tapControl("reset");
    await input.fill(description);
    await waitFor((value) => value.description === description, "Description sync");
    await drawStroke();
  };
  const assertSafe = (current, label) => {
    const result = current.result;
    assert(result?.weapon_spec, `${label}: WeaponSpec missing`);
    assert(result.schema_valid === true, `${label}: schema invalid`);
    assert(result.allow_list_valid === true, `${label}: allow-list invalid`);
    assert(result.runtime_valid === true, `${label}: runtime invalid`);
    assert(
      Number.isFinite(result.weapon_spec.power_score) && result.weapon_spec.power_score <= 100,
      `${label}: invalid Power Score`,
    );
    return result;
  };
  const assertCreativeInput = (current, description, label) => {
    assert(current.description === description, `${label}: Description lost`);
    assert(current.drawing_count > 0, `${label}: drawing lost`);
  };
  const terminal = (value) =>
    value.screen === "confirmation" && ["result", "fallback"].includes(value.phase);

  const viewportMeta = await page.locator('meta[name="viewport"]').getAttribute("content");
  assert(viewportMeta?.includes("viewport-fit=cover"), `viewport-fit=cover missing: ${viewportMeta}`);
  await page.setViewportSize({ width: 844, height: 390 });
  await waitForForge();

  const initialState = await state();
  const initialControls = await controls();
  assert(!initialState.selector_visible, "Normal player sees attack-pattern selector");
  assert(!initialState.developer_mode && !initialState.modify_mode, "Normal player entered test UI");
  assert(
    (initialControls.pattern_buttons || []).every((rect) => !rect || rect.width === 0 || rect.height === 0),
    "Hidden selector retains a clickable rectangle",
  );

  const layouts = [];
  for (const viewport of MOBILE_VIEWPORTS) {
    await page.setViewportSize(viewport);
    await sleep(240);
    await waitForForge();
    const currentControls = await controls();
    const inputBox = await input.boundingBox();
    const clearBox = await clearDescription.boundingBox();
    for (const [label, rect] of Object.entries({
      canvas: currentControls.canvas,
      forge: currentControls.forge,
      reset: currentControls.reset,
      input: inputBox,
      clear: clearBox,
    })) {
      assertInside(rect, viewport, label);
    }
    assert(
      currentControls.canvas.height >= 149.5 && currentControls.canvas.height >= viewport.height * 0.4,
      `Canvas too short at ${viewport.width}x${viewport.height}`,
    );
    assert(inputBox.height >= 43.5, `Description target too short at ${viewport.width}x${viewport.height}`);
    assert(
      clearBox.width >= 44 && clearBox.height >= 44,
      `Description clear target too small at ${viewport.width}x${viewport.height}`,
    );
    const metrics = await page.evaluate(() => ({
      innerWidth,
      innerHeight,
      scrollWidth: document.documentElement.scrollWidth,
      scrollHeight: document.documentElement.scrollHeight,
      visualWidth: window.visualViewport?.width ?? innerWidth,
      visualHeight: window.visualViewport?.height ?? innerHeight,
    }));
    assert(
      metrics.scrollWidth <= metrics.innerWidth && metrics.scrollHeight <= metrics.innerHeight,
      `Document scroll at ${viewport.width}x${viewport.height}: ${JSON.stringify(metrics)}`,
    );
    layouts.push({
      viewport: { width: viewport.width, height: viewport.height, label: viewport.label || "target" },
      canvasHeight: currentControls.canvas.height,
      inputHeight: inputBox.height,
      visualHeight: metrics.visualHeight,
    });
    await capture(`forge-${viewport.width}x${viewport.height}`);
  }

  await page.setViewportSize({ width: 844, height: 390 });
  await waitForForge();
  await input.click();
  assert(await input.evaluate((element) => document.activeElement === element), "Description did not focus");
  await input.fill("editable electric umbrella");
  await input.press("End");
  await input.press("Backspace");
  assert((await input.inputValue()) === "editable electric umbrell", "Description edit/delete failed");
  await clearDescription.click();
  assert((await input.inputValue()) === "", "Description clear button failed");

  if (mode === "live-one-call" || mode === "fixture-one-call") {
    const description = "a returning electric boomerang that shocks targets";
    await prepareInput(description);
    const before = await state();
    await tapControl("forge");
    const completed = await waitFor(terminal, "live Anthropic result", 20000);
    await Promise.all(apiResponseTasks);
    assertCreativeInput(completed, description, "live Anthropic result");
    const result = assertSafe(completed, "live Anthropic result");
    assert(
      completed.request_count === before.request_count + 1,
      "Single-call smoke made multiple logical requests",
    );
    assert(
      completed.phase === "result" && !completed.fallback_reason,
      `Single-call smoke fell back: ${completed.fallback_reason || "unknown"}; ` +
        `response=${JSON.stringify(apiResponseSnapshots.at(-1) || null)}`,
    );
    assert(result.provider_metadata?.provider === EXPECTED_PROVIDER, "Live response provider mismatch");
    assert(result.provider_metadata?.model === EXPECTED_MODEL, "Live response model mismatch");
    assert(result.provider_metadata?.attempts === 1, "Live success used more than one upstream attempt");
    assert(result.weapon_spec.attack_pattern === "boomerang", "Live semantic smoke pattern mismatch");
    assert(result.weapon_spec.element === "electric", "Live semantic smoke element mismatch");
    assert(
      result.estimated_cost &&
        typeof result.estimated_cost === "object" &&
        result.estimated_cost.currency === "USD" &&
        Number.isFinite(result.estimated_cost.amount) &&
        result.estimated_cost.amount >= 0 &&
        result.estimated_cost.amount < 5,
      "Live provider usage cost was not recorded as bounded USD metadata",
    );
    await capture("live-confirmation");
    await tapControl("confirm");
    let combat = await waitFor((value) => value.screen === "combat", "live combat");
    assert(!combat.selector_visible, "Selector leaked into live combat");
    const attackCount = combat.attack_count;
    await tapControl("attack");
    combat = await waitFor((value) => value.attack_count > attackCount, "live attack");
    assert(combat.last_attack_pattern === "boomerang", "Live weapon executed wrong attack module");
    await capture("live-combat-boomerang-attack");
  } else {
    const preservedDescription = "a delayed electric boomerang for mobile cancellation";
    await prepareInput(preservedDescription);
    // Public startup, orientation, and screenshot capture can consume more than
    // the former 1.6 s delay. Keep the intercepted response pending long enough
    // to prove CANCEL and the later stale response as distinct transitions.
    simulatedPlans.push({ pattern: "boomerang", attempts: 1, delayMs: 6000 });
    const beforeCancel = await state();
    await tapControl("forge");
    const loading = await waitFor((value) => value.phase === "loading", "cancellable loading");
    assert(loading.in_flight, "Loading state is not in flight");
    const loadingControls = await controls();
    assertInside(loadingControls.cancel, page.viewportSize(), "cancel");

    const backgroundPage = await context.newPage();
    await backgroundPage.goto("about:blank");
    await backgroundPage.bringToFront();
    await sleep(120);
    await page.bringToFront();
    assertCreativeInput(await state(), preservedDescription, "background/resume simulation");
    await backgroundPage.close();

    await page.setViewportSize({ width: 390, height: 844 });
    const portraitLoading = await waitFor((value) => value.screen === "portrait", "portrait during loading");
    assert(portraitLoading.in_flight, "Rotation cancelled the active request unexpectedly");
    assert(!(await input.isVisible()), "Description overlay leaked above portrait gate");
    await capture("portrait-during-loading");
    await page.setViewportSize({ width: 844, height: 390 });
    await waitFor((value) => value.screen === "forge" && value.phase === "loading", "loading after rotation");
    await tapControl("cancel");
    const cancelled = await waitFor(
      (value) => value.screen === "forge" && value.phase === "idle",
      "cancel recovery",
    );
    assert(cancelled.request_count === beforeCancel.request_count + 1, "CANCEL duplicated the request");
    assertCreativeInput(cancelled, preservedDescription, "CANCEL");
    assert(!cancelled.in_flight, "CANCEL left request in flight");
    await sleep(6200);
    const afterLate = await state();
    assert(afterLate.screen === "forge" && afterLate.phase === "idle", "Late response changed the screen");
    assert(afterLate.late_response_ignored >= 1, "Late response was not invalidated");
    assertCreativeInput(afterLate, preservedDescription, "late response");

    await tapControl("reset");
    const timeoutDescription = "an ice lance preserved through provider timeout";
    await input.fill(timeoutDescription);
    await drawStroke();
    simulatedPlans.push({
      pattern: "melee_slash",
      attempts: 1,
      delayMs: 320,
      fallbackReason: "provider_timeout",
      confidence: 0,
      cost: "UNKNOWN",
      summary: "A safe practice weapon was substituted because the interpreter timed out.",
    });
    const timeoutBefore = await state();
    await tapControl("forge");
    const timeoutResult = await waitFor(terminal, "timeout fallback");
    assert(timeoutResult.phase === "fallback", "Timeout did not enter a safe fallback");
    assert(timeoutResult.request_count === timeoutBefore.request_count + 1, "Timeout duplicated logical request");
    assert(timeoutResult.request_attempts === 1, "Wrapper timeout automatically retried");
    assert(timeoutResult.result.provider_metadata?.attempts === 1, "Timeout billed more than one attempt");
    assert(timeoutResult.fallback_reason === "provider_timeout", "Timeout fallback reason mismatch");
    assertCreativeInput(timeoutResult, timeoutDescription, "timeout fallback");
    assertSafe(timeoutResult, "timeout fallback");

    simulatedPlans.push({ pattern: "boomerang", attempts: 1, delayMs: 420 });
    const retryBefore = await state();
    await tapControl("try_again");
    const retryLoading = await waitFor(
      (value) => value.phase === "loading" || terminal(value),
      "TRY AGAIN loading or safe terminal",
    );
    const retryResult = terminal(retryLoading)
      ? retryLoading
      : await waitFor(terminal, "TRY AGAIN result");
    assert(retryResult.request_count === retryBefore.request_count + 1, "TRY AGAIN request count mismatch");
    assert(retryResult.request_id !== retryBefore.request_id, "TRY AGAIN reused the logical request id");
    assertCreativeInput(retryResult, timeoutDescription, "TRY AGAIN");
    assertSafe(retryResult, "TRY AGAIN");
    assert(!retryResult.selector_visible, "TRY AGAIN exposed selector to normal player");

    await page.setViewportSize({ width: 390, height: 844 });
    await waitFor((value) => value.screen === "portrait", "portrait from confirmation");
    await page.setViewportSize({ width: 844, height: 390 });
    const restoredConfirmation = await waitFor(
      (value) => value.screen === "confirmation" && value.phase === "result",
      "confirmation after rotation",
    );
    assertCreativeInput(restoredConfirmation, timeoutDescription, "confirmation rotation");
    await capture("confirmation-after-rotation");

    // A physical orientation animation does not permit a same-frame tap. Give
    // WebKit one short visual-settle window after the bridge reports the restored
    // confirmation, then require the very first user-equivalent tap to succeed.
    await sleep(250);

    await tapControl("modify");
    let modified = await waitFor(
      (value) => value.screen === "confirmation" && value.modify_mode && value.selector_visible,
      "MODIFY selector",
    );
    const modifyControls = await controls();
    assert(modifyControls.pattern_buttons?.length === 5, "MODIFY did not expose five modes");
    for (let index = 0; index < PATTERNS.length; index += 1) {
      await tapRect(modifyControls.pattern_buttons[index]);
      modified = await waitFor(
        (value) =>
          value.selected_pattern === PATTERNS[index] &&
          value.result?.schema_valid === true &&
          value.result?.runtime_valid === true,
        `validated MODIFY ${PATTERNS[index]}`,
      );
      assertSafe(modified, `MODIFY ${PATTERNS[index]}`);
      assert(
        modified.result.weapon_spec.attack_pattern === PATTERNS[index],
        `MODIFY mismatch for ${PATTERNS[index]}`,
      );
    }
    for (let index = 0; index < 20; index += 1) {
      await tapRect(modifyControls.pattern_buttons[index % PATTERNS.length]);
    }
    await tapRect(modifyControls.pattern_buttons[2]);
    modified = await waitFor(
      (value) => value.selected_pattern === "boomerang" && value.result?.runtime_valid === true,
      "final boomerang correction",
    );
    assertCreativeInput(modified, timeoutDescription, "MODIFY");
    await capture("modify-boomerang-selected");
    await tapControl("confirm");
    let combat = await waitFor((value) => value.screen === "combat", "corrected combat");
    assert(!combat.selector_visible, "Selector leaked into combat");
    const beforeAttack = combat.attack_count;
    await tapControl("attack");
    combat = await waitFor((value) => value.attack_count > beforeAttack, "corrected attack");
    assert(combat.last_attack_pattern === "boomerang", "Corrected weapon executed wrong module");
    await capture("combat-boomerang-attack");
    await tapControl("reforge");
    await waitForForge();

    const retrySafeDescription = "an electric crowd blast after retry-safe transport reset";
    await prepareInput(retrySafeDescription);
    simulatedPlans.push({
      pattern: "area_blast",
      attempts: 2,
      delayMs: 360,
      corrections: ["provider transport: one explicitly retry-safe attempt recovered"],
    });
    const retrySafeBefore = await state();
    await tapControl("forge");
    const retrySafeResult = await waitFor(terminal, "explicitly retry-safe result");
    const retrySafeSpec = assertSafe(retrySafeResult, "explicitly retry-safe result");
    assert(retrySafeResult.request_count === retrySafeBefore.request_count + 1, "Safe retry duplicated logical request");
    assert(retrySafeSpec.provider_metadata?.attempts === 2, "Safe retry did not record exactly two attempts");
    assertCreativeInput(retrySafeResult, retrySafeDescription, "safe retry");
    assert(!retrySafeResult.selector_visible, "Safe retry exposed selector");
  }

  assert(apiObservations.length >= 1, "No same-origin compile request was observed");
  for (const observation of apiObservations) {
    assert(observation.sameOrigin, "Godot called a cross-origin provider endpoint");
    assert(!observation.hasAuthorization, "Client request contains provider authorization");
    assert(!observation.hasAnthropicVersion, "Client request contains Anthropic provider headers");
    assert(observation.requestIdShape, "Client request id is not a random 128-bit namespace");
    assert(observation.hasNumericDrawingSummary, "Client omitted bounded numeric drawing_summary");
    assert(!observation.leakedStrokeGeometry, "Client sent raw stroke geometry to M1B1");
  }

  const expectedSimulatedCalls =
    mode === "simulated" ? 4 : mode === "fixture-one-call" ? 1 : 0;
  assert(
    simulatedProviderCalls === expectedSimulatedCalls,
    `Provider-call accounting mismatch: expected ${expectedSimulatedCalls}, got ${simulatedProviderCalls}`,
  );

  const knownRendererMessage = (entry) =>
    entry.text.includes("GPU stall due to ReadPixels") ||
    entry.text.includes("CONTEXT_LOST_WEBGL: loseContext") ||
    entry.text.includes("glBlitFramebuffer") ||
    entry.text.includes("glClear") ||
    entry.text.includes("WEBGL_polygon_mode");
  const knownHostingMessage = (entry) =>
    entry.text ===
    "window.styleMedia is a deprecated draft version of window.matchMedia API, and it will be removed in the future.";
  const seriousConsole = consoleMessages.filter((entry) => {
    if (entry.type !== "error" && entry.type !== "warning") return false;
    return !knownRendererMessage(entry) && !knownHostingMessage(entry);
  });
  assert(seriousConsole.length === 0, `Application console errors/warnings: ${JSON.stringify(seriousConsole)}`);

  const result = {
    suite: "M1B1 Anthropic mobile regression",
    mode,
    browserName,
    providerClaim:
      mode === "live-one-call"
        ? EXPECTED_PROVIDER
        : mode === "fixture-one-call"
          ? "SIMULATED REAL RESPONSE FIXTURE"
          : "NOT TESTED - simulated HTTP only",
    modelClaim:
      mode === "live-one-call"
        ? EXPECTED_MODEL
        : mode === "fixture-one-call"
          ? "SIMULATED REAL RESPONSE FIXTURE"
          : "NOT TESTED - simulated HTTP only",
    layouts,
    apiRequestCount: apiObservations.length,
    apiResponses: apiResponseSnapshots,
    simulatedProviderCalls: mode === "live-one-call" ? 0 : simulatedProviderCalls,
    orientationDuringLoading: mode === "simulated" ? "PASS" : "NOT RUN",
    confirmationRotation: mode === "simulated" ? "PASS" : "NOT RUN",
    backgroundResume: mode === "simulated" ? "PASS - tab simulation only" : "NOT RUN",
    physicalIPhoneSafari: "TO VALIDATE",
    applicationConsoleErrors: 0,
    screenshots,
    knownHostingMessages: consoleMessages.filter(knownHostingMessage).map((entry) => entry.text),
    knownRendererMessages: consoleMessages.filter(knownRendererMessage).map((entry) => entry.text),
  };
  const serialized = `${JSON.stringify(result, null, 2)}\n`;
  process.stdout.write(serialized);
  if (outputPath) {
    const destination = resolve(outputPath);
    await mkdir(dirname(destination), { recursive: true });
    await writeFile(destination, serialized, "utf8");
  }
  await context.close();
  context = null;
} finally {
  if (context) await context.close();
  await browser.close();
}
