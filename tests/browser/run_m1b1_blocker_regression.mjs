import { createRequire } from "node:module";
import { mkdir, writeFile } from "node:fs/promises";
import { join, resolve } from "node:path";

const require = createRequire(import.meta.url);
const playwright = require(process.env.PLAYWRIGHT_MODULE_PATH || "playwright");
const [browserName = "chromium", targetUrl = "http://127.0.0.1:8063/", outputRoot = "output/playwright/m1b1-blockers/fixed"] = process.argv.slice(2);
const browserType = playwright[browserName];
if (!browserType) throw new Error(`Unsupported browser: ${browserName}`);

const PROVIDER = "anthropic";
const MODEL = "claude-haiku-4-5-20251001";
const destination = resolve(outputRoot);
await mkdir(destination, { recursive: true });

const specs = {
  bow: {
    name: "Ink Longbow",
    weapon_class: "ranged",
    weapon_form: "bow",
    delivery: "projectile",
    trajectory: "direct",
    impact: "contact",
    area_effect: "none",
    attack_pattern: "straight_projectile",
    element: "normal",
    damage: 26,
    attack_speed: 1.3,
    range: 675,
    special_ability: "none",
    status_effect: "none",
    drawback: "low_impact",
    visual_material: "forged_metal",
    power_score: 49,
    projectile_speed: 620,
    area_radius: 120,
    pierce_count: 1,
    return_speed: 680,
  },
  grenade: {
    name: "Ink Arc Grenade",
    weapon_class: "ranged",
    weapon_form: "grenade",
    delivery: "thrown",
    trajectory: "arc",
    impact: "delayed_or_contact",
    area_effect: "explosion",
    attack_pattern: "area_blast",
    element: "normal",
    damage: 36,
    attack_speed: 1,
    range: 132,
    special_ability: "knockback_burst",
    status_effect: "knockback",
    drawback: "slow_recovery",
    visual_material: "forged_metal",
    power_score: 76,
    projectile_speed: 560,
    area_radius: 120,
    pierce_count: 1,
    return_speed: 680,
  },
  sword: {
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
  },
  boomerang: {
    name: "Volt Returning Crescent",
    weapon_class: "ranged",
    weapon_form: "boomerang",
    delivery: "thrown",
    trajectory: "returning",
    impact: "contact",
    area_effect: "none",
    attack_pattern: "boomerang",
    element: "electric",
    damage: 30,
    attack_speed: 0.95,
    range: 620,
    special_ability: "return_strike",
    status_effect: "shock",
    drawback: "self_stagger",
    visual_material: "charged_metal",
    power_score: 87,
    projectile_speed: 520,
    area_radius: 120,
    pierce_count: 1,
    return_speed: 760,
  },
};

function responseFor(requestId, kind) {
  return {
    success: true,
    provider_invoked: true,
    request_id: requestId,
    weapon_spec: specs[kind],
    interpretation_summary: {
      grenade: "A thrown grenade follows a visible arc, then explodes at its landing point.",
      bow: "A bow stays held and launches a direct arrow.",
      sword: "A held sword executes a melee slash.",
      boomerang: "A boomerang leaves the hand and returns.",
    }[kind],
    confidence: 0.94,
    corrections: [],
    fallback_reason: "",
    provider_metadata: { provider: PROVIDER, model: MODEL, attempts: 1 },
    latency: { total_ms: 41, provider_ms: 36, attempts: 1 },
    latency_ms: 41,
    estimated_cost: { amount: 0.0002, currency: "USD" },
    power_budget: { total: specs[kind].power_score },
    schema_valid: true,
    allow_list_valid: true,
    power_valid: true,
    runtime_valid: true,
  };
}

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

const sleep = (ms) => new Promise((resolvePromise) => setTimeout(resolvePromise, ms));
const browser = await browserType.launch({ headless: true });
const evidence = {
  suite: "M1B1 P0/P1 blocker regression",
  browser: browserName,
  target: targetUrl,
  captured_at: new Date().toISOString(),
  provider_claim: "SIMULATED RESPONSE - real provider is tested separately",
  cases: [],
  keyboard: null,
  console_errors: [],
};

