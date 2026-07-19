async (page) => {
  const browserName = page.context().browser().browserType().name();
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
    throw new Error(`safe-area viewport metadata missing: ${viewportMeta}`);
  }

  const tap = async (x, y) => page.touchscreen.tap(x, y);
  const compactGeometry = async () => {
    const viewport = page.viewportSize();
    const box = await input.boundingBox();
    if (!viewport || !box) throw new Error("compact forge/input geometry unavailable");
    const touch = box.height;
    return {
      width: viewport.width,
      height: viewport.height,
      input: box,
      touch,
      modeY: box.y + touch + 2 + touch / 2,
      actionY: box.y + touch * 2 + 4 + touch / 2,
      modeX: (index) => 2 + (viewport.width - 4) * (index + 0.5) / 5,
      resetX: 45,
      loadX: 143,
      compileX: viewport.width - 81,
      backX: viewport.width - 40,
      backY: 25,
    };
  };

  const drawStroke = async () => {
    const geometry = await compactGeometry();
    const y = Math.max(65, geometry.input.y - 78);
    if (browserName === "chromium") {
      const cdp = await page.context().newCDPSession(page);
      await cdp.send("Input.dispatchTouchEvent", {
        type: "touchStart",
        touchPoints: [{ x: 100, y, radiusX: 4, radiusY: 4, force: 1, id: 1 }],
      });
      for (const point of [{ x: 170, y: y - 20 }, { x: 245, y: y + 18 }, { x: 320, y: y - 12 }]) {
        await cdp.send("Input.dispatchTouchEvent", {
          type: "touchMove",
          touchPoints: [{ ...point, radiusX: 4, radiusY: 4, force: 1, id: 1 }],
        });
      }
      await cdp.send("Input.dispatchTouchEvent", { type: "touchEnd", touchPoints: [] });
      await cdp.detach();
    } else {
      await page.mouse.move(100, y);
      await page.mouse.down();
      await page.mouse.move(170, y - 20, { steps: 3 });
      await page.mouse.move(245, y + 18, { steps: 3 });
      await page.mouse.move(320, y - 12, { steps: 3 });
      await page.mouse.up();
    }
    await sleep(80);
  };

  const latestRecord = () => {
    const line = messages.map((entry) => entry.text)
      .filter((text) => text.startsWith("[WeaponCompiler] ")).at(-1);
    if (!line) throw new Error("WeaponCompiler audit log missing");
    return JSON.parse(line.slice(line.indexOf("{")));
  };

  const assertCompactViewport = async (viewport) => {
    await page.setViewportSize(viewport);
    await sleep(280);
    await waitForForge();
    const geometry = await compactGeometry();
    const browser = await page.evaluate(() => ({
      innerWidth,
      innerHeight,
      scrollWidth: document.documentElement.scrollWidth,
      scrollHeight: document.documentElement.scrollHeight,
      metrics: window.__forgeMobileInput.metrics(),
    }));
    if (browser.scrollWidth > browser.innerWidth || browser.scrollHeight > browser.innerHeight) {
      throw new Error(`page scrolls at ${viewport.width}x${viewport.height}: ${JSON.stringify(browser)}`);
    }
    if (geometry.touch < 43.5 || geometry.touch > 48.5) {
      throw new Error(`touch row is ${geometry.touch}px at ${viewport.width}x${viewport.height}`);
    }
    const drawingTop = 2 + geometry.touch + 1;
    const drawingHeight = geometry.input.y - 1 - drawingTop;
    if (drawingHeight < 149.5 || drawingHeight < viewport.height * 0.4) {
      throw new Error(`drawing canvas is too short at ${viewport.width}x${viewport.height}: ${drawingHeight}`);
    }
    if (geometry.actionY + geometry.touch / 2 > viewport.height - 1) {
      throw new Error(`action row clipped at ${viewport.width}x${viewport.height}`);
    }
    await page.screenshot({ path: `output/playwright/v9/chromium-${viewport.width}x${viewport.height}.png` });
    return { viewport, drawingHeight, touchHeight: geometry.touch, browser };
  };

  await page.setViewportSize({ width: 844, height: 390 });
  await page.reload();
  await waitForForge();

  const layouts = [];
  for (const viewport of [{ width: 844, height: 390 }, { width: 852, height: 393 }, { width: 915, height: 412 }]) {
    layouts.push(await assertCompactViewport(viewport));
  }
  await page.setViewportSize({ width: 844, height: 390 });
  await waitForForge();

  // LOAD IDEA populates a real native DOM input; focus, edit, delete, and the
  // independent 44px clear button all synchronize back to Godot.
  let geometry = await compactGeometry();
  await tap(geometry.modeX(2), geometry.modeY);
  await tap(geometry.loadX, geometry.actionY);
  await sleep(120);
  if (await input.inputValue() !== ideas[2]) throw new Error("LOAD IDEA did not populate Description");
  await input.click();
  if (!(await input.evaluate((element) => document.activeElement === element))) throw new Error("Description did not receive DOM focus");
  await input.fill("editable fire boomerang");
  if (await input.inputValue() !== "editable fire boomerang") throw new Error("Description edit did not stick");
  await input.press("End");
  await input.press("Backspace");
  if (await input.inputValue() !== "editable fire boomeran") throw new Error("Description deletion failed");
  await page.screenshot({ path: "output/playwright/v9/description-focused.png" });
  const clearBox = await clearDescription.boundingBox();
  if (!clearBox || clearBox.width < 44 || clearBox.height < 44) throw new Error("Description clear target is smaller than 44x44 CSS px");
  await clearDescription.click();
  if (await input.inputValue() !== "") throw new Error("Description clear button did not clear text");
  if (!(await input.evaluate((element) => document.activeElement === element))) throw new Error("Description lost editability after clear");
  await page.screenshot({ path: "output/playwright/v9/description-cleared.png" });

  // RESET clears strokes, text, loaded-example state, and feedback, but leaves
  // BOOMERANG selected. A compile without redrawing must be rejected.
  await drawStroke();
  await input.fill("reset this description");
  const logsBeforeResetCompile = messages.filter((entry) => entry.text.startsWith("[WeaponCompiler] ")).length;
  geometry = await compactGeometry();
  await tap(geometry.resetX, geometry.actionY);
  await sleep(120);
  if (await input.inputValue() !== "") throw new Error("RESET did not clear Description");
  await page.screenshot({ path: "output/playwright/v9/reset-blank-state.png" });
  await tap(geometry.compileX, geometry.actionY);
  await sleep(160);
  const logsAfterResetCompile = messages.filter((entry) => entry.text.startsWith("[WeaponCompiler] ")).length;
  if (logsAfterResetCompile !== logsBeforeResetCompile) throw new Error("RESET left drawing strokes behind");
  await drawStroke();
  await input.fill("new editable idea after reset");
  await tap(geometry.compileX, geometry.actionY);
  await sleep(300);
  if (latestRecord().weapon_spec.attack_pattern !== "boomerang") throw new Error("RESET changed the selected mode");

  // Return to the forge, exercise BACK, and confirm the native input remains usable.
  await tap(geometry.backX, geometry.backY); // REFORGE in combat.
  await sleep(180);
  await waitForForge();
  await input.fill("input after reforge");
  geometry = await compactGeometry();
  await tap(geometry.backX, geometry.backY); // BACK to combat.
  await sleep(120);
  await tap(geometry.backX, geometry.backY); // REFORGE again.
  await sleep(180);
  await waitForForge();
  await input.fill("input after back and reforge");
  if (await input.inputValue() !== "input after back and reforge") throw new Error("Description failed after BACK/REFORGE");

  // Keyboard-like visualViewport shrink and Safari toolbar height variations
  // must restore the same compact geometry when the viewport returns.
  const stableBox = await input.boundingBox();
  await input.click();
  await page.setViewportSize({ width: 844, height: 220 });
  await sleep(220);
  await page.setViewportSize({ width: 844, height: 390 });
  await input.evaluate((element) => element.blur());
  await sleep(300);
  await waitForForge();
  const restoredBox = await input.boundingBox();
  if (!stableBox || !restoredBox || Math.abs(stableBox.height - restoredBox.height) > 1 || Math.abs(stableBox.y - restoredBox.y) > 2) {
    throw new Error(`layout did not restore after keyboard simulation: ${JSON.stringify({ stableBox, restoredBox })}`);
  }
  await page.setViewportSize({ width: 844, height: 343 });
  await sleep(250);
  const toolbarCompact = await assertCompactViewport({ width: 844, height: 343 });
  await page.setViewportSize({ width: 844, height: 390 });
  await waitForForge();

  // Three portrait/landscape cycles must hide/recreate the native input without
  // leaving an invisible overlay or losing touch state.
  for (let cycle = 0; cycle < 3; cycle += 1) {
    await page.setViewportSize({ width: 390, height: 844 });
    await sleep(140);
    if (await input.isVisible()) throw new Error(`native input visible over portrait gate in cycle ${cycle + 1}`);
    await page.setViewportSize({ width: 844, height: 390 });
    await waitForForge();
  }

  // Forward, reverse, and 20 more selector taps remain responsive.
  geometry = await compactGeometry();
  for (const index of [0, 1, 2, 3, 4, 4, 3, 2, 1, 0]) await tap(geometry.modeX(index), geometry.modeY);
  for (let step = 0; step < 20; step += 1) await tap(geometry.modeX(step % 5), geometry.modeY);

  // All five deterministic modes still compile and attack in v9.
  const compileResults = [];
  for (let index = 0; index < patterns.length; index += 1) {
    geometry = await compactGeometry();
    await tap(geometry.modeX(index), geometry.modeY);
    await tap(geometry.loadX, geometry.actionY);
    await sleep(70);
    if (await input.inputValue() !== ideas[index]) throw new Error(`LOAD IDEA mismatch for ${patterns[index]}`);
    await drawStroke();
    await tap(geometry.compileX, geometry.actionY);
    await sleep(300);
    const record = latestRecord();
    if (record.weapon_spec.attack_pattern !== patterns[index] || record.forced_attack_pattern !== patterns[index]) {
      throw new Error(`compile pattern mismatch for ${patterns[index]}`);
    }
    await tap(790, 352);
    await sleep(patterns[index] === "melee_slash" ? 90 : 170);
    compileResults.push({ pattern: patterns[index], input: record.input, runtimeValid: record.runtime_valid });
    await tap(792, 30);
    await sleep(180);
    await waitForForge();
  }

  // Desktop retains the spacious 3+2 layout and remains fully visible.
  await page.setViewportSize({ width: 1280, height: 720 });
  await sleep(300);
  await waitForForge();
  const desktop = await page.evaluate(() => ({
    innerWidth, innerHeight,
    scrollWidth: document.documentElement.scrollWidth,
    scrollHeight: document.documentElement.scrollHeight,
    input: (() => { const b = document.querySelector("#forge-description-input").getBoundingClientRect(); return { y: b.y, height: b.height }; })(),
  }));
  if (desktop.scrollWidth > desktop.innerWidth || desktop.scrollHeight > desktop.innerHeight || desktop.input.height < 44) {
    throw new Error(`desktop layout regression: ${JSON.stringify(desktop)}`);
  }
  await page.screenshot({ path: "output/playwright/v9/chromium-desktop-1280x720.png" });

  const seriousConsole = messages.filter((entry) => entry.type === "error" || entry.type === "warning");
  if (browserName === "chromium" && seriousConsole.length) {
    throw new Error(`new Chromium console errors/warnings: ${JSON.stringify(seriousConsole)}`);
  }
  return {
    browserName,
    layouts,
    toolbarCompact,
    compileResults,
    rapidSwitches: 30,
    rotationCycles: 3,
    seriousConsole,
  };
}
