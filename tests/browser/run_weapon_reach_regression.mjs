import { createRequire } from "node:module";
import { mkdir, readFile, writeFile } from "node:fs/promises";
import { join, resolve } from "node:path";

const require = createRequire(import.meta.url);
const playwright = require(process.env.PLAYWRIGHT_MODULE_PATH || "playwright");
const [browserName = "chromium", targetUrl = "http://127.0.0.1:8063/", outputRoot = "output/playwright/weapon-reach"] = process.argv.slice(2);
const browserType = playwright[browserName];
if (!browserType) throw new Error(`Unsupported browser: ${browserName}`);

const PROVIDER = "anthropic";
const MODEL = "claude-haiku-4-5-20251001";
const destination = resolve(outputRoot);
await mkdir(destination, { recursive: true });
const sleep = (ms) => new Promise((resolvePromise) => setTimeout(resolvePromise, ms));
const assert = (condition, message) => { if (!condition) throw new Error(message); };

const baseSword = {
  name: "Ink Sketchsword",
  weapon_class: "melee",
  weapon_form: "sword",
  delivery: "held",
  trajectory: "direct",
  impact: "contact",
  area_effect: "none",
  attack_pattern: "melee_slash",
  element: "normal",
  damage: 36,
  attack_speed: 1,
  range: 132,
  special_ability: "knockback_burst",
  status_effect: "knockback",
  drawback: "slow_recovery",
  visual_material: "forged_metal",
  power_score: 33,
  projectile_speed: 560,
  area_radius: 120,
  pierce_count: 1,
  return_speed: 680,
};

function responseFor(requestId) {
  return {
    success: true,
    provider_invoked: true,
    request_id: requestId,
    weapon_spec: baseSword,
    interpretation_summary: "A held sword executes a melee slash.",
    confidence: 0.94,
    corrections: [],
    fallback_reason: "",
    provider_metadata: { provider: PROVIDER, model: MODEL, attempts: 1 },
    latency: { total_ms: 41, provider_ms: 36, attempts: 1 },
    latency_ms: 41,
    estimated_cost: { amount: 0.0002, currency: "USD" },
    power_budget: { total: baseSword.power_score },
    schema_valid: true,
    allow_list_valid: true,
    power_valid: true,
    runtime_valid: true,
  };
}

const browser = await browserType.launch({ headless: true });
const report = {
  suite: "Weapon Physics B1 held-melee reach x mass regression",
  browser: browserName,
  target: targetUrl,
  provider_claim: "SIMULATED RESPONSE - no paid provider invocation",
  captured_at: new Date().toISOString(),
  cases: [],
  console_errors: [],
};

