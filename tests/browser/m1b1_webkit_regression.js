/*
 * HISTORICAL / NOT EXECUTED.
 * Retained only to audit the pre-Anthropic expression runner. The supported
 * run_m1b1_regression.mjs entry point now delegates to the canonical Anthropic
 * mobile suite. Current provider failures are explicit non-equipable errors
 * with weapon_spec=null; this old file's local-fallback assertions are obsolete.
 */
async (page) => {
  const messages = [];
  page.on("console", (message) => messages.push({ type: message.type(), text: message.text() }));
  const sleep = (milliseconds) => page.waitForTimeout(milliseconds);
  const input = page.locator("#forge-description-input");
  const clearDescription = page.locator("#forge-description-clear");
  const patterns = ["melee_slash", "straight_projectile", "boomerang", "area_blast", "piercing"];

  const qaUrl = new URL(page.url());
  qaUrl.searchParams.set("qa", "m1b1");
  await page.goto(qaUrl.toString(), { waitUntil: "domcontentloaded" });

  const call = async (method, ...args) => page.evaluate(async ({ method, args }) => {
    const bridge = window.__forgeM1B1Test;
    if (!bridge || typeof bridge[method] !== "function") throw new Error(`M1B1 QA bridge method missing: ${method}`);
    return await bridge[method](...args);
  }, { method, args });
  const state = () => call("state");
  const controls = () => call("controls");
  const center = (rect) => {
    if (!rect || rect.visible === false || rect.width <= 0 || rect.height <= 0) throw new Error(`hidden/missing rect: ${JSON.stringify(rect)}`);
    return { x: rect.x + rect.width / 2, y: rect.y + rect.height / 2 };
  };
  const tapRect = async (rect) => {
    const point = center(rect);
    await page.touchscreen.tap(point.x, point.y);
  };
  const tap = async (name) => {
    const current = await controls();
    if (!current[name]) throw new Error(`missing M1B1 control: ${name}`);
    await tapRect(current[name]);
  };
  const waitFor = async (predicate, label, timeout = 12000) => {
    const started = Date.now();
    let latest = null;
    while (Date.now() - started < timeout) {
      latest = await state();
      if (predicate(latest)) return latest;
      await sleep(60);
    }
    throw new Error(`WebKit timed out waiting for ${label}: ${JSON.stringify(latest)}`);
  };
  const waitForForge = async () => {
    await page.waitForFunction(() => Boolean(
      window.__forgeM1B1Test && document.querySelector("#forge-description-input")?.offsetParent
    ), null, { timeout: 15000 });
    await waitFor((value) => value.screen === "forge" && value.phase === "idle", "idle forge");
  };
  const reloadForge = async () => {
    await page.setViewportSize({ width: 844, height: 390 });
    await page.reload({ waitUntil: "domcontentloaded" });
    await waitForForge();
  };
  const assertInside = (rect, viewport, label) => {
    if (!rect || rect.visible === false || rect.x < -0.5 || rect.y < -0.5 ||
        rect.x + rect.width > viewport.width + 0.5 || rect.y + rect.height > viewport.height + 0.5) {
      throw new Error(`WebKit ${label} outside viewport: ${JSON.stringify({ viewport, rect })}`);
    }
  };
  const draw = async () => {
    const canvas = (await controls()).canvas;
    const points = [
      { x: canvas.x + canvas.width * 0.2, y: canvas.y + canvas.height * 0.6 },
      { x: canvas.x + canvas.width * 0.4, y: canvas.y + canvas.height * 0.4 },
      { x: canvas.x + canvas.width * 0.65, y: canvas.y + canvas.height * 0.65 },
    ];
    await page.mouse.move(points[0].x, points[0].y);
    await page.mouse.down();
    for (const point of points.slice(1)) await page.mouse.move(point.x, point.y, { steps: 4 });
    await page.mouse.up();
    await waitFor((value) => value.drawing_count > 0, "drawing stroke");
  };
  const prepare = async (description) => {
    await input.fill(description);
    await waitFor((value) => value.description === description, "Description synchronization");
    await draw();
  };
  const assertSafe = (current, label) => {
    const result = current.result;
    if (!result?.weapon_spec || result.schema_valid !== true || result.allow_list_valid !== true || result.runtime_valid !== true) {
      throw new Error(`WebKit ${label} invalid result: ${JSON.stringify(result)}`);
    }
    if (!Number.isFinite(result.weapon_spec.power_score) || result.weapon_spec.power_score > 100) {
      throw new Error(`WebKit ${label} invalid power: ${result.weapon_spec.power_score}`);
    }
    return result;
  };

  const viewportMeta = await page.locator('meta[name="viewport"]').getAttribute("content");
  if (!viewportMeta?.includes("viewport-fit=cover")) throw new Error(`WebKit safe-area metadata missing: ${viewportMeta}`);

  await page.setViewportSize({ width: 844, height: 390 });
  await waitForForge();
  let current = await state();
  if (current.selector_visible || current.developer_mode || current.modify_mode) {
    throw new Error(`WebKit normal forge leaked selector: ${JSON.stringify(current)}`);
  }

  const layouts = [];
  for (const viewport of [
    { width: 844, height: 390 }, { width: 852, height: 393 },
    { width: 915, height: 412 }, { width: 844, height: 343 },
  ]) {
    await page.setViewportSize(viewport);
    await sleep(280);
    await waitForForge();
    const c = await controls();
    const inputBox = await input.boundingBox();
    const clearBox = await clearDescription.boundingBox();
    for (const [name, rect] of Object.entries({ canvas: c.canvas, forge: c.forge, reset: c.reset, input: inputBox, clear: clearBox })) {
      assertInside(rect, viewport, name);
    }
    if (c.canvas.height < 149.5 || c.canvas.height < viewport.height * 0.4 ||
        !inputBox || inputBox.height < 43.5 || !clearBox || clearBox.width < 44 || clearBox.height < 44) {
      throw new Error(`WebKit compact geometry regression: ${JSON.stringify({ viewport, controls: c, inputBox, clearBox })}`);
    }
    const metrics = await page.evaluate(() => ({
      innerWidth, innerHeight,
      scrollWidth: document.documentElement.scrollWidth,
      scrollHeight: document.documentElement.scrollHeight,
      visualWidth: window.visualViewport?.width ?? innerWidth,
      visualHeight: window.visualViewport?.height ?? innerHeight,
    }));
    if (metrics.scrollWidth > metrics.innerWidth || metrics.scrollHeight > metrics.innerHeight) {
      throw new Error(`WebKit document scroll: ${JSON.stringify({ viewport, metrics })}`);
    }
    layouts.push({ viewport, canvas: c.canvas, input: inputBox, metrics });
  }
  await page.setViewportSize({ width: 844, height: 390 });
  await waitForForge();

  await input.click();
  if (!(await input.evaluate((element) => document.activeElement === element))) throw new Error("WebKit Description did not focus");
  await input.fill("冰冻 WebKit umbrella");
  await input.press("End");
  await input.press("Backspace");
  if (await input.inputValue() !== "冰冻 WebKit umbrell") throw new Error("WebKit Description edit/delete failed");
  await clearDescription.click();
  if (await input.inputValue() !== "") throw new Error("WebKit Description × failed");

  // Delayed request: duplicate taps are ignored; cancel preserves state; late result loses.
  await call("setScenario", "delayed_success", { delay_ms: 900 });
  const cancelledText = "WebKit cancel electric umbrella";
  await prepare(cancelledText);
  const before = await state();
  await tap("forge");
  const loading = await waitFor((value) => value.phase === "loading", "loading");
  const loadingControls = await controls();
  for (let index = 0; index < 5; index += 1) await tapRect(loadingControls.forge);
  current = await state();
  if (current.request_count !== before.request_count + 1 || current.request_id !== loading.request_id) {
    throw new Error(`WebKit duplicate request: ${JSON.stringify(current)}`);
  }
  await tap("cancel");
  current = await waitFor((value) => value.screen === "forge" && value.phase === "idle", "cancel recovery");
  if (current.description !== cancelledText || current.drawing_count < 1) throw new Error("WebKit CANCEL lost creative input");
  await sleep(1000);
  current = await state();
  if (current.phase !== "idle" || current.screen !== "forge" ||
      !Number.isInteger(current.late_response_ignored) || current.late_response_ignored < 1) {
    throw new Error(`WebKit late response won after cancel: ${JSON.stringify(current)}`);
  }

  // Timeout retries once, then presents a validated fallback.
  await reloadForge();
  await call("setScenario", "timeout", {});
  await prepare("WebKit timeout ice umbrella");
  await tap("forge");
  current = await waitFor((value) => value.phase === "fallback", "timeout fallback", 15000);
  if (current.request_attempts !== 2 || !current.message || !current.fallback_reason) {
    throw new Error(`WebKit timeout retry contract failed: ${JSON.stringify(current)}`);
  }
  assertSafe(current, "timeout fallback");

  // A normal result remains hidden from manual selectors until MODIFY.
  await reloadForge();
  await call("setScenario", "success", { delay_ms: 100 });
  await prepare("a returning frozen WebKit umbrella");
  await tap("forge");
  current = await waitFor((value) => value.screen === "confirmation" && value.phase === "result", "success confirmation");
  let result = assertSafe(current, "success");
  if (current.selector_visible) throw new Error("WebKit confirmation exposed selector before MODIFY");
  const confirmationControls = await controls();
  for (const name of ["confirm", "modify", "try_again", "feedback"]) assertInside(confirmationControls[name], page.viewportSize(), name);
  await tap("modify");
  current = await waitFor((value) => value.modify_mode && value.selector_visible, "MODIFY selector");
  let c = await controls();
  if (c.pattern_buttons.length !== 5) throw new Error("WebKit MODIFY does not expose five controls");
  for (let index = 0; index < patterns.length; index += 1) {
    await tapRect(c.pattern_buttons[index]);
    current = await waitFor((value) => value.selected_pattern === patterns[index] &&
      value.result?.schema_valid === true && value.result?.allow_list_valid === true &&
      value.result?.runtime_valid === true, `WebKit validated ${patterns[index]}`);
    result = assertSafe(current, `manual ${patterns[index]}`);
    if (result.weapon_spec.attack_pattern !== patterns[index]) throw new Error(`WebKit correction mismatch: ${patterns[index]}`);
  }
  for (let step = 0; step < 20; step += 1) await tapRect(c.pattern_buttons[step % patterns.length]);
  await tapRect(c.pattern_buttons[2]);
  await waitFor((value) => value.selected_pattern === "boomerang" &&
    value.result?.schema_valid === true && value.result?.allow_list_valid === true &&
    value.result?.runtime_valid === true, "WebKit corrected boomerang");
  await tap("confirm");
  current = await waitFor((value) => value.screen === "combat", "WebKit combat");
  if (current.selector_visible) throw new Error("WebKit selector leaked into combat");
  await tap("attack");
  await waitFor((value) => value.attack_count > 0 && value.last_attack_pattern === "boomerang", "WebKit boomerang attack");
  await tap("reforge");
  await waitForForge();

  // Network recovery and representative malformed output paths.
  const failureResults = [];
  for (const scenario of ["network_error", "rate_limit", "invalid_json", "missing_fields", "unsupported_ability"]) {
    await reloadForge();
    await call("setScenario", scenario, {});
    const description = `WebKit ${scenario} concept`;
    await prepare(description);
    await tap("forge");
    current = await waitFor((value) => value.phase === "fallback", `${scenario} fallback`, 15000);
    result = assertSafe(current, `${scenario} fallback`);
    if (current.description !== description || current.drawing_count < 1 ||
        !Number.isInteger(current.request_attempts) || current.request_attempts > 2) {
      throw new Error(`WebKit ${scenario} lost state or retried too much: ${JSON.stringify(current)}`);
    }
    failureResults.push({ scenario, attempts: current.request_attempts, fallback: current.fallback_reason, power: result.weapon_spec.power_score });
  }

  // Keyboard-sized viewport and three orientation cycles recover without an overlay lock.
  await reloadForge();
  const stableBox = await input.boundingBox();
  await input.click();
  await page.setViewportSize({ width: 844, height: 220 });
  await sleep(240);
  await page.setViewportSize({ width: 844, height: 390 });
  await input.evaluate((element) => element.blur());
  await waitForForge();
  const restoredBox = await input.boundingBox();
  if (!stableBox || !restoredBox || Math.abs(stableBox.y - restoredBox.y) > 2 || Math.abs(stableBox.height - restoredBox.height) > 1) {
    throw new Error(`WebKit keyboard layout failed to restore: ${JSON.stringify({ stableBox, restoredBox })}`);
  }
  for (let cycle = 0; cycle < 3; cycle += 1) {
    await page.setViewportSize({ width: 390, height: 844 });
    await sleep(170);
    current = await state();
    if (current.screen !== "portrait" || await input.isVisible()) throw new Error(`WebKit portrait gate failed: cycle ${cycle + 1}`);
    await page.setViewportSize({ width: 844, height: 390 });
    await waitForForge();
  }

  // Existing five attack modules still execute through Developer/Test Mode.
  const attackResults = [];
  for (let index = 0; index < patterns.length; index += 1) {
    await reloadForge();
    await call("setDeveloperMode", true);
    await waitFor((value) => value.selector_visible && value.developer_mode, "WebKit developer selector");
    c = await controls();
    await tapRect(c.pattern_buttons[index]);
    await waitFor((value) => value.selected_pattern === patterns[index], `WebKit developer ${patterns[index]}`);
    await call("setScenario", "success", { delay_ms: 80, attack_pattern: patterns[index] });
    await prepare(`WebKit developer ${patterns[index]}`);
    await tap("forge");
    current = await waitFor((value) => value.screen === "confirmation" && value.phase === "result", `${patterns[index]} confirmation`);
    result = assertSafe(current, patterns[index]);
    if (result.weapon_spec.attack_pattern !== patterns[index]) throw new Error(`WebKit developer compile mismatch: ${patterns[index]}`);
    await tap("confirm");
    current = await waitFor((value) => value.screen === "combat", `${patterns[index]} combat`);
    if (current.selector_visible) throw new Error(`WebKit ${patterns[index]} selector visible in combat`);
    const beforeAttack = current.attack_count;
    await tap("attack");
    current = await waitFor((value) => value.attack_count > beforeAttack, `${patterns[index]} attack`);
    if (current.last_attack_pattern !== patterns[index]) throw new Error(`WebKit runtime mismatch: ${patterns[index]}`);
    attackResults.push({ pattern: patterns[index], power: result.weapon_spec.power_score, runtimeValid: result.runtime_valid });
  }

  const seriousConsole = messages.filter((entry) => {
    if (entry.type !== "error" && entry.type !== "warning") return false;
    return !entry.text.includes("glBlitFramebuffer") &&
      !entry.text.includes("glClear") &&
      !entry.text.includes("WEBGL_polygon_mode");
  });
  if (seriousConsole.length) throw new Error(`new WebKit application errors/warnings: ${JSON.stringify(seriousConsole)}`);

  return {
    browserName: page.context().browser().browserType().name(),
    layouts,
    timeoutRetryAttempts: 2,
    failureResults,
    attackResults,
    rotationCycles: 3,
    consoleErrors: messages.filter((entry) => entry.type === "error").map((entry) => entry.text),
    consoleWarnings: messages.filter((entry) => entry.type === "warning").map((entry) => entry.text),
  };
}
