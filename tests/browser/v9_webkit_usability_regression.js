async (page) => {
  const messages = [];
  page.on("console", (message) => messages.push({ type: message.type(), text: message.text() }));
  const sleep = (milliseconds) => page.waitForTimeout(milliseconds);
  const input = page.locator("#forge-description-input");
  const clearDescription = page.locator("#forge-description-clear");
  const patterns = ["melee_slash", "straight_projectile", "boomerang", "area_blast", "piercing"];
  const ideas = [
    "a solid normal blade for close combat",
    "a fast ice projectile launcher",
    "a returning fire boomerang",
    "an electric area blast for a crowd",
    "a piercing normal lance that breaks shields",
  ];

  const waitForForge = async () => {
    await page.waitForFunction(() => {
      const field = document.querySelector("#forge-description-input");
      return Boolean(window.__forgeMobileInput && field && field.offsetParent);
    }, null, { timeout: 15000 });
    await sleep(180);
  };

  const viewportMeta = await page.locator('meta[name="viewport"]').getAttribute('content');
  if (!viewportMeta || !viewportMeta.includes("viewport-fit=cover")) {
    throw new Error(`WebKit safe-area viewport metadata missing: ${viewportMeta}`);
  }

  const geometry = async () => {
    const viewport = page.viewportSize();
    const box = await input.boundingBox();
    if (!viewport || !box) throw new Error("WebKit compact geometry unavailable");
    return {
      width: viewport.width,
      height: viewport.height,
      input: box,
      touch: box.height,
      modeY: box.y + box.height + 2 + box.height / 2,
      actionY: box.y + box.height * 2 + 4 + box.height / 2,
      modeX: (index) => 2 + (viewport.width - 4) * (index + 0.5) / 5,
      resetX: 45,
      loadX: 143,
      compileX: viewport.width - 81,
      reforgeX: viewport.width - 51,
      topButtonY: 25,
    };
  };

  const tap = (x, y) => page.touchscreen.tap(x, y);
  const drawStroke = async () => {
    const current = await geometry();
    const y = Math.max(65, current.input.y - 78);
    await page.mouse.move(100, y);
    await page.mouse.down();
    await page.mouse.move(170, y - 20, { steps: 3 });
    await page.mouse.move(245, y + 18, { steps: 3 });
    await page.mouse.move(320, y - 12, { steps: 3 });
    await page.mouse.up();
    await sleep(90);
  };

  const latestRecord = () => {
    const line = messages.map((entry) => entry.text)
      .filter((text) => text.startsWith("[WeaponCompiler] ")).at(-1);
    if (!line) throw new Error("WebKit compiler audit log missing");
    return JSON.parse(line.slice(line.indexOf("{")));
  };

  await page.setViewportSize({ width: 844, height: 390 });
  await waitForForge();

  const first = await geometry();
  const pageMetrics = await page.evaluate(() => ({
    innerWidth,
    innerHeight,
    scrollWidth: document.documentElement.scrollWidth,
    scrollHeight: document.documentElement.scrollHeight,
    visualViewport: window.__forgeMobileInput.metrics(),
  }));
  const drawingHeight = first.input.y - 1 - (2 + first.touch + 1);
  if (first.touch < 43.5 || first.touch > 48.5 || drawingHeight < 149.5 || drawingHeight < 156) {
    throw new Error(`WebKit compact geometry failed: ${JSON.stringify({ first, drawingHeight })}`);
  }
  if (pageMetrics.scrollWidth > pageMetrics.innerWidth || pageMetrics.scrollHeight > pageMetrics.innerHeight) {
    throw new Error(`WebKit page scrolls: ${JSON.stringify(pageMetrics)}`);
  }

  // Native HTML input must focus, edit, delete, and remain editable after ×.
  await tap(first.modeX(2), first.modeY);
  await tap(first.loadX, first.actionY);
  await sleep(120);
  if (await input.inputValue() !== ideas[2]) throw new Error("WebKit LOAD IDEA did not populate Description");
  await input.click();
  if (!(await input.evaluate((element) => document.activeElement === element))) throw new Error("WebKit Description did not focus");
  await input.fill("editable WebKit boomerang");
  await input.press("End");
  await input.press("Backspace");
  if (await input.inputValue() !== "editable WebKit boomeran") throw new Error("WebKit Description edit/delete failed");
  await page.screenshot({ path: "output/playwright/v9/webkit-description-focused.png" });
  const clearBox = await clearDescription.boundingBox();
  if (!clearBox || clearBox.width < 44 || clearBox.height < 44) throw new Error("WebKit × target is under 44x44 CSS px");
  await clearDescription.click();
  if (await input.inputValue() !== "") throw new Error("WebKit × did not clear Description");
  if (!(await input.evaluate((element) => document.activeElement === element))) throw new Error("WebKit Description lost focus after ×");

  // RESET clears drawing and text but preserves the selected BOOMERANG mode.
  await drawStroke();
  await input.fill("reset WebKit state");
  const logsBefore = messages.filter((entry) => entry.text.startsWith("[WeaponCompiler] ")).length;
  let current = await geometry();
  await tap(current.resetX, current.actionY);
  await sleep(120);
  if (await input.inputValue() !== "") throw new Error("WebKit RESET did not clear Description");
  await tap(current.compileX, current.actionY);
  await sleep(150);
  const logsAfter = messages.filter((entry) => entry.text.startsWith("[WeaponCompiler] ")).length;
  if (logsAfter !== logsBefore) throw new Error("WebKit RESET left a drawing stroke");
  await drawStroke();
  await input.fill("WebKit redraw after reset");
  await tap(current.compileX, current.actionY);
  await sleep(300);
  if (latestRecord().weapon_spec.attack_pattern !== "boomerang") throw new Error("WebKit RESET changed selected mode");
  await tap(current.reforgeX, current.topButtonY);
  await waitForForge();

  // Safari toolbar and orientation changes must relayout and restore the input.
  await page.setViewportSize({ width: 844, height: 343 });
  await sleep(280);
  current = await geometry();
  const toolbarDrawingHeight = current.input.y - 1 - (2 + current.touch + 1);
  if (current.touch < 43.5 || current.touch > 48.5 || toolbarDrawingHeight < 149.5) {
    throw new Error(`WebKit toolbar compact layout failed: ${JSON.stringify({ current, toolbarDrawingHeight })}`);
  }
  await page.setViewportSize({ width: 844, height: 390 });
  await waitForForge();
  for (let cycle = 0; cycle < 3; cycle += 1) {
    await page.setViewportSize({ width: 390, height: 844 });
    await sleep(160);
    if (await input.isVisible()) throw new Error(`WebKit input remained above portrait gate at cycle ${cycle + 1}`);
    await page.setViewportSize({ width: 844, height: 390 });
    await waitForForge();
  }

  // All five deterministic modes still switch, compile, attack, and reforge.
  current = await geometry();
  for (const index of [0, 1, 2, 3, 4, 4, 3, 2, 1, 0]) await tap(current.modeX(index), current.modeY);
  for (let step = 0; step < 20; step += 1) await tap(current.modeX(step % 5), current.modeY);

  const compileResults = [];
  for (let index = 0; index < patterns.length; index += 1) {
    current = await geometry();
    await tap(current.modeX(index), current.modeY);
    await tap(current.loadX, current.actionY);
    await sleep(90);
    if (await input.inputValue() !== ideas[index]) throw new Error(`WebKit LOAD IDEA mismatch for ${patterns[index]}`);
    await drawStroke();
    await tap(current.compileX, current.actionY);
    await sleep(320);
    const record = latestRecord();
    if (record.forced_attack_pattern !== patterns[index] || record.weapon_spec.attack_pattern !== patterns[index]) {
      throw new Error(`WebKit compile mismatch for ${patterns[index]}`);
    }
    await tap(790, 352);
    await sleep(patterns[index] === "melee_slash" ? 100 : 180);
    compileResults.push({ pattern: patterns[index], runtimeValid: record.runtime_valid, input: record.input });
    await tap(792, 30);
    await waitForForge();
  }

  await page.screenshot({ path: "output/playwright/v9/webkit-844x390-final.png" });
  const seriousConsole = messages.filter((entry) => {
    if (entry.type !== "error" && entry.type !== "warning") return false;
    return !entry.text.includes("glBlitFramebuffer") && !entry.text.includes("glClear");
  });
  if (seriousConsole.length) throw new Error(`new WebKit console errors/warnings: ${JSON.stringify(seriousConsole)}`);

  return {
    browserName: page.context().browser().browserType().name(),
    pageMetrics,
    drawingHeight,
    touchHeight: first.touch,
    toolbarDrawingHeight,
    compileResults,
    rapidSwitches: 30,
    rotationCycles: 3,
    consoleErrors: messages.filter((entry) => entry.type === "error").map((entry) => entry.text),
    consoleWarnings: messages.filter((entry) => entry.type === "warning").map((entry) => entry.text),
  };
}
