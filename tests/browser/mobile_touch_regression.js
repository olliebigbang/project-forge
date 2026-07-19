async (page) => {
  const browserName = page.context().browser().browserType().name();
  const consoleMessages = [];
  page.on("console", (message) => consoleMessages.push({
    type: message.type(),
    text: message.text(),
  }));

  const sleep = (milliseconds) => page.waitForTimeout(milliseconds);
  const tap = (x, y) => page.touchscreen.tap(x, y);
  const forgePatternCenters = [
    { x: 158, y: 234 },
    { x: 422, y: 234 },
    { x: 686, y: 234 },
    { x: 158, y: 286 },
    { x: 422, y: 286 },
  ];
  const patterns = [
    "melee_slash",
    "straight_projectile",
    "boomerang",
    "area_blast",
    "piercing",
  ];

  const drawStroke = async () => {
    if (browserName === "chromium") {
      const cdp = await page.context().newCDPSession(page);
      await cdp.send("Input.dispatchTouchEvent", {
        type: "touchStart",
        touchPoints: [{ x: 110, y: 108, radiusX: 4, radiusY: 4, force: 1, id: 1 }],
      });
      for (const point of [{ x: 170, y: 90 }, { x: 230, y: 124 }, { x: 290, y: 96 }]) {
        await cdp.send("Input.dispatchTouchEvent", {
          type: "touchMove",
          touchPoints: [{ ...point, radiusX: 4, radiusY: 4, force: 1, id: 1 }],
        });
      }
      await cdp.send("Input.dispatchTouchEvent", { type: "touchEnd", touchPoints: [] });
      await cdp.detach();
    } else {
      // Playwright WebKit does not expose CDP. Mouse drag still exercises the
      // canvas-bounded Godot GUI path; real iOS touch remains the user's gate.
      await page.mouse.move(110, 108);
      await page.mouse.down();
      await page.mouse.move(170, 90, { steps: 3 });
      await page.mouse.move(230, 124, { steps: 3 });
      await page.mouse.move(290, 96, { steps: 3 });
      await page.mouse.up();
    }
    await sleep(80);
  };

  const latestCompileRecord = () => {
    const entries = consoleMessages
      .map((entry) => entry.text)
      .filter((text) => text.startsWith("[WeaponCompiler] "));
    if (entries.length === 0) throw new Error("compile produced no WeaponCompiler audit log");
    return JSON.parse(entries.at(-1).slice(entries.at(-1).indexOf("{")));
  };

  await page.setViewportSize({ width: 390, height: 844 });
  await page.reload();
  await sleep(900);
  await page.screenshot({ path: `artifacts/${browserName}-portrait-rotate.png` });

  for (let cycle = 0; cycle < 3; cycle += 1) {
    await page.setViewportSize({ width: 844, height: 390 });
    await sleep(120);
    await page.setViewportSize({ width: 390, height: 844 });
    await sleep(120);
  }
  await page.setViewportSize({ width: 844, height: 390 });
  await sleep(450);

  for (const viewport of [{ width: 844, height: 390 }, { width: 852, height: 393 }, { width: 915, height: 412 }]) {
    await page.setViewportSize(viewport);
    await sleep(150);
    const geometry = await page.evaluate(() => ({
      innerWidth,
      innerHeight,
      scrollWidth: document.documentElement.scrollWidth,
      scrollHeight: document.documentElement.scrollHeight,
    }));
    if (geometry.scrollWidth > geometry.innerWidth || geometry.scrollHeight > geometry.innerHeight) {
      throw new Error(`page scrolls at ${viewport.width}x${viewport.height}: ${JSON.stringify(geometry)}`);
    }
    await page.screenshot({ path: `artifacts/${browserName}-${viewport.width}x${viewport.height}.png` });
  }
  await page.setViewportSize({ width: 844, height: 390 });
  await sleep(250);

  // Forward, reverse, then 20 more switches exercise release-triggered touch
  // without opening or depending on any modal/popup control.
  for (const index of [0, 1, 2, 3, 4, 4, 3, 2, 1, 0]) {
    await tap(forgePatternCenters[index].x, forgePatternCenters[index].y);
  }
  for (let step = 0; step < 20; step += 1) {
    const index = step % patterns.length;
    await tap(forgePatternCenters[index].x, forgePatternCenters[index].y);
  }
  await tap(600, 338); // ignored status-label area must never lock the page.
  await tap(forgePatternCenters[0].x, forgePatternCenters[0].y);

  // The first CLEAR regression proves a cleared canvas cannot compile.
  await drawStroke();
  await tap(62, 338);
  await tap(143, 338);
  const logsBeforeRejectedCompile = consoleMessages.length;
  await tap(754, 338);
  await sleep(180);
  if (consoleMessages.length !== logsBeforeRejectedCompile) {
    const unexpected = consoleMessages.slice(logsBeforeRejectedCompile)
      .some((entry) => entry.text.startsWith("[WeaponCompiler] "));
    if (unexpected) throw new Error("CLEAR left drawing data behind and allowed compile");
  }

  const compileResults = [];
  for (let index = 0; index < patterns.length; index += 1) {
    await tap(forgePatternCenters[index].x, forgePatternCenters[index].y);
    await tap(143, 338); // LOAD IDEA
    await drawStroke();
    await tap(754, 338); // COMPILE WEAPON
    await sleep(320);

    const record = latestCompileRecord();
    if (record.forced_attack_pattern !== patterns[index]) {
      throw new Error(`forced pattern mismatch: expected ${patterns[index]}, got ${record.forced_attack_pattern}`);
    }
    if (record.weapon_spec.attack_pattern !== patterns[index]) {
      throw new Error(`WeaponSpec mismatch: expected ${patterns[index]}, got ${record.weapon_spec.attack_pattern}`);
    }

    await tap(790, 356); // ATTACK
    await sleep(patterns[index] === "melee_slash" ? 80 : 180);
    await page.screenshot({ path: `artifacts/${browserName}-${patterns[index]}-attack.png` });
    compileResults.push({
      pattern: patterns[index],
      input: record.input,
      runtimeValid: record.runtime_valid,
      power: record.weapon_spec.power_score,
    });

    await tap(792, 30); // REFORGE
    await sleep(180);
    if (index === 0) {
      await tap(782, 49); // BACK to combat without recompiling.
      await sleep(120);
      await tap(792, 30); // REFORGE again; selectors must still work.
      await sleep(180);
    }
  }

  const seriousConsole = consoleMessages.filter((entry) =>
    entry.type === "error" || entry.type === "warning"
  );
  return {
    browserName,
    patterns: compileResults,
    seriousConsole,
    rotationCycles: 3,
    rapidSwitches: 30,
  };
}