async function runCase(kind) {
  const context = await browser.newContext({
    ...playwright.devices["iPhone 15"],
    viewport: { width: 844, height: 390 },
    screen: { width: 844, height: 390 },
  });
  const page = await context.newPage();
  const consoleEntries = [];
  let postedBody = null;
  page.on("console", (message) => consoleEntries.push({ type: message.type(), text: message.text() }));
  await page.route("**/api/compile-weapon", async (route) => {
    postedBody = route.request().postDataJSON();
    await route.fulfill({
      status: 200,
      contentType: "application/json",
      headers: { "Cache-Control": "no-store" },
      body: JSON.stringify(responseFor(postedBody.request_id, kind)),
    });
  });

  const url = new URL(targetUrl);
  url.searchParams.set("qa", "m1b1");
  await page.goto(url.href, { waitUntil: "domcontentloaded", timeout: 30000 });
  const state = () => page.evaluate(() => window.__forgeM1B1Test?.state?.() || {});
  const controls = () => page.evaluate(() => window.__forgeM1B1Test?.controls?.() || {});
  const waitFor = async (predicate, label, timeout = 20000) => {
    const started = Date.now();
    let value = {};
    while (Date.now() - started < timeout) {
      value = await state();
      if (predicate(value)) return value;
      await sleep(50);
    }
    throw new Error(`${kind}: timeout waiting for ${label}: ${JSON.stringify(value)}`);
  };
  const tap = async (rect) => {
    assert(rect?.width > 0 && rect?.height > 0, `${kind}: hidden control ${JSON.stringify(rect)}`);
    await page.touchscreen.tap(rect.x + rect.width / 2, rect.y + rect.height / 2);
  };

  await waitFor((value) => value.screen === "forge" && value.phase === "idle", "forge");
  const description = {
    grenade: "a thrown grenade that explodes after landing",
    bow: "a wooden bow firing arrows",
    sword: "a plain steel sword",
    boomerang: "an electric boomerang that returns",
  }[kind];
  const input = page.locator("#forge-description-input");
  await input.fill(description);
  await waitFor((value) => value.description === description, "description sync");

  const canvas = (await controls()).canvas;
  const points = kind === "grenade"
    ? Array.from({ length: 33 }, (_, index) => {
        const angle = (Math.PI * 2 * index) / 32;
        const radius = Math.min(canvas.height * 0.27, canvas.width * 0.12);
        return {
          x: canvas.x + canvas.width * 0.55 + Math.cos(angle) * radius,
          y: canvas.y + canvas.height * 0.52 + Math.sin(angle) * radius,
        };
      })
    : kind === "boomerang"
      ? [
          { x: canvas.x + canvas.width * 0.30, y: canvas.y + canvas.height * 0.28 },
          { x: canvas.x + canvas.width * 0.62, y: canvas.y + canvas.height * 0.18 },
          { x: canvas.x + canvas.width * 0.78, y: canvas.y + canvas.height * 0.42 },
          { x: canvas.x + canvas.width * 0.62, y: canvas.y + canvas.height * 0.72 },
          { x: canvas.x + canvas.width * 0.32, y: canvas.y + canvas.height * 0.62 },
        ]
      : kind === "sword"
        ? [
            { x: canvas.x + canvas.width * 0.18, y: canvas.y + canvas.height * 0.66 },
            { x: canvas.x + canvas.width * 0.82, y: canvas.y + canvas.height * 0.28 },
          ]
        : [
        { x: canvas.x + canvas.width * 0.10, y: canvas.y + canvas.height * 0.50 },
        { x: canvas.x + canvas.width * 0.30, y: canvas.y + canvas.height * 0.30 },
        { x: canvas.x + canvas.width * 0.58, y: canvas.y + canvas.height * 0.28 },
        { x: canvas.x + canvas.width * 0.88, y: canvas.y + canvas.height * 0.50 },
        { x: canvas.x + canvas.width * 0.58, y: canvas.y + canvas.height * 0.72 },
        { x: canvas.x + canvas.width * 0.30, y: canvas.y + canvas.height * 0.70 },
        { x: canvas.x + canvas.width * 0.10, y: canvas.y + canvas.height * 0.50 },
        ];
  await page.mouse.move(points[0].x, points[0].y);
  await page.mouse.down();
  await sleep(16);
  for (const point of points.slice(1)) {
    await page.mouse.move(point.x, point.y, { steps: 3 });
    // Let Godot consume each segment before WebKit coalesces the next batch.
    // Without this, a closed bow stroke can collapse to identical endpoints
    // and make a degenerate test shape that never existed in the UI intent.
    await sleep(12);
  }
  await page.mouse.up();
  await waitFor((value) => value.drawing_count === 1, "drawing");

  await tap((await controls()).forge);
  const confirmation = await waitFor(
    (value) => value.screen === "confirmation" && value.phase === "result",
    "successful confirmation",
  );
  assert(postedBody.description === description, `${kind}: posted description was lost`);
  assert(confirmation.request_snapshot.description === description, `${kind}: visible snapshot differs`);
  assert(postedBody.request_id === confirmation.request_snapshot.request_id, `${kind}: request ID differs`);
  assert(confirmation.result.success === true && confirmation.result.provider_invoked === true, `${kind}: provider success gate missing`);
  assert(confirmation.result.provider_metadata.provider === PROVIDER, `${kind}: provider identity missing`);
  assert(confirmation.result.provider_metadata.model === MODEL, `${kind}: model identity missing`);
  assert(confirmation.stroke_geometry.relative_aspect_error <= 0.02, `${kind}: aspect error exceeds 2%`);
  assert(Math.abs(confirmation.stroke_geometry.scale_x - confirmation.stroke_geometry.scale_y) <= 1e-6, `${kind}: non-uniform scale`);
  assert(confirmation.stroke_geometry.padding_fraction >= 0.08 && confirmation.stroke_geometry.padding_fraction <= 0.12, `${kind}: padding outside 8-12%`);
  assert(confirmation.visual_transforms.review.absolute_delta <= 1e-6, `${kind}: confirmation preview parent is non-uniform`);
  for (const [field, expected] of Object.entries(specs[kind])) {
    if (["name", "power_score"].includes(field) || (kind === "sword" && ["attack_speed", "range"].includes(field))) continue;
    assert(confirmation.spec[field] === expected, `${kind}: ${field} mismatch; got ${confirmation.spec[field]}, expected ${expected}`);
  }
  if (kind === "sword") {
    assert(confirmation.spec.range === confirmation.geometry_profile.effective_reach, "sword: HUD/runtime Range differs from frozen reach");
    assert(confirmation.spec.damage === specs.sword.damage, "sword: drawing length changed damage");
  }
  await page.screenshot({ path: join(destination, `${browserName}-${kind}-confirmation.png`) });

  await tap((await controls()).confirm);
  const combat = await waitFor((value) => value.screen === "combat", "combat");
  assert(combat.stroke_geometry.relative_aspect_error <= 0.02, `${kind}: combat aspect error exceeds 2%`);
  assert(combat.visual_transforms.held.absolute_delta <= 1e-6, `${kind}: held parent is non-uniform`);
  await page.screenshot({ path: join(destination, `${browserName}-${kind}-combat-held.png`) });
  const attackControl = (await controls()).attack;
  let attacked = combat;
  const attackEvidence = {};
  if (kind === "bow") {
    const rest = structuredClone(combat.held_visual.local_position);
    const iterations = [];
    for (let index = 0; index < 10; index += 1) {
      const ready = await waitFor(
        (value) => value.held_visual.cooldown <= 0.01 && value.active_projectiles === 0,
        `bow ready ${index + 1}`,
      );
      const beforeAttack = ready.attack_count;
      const beforeSpawn = ready.projectile_spawn_count;
      const beforeFinish = ready.projectile_finish_count;
      // Give WebKit one settled frame after the cooldown reaches zero. Its
      // synthetic touch queue can otherwise drop the very first press after a
      // state transition even though the game is already ready.
      await sleep(75);
      let accepted = null;
      let tapAttempts = 0;
      while (!accepted && tapAttempts < 2) {
        tapAttempts += 1;
        await tap((await controls()).attack || attackControl);
        if (index === 0) {
          await sleep(25);
          await page.screenshot({ path: join(destination, `${browserName}-bow-held-arrow-flight.png`) });
        }
        try {
          accepted = await waitFor(
            (value) => value.attack_count === beforeAttack + 1 && value.projectile_spawn_count === beforeSpawn + 1,
            `bow arrow accepted ${index + 1}`,
            1200,
          );
        } catch (error) {
          if (tapAttempts >= 2) throw error;
        }
      }
      attacked = accepted;
      const arrow = accepted.projectiles[0] || accepted.last_finished_projectile;
      assert(accepted.visual_bundle.projectile_kind === "arrow", "bow: bundle did not select arrow");
      assert(accepted.visual_bundle.projectile_source === "procedural", "bow: projectile copied held strokes");
      assert(accepted.visual_bundle.hide_held_during_attack === false, "bow: bundle hides the held bow");
      assert(accepted.held_visual.visible === true, `bow: held bow hidden on attack ${index + 1}`);
      assert(arrow.kind === "arrow" && arrow.source === "procedural" && !arrow.uses_player_strokes, "bow: flying visual is not one procedural arrow");
      assert(arrow.rotation_mode === "face_velocity" && arrow.heading_error <= 0.02, `bow: arrow tumbled (${arrow.heading_error})`);
      assert(accepted.held_visual.position_drift <= 0.5, `bow: held position drifted on attack ${index + 1}`);
      assert(accepted.peak_active_projectiles <= 1, `bow: more than one arrow was active (${accepted.peak_active_projectiles})`);
      const finished = await waitFor(
        (value) => value.projectile_finish_count === beforeFinish + 1 && value.active_projectiles === 0,
        `bow arrow finish ${index + 1}`,
      );
      const settled = await waitFor(
        (value) => value.held_visual.cooldown <= 0.01 && value.held_visual.visible,
        `bow rest ${index + 1}`,
      );
      assert(settled.held_visual.position_drift <= 0.5, `bow: did not return to rest on attack ${index + 1}`);
      assert(settled.held_visual.local_position.x === rest.x && settled.held_visual.local_position.y === rest.y, "bow: exact held rest position changed");
      iterations.push({
        attack: index + 1,
        tap_attempts: tapAttempts,
        spawn_count: accepted.projectile_spawn_count,
        finish_count: finished.projectile_finish_count,
        max_active: accepted.peak_active_projectiles,
        heading_error: arrow.heading_error,
        held_drift: settled.held_visual.position_drift,
      });
    }
    attackEvidence.iterations = iterations;
  } else if (kind === "grenade") {
    const beforeAttack = combat.attack_count;
    const beforeSpawn = combat.projectile_spawn_count;
    const beforeFinish = combat.projectile_finish_count;
    const beforeImpact = combat.impact_spawn_count;
    await tap(attackControl);
    const flight = await waitFor(
      (value) => value.attack_count === beforeAttack + 1 && value.projectile_spawn_count === beforeSpawn + 1 && value.active_projectiles === 1,
      "grenade flight",
    );
    attacked = flight;
    const grenade = flight.projectiles[0];
    assert(flight.active_area_blasts === 0, "grenade exploded before its visible flight");
    assert(flight.held_visual.visible === false, "grenade remained duplicated in the hand");
    assert(grenade.kind === "grenade" && grenade.source === "player_strokes" && grenade.uses_player_strokes, "grenade did not use a temporary drawing copy");
    assert(grenade.rotation_mode === "tumble", "grenade rotation mode is not tumble");
    assert(grenade.relative_aspect_error <= 0.02, `grenade aspect error ${grenade.relative_aspect_error}`);
    assert(grenade.pivot_error <= 1.0, `grenade external rotation pivot error ${grenade.pivot_error}`);
    assert(flight.combat_message.includes("visible arc"), `grenade: missing flight message ${flight.combat_message}`);
    await page.screenshot({ path: join(destination, `${browserName}-grenade-arc-flight.png`) });
    const impact = await waitFor(
      (value) => value.projectile_finish_count === beforeFinish + 1 && value.impact_spawn_count === beforeImpact + 1 && value.active_projectiles === 0 && value.active_area_blasts > 0,
      "grenade landing explosion",
      5000,
    );
    const arcPositions = impact.last_finished_projectile.path_samples || [];
    assert(arcPositions.length >= 5, `grenade: insufficient physics arc samples ${JSON.stringify(arcPositions)}`);
    assert(arcPositions.every((value, index) => index === 0 || value.x >= arcPositions[index - 1].x), "grenade: arc did not move forward");
    const middleMinY = Math.min(...arcPositions.slice(1, -1).map((value) => value.y));
    assert(middleMinY < Math.min(arcPositions[0].y, arcPositions.at(-1).y) - 3, `grenade: sampled path is not parabolic ${JSON.stringify(arcPositions)}`);
    assert(impact.last_finished_projectile.impact_reason === "ground", `grenade: controlled case did not reach the floor ${JSON.stringify(impact.last_finished_projectile)}`);
    assert(impact.last_finished_projectile.landed_on_ground === true, "grenade: ground landing was not recorded");
    assert(impact.last_finished_projectile.landing_error <= 1.0, `grenade: final centre missed landing line by ${impact.last_finished_projectile.landing_error}px`);
    assert(arcPositions.at(-1).y > arcPositions[0].y + 10, `grenade: exploded before descending to the floor ${JSON.stringify(arcPositions)}`);
    assert(impact.area_impact_distance > 24, `grenade: explosion did not move away from throw origin (${impact.area_impact_distance})`);
    assert(impact.held_visual.visible === false && impact.held_visual.cooldown > 0, "grenade returned before cooldown completed");
    // Allow at least one fully rendered post-spawn frame, then capture while the
    // independent blast ring is still bright. A 25 ms lifecycle-only sample
    // could pass before Chromium visibly painted the effect.
    await sleep(110);
    assert((await state()).active_area_blasts > 0, "grenade: explosion visual ended before capture");
    await page.screenshot({ path: join(destination, `${browserName}-grenade-landing-explosion.png`) });
    const restored = await waitFor(
      (value) => value.held_visual.cooldown <= 0.01 && value.held_visual.visible,
      "grenade held restore after cooldown",
    );
    const events = restored.attack_events.filter((entry) => ["projectile_spawn", "impact_spawn", "projectile_finish"].includes(entry.kind));
    const spawnEventIndex = events.findIndex((entry) => entry.kind === "projectile_spawn");
    const impactEventIndex = events.findIndex((entry) => entry.kind === "impact_spawn");
    assert(spawnEventIndex >= 0 && impactEventIndex >= 0, `grenade: missing lifecycle event ${JSON.stringify(events)}`);
    assert(spawnEventIndex < impactEventIndex, "grenade: impact preceded flight");
    attackEvidence.arc_positions = arcPositions;
    attackEvidence.impact_reason = impact.last_finished_projectile.impact_reason;
    attackEvidence.landing_surface_y = impact.last_finished_projectile.landing_surface_y;
    attackEvidence.landing_center_y = impact.last_finished_projectile.landing_center_y;
    attackEvidence.landing_error = impact.last_finished_projectile.landing_error;
    attackEvidence.restored_after_cooldown = true;
  } else if (kind === "sword") {
    const beforeAttack = combat.attack_count;
    const beforeSpawn = combat.projectile_spawn_count;
    await tap(attackControl);
    attacked = await waitFor((value) => value.attack_count === beforeAttack + 1, "sword attack");
    await sleep(180);
    attacked = await state();
    assert(attacked.projectile_spawn_count === beforeSpawn && attacked.active_projectiles === 0, "sword generated a projectile");
    assert(attacked.held_visual.visible, "sword left the player's hand");
    attackEvidence.projectile_delta = attacked.projectile_spawn_count - beforeSpawn;
  } else if (kind === "boomerang") {
    const beforeAttack = combat.attack_count;
    const beforeSpawn = combat.projectile_spawn_count;
    const beforeFinish = combat.projectile_finish_count;
    const beforeImpact = combat.impact_spawn_count;
    await tap(attackControl);
    const outbound = await waitFor(
      (value) => value.attack_count === beforeAttack + 1 && value.projectile_spawn_count === beforeSpawn + 1 && value.active_projectiles === 1 && value.projectiles[0]?.returning === false,
      "boomerang outbound",
    );
    attacked = outbound;
    const instanceId = outbound.projectiles[0].instance_id;
    assert(!outbound.held_visual.visible, "boomerang remained duplicated in the hand");
    assert(outbound.projectiles[0].kind === "boomerang" && outbound.projectiles[0].source === "player_strokes", "boomerang did not throw the drawn weapon");
    assert(outbound.projectiles[0].pivot_error <= 1.0 && outbound.projectiles[0].relative_aspect_error <= 0.02, "boomerang pivot/aspect changed");
    const returning = await waitFor(
      (value) => value.projectiles[0]?.instance_id === instanceId && value.projectiles[0]?.returning === true,
      "boomerang return phase",
    );
    assert(returning.held_visual.visible === false, "boomerang reappeared in the hand before returning");
    assert(returning.impact_spawn_count === beforeImpact, "boomerang created an explosion");
    await page.screenshot({ path: join(destination, `${browserName}-boomerang-returning.png`) });
    await waitFor(
      (value) => value.projectile_finish_count === beforeFinish + 1 && value.active_projectiles === 0,
      "boomerang return completion",
    );
    const restored = await waitFor(
      (value) => value.held_visual.cooldown <= 0.01 && value.held_visual.visible,
      "boomerang held restore",
    );
    assert(restored.impact_spawn_count === beforeImpact, "boomerang produced an impact blast");
    attackEvidence.instance_id = instanceId;
    attackEvidence.returned = true;
  }

  assert(attacked.last_attack_pattern === specs[kind].attack_pattern, `${kind}: wrong attack module`);
  assert(attacked.visual_transforms.held.absolute_delta <= 1e-6, `${kind}: attack animation parent is non-uniform`);

  const known = (entry) =>
    entry.text.includes("GPU stall due to ReadPixels") ||
    entry.text.includes("CONTEXT_LOST_WEBGL") ||
    entry.text.includes("glBlitFramebuffer") ||
    entry.text.includes("WEBGL_polygon_mode") ||
    entry.text === "window.styleMedia is a deprecated draft version of window.matchMedia API, and it will be removed in the future.";
  const serious = consoleEntries.filter((entry) => ["error", "warning"].includes(entry.type) && !known(entry));
  assert(serious.length === 0, `${kind}: console errors ${JSON.stringify(serious)}`);
  evidence.console_errors.push(...serious);
  evidence.cases.push({
    kind,
    description,
    request_id: postedBody.request_id,
    request_snapshot: confirmation.request_snapshot,
    provider_metadata: confirmation.result.provider_metadata,
    latency_ms: confirmation.result.latency_ms,
    spec: confirmation.spec,
    stroke_geometry: confirmation.stroke_geometry,
    visual_transforms: confirmation.visual_transforms,
    attack: {
      attack_pattern: attacked.last_attack_pattern,
      delivery: confirmation.spec.delivery,
      trajectory: confirmation.spec.trajectory,
      impact: confirmation.spec.impact,
      area_effect: confirmation.spec.area_effect,
      evidence: attackEvidence,
    },
  });
  await context.close();
}

