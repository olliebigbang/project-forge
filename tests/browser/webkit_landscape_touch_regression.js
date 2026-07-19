async (page) => {
  const messages = [];
  page.on("console", (message) => messages.push({ type: message.type(), text: message.text() }));
  const sleep = (milliseconds) => page.waitForTimeout(milliseconds);
  const tap = (x, y) => page.touchscreen.tap(x, y);
  const patterns = ["melee_slash", "straight_projectile", "boomerang", "area_blast", "piercing"];
  const centers = [
    { x: 137, y: 204 }, { x: 367, y: 204 }, { x: 596, y: 204 },
    { x: 137, y: 256 }, { x: 367, y: 256 },
  ];

  const drawStroke = async () => {
    await page.mouse.move(90, 100);
    await page.mouse.down();
    await page.mouse.move(150, 84, { steps: 3 });
    await page.mouse.move(210, 116, { steps: 3 });
    await page.mouse.move(270, 92, { steps: 3 });
    await page.mouse.up();
    await sleep(60);
  };

  const latestRecord = () => {
    const line = messages.map((entry) => entry.text)
      .filter((text) => text.startsWith("[WeaponCompiler] ")).at(-1);
    if (!line) throw new Error("WebKit compile audit log missing");
    return JSON.parse(line.slice(line.indexOf("{")));
  };

  await page.reload();
  await sleep(900);
  const geometry = await page.evaluate(() => ({
    width: innerWidth,
    height: innerHeight,
    dpr: devicePixelRatio,
    orientation: screen.orientation ? screen.orientation.type : "unavailable",
    scrollWidth: document.documentElement.scrollWidth,
    scrollHeight: document.documentElement.scrollHeight,
  }));
  if (!geometry.orientation.startsWith("landscape")) throw new Error(`not a landscape device context: ${JSON.stringify(geometry)}`);
  if (geometry.scrollWidth > geometry.width || geometry.scrollHeight > geometry.height) {
    throw new Error(`WebKit page scrolls: ${JSON.stringify(geometry)}`);
  }

  for (const index of [0, 1, 2, 3, 4, 4, 3, 2, 1, 0]) await tap(centers[index].x, centers[index].y);
  for (let step = 0; step < 20; step += 1) {
    const index = step % patterns.length;
    await tap(centers[index].x, centers[index].y);
  }
  await tap(520, 307); // visual status area; must not capture the page.

  const results = [];
  for (let index = 0; index < patterns.length; index += 1) {
    await tap(centers[index].x, centers[index].y);
    await tap(126, 307); // LOAD IDEA
    await drawStroke();
    await tap(655, 307); // COMPILE WEAPON
    await sleep(300);
    const record = latestRecord();
    if (record.forced_attack_pattern !== patterns[index] || record.weapon_spec.attack_pattern !== patterns[index]) {
      throw new Error(`WebKit attack pattern mismatch for ${patterns[index]}`);
    }
    await tap(690, 315); // ATTACK
    await sleep(patterns[index] === "melee_slash" ? 80 : 160);
    await page.screenshot({ path: `artifacts/webkit-fresh-${patterns[index]}-attack.png` });
    results.push({ pattern: patterns[index], runtimeValid: record.runtime_valid, input: record.input });
    await tap(690, 27); // REFORGE
    await sleep(150);
    if (index === 0) {
      await tap(678, 46); // BACK
      await sleep(100);
      await tap(690, 27); // REFORGE again
      await sleep(150);
    }
  }

  await page.screenshot({ path: "artifacts/webkit-fresh-selector-after-regression.png" });
  return {
    geometry,
    results,
    rapidSwitches: 30,
    consoleErrors: messages.filter((entry) => entry.type === "error").map((entry) => entry.text),
    consoleWarnings: messages.filter((entry) => entry.type === "warning").map((entry) => entry.text),
  };
}