async function runCase(caseName, startFraction, endFraction, crossAxisFraction, expectedMass, expectHit) {
  const context = await browser.newContext({
    ...playwright.devices["iPhone 15"],
    viewport: { width: 844, height: 390 },
    screen: { width: 844, height: 390 },
  });
  const page = await context.newPage();
  const consoleEntries = [];
  page.on("console", (message) => consoleEntries.push({ type: message.type(), text: message.text() }));
  page.on("pageerror", (error) => consoleEntries.push({ type: "error", text: error.message }));
  page.route("**/api/compile-weapon", async (route) => {
    const body = route.request().postDataJSON();
    await route.fulfill({ status: 200, contentType: "application/json", body: JSON.stringify(responseFor(body.request_id)) });
  });

  const url = new URL(targetUrl);
  url.searchParams.set("qa", "m1b1");
  await page.goto(url.href, { waitUntil: "domcontentloaded", timeout: 30000 });
  const state = () => page.evaluate(() => window.__forgeM1B1Test?.state?.() || {});
  const controls = () => page.evaluate(() => window.__forgeM1B1Test?.controls?.() || {});
  const waitFor = async (predicate, label, timeout = 20000) => {
    const started = Date.now();
    let current = {};
    while (Date.now() - started < timeout) {
      current = await state();
      if (predicate(current)) return current;
      await sleep(40);
    }
    throw new Error(`${caseName}: timeout waiting for ${label}: ${JSON.stringify(current)}`);
  };
  const tap = async (rect) => {
    assert(rect?.width > 0 && rect?.height > 0, `${caseName}: hidden control`);
    await page.touchscreen.tap(rect.x + rect.width / 2, rect.y + rect.height / 2);
  };

  await waitFor((value) => value.screen === "forge" && value.phase === "idle", "forge");
  const description = `a plain steel ${caseName} sword`;
  await page.locator("#forge-description-input").fill(description);
  await waitFor((value) => value.description === description, "description sync");
  const canvas = (await controls()).canvas;
  const y = canvas.y + canvas.height * 0.52;
  const halfCrossAxis = crossAxisFraction * 0.5;
  const bladePoints = [
    { x: canvas.x + canvas.width * startFraction, y: y - canvas.height * halfCrossAxis * 0.35 },
    { x: canvas.x + canvas.width * (endFraction - 0.015), y: y - canvas.height * halfCrossAxis },
    { x: canvas.x + canvas.width * endFraction, y },
    { x: canvas.x + canvas.width * (endFraction - 0.015), y: y + canvas.height * halfCrossAxis },
    { x: canvas.x + canvas.width * startFraction, y: y + canvas.height * halfCrossAxis * 0.35 },
  ];
  const strokes = [bladePoints];
  for (const stroke of strokes) {
    await page.mouse.move(stroke[0].x, stroke[0].y);
    await page.mouse.down();
    for (const point of stroke.slice(1)) {
      await page.mouse.move(point.x, point.y, { steps: 4 });
      await sleep(12);
    }
    await page.mouse.up();
  }
  await waitFor((value) => value.drawing_count === strokes.length, "drawing");
  await tap((await controls()).forge);
  const confirmation = await waitFor((value) => value.screen === "confirmation" && value.phase === "result", "confirmation");
  assert(confirmation.spec.damage === baseSword.damage, `${caseName}: damage changed`);
  assert(confirmation.spec.power_score <= 100, `${caseName}: PowerBudget exceeded 100`);
  assert(confirmation.result.corrections.some((entry) => entry.startsWith("physics B1:")), `${caseName}: physics correction reason missing`);
  assert(confirmation.spec.range === confirmation.geometry_profile.effective_reach, `${caseName}: Range differs from effective reach`);
  assert(confirmation.geometry_profile.mass_profile === expectedMass, `${caseName}: expected mass ${expectedMass}, got ${confirmation.geometry_profile.mass_profile}`);
  assert(Math.abs(confirmation.stroke_geometry.visible_reach - confirmation.spec.range) <= 0.05, `${caseName}: visible tip differs from Range`);
  assert(confirmation.stroke_geometry.relative_aspect_error <= 0.02, `${caseName}: aspect error exceeds 2%`);
  assert(Math.abs(confirmation.stroke_geometry.scale_x - confirmation.stroke_geometry.scale_y) <= 1e-6, `${caseName}: fit is non-uniform`);
  assert(confirmation.stroke_geometry.padding_fraction >= 0.08 && confirmation.stroke_geometry.padding_fraction <= 0.12, `${caseName}: padding outside 8-12%`);
  const derived = confirmation.geometry_profile.combat_derived;
  assert(derived.startup_seconds > 0 && derived.active_seconds > 0 && derived.recovery_seconds > 0, `${caseName}: timing phases are not observable`);
  assert(Number.isFinite(derived.budget_effects.combined_delta), `${caseName}: physics budget delta missing`);
  assert(Math.abs(derived.attack_speed - confirmation.spec.attack_speed) <= 1e-6, `${caseName}: attack_speed differs from CombatDerived`);
  assert(derived.contact_model.mode === "uniform_grip_to_tip" && derived.contact_model.regions.length === 0 && !derived.contact_model.sweet_spots_enabled, `${caseName}: B2 contact behavior leaked into B1`);

  await tap((await controls()).confirm);
  let combat = await waitFor((value) => value.screen === "combat", "combat");
  const frozenGeometry = JSON.stringify(combat.geometry_profile);

  const desiredGap = 170;
	await page.evaluate((gap) => window.__forgeM1B1Test.setPlayerTargetGap(gap), desiredGap);
	combat = await waitFor((value) => {
    const target = value.targets?.find((entry) => entry.visible);
    return target && Math.abs(target.position.x - value.held_visual.global_position.x - desiredGap) <= 0.1;
	}, "fixed target gap");
  const targetBefore = combat.targets.find((entry) => entry.visible);
  const actualGap = targetBefore.position.x - combat.held_visual.global_position.x;
	assert(Math.abs(actualGap - desiredGap) <= 0.1, `${caseName}: target gap did not converge (${actualGap})`);
  const healthBefore = targetBefore.health;
  await page.screenshot({ path: join(destination, `${browserName}-${caseName}-combat.png`) });

  const attackBefore = combat.attack_count;
  const tapStarted = Date.now();
  await tap((await controls()).attack);
  await waitFor((value) => value.attack_count === attackBefore + 1, "melee hit window");
  const measuredHitDelayMs = Date.now() - tapStarted;
	await sleep(150);
	const impact = await state();
  const targetAfter = impact.targets.find((entry) => entry.visible);
  const didHit = targetAfter.health < healthBefore;
  assert(didHit === expectHit, `${caseName}: expected hit=${expectHit}, got ${didHit} at gap ${actualGap}`);
  assert(impact.active_projectiles === 0 && impact.projectile_spawn_count === 0, `${caseName}: sword emitted a projectile`);
  await page.screenshot({ path: join(destination, `${browserName}-${caseName}-impact.png`) });

  if (caseName === "long-heavy") {
    await waitFor((value) => value.held_visual?.cooldown <= 0.01, "melee recovery");
    const reverseStart = await state();
    const reverseStartX = reverseStart.player_position.x;
    const secondAttackBefore = reverseStart.attack_count;
    await tap((await controls()).attack);
    await waitFor((value) => value.held_visual?.attack_facing === 1, "second swing start");
    const left = (await controls()).left;
    assert(left?.width > 0 && left?.height > 0, "long: LEFT control unavailable");
    await page.mouse.move(left.x + left.width / 2, left.y + left.height / 2);
    await page.mouse.down();
    const reverseAttempt = await waitFor(
      (value) =>
        value.player_position?.x < reverseStartX - 4 &&
        value.held_visual?.attack_facing === 1 &&
        value.held_visual?.visual_facing === 1,
      "reverse movement while swing direction stays frozen",
    );
    await page.mouse.up();
    const reverseHit = await waitFor((value) => value.attack_count === secondAttackBefore + 1, "reverse-input hit window");
    const reverseEvent = [...(reverseHit.attack_events || [])].reverse().find((entry) => entry.kind === "hit_window_open");
    assert(reverseEvent?.direction_x === 1, "long: reverse input changed the frozen hit direction");
    assert(reverseHit.held_visual.attack_facing === 1, "long: attack lock cleared before recovery");
    assert(reverseHit.held_visual.visual_facing === 1, "long: held visual flipped away from the hit direction");
    report.reverse_during_swing = {
      movement_delta_x: reverseAttempt.player_position.x - reverseStartX,
      attack_facing: reverseHit.held_visual.attack_facing,
      visual_facing: reverseHit.held_visual.visual_facing,
      hit_direction_x: reverseEvent.direction_x,
    };
    await waitFor((value) => value.held_visual?.attack_facing === 0, "direction lock release");
    for (const viewport of [{ width: 852, height: 393 }, { width: 915, height: 412 }, { width: 844, height: 390 }]) {
      await page.setViewportSize(viewport);
      const resized = await waitFor((value) => value.screen === "combat", `${viewport.width}x${viewport.height}`);
      assert(JSON.stringify(resized.geometry_profile) === frozenGeometry, `long: reach drifted at ${viewport.width}x${viewport.height}`);
    }
    await page.setViewportSize({ width: 390, height: 844 });
    await waitFor((value) => value.screen === "portrait", "portrait gate");
    await page.setViewportSize({ width: 844, height: 390 });
    const restored = await waitFor((value) => value.screen === "combat", "landscape restore");
    assert(JSON.stringify(restored.geometry_profile) === frozenGeometry, "long: reach drifted after orientation cycle");
  }

  const known = (entry) =>
    entry.text.includes("GPU stall due to ReadPixels") ||
    entry.text.includes("CONTEXT_LOST_WEBGL") ||
    entry.text.includes("glBlitFramebuffer") ||
    entry.text.includes("WEBGL_polygon_mode") ||
    entry.text === "window.styleMedia is a deprecated draft version of window.matchMedia API, and it will be removed in the future.";
  const serious = consoleEntries.filter((entry) => ["error", "warning"].includes(entry.type) && !known(entry));
  assert(serious.length === 0, `${caseName}: console errors ${JSON.stringify(serious)}`);
  report.console_errors.push(...serious);
  report.cases.push({
    name: caseName,
    geometry_profile: confirmation.geometry_profile,
    spec: confirmation.spec,
    visible_reach: confirmation.stroke_geometry.visible_reach,
    aspect_error: confirmation.stroke_geometry.relative_aspect_error,
    target_gap: actualGap,
    health_before: healthBefore,
    health_after: targetAfter.health,
    hit: didHit,
    attack_cycle_seconds: combat.held_visual.attack_cycle_seconds,
    startup_seconds: combat.held_visual.startup_seconds,
    active_seconds: combat.held_visual.active_seconds,
    hit_delay_seconds: combat.held_visual.hit_delay_seconds,
    recovery_seconds: combat.held_visual.recovery_seconds,
    measured_hit_delay_ms: measuredHitDelayMs,
    source_bounds: confirmation.geometry_profile.source_bounds,
  });
  await context.close();
}

