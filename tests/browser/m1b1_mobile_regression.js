/*
 * HISTORICAL / NOT EXECUTED.
 * Retained only to audit the pre-Anthropic expression runner. The supported
 * run_m1b1_regression.mjs entry point now delegates to the canonical Anthropic
 * mobile suite. Current provider failures are explicit non-equipable errors
 * with weapon_spec=null; this old file's local-fallback assertions are obsolete.
 */
async (page) => {
  const browserName = page.context().browser().browserType().name();
  const messages = [];
  page.on("console", (message) => messages.push({ type: message.type(), text: message.text() }));

  const sleep = (milliseconds) => page.waitForTimeout(milliseconds);
  const input = page.locator("#forge-description-input");
  const clearDescription = page.locator("#forge-description-clear");
  const patterns = ["melee_slash", "straight_projectile", "boomerang", "area_blast", "piercing"];
  const requiredResultFields = [
    "name", "summary", "attack_pattern", "element", "damage", "attack_speed",
    "range", "special_ability", "status_effect", "weakness", "power_score",
  ];

  const qaUrl = new URL(page.url());
  qaUrl.searchParams.set("qa", "m1b1");
  await page.goto(qaUrl.toString(), { waitUntil: "domcontentloaded" });

  const bridgeCall = async (method, ...args) => page.evaluate(async ({ method, args }) => {
    const bridge = window.__forgeM1B1Test;
    if (!bridge || typeof bridge[method] !== "function") {
      throw new Error(`M1B1 QA bridge method missing: ${method}`);
    }
    return await bridge[method](...args);
  }, { method, args });

  const state = () => bridgeCall("state");
  const controls = () => bridgeCall("controls");
  const center = (rect) => {
    if (!rect || rect.visible === false || rect.width <= 0 || rect.height <= 0) {
      throw new Error(`control rectangle is not visible: ${JSON.stringify(rect)}`);
    }
    return { x: rect.x + rect.width / 2, y: rect.y + rect.height / 2 };
  };
  const tapRect = async (rect) => {
    const point = center(rect);
    await page.touchscreen.tap(point.x, point.y);
  };
  const tapControl = async (name) => {
    const current = await controls();
    if (!current[name]) throw new Error(`M1B1 control missing: ${name}`);
    await tapRect(current[name]);
  };
  const waitFor = async (predicate, description, timeout = 10000) => {
    const started = Date.now();
    let last = null;
    while (Date.now() - started < timeout) {
      last = await state();
      if (predicate(last)) return last;
      await sleep(50);
    }
    throw new Error(`timed out waiting for ${description}: ${JSON.stringify(last)}`);
  };
  const waitForForge = async () => {
    await page.waitForFunction(() => Boolean(
      window.__forgeM1B1Test &&
      typeof window.__forgeM1B1Test.state === "function" &&
      document.querySelector("#forge-description-input")?.offsetParent
    ), null, { timeout: 15000 });
    await waitFor((value) => value.screen === "forge" && value.phase === "idle", "idle forge");
    await sleep(100);
  };
  const reloadForge = async () => {
    await page.setViewportSize({ width: 844, height: 390 });
    await page.reload({ waitUntil: "domcontentloaded" });
    await waitForForge();
  };

  const assertInsideViewport = (rect, viewport, label) => {
    if (!rect || rect.visible === false || rect.x < -0.5 || rect.y < -0.5 ||
        rect.x + rect.width > viewport.width + 0.5 || rect.y + rect.height > viewport.height + 0.5) {
      throw new Error(`${label} outside ${viewport.width}x${viewport.height}: ${JSON.stringify(rect)}`);
    }
  };
  const overlaps = (a, b) => Boolean(a && b &&
    a.x < b.x + b.width && a.x + a.width > b.x &&
    a.y < b.y + b.height && a.y + a.height > b.y);

  const drawStroke = async () => {
    const current = await controls();
    const canvas = current.canvas;
    assertInsideViewport(canvas, page.viewportSize(), "canvas");
    const points = [
      { x: canvas.x + canvas.width * 0.18, y: canvas.y + canvas.height * 0.62 },
      { x: canvas.x + canvas.width * 0.36, y: canvas.y + canvas.height * 0.40 },
      { x: canvas.x + canvas.width * 0.56, y: canvas.y + canvas.height * 0.66 },
      { x: canvas.x + canvas.width * 0.76, y: canvas.y + canvas.height * 0.38 },
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
      await page.mouse.move(points[0].x, points[0].y);
      await page.mouse.down();
      for (const point of points.slice(1)) await page.mouse.move(point.x, point.y, { steps: 3 });
      await page.mouse.up();
    }
    await waitFor((value) => value.drawing_count > 0, "recorded drawing stroke");
  };

  const prepareCreativeInput = async (description) => {
    const current = await state();
    if (current.phase !== "idle" || current.screen !== "forge") {
      throw new Error(`cannot prepare input outside idle forge: ${JSON.stringify(current)}`);
    }
    if (current.drawing_count > 0 || current.description) await tapControl("reset");
    await input.fill(description);
    await waitFor((value) => value.description === description, "Description synchronization");
    await drawStroke();
  };

  const assertSafeResult = (current, label) => {
    const result = current.result;
    if (!result || !result.weapon_spec) throw new Error(`${label}: result/WeaponSpec missing`);
    if (result.schema_valid !== true || result.allow_list_valid !== true || result.runtime_valid !== true) {
      throw new Error(`${label}: validation failed: ${JSON.stringify(result)}`);
    }
    if (!Number.isFinite(result.weapon_spec.power_score) || result.weapon_spec.power_score > 100) {
      throw new Error(`${label}: invalid Power Score: ${JSON.stringify(result.weapon_spec.power_score)}`);
    }
    if (!current.confirmation_fields || typeof current.confirmation_fields !== "object") {
      throw new Error(`${label}: confirmation_fields test evidence missing`);
    }
    for (const field of requiredResultFields) {
      if (!(field in current.confirmation_fields) || current.confirmation_fields[field] === "") {
        throw new Error(`${label}: confirmation field not visible/populated: ${field}`);
      }
    }
    return result;
  };

  const submitAndWaitForResult = async (scenario, options = {}, description = `QA ${scenario} weapon`) => {
    await reloadForge();
    await bridgeCall("setScenario", scenario, options);
    await prepareCreativeInput(description);
    const before = await state();
    await tapControl("forge");
    const loading = await waitFor((value) => value.phase === "loading", `${scenario} loading state`);
    if (!loading.in_flight || loading.request_count !== before.request_count + 1 || !loading.message) {
      throw new Error(`${scenario}: invalid loading state: ${JSON.stringify(loading)}`);
    }
    const completed = await waitFor(
      (value) => ["result", "fallback", "error"].includes(value.phase),
      `${scenario} terminal state`,
      options.test_timeout_ms || 15000
    );
    if (completed.in_flight) throw new Error(`${scenario}: terminal state remains in flight`);
    if (completed.description !== description || completed.drawing_count < 1) {
      throw new Error(`${scenario}: creative input was lost: ${JSON.stringify(completed)}`);
    }
    return completed;
  };

  const viewportMeta = await page.locator('meta[name="viewport"]').getAttribute("content");
  if (!viewportMeta || !viewportMeta.includes("viewport-fit=cover")) {
    throw new Error(`safe-area viewport metadata missing: ${viewportMeta}`);
  }

  await page.setViewportSize({ width: 844, height: 390 });
  await waitForForge();

  // Normal-player forge must not expose the five deterministic M1A controls.
  let current = await state();
  let currentControls = await controls();
  if (current.selector_visible || current.developer_mode || current.modify_mode) {
    throw new Error(`normal forge leaked attack selector: ${JSON.stringify(current)}`);
  }
  if ((currentControls.pattern_buttons || []).some((rect) => rect.visible !== false && rect.width > 0 && rect.height > 0)) {
    throw new Error("normal forge retained clickable pattern-button rectangles");
  }

  // Compact Landscape must preserve the accepted v9 canvas/input/action geometry.
  const layouts = [];
  for (const viewport of [
    { width: 844, height: 390 },
    { width: 852, height: 393 },
    { width: 915, height: 412 },
    { width: 844, height: 343 },
  ]) {
    await page.setViewportSize(viewport);
    await sleep(250);
    await waitForForge();
    currentControls = await controls();
    const inputBox = await input.boundingBox();
    const clearBox = await clearDescription.boundingBox();
    for (const [name, rect] of Object.entries({
      canvas: currentControls.canvas,
      forge: currentControls.forge,
      reset: currentControls.reset,
      input: inputBox,
      clear: clearBox,
    })) assertInsideViewport(rect, viewport, name);
    if (currentControls.canvas.height < 149.5 || currentControls.canvas.height < viewport.height * 0.40) {
      throw new Error(`canvas too short at ${viewport.width}x${viewport.height}: ${currentControls.canvas.height}`);
    }
    if (!inputBox || inputBox.height < 43.5 || !clearBox || clearBox.width < 44 || clearBox.height < 44) {
      throw new Error(`input/clear touch target regression at ${viewport.width}x${viewport.height}`);
    }
    if (overlaps(currentControls.canvas, currentControls.forge) || overlaps(currentControls.canvas, inputBox)) {
      throw new Error(`forge controls overlap canvas at ${viewport.width}x${viewport.height}`);
    }
    const metrics = await page.evaluate(() => ({
      innerWidth, innerHeight,
      scrollWidth: document.documentElement.scrollWidth,
      scrollHeight: document.documentElement.scrollHeight,
      visualWidth: window.visualViewport?.width ?? innerWidth,
      visualHeight: window.visualViewport?.height ?? innerHeight,
    }));
    if (metrics.scrollWidth > metrics.innerWidth || metrics.scrollHeight > metrics.innerHeight) {
      throw new Error(`document scroll at ${viewport.width}x${viewport.height}: ${JSON.stringify(metrics)}`);
    }
    layouts.push({ viewport, canvas: currentControls.canvas, input: inputBox, metrics });
  }
  await page.setViewportSize({ width: 844, height: 390 });
  await waitForForge();

  // Description stays editable and independently clearable.
  await input.click();
  if (!(await input.evaluate((element) => document.activeElement === element))) {
    throw new Error("Description did not focus");
  }
  await input.fill("冰冻 returning umbrella");
  await input.press("End");
  await input.press("Backspace");
  if (await input.inputValue() !== "冰冻 returning umbrell") throw new Error("Description edit/delete failed");
  await clearDescription.click();
  if (await input.inputValue() !== "") throw new Error("Description × did not clear text");

  // Duplicate suppression and cancellation, including a late response.
  await bridgeCall("setScenario", "delayed_success", { delay_ms: 900 });
  const cancelDescription = "a delayed electric returning umbrella";
  await prepareCreativeInput(cancelDescription);
  const beforeCancel = await state();
  await tapControl("forge");
  const loading = await waitFor((value) => value.phase === "loading", "delayed loading");
  currentControls = await controls();
  assertInsideViewport(currentControls.cancel, page.viewportSize(), "cancel");
  for (let index = 0; index < 5; index += 1) await tapRect(currentControls.forge);
  await sleep(100);
  current = await state();
  if (current.request_count !== beforeCancel.request_count + 1 || current.request_id !== loading.request_id) {
    throw new Error(`duplicate FORGE produced another request: ${JSON.stringify(current)}`);
  }
  await tapControl("cancel");
  current = await waitFor((value) => value.screen === "forge" && value.phase === "idle", "cancelled idle forge");
  if (current.description !== cancelDescription || current.drawing_count < 1 || current.in_flight) {
    throw new Error(`CANCEL lost data or remained active: ${JSON.stringify(current)}`);
  }
  await sleep(1000);
  current = await state();
  if (current.screen !== "forge" || current.phase !== "idle" ||
      !Number.isInteger(current.late_response_ignored) || current.late_response_ignored < 1) {
    throw new Error(`cancelled late response was not ignored: ${JSON.stringify(current)}`);
  }

  // A normal success reaches confirmation with every required field.
  await bridgeCall("setScenario", "success", { delay_ms: 120 });
  const successBefore = await state();
  await tapControl("forge");
  current = await waitFor((value) => value.screen === "confirmation" && value.phase === "result", "success confirmation");
  let result = assertSafeResult(current, "success");
  if (current.request_count !== successBefore.request_count + 1 || current.selector_visible) {
    throw new Error(`success request/selector state invalid: ${JSON.stringify(current)}`);
  }
  currentControls = await controls();
  for (const name of ["confirm", "modify", "try_again", "feedback"]) {
    assertInsideViewport(currentControls[name], page.viewportSize(), name);
  }

  // TRY AGAIN is one new request, not an unlimited rapid-tap race.
  await bridgeCall("setScenario", "success", { delay_ms: 220 });
  const retryBefore = await state();
  const retryRect = (await controls()).try_again;
  await tapControl("try_again");
  await waitFor((value) => value.phase === "loading", "TRY AGAIN loading");
  for (let index = 0; index < 5; index += 1) await tapRect(retryRect);
  current = await waitFor((value) => value.screen === "confirmation" && value.phase === "result", "TRY AGAIN result");
  result = assertSafeResult(current, "TRY AGAIN");
  if (current.request_count !== retryBefore.request_count + 1) {
    throw new Error(`TRY AGAIN duplicated requests: ${JSON.stringify(current)}`);
  }

  // MODIFY exposes five buttons only here; every manual change is validated.
  await tapControl("modify");
  current = await waitFor((value) => value.modify_mode && value.selector_visible, "modify selector");
  currentControls = await controls();
  if (!Array.isArray(currentControls.pattern_buttons) || currentControls.pattern_buttons.length !== 5) {
    throw new Error("MODIFY did not expose exactly five pattern controls");
  }
  for (let index = 0; index < patterns.length; index += 1) {
    await tapRect(currentControls.pattern_buttons[index]);
    current = await waitFor((value) => value.selected_pattern === patterns[index] &&
      value.result?.schema_valid === true && value.result?.allow_list_valid === true &&
      value.result?.runtime_valid === true, `validated ${patterns[index]}`);
    result = assertSafeResult(current, `manual ${patterns[index]}`);
    if (result.weapon_spec.attack_pattern !== patterns[index]) {
      throw new Error(`manual correction did not update WeaponSpec: ${patterns[index]}`);
    }
  }
  for (let step = 0; step < 20; step += 1) {
    await tapRect(currentControls.pattern_buttons[step % patterns.length]);
  }
  await tapRect(currentControls.pattern_buttons[2]);
  current = await waitFor((value) => value.selected_pattern === "boomerang" &&
    value.result?.schema_valid === true && value.result?.allow_list_valid === true &&
    value.result?.runtime_valid === true, "final boomerang correction");
  assertSafeResult(current, "corrected boomerang");
  await tapControl("feedback");
  current = await state();
  if (current.feedback_count < 1) throw new Error("result-inappropriate feedback did not register");
  await tapControl("confirm");
  current = await waitFor((value) => value.screen === "combat", "confirmed combat");
  if (current.selector_visible) throw new Error("attack selector leaked into combat");
  await tapControl("attack");
  await waitFor((value) => value.attack_count > 0 && value.last_attack_pattern === "boomerang", "boomerang attack");
  await tapControl("reforge");
  await waitForForge();

  // Timeout retries exactly once and then yields a validated fallback.
  current = await submitAndWaitForResult("timeout", { test_timeout_ms: 15000 }, "timeout ice umbrella");
  if (current.request_attempts !== 2 || current.phase !== "fallback" || !current.message || !current.fallback_reason) {
    throw new Error(`timeout retry/fallback contract failed: ${JSON.stringify(current)}`);
  }
  assertSafeResult(current, "timeout fallback");

  // Network failure is recoverable without refresh or creative-data loss.
  current = await submitAndWaitForResult("network_error", {}, "network recovery spear");
  if (!Number.isInteger(current.request_attempts) || current.request_attempts > 2 || current.phase !== "fallback") {
    throw new Error(`network fallback/retry contract failed: ${JSON.stringify(current)}`);
  }
  assertSafeResult(current, "network fallback");
  await bridgeCall("setScenario", "success", { delay_ms: 100 });
  const recoveryCount = current.request_count;
  await tapControl("try_again");
  current = await waitFor((value) => value.screen === "confirmation" && value.phase === "result", "network recovery result");
  if (current.request_count !== recoveryCount + 1 || current.description !== "network recovery spear") {
    throw new Error(`network recovery lost state or duplicated: ${JSON.stringify(current)}`);
  }
  assertSafeResult(current, "network recovery");

  // Malformed/unavailable backend outputs never reach confirmation unvalidated.
  const failureResults = [];
  for (const scenario of ["rate_limit", "backend_unavailable", "invalid_json", "missing_fields", "unsupported_ability"]) {
    current = await submitAndWaitForResult(scenario, {}, `QA ${scenario} concept`);
    if (current.phase !== "fallback" || !Number.isInteger(current.request_attempts) ||
        current.request_attempts > 2 || !current.message || !current.fallback_reason) {
      throw new Error(`${scenario}: unsafe failure state: ${JSON.stringify(current)}`);
    }
    result = assertSafeResult(current, `${scenario} fallback`);
    failureResults.push({ scenario, attempts: current.request_attempts, fallback: current.fallback_reason, power: result.weapon_spec.power_score });
  }

  // Portrait gate and visualViewport/keyboard-like resize preserve a usable forge.
  await reloadForge();
  const stableInput = await input.boundingBox();
  await input.click();
  await page.setViewportSize({ width: 844, height: 220 });
  await sleep(220);
  await page.setViewportSize({ width: 844, height: 390 });
  await input.evaluate((element) => element.blur());
  await waitForForge();
  const restoredInput = await input.boundingBox();
  if (!stableInput || !restoredInput || Math.abs(stableInput.y - restoredInput.y) > 2 || Math.abs(stableInput.height - restoredInput.height) > 1) {
    throw new Error(`layout did not restore after keyboard simulation: ${JSON.stringify({ stableInput, restoredInput })}`);
  }
  for (let cycle = 0; cycle < 3; cycle += 1) {
    await page.setViewportSize({ width: 390, height: 844 });
    await sleep(160);
    current = await state();
    if (current.screen !== "portrait" || await input.isVisible()) {
      throw new Error(`portrait gate failed at cycle ${cycle + 1}: ${JSON.stringify(current)}`);
    }
    await page.setViewportSize({ width: 844, height: 390 });
    await waitForForge();
  }

  // Developer/Test Mode retains the five M1A attack modules without exposing
  // controls to the normal player or combat screen.
  const attackResults = [];
  for (let index = 0; index < patterns.length; index += 1) {
    await reloadForge();
    await bridgeCall("setDeveloperMode", true);
    current = await waitFor((value) => value.developer_mode && value.selector_visible, "developer selector");
    currentControls = await controls();
    if (currentControls.pattern_buttons.length !== 5) throw new Error("Developer Mode missing pattern controls");
    await tapRect(currentControls.pattern_buttons[index]);
    await waitFor((value) => value.selected_pattern === patterns[index], `Developer Mode ${patterns[index]}`);
    await bridgeCall("setScenario", "success", { delay_ms: 80, attack_pattern: patterns[index] });
    await prepareCreativeInput(`developer ${patterns[index]} regression`);
    await tapControl("forge");
    current = await waitFor((value) => value.screen === "confirmation" && value.phase === "result", `${patterns[index]} confirmation`);
    result = assertSafeResult(current, patterns[index]);
    if (result.weapon_spec.attack_pattern !== patterns[index]) throw new Error(`Developer compile mismatch: ${patterns[index]}`);
    await tapControl("confirm");
    current = await waitFor((value) => value.screen === "combat", `${patterns[index]} combat`);
    if (current.selector_visible) throw new Error(`${patterns[index]} selector leaked into combat`);
    const attacksBefore = current.attack_count;
    await tapControl("attack");
    current = await waitFor((value) => value.attack_count > attacksBefore, `${patterns[index]} attack`);
    if (current.last_attack_pattern !== patterns[index]) throw new Error(`runtime attack mismatch: ${patterns[index]}`);
    attackResults.push({ pattern: patterns[index], power: result.weapon_spec.power_score, runtimeValid: result.runtime_valid });
  }

  // Desktop remains usable and does not expose normal-player selectors.
  await reloadForge();
  await page.setViewportSize({ width: 1280, height: 720 });
  await sleep(300);
  await waitForForge();
  current = await state();
  const desktopMetrics = await page.evaluate(() => ({
    innerWidth, innerHeight,
    scrollWidth: document.documentElement.scrollWidth,
    scrollHeight: document.documentElement.scrollHeight,
  }));
  if (current.selector_visible || desktopMetrics.scrollWidth > desktopMetrics.innerWidth || desktopMetrics.scrollHeight > desktopMetrics.innerHeight) {
    throw new Error(`desktop regression: ${JSON.stringify({ current, desktopMetrics })}`);
  }

  const rendererNoise = messages.filter((entry) =>
    entry.text.includes("GPU stall due to ReadPixels") ||
    entry.text.includes("GL Driver Message") ||
    entry.text.includes("WEBGL_polygon_mode")
  );
  const seriousConsole = messages.filter((entry) =>
    (entry.type === "error" || entry.type === "warning") &&
    !rendererNoise.includes(entry)
  );
  if (seriousConsole.length) throw new Error(`new Chromium console errors/warnings: ${JSON.stringify(seriousConsole)}`);

  return {
    browserName,
    layouts,
    cancellation: "pass",
    timeoutRetryAttempts: 2,
    failureResults,
    attackResults,
    rotationCycles: 3,
    rendererNoise,
    seriousConsole,
  };
}