async function runKeyboardCase() {
  const context = await browser.newContext({
    ...playwright.devices["iPhone 15"],
    viewport: { width: 844, height: 390 },
    screen: { width: 844, height: 390 },
  });
  const page = await context.newPage();
  const consoleEntries = [];
  page.on("console", (message) => consoleEntries.push({ type: message.type(), text: message.text() }));
  const url = new URL(targetUrl);
  url.searchParams.set("qa", "m1b1");
  await page.goto(url.href, { waitUntil: "domcontentloaded", timeout: 30000 });

  const sleepLocal = (ms) => new Promise((resolvePromise) => setTimeout(resolvePromise, ms));
  const state = () => page.evaluate(() => window.__forgeM1B1Test?.state?.() || {});
  const mobile = () => page.evaluate(() => window.__forgeM1B1Test?.mobileInput?.() || {});
  const waitForState = async (predicate, label, timeout = 12000) => {
    const started = Date.now();
    let current = {};
    while (Date.now() - started < timeout) {
      current = await state();
      if (predicate(current)) return current;
      await sleepLocal(50);
    }
    throw new Error(`keyboard: timeout waiting for ${label}: ${JSON.stringify(current)}`);
  };
  const waitForMobile = async (predicate, label, timeout = 12000) => {
    const started = Date.now();
    let current = {};
    while (Date.now() - started < timeout) {
      current = await mobile();
      if (predicate(current)) return current;
      await sleepLocal(40);
    }
    throw new Error(`keyboard: timeout waiting for ${label}: ${JSON.stringify(current)}`);
  };

  await waitForState((value) => value.screen === "forge" && value.phase === "idle", "forge");
  const input = page.locator("#forge-description-input");
  const done = page.locator("#forge-description-done");
  const baseline = await mobile();
  assert(baseline.metrics.canvasBackingWidth > 0 && baseline.metrics.canvasBackingHeight > 0, "keyboard: Canvas backing store was not initialized before Godot");
  assert(baseline.inputRect?.width > 0 && baseline.inputRect?.height > 0, "keyboard: native Description input has no initial touch target");
  const firstTapPoint = {
    x: baseline.inputRect.x + baseline.inputRect.width / 2,
    y: baseline.inputRect.y + baseline.inputRect.height / 2,
  };
  await page.touchscreen.tap(firstTapPoint.x, firstTapPoint.y);
  const firstTap = await waitForMobile(
    (value) => value.metrics?.inputFocused && value.metrics?.textEntryActive && value.doneVisible,
    "first physical-style touch focus",
  );
  assert(firstTap.inputRect?.y <= baseline.inputRect.y, "keyboard: first touch did not enter compact text mode");
  await input.fill("keyboard text remains visible");
  await waitForState((value) => value.description === "keyboard text remains visible", "description sync");

  await page.evaluate(() => window.__forgeM1B1Test.setVisualViewport({
    width: 844,
    height: 190,
    offsetLeft: 0,
    offsetTop: 92,
    innerWidth: 844,
    innerHeight: 390,
    scale: 1,
  }));
  const opened = await waitForMobile(
    (value) => value.metrics?.keyboardOpen && value.doneVisible && value.rootVisible,
    "compact text-entry mode",
  );
  const visibleRect = {
    x: opened.metrics.offsetLeft + opened.metrics.safeLeft,
    y: opened.metrics.offsetTop + opened.metrics.safeTop,
    width: opened.metrics.width - opened.metrics.safeLeft - opened.metrics.safeRight,
    height: opened.metrics.height - opened.metrics.safeTop - opened.metrics.safeBottom,
  };
  const inside = (rect) => rect &&
    rect.x >= visibleRect.x - 1 && rect.y >= visibleRect.y - 1 &&
    rect.x + rect.width <= visibleRect.x + visibleRect.width + 1 &&
    rect.y + rect.height <= visibleRect.y + visibleRect.height + 1;
  assert(inside(opened.inputRect), `keyboard: input outside Visual Viewport ${JSON.stringify(opened)}`);
  assert(inside(opened.clearRect), "keyboard: clear button outside Visual Viewport");
  assert(inside(opened.doneRect), "keyboard: Done outside Visual Viewport");
  assert(opened.doneRect.width >= 44 && opened.doneRect.height >= 44, "keyboard: Done touch target is below 44px");
  assert(opened.inputFontSize >= 16, `keyboard: input font triggers iOS zoom (${opened.inputFontSize}px)`);
  assert(opened.metrics.canvasBackingWidth === baseline.metrics.canvasBackingWidth && opened.metrics.canvasBackingHeight === baseline.metrics.canvasBackingHeight, "keyboard: opening resized the WebGL backing store");
  assert(opened.metrics.canvasRect.width === baseline.metrics.canvasRect.width && opened.metrics.canvasRect.height === baseline.metrics.canvasRect.height, "keyboard: opening rescaled the Godot Canvas");
  const canvasBottom = opened.metrics.canvasRect.y + opened.metrics.canvasRect.height;
  const visibleBottom = visibleRect.y + visibleRect.height;
  assert(Math.min(canvasBottom, visibleBottom) - Math.max(opened.metrics.canvasRect.y, visibleRect.y) > 80, "keyboard: Visual Viewport has no meaningful Canvas intersection");
  assert(opened.metrics.pageScrollX === 0 && opened.metrics.pageScrollY === 0, "keyboard: Safari focus scrolled the page away from Canvas");

  await input.fill("keyboard editable text");
  await input.press("End");
  await input.press("Backspace");
  assert((await input.inputValue()) === "keyboard editable tex", "keyboard: edit/delete failed while compact entry was open");
  await waitForState((value) => value.description === "keyboard editable tex", "edited description sync");
  await page.screenshot({ path: join(destination, `${browserName}-keyboard-open.png`) });

  await done.click();
  await page.evaluate(() => window.__forgeM1B1Test.clearVisualViewport());
  const closed = await waitForMobile(
    (value) => !value.metrics?.textEntryActive && !value.metrics?.keyboardOpen && !value.doneVisible,
    "keyboard close and stable layout restore",
  );
  assert(closed.metrics.canvasBackingWidth === baseline.metrics.canvasBackingWidth && closed.metrics.canvasBackingHeight === baseline.metrics.canvasBackingHeight, "keyboard: close did not restore stable Canvas");
  assert(closed.inputValue === "keyboard editable tex", "keyboard: close lost Description text");
  assert((await state()).description === "keyboard editable tex", "keyboard: Godot lost Description after close");
  await page.screenshot({ path: join(destination, `${browserName}-keyboard-closed.png`) });

  await page.setViewportSize({ width: 844, height: 343 });
  await waitForState((value) => value.screen === "forge", "Safari toolbar expanded");
  const toolbar = await waitForMobile((value) => Math.abs(value.metrics.canvasRect.height - 343) <= 2, "toolbar Canvas relayout");
  assert(toolbar.inputValue === "keyboard editable tex", "keyboard: toolbar resize lost text");
  await page.setViewportSize({ width: 844, height: 390 });
  await waitForMobile((value) => Math.abs(value.metrics.canvasRect.height - 390) <= 2, "toolbar Canvas restore");

  for (let cycle = 0; cycle < 3; cycle += 1) {
    await page.setViewportSize({ width: 390, height: 844 });
    await waitForState((value) => value.screen === "portrait", `portrait cycle ${cycle + 1}`);
    assert(!(await input.isVisible()), `keyboard: native input leaked over portrait cycle ${cycle + 1}`);
    await page.setViewportSize({ width: 844, height: 390 });
    const landscape = await waitForState((value) => value.screen === "forge", `landscape cycle ${cycle + 1}`);
    assert(landscape.description === "keyboard editable tex", `keyboard: rotation cycle ${cycle + 1} lost text`);
  }

  const known = (entry) =>
    entry.text.includes("GPU stall due to ReadPixels") ||
    entry.text.includes("CONTEXT_LOST_WEBGL") ||
    entry.text.includes("glBlitFramebuffer") ||
    entry.text.includes("WEBGL_polygon_mode") ||
    entry.text === "window.styleMedia is a deprecated draft version of window.matchMedia API, and it will be removed in the future.";
  const serious = consoleEntries.filter((entry) => ["error", "warning"].includes(entry.type) && !known(entry));
  assert(serious.length === 0, `keyboard: console errors ${JSON.stringify(serious)}`);
  evidence.keyboard = {
    mode: "synthetic Visual Viewport; physical iPhone remains TO VALIDATE",
    baseline,
    first_touch_focus: {
      point: firstTapPoint,
      focused: firstTap.metrics.inputFocused,
      compact_entry_visible: firstTap.doneVisible,
    },
    opened,
    closed,
    toolbar_height: toolbar.metrics.canvasRect.height,
    orientation_cycles: 3,
    description_preserved: true,
  };
  evidence.console_errors.push(...serious);
  await context.close();
}

try {
  await runKeyboardCase();
  await runCase("bow");
  await runCase("grenade");
  await runCase("sword");
  await runCase("boomerang");
  await writeFile(join(destination, `${browserName}-report.json`), `${JSON.stringify(evidence, null, 2)}\n`, "utf8");
  console.log(JSON.stringify(evidence, null, 2));
} finally {
  await browser.close();
}