try {
  await runCase("short-light", 0.12, 0.30, 0.05, "light", false);
  await runCase("short-heavy", 0.12, 0.30, 0.28, "heavy", false);
  await runCase("standard-balanced", 0.10, 0.52, 0.14, "balanced", false);
  await runCase("long-light", 0.035, 0.965, 0.05, "light", true);
  await runCase("long-heavy", 0.035, 0.965, 0.28, "heavy", true);
  const byName = Object.fromEntries(report.cases.map((entry) => [entry.name, entry]));
  assert(byName["short-light"].spec.range < byName["standard-balanced"].spec.range && byName["standard-balanced"].spec.range < byName["long-light"].spec.range, "visible/runtime reach is not strictly monotonic");
  assert(byName["short-light"].spec.range === byName["short-heavy"].spec.range, "short reach changed with mass");
  assert(byName["long-light"].spec.range === byName["long-heavy"].spec.range, "long reach changed with mass");
  assert(byName["short-light"].attack_cycle_seconds < byName["short-heavy"].attack_cycle_seconds, "short mass does not slow the complete cycle");
  assert(byName["long-light"].attack_cycle_seconds < byName["long-heavy"].attack_cycle_seconds, "long mass does not slow the complete cycle");
  assert(byName["short-light"].hit_delay_seconds < byName["long-light"].hit_delay_seconds, "reach does not delay the light hit window");
  assert(byName["short-heavy"].hit_delay_seconds < byName["long-heavy"].hit_delay_seconds, "reach does not delay the heavy hit window");
  const extremeCycleRatio = byName["long-heavy"].attack_cycle_seconds / byName["short-light"].attack_cycle_seconds;
  assert(extremeCycleRatio >= 1.35 && extremeCycleRatio < 3.0, `bounded extreme cycle ratio is ${extremeCycleRatio}`);
  await writeFile(join(destination, `${browserName}-report.json`), `${JSON.stringify(report, null, 2)}\n`, "utf8");

  if (browserName === "chromium") {
    const comparisonContext = await browser.newContext({ viewport: { width: 1820, height: 980 } });
    const comparison = await comparisonContext.newPage();
    const cards = await Promise.all(report.cases.map(async (entry) => ({
      ...entry,
      image: (await readFile(join(destination, `${browserName}-${entry.name}-combat.png`))).toString("base64"),
    })));
    await comparison.setContent(`<!doctype html><style>
      body{margin:0;background:#07111f;color:#edf4ff;font:20px system-ui;padding:24px}h1{margin:0 0 18px;font-size:28px}
      .row{display:flex;flex-wrap:wrap;gap:18px}.card{width:560px;background:#0d1b2d;border:1px solid #536f8e;border-radius:12px;overflow:hidden}
      img{width:100%;display:block}.copy{padding:12px 16px;line-height:1.45}.name{font-size:24px;color:#65d9ff;text-transform:uppercase}
    </style><h1>Project Forge — Weapon Physics B1 reach × mass</h1><div class="row">${cards.map((entry) => `
      <div class="card"><img src="data:image/png;base64,${entry.image}"><div class="copy"><div class="name">${entry.name}</div>
      Range ${entry.spec.range}px · Mass ${entry.geometry_profile.mass_profile} · Speed ${entry.spec.attack_speed.toFixed(2)} · Cycle ${entry.attack_cycle_seconds.toFixed(2)}s<br>
      Startup ${entry.startup_seconds.toFixed(2)}s · Active ${entry.active_seconds.toFixed(2)}s · Recovery ${entry.recovery_seconds.toFixed(2)}s<br>
      Same target gap ${entry.target_gap.toFixed(1)}px · ${entry.hit ? `HIT (${entry.health_before}→${entry.health_after})` : `MISS (${entry.health_before}→${entry.health_after})`}</div></div>`).join("")}</div>`);
    await comparison.screenshot({ path: join(destination, "chromium-short-standard-long-comparison.png"), fullPage: true });
    await comparisonContext.close();
  }
  console.log(JSON.stringify(report, null, 2));
} finally {
  await browser.close();
}
