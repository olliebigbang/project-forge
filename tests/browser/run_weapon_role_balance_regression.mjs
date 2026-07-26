import { createRequire } from "node:module";
import { mkdir, readFile, writeFile } from "node:fs/promises";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const require = createRequire(import.meta.url);
const playwright = require(process.env.PLAYWRIGHT_MODULE_PATH || "playwright");
const [browserName = "chromium", targetUrl = "http://127.0.0.1:8063/", outputRoot = "output/playwright/weapon-role-balance-b1-5"] = process.argv.slice(2);
const browserType = playwright[browserName];
if (!browserType) throw new Error(`Unsupported browser: ${browserName}`);

const scriptDirectory = dirname(fileURLToPath(import.meta.url));
const matrix = JSON.parse(await readFile(resolve(scriptDirectory, "../weapon_role_balance_matrix.json"), "utf8"));
const roleFilter = process.env.WEAPON_ROLE_FILTER || "";
const destination = resolve(outputRoot, browserName);
await mkdir(destination, { recursive: true });

const PROVIDER = "anthropic";
const MODEL = "claude-haiku-4-5-20251001";
const PROVIDER_FREE_TEXT_MARKER = "PROVIDER_FREE_TEXT_MUST_NOT_BECOME_ROLE_HUD";
const assert = (condition, message) => {
  if (!condition) throw new Error(message);
};
const knownConsoleEntry = (entry) =>
  entry.text.includes("GPU stall due to ReadPixels") ||
  entry.text.includes("CONTEXT_LOST_WEBGL") ||
  entry.text.includes("glBlitFramebuffer") ||
  entry.text.includes("WEBGL_polygon_mode") ||
  entry.text === "window.styleMedia is a deprecated draft version of window.matchMedia API, and it will be removed in the future.";

const common = {
  name: "Ink Test Weapon",
  weapon_class: "melee",
  weapon_form: "generic",
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

function serverSpecFor(roleCase) {
  const role = roleCase.role_id;
  if (["short_melee", "standard_melee", "long_melee"].includes(role)) {
    return { ...common, name: "Ink Sketchsword", weapon_form: "sword" };
  }
  if (role === "straight_ranged") {
    return {
      ...common,
      name: "Ink Longbow",
      weapon_class: "ranged",
      weapon_form: "bow",
      delivery: "projectile",
      attack_pattern: "straight_projectile",
      damage: 26,
      attack_speed: 1.3,
      range: 675,
      special_ability: "none",
      status_effect: "none",
      drawback: "low_impact",
      power_score: 49,
      projectile_speed: 620,
    };
  }
  if (role === "thrown_blast") {
    return {
      ...common,
      name: "Ink Arc Grenade",
      weapon_class: "ranged",
      weapon_form: "grenade",
      delivery: "thrown",
      trajectory: "arc",
      impact: "delayed_or_contact",
      area_effect: "explosion",
      attack_pattern: "area_blast",
      damage: 34,
      attack_speed: 0.7,
      range: 220,
      special_ability: "splash_wave",
      status_effect: "none",
      drawback: "cooldown_lock",
      power_score: 69,
      area_radius: 165,
    };
  }
  if (role === "boomerang") {
    return {
      ...common,
      name: "Ink Returning Crescent",
      weapon_class: "ranged",
      weapon_form: "boomerang",
      delivery: "thrown",
      trajectory: "returning",
      attack_pattern: "boomerang",
      damage: 30,
      attack_speed: 0.95,
      range: 620,
      special_ability: "return_strike",
      status_effect: "none",
      drawback: "self_stagger",
      power_score: 66,
      projectile_speed: 520,
      return_speed: 760,
    };
  }
  if (role === "piercing") {
    return {
      ...common,
      name: "Ink Shieldsplitter Spear",
      weapon_class: "ranged",
      weapon_form: "spear",
      delivery: "projectile",
      impact: "piercing",
      attack_pattern: "piercing",
      damage: 29,
      attack_speed: 1.05,
      range: 700,
      special_ability: "shield_break",
      status_effect: "none",
      drawback: "narrow_arc",
      power_score: 84,
      projectile_speed: 720,
      pierce_count: 3,
    };
  }
  if (role === "direct_blast") {
    return {
      ...common,
      name: "Ink Proximity Burst",
      area_effect: "explosion",
      attack_pattern: "area_blast",
      damage: 34,
      attack_speed: 0.7,
      range: 220,
      special_ability: "splash_wave",
      status_effect: "none",
      drawback: "cooldown_lock",
      power_score: 55,
      area_radius: 165,
    };
  }
  throw new Error(`No provider-free spec fixture for ${role}`);
}

function responseFor(requestId, spec) {
  return {
    success: true,
    provider_invoked: true,
    request_id: requestId,
    weapon_spec: spec,
    interpretation_summary: PROVIDER_FREE_TEXT_MARKER,
    confidence: 0.95,
    corrections: [],
    fallback_reason: "",
    provider_metadata: { provider: PROVIDER, model: MODEL, attempts: 1 },
    latency: { total_ms: 40, provider_ms: 35, attempts: 1 },
    latency_ms: 40,
    estimated_cost: { amount: 0.0002, currency: "USD" },
    power_budget: { total: spec.power_score },
    schema_valid: true,
    allow_list_valid: true,
    power_valid: true,
    runtime_valid: true,
  };
}

async function state(page) {
  return page.evaluate(() => window.__forgeM1B1Test?.state?.() || {});
}

async function controls(page) {
  return page.evaluate(() => window.__forgeM1B1Test?.controls?.() || {});
}

async function waitForState(page, check, argument, label, timeout = 30000) {
  const handle = await page.waitForFunction(
    ({ predicate, payload }) => {
      const current = window.__forgeM1B1Test?.state?.() || {};
      if (predicate === "screen") return current.screen === payload.screen && current.phase === payload.phase ? current : false;
      if (predicate === "description") return current.description === payload ? current : false;
      if (predicate === "drawing") return current.drawing_count === payload ? current : false;
      if (predicate === "developer") return current.developer_mode === payload && current.phase === "idle" ? current : false;
      if (predicate === "selected_pattern") return current.selected_pattern === payload ? current : false;
      if (predicate === "modify_ready") return current.screen === "confirmation" && current.phase === "modify" && current.modify_mode && current.selector_visible ? current : false;
      if (predicate === "manual_correction") return current.screen === "confirmation" && current.phase === "modify" && current.modify_mode && current.selected_pattern === payload && current.result?.runtime_valid === true && (current.result?.corrections || []).some((value) => value.includes("manual correction")) ? current : false;
      if (predicate === "scenario") {
        const visible = (current.targets || []).filter((target) => target.visible);
        return current.target_scenario === payload.kind && visible.length === payload.count && visible.every((target) => target.kind === payload.kind) && (current.damage_events || []).length === 0 && (current.attack_events || []).length === 0 ? current : false;
      }
      if (predicate === "movement_lock") {
        return current.held_visual?.movement_locked === payload && current.held_visual?.movement_lock_reason === (payload ? "piercing_startup" : "none") ? current : false;
      }
      if (predicate === "movement_progress") {
        return current.player_position?.x >= payload.start_x + payload.minimum_delta && current.held_visual?.movement_locked === false ? current : false;
      }
      if (predicate === "attack_open") return current.attack_count > payload ? current : false;
      if (predicate === "settled") return current.attack_count > payload && (current.held_visual?.cooldown ?? 1) <= 0.01 && current.active_projectiles === 0 && current.active_area_blasts === 0 && current.held_visual?.visible ? current : false;
      return false;
    },
    { predicate: check, payload: argument },
    { polling: "raf", timeout },
  );
  const result = await handle.jsonValue();
  await handle.dispose();
  assert(result && typeof result === "object", `Timed out waiting for ${label}`);
  return result;
}

async function waitForMobile(page, check, argument, label, timeout = 30000) {
  const handle = await page.waitForFunction(
    ({ predicate, payload }) => {
      const current = window.__forgeM1B1Test?.mobileInput?.() || {};
      if (predicate === "focused") return current.metrics?.inputFocused && current.metrics?.textEntryActive && current.doneVisible ? current : false;
      if (predicate === "keyboard_open") return current.metrics?.keyboardOpen && current.doneVisible && current.rootVisible ? current : false;
      if (predicate === "closed") return !current.metrics?.textEntryActive && !current.metrics?.keyboardOpen && !current.doneVisible ? current : false;
      if (predicate === "canvas_height") return Math.abs((current.metrics?.canvasRect?.height ?? -1000) - payload) <= 2 ? current : false;
      return false;
    },
    { predicate: check, payload: argument },
    { polling: "raf", timeout },
  );
  const result = await handle.jsonValue();
  await handle.dispose();
  assert(result && typeof result === "object", `Timed out waiting for ${label}`);
  return result;
}

async function tap(page, rect, label) {
  assert(rect?.width > 0 && rect?.height > 0, `${label} has no touch target`);
  await page.touchscreen.tap(rect.x + rect.width / 2, rect.y + rect.height / 2);
}

async function drawFixture(page, roleCase) {
  const canvas = (await controls(page)).canvas;
  assert(canvas?.width > 0 && canvas?.height > 0, `${roleCase.id}: drawing canvas unavailable`);
  const geometry = roleCase.geometry || { normalized_span: 0.42, cross_axis_load: 0.14 };
  const start = 0.03;
  const end = start + geometry.normalized_span;
  const half = geometry.cross_axis_load * 0.5;
  const center = 0.52;
  const points = [
    { x: canvas.x + canvas.width * start, y: canvas.y + canvas.height * (center - half) },
    { x: canvas.x + canvas.width * (end - 0.012), y: canvas.y + canvas.height * (center - half) },
    { x: canvas.x + canvas.width * end, y: canvas.y + canvas.height * center },
    { x: canvas.x + canvas.width * (end - 0.012), y: canvas.y + canvas.height * (center + half) },
    { x: canvas.x + canvas.width * start, y: canvas.y + canvas.height * (center + half) },
  ];
  await page.mouse.move(points[0].x, points[0].y);
  await page.mouse.down();
  await page.waitForTimeout(20);
  for (const point of points.slice(1)) {
    await page.mouse.move(point.x, point.y, { steps: 8 });
    // WebKit may coalesce an entire synthetic drag when every move is issued in
    // one JavaScript turn. One rendered frame per segment keeps the fixture
    // equivalent to a real finger stroke without changing runtime input code.
    await page.waitForTimeout(20);
  }
  await page.mouse.up();
  await waitForState(page, "drawing", 1, `${roleCase.id} drawing`);
}

function assertFiniteRole(roleCase, role, spec) {
  assert(role.role_id === roleCase.role_id, `${roleCase.id}: expected role ${roleCase.role_id}, got ${role.role_id}`);
  const expectedStatus = roleCase.role_id === "direct_blast" ? "compatibility_existing_path" : "authorized_b1_5_role";
  assert(role.authority === "WeaponRoleProfile" && role.role_family_status === expectedStatus, `${roleCase.id}: wrong internal role authority/status`);
  assert(Array.isArray(role.advantages) && role.advantages.length > 0, `${roleCase.id}: no derived advantage`);
  assert(Array.isArray(role.deterministic_costs) && role.deterministic_costs.length > 0, `${roleCase.id}: no derived deterministic cost`);
  assert(Array.isArray(role.audit_reasons) && role.audit_reasons.some((reason) => reason.includes(role.role_id)), `${roleCase.id}: role derivation is not audited`);
  for (const field of ["cycle_seconds", "startup_seconds", "active_seconds", "commit_delay_seconds", "recovery_seconds", "effective_reach", "projectile_travel_seconds", "nominal_projectile_travel_seconds", "projectile_hit_radius", "blast_damage_delay_seconds", "single_target_dps", "return_window_dps", "power_score"]) {
    assert(Number.isFinite(role[field]), `${roleCase.id}: ${field} is not finite`);
  }
  assert(role.cycle_seconds > 0 && role.commit_delay_seconds > 0 && role.commit_delay_seconds <= role.cycle_seconds, `${roleCase.id}: invalid role timing`);
  assert(Math.abs(role.startup_seconds + role.active_seconds + role.recovery_seconds - role.cycle_seconds) <= 0.002, `${roleCase.id}: role phases do not sum to cycle`);
  assert(role.power_score === spec.power_score && role.power_score <= 100 && role.power_components.total <= 100, `${roleCase.id}: role audit disagrees with PowerBudget`);
  assert(!("role_id" in spec) && !("role_profile" in spec) && !("weapon_role" in spec), `${roleCase.id}: internal role leaked into public WeaponSpec`);
  if (role.role_id === "piercing") {
    assert(JSON.stringify(role.piercing_damage_multipliers) === JSON.stringify([1, 0.7, 0.45]), `${roleCase.id}: piercing damage schedule is not fixed at 100/70/45 percent`);
    assert(role.movement_lock_policy === "horizontal_during_startup" && role.movement_locked_during_startup === true, `${roleCase.id}: piercing startup movement commitment is missing`);
  }
}

function scenarioConfiguration(role, spec, kind) {
  let gap = 260;
  if (role.role_id.endsWith("melee")) gap = Math.max(45, Math.min(role.effective_reach * 0.72, role.effective_reach - 8));
  // The grenade's player-ink held visual places its projectile origin about
  // 60 px ahead of the grip. Keep the target beyond the combined projectile
  // and body radii so the test observes the arc, while the 165 px blast still
  // covers the configured group after landing.
  if (role.role_id === "thrown_blast") gap = 220;
  if (role.role_id === "direct_blast") gap = 80;
  if (kind === "moving") {
    if (role.role_id.endsWith("melee")) gap = Math.max(45, role.effective_reach - 2);
    else if (["straight_ranged", "piercing"].includes(role.role_id)) gap = Math.max(80, role.effective_reach * 0.93);
    else if (role.role_id === "thrown_blast") gap = 300;
    else if (role.role_id === "direct_blast") gap = Math.max(45, spec.area_radius - 5);
    else if (role.role_id === "boomerang") gap = Math.max(80, role.effective_reach * 0.5);
  }
  return { kind, gap, spacing: kind === "group" ? 40 : 54 };
}

function summarizeScenario(roleCase, scenario, before, opened, current, elapsedToCommitMs, elapsedToSettleMs, movementObservation = null) {
  const visibleTargets = current.targets.filter((target) => target.visible);
  const damageEvents = current.damage_events || [];
  const distinctTargets = new Set(damageEvents.map((event) => event.target));
  const perTarget = {};
  for (const event of damageEvents) perTarget[event.target] = (perTarget[event.target] || 0) + 1;
  return {
    scenario,
    elapsed_to_commit_ms: elapsedToCommitMs,
    elapsed_to_settle_ms: elapsedToSettleMs,
    targets_before: before.targets.filter((target) => target.visible),
    targets_at_commit: opened.targets.filter((target) => target.visible),
    visible_targets: visibleTargets,
    damage_events: damageEvents,
    distinct_targets_hit: distinctTargets.size,
    per_target_hit_counts: perTarget,
    total_damage: damageEvents.reduce((sum, event) => sum + event.amount, 0),
    attack_count: current.attack_count,
    projectile_spawn_count: current.projectile_spawn_count,
    projectile_finish_count: current.projectile_finish_count,
    projectile_spawn_delta: current.projectile_spawn_count - before.projectile_spawn_count,
    projectile_finish_delta: current.projectile_finish_count - before.projectile_finish_count,
    impact_spawn_delta: current.impact_spawn_count - before.impact_spawn_count,
    peak_active_projectiles: current.peak_active_projectiles,
    attack_events: current.attack_events,
    combat_message: current.combat_message,
    impact_spawn_count: current.impact_spawn_count,
    last_finished_projectile: current.last_finished_projectile,
    visual_bundle: current.visual_bundle,
    held_visual: current.held_visual,
    movement_observation: movementObservation,
  };
}

async function attackWithMovementObservation(page, roleCase, isolated, attackBefore) {
  const attackRect = (await controls(page)).attack;
  if (!["straight_ranged", "piercing"].includes(roleCase.role_id)) {
    await tap(page, attackRect, `${roleCase.id}/stationary ATTACK`);
    return {
      opened: await waitForState(page, "attack_open", attackBefore, `${roleCase.id}/stationary commit`),
      commitCapturedAtMs: Date.now(),
      observation: null,
    };
  }

  const startX = isolated.player_position.x;
  const right = (await controls(page)).right;
  assert(right?.width > 0 && right?.height > 0, `${roleCase.id}: right movement control unavailable`);
  await tap(page, attackRect, `${roleCase.id}/stationary ATTACK`);
  await page.mouse.move(right.x + right.width / 2, right.y + right.height / 2);
  await page.mouse.down();
  let locked = null;
  try {
    if (roleCase.role_id === "piercing") {
      locked = await waitForState(page, "movement_lock", true, `${roleCase.id}/stationary startup movement lock`);
      assert(Math.abs(locked.player_position.x - startX) <= 2, `${roleCase.id}: player moved ${locked.player_position.x - startX}px during committed startup`);
    }
    const opened = await waitForState(page, "attack_open", attackBefore, `${roleCase.id}/stationary commit`);
    const commitCapturedAtMs = Date.now();
    let postCommit = opened;
    if (roleCase.role_id === "piercing") {
      postCommit = await waitForState(
        page,
        "movement_progress",
        { start_x: opened.player_position.x, minimum_delta: 2 },
        `${roleCase.id}/stationary movement restored after commit`,
      );
      assert(opened.held_visual?.movement_locked === false, `${roleCase.id}: movement lock survived projectile release`);
    } else {
      assert(opened.held_visual?.movement_locked === false && opened.held_visual?.last_attack_movement_locked_during_startup === false, `${roleCase.id}: Bow inherited Piercing movement commitment`);
      postCommit = await waitForState(
        page,
        "movement_progress",
        { start_x: opened.player_position.x, minimum_delta: 2 },
        `${roleCase.id}/stationary mobile movement remains available`,
      );
    }
    return {
      opened,
      commitCapturedAtMs,
      observation: {
        role_id: roleCase.role_id,
        start_x: startX,
        startup_observed_x: locked?.player_position?.x ?? opened.player_position.x,
        position_at_commit_x: opened.player_position.x,
        post_commit_x: postCommit.player_position.x,
        movement_locked_during_startup: locked?.held_visual?.movement_locked ?? false,
        movement_lock_reason: locked?.held_visual?.movement_lock_reason ?? "none",
        movement_locked_at_commit: opened.held_visual?.movement_locked ?? null,
        last_attack_movement_locked_during_startup: postCommit.held_visual?.last_attack_movement_locked_during_startup ?? false,
        restored_after_commit: postCommit.held_visual?.movement_locked === false,
      },
    };
  } finally {
    await page.mouse.up();
  }
}

function assertScenario(roleCase, role, spec, evidence) {
  const { scenario, damage_events: damageEvents, distinct_targets_hit: targetsHit, per_target_hit_counts: perTarget } = evidence;
  assert(evidence.visible_targets.every((target) => target.kind === scenario), `${roleCase.id}/${scenario}: target isolation failed`);
  assert(damageEvents.every((event) => event.target_kind === scenario && event.pattern === spec.attack_pattern), `${roleCase.id}/${scenario}: damage audit lost target kind or pattern`);
  for (const target of evidence.visible_targets) {
    const matching = damageEvents.filter((event) => event.target === target.label);
    const auditedDamage = matching.reduce((sum, event) => sum + event.amount, 0);
    const initial = evidence.targets_before.find((entry) => entry.label === target.label);
    assert(initial && initial.health - target.health === auditedDamage, `${roleCase.id}/${scenario}: target health delta disagrees with audited damage events`);
  }
  if (scenario === "stationary") assert(damageEvents.length >= 1, `${roleCase.id}: stationary target was not hit`);
  if (scenario === "moving") {
    assert(["low", "medium", "high"].includes(role.moving_target_risk), `${roleCase.id}: moving risk missing`);
    const before = evidence.targets_before[0];
    const committed = evidence.targets_at_commit[0];
    assert(before && committed && Math.abs(committed.position.x - before.position.x) > 1, `${roleCase.id}: moving target did not actually move before commit`);
    if (damageEvents.length === 0) {
      const lifecycleFinished = role.role_id.endsWith("melee")
        ? evidence.combat_message.toLowerCase().includes("missed")
        : evidence.projectile_finish_count > 0 || evidence.impact_spawn_count > 0;
      assert(lifecycleFinished && evidence.visible_targets[0].health === evidence.targets_before[0].health, `${roleCase.id}: no-hit result was not an observable reasonable miss`);
    }
  }
  if (scenario === "shield") assert(damageEvents.length >= 1, `${roleCase.id}: shield scenario completed without an observable hit`);
  if (scenario === "shield" && damageEvents.length > 0) {
    if (["thrown_blast", "direct_blast", "piercing"].includes(role.role_id)) assert(damageEvents.some((event) => event.amount === spec.damage), `${roleCase.id}: declared shield bypass did not execute`);
    if (["short_melee", "standard_melee", "long_melee", "straight_ranged"].includes(role.role_id)) assert(damageEvents.every((event) => event.amount === Math.max(1, Math.ceil(spec.damage * 0.2))), `${roleCase.id}: frontal shield reduction did not execute`);
    if (role.role_id === "boomerang") assert(damageEvents.some((event) => event.amount < spec.damage) && damageEvents.some((event) => event.amount === spec.damage), `${roleCase.id}: outbound block/return bypass did not execute`);
  }
  if (scenario === "group") {
    if (["short_melee", "standard_melee", "long_melee"].includes(role.role_id)) assert(targetsHit <= 1, `${roleCase.id}: single-body role hit ${targetsHit} grouped targets`);
    if (role.role_id === "straight_ranged") {
      assert(targetsHit === 1 && damageEvents.length === 1 && damageEvents[0].amount === spec.damage, `${roleCase.id}: Bow did not stop after exactly one grouped target`);
    }
    if (["thrown_blast", "direct_blast"].includes(role.role_id)) assert(targetsHit >= 2, `${roleCase.id}: blast did not produce group value`);
    if (role.role_id === "piercing") {
      const ordered = [...damageEvents].sort((left, right) => left.hit_index - right.hit_index);
      const projection = ordered.map(({ hit_index, damage_multiplier, base_damage, requested_damage, amount }) => ({ hit_index, damage_multiplier, base_damage, requested_damage, amount }));
      assert(targetsHit === 3 && spec.pierce_count === 3, `${roleCase.id}: piercing did not stop at its exact three-body bound`);
      assert(JSON.stringify(projection) === JSON.stringify([
        { hit_index: 1, damage_multiplier: 1, base_damage: 29, requested_damage: 29, amount: 29 },
        { hit_index: 2, damage_multiplier: 0.7, base_damage: 29, requested_damage: 20, amount: 20 },
        { hit_index: 3, damage_multiplier: 0.45, base_damage: 29, requested_damage: 13, amount: 13 },
      ]), `${roleCase.id}: serialized piercing damage audit drifted ${JSON.stringify(projection)}`);
      const projectileProjection = (evidence.last_finished_projectile?.hit_records || []).map(
        ({ hit_index, damage_multiplier, base_damage, requested_damage, amount }) => ({ hit_index, damage_multiplier, base_damage, requested_damage, amount }),
      );
      assert(JSON.stringify(projectileProjection) === JSON.stringify(projection), `${roleCase.id}: projectile and damage-event piercing audits disagree`);
    }
    if (role.role_id === "boomerang") {
      assert(Object.values(perTarget).every((count) => count <= role.per_target_hit_limit), `${roleCase.id}: boomerang exceeded its per-target hit limit`);
      assert(role.per_phase_per_target_limit === 1, `${roleCase.id}: boomerang phase limit is not one`);
    }
  }
  if (role.role_id === "piercing" && scenario === "shield" && damageEvents.length > 0) {
    const hit = damageEvents[0];
    assert(hit.hit_index === 1 && hit.damage_multiplier === 1 && hit.base_damage === 29 && hit.requested_damage === 29 && hit.amount === 29, `${roleCase.id}: shield bypass lost first-hit damage audit ${JSON.stringify(hit)}`);
  }
}

async function runMobileViewportRegression(page, report) {
  const input = page.locator("#forge-description-input");
  const done = page.locator("#forge-description-done");
  const initialState = await state(page);
  const baseline = await page.evaluate(() => window.__forgeM1B1Test.mobileInput());
  const countersBefore = {
    attack_count: initialState.attack_count,
    damage_event_count: (initialState.damage_events || []).length,
    projectile_spawn_count: initialState.projectile_spawn_count,
    projectile_finish_count: initialState.projectile_finish_count,
    impact_spawn_count: initialState.impact_spawn_count,
  };
  assert(baseline.metrics?.canvasBackingWidth > 0 && baseline.metrics?.canvasBackingHeight > 0, "mobile: Canvas backing store was not initialized");
  assert(baseline.inputRect?.width > 0 && baseline.inputRect?.height > 0, "mobile: Description has no native touch target");
  await page.touchscreen.tap(baseline.inputRect.x + baseline.inputRect.width / 2, baseline.inputRect.y + baseline.inputRect.height / 2);
  const focused = await waitForMobile(page, "focused", true, "mobile first-touch focus");
  await input.fill("keyboard editable text");
  await waitForState(page, "description", "keyboard editable text", "mobile Description sync");

  await page.evaluate(() => window.__forgeM1B1Test.setVisualViewport({
    width: 844,
    height: 190,
    offsetLeft: 0,
    offsetTop: 92,
    innerWidth: 844,
    innerHeight: 390,
    scale: 1,
  }));
  const opened = await waitForMobile(page, "keyboard_open", true, "mobile compact keyboard layout");
  const visible = {
    x: opened.metrics.offsetLeft + opened.metrics.safeLeft,
    y: opened.metrics.offsetTop + opened.metrics.safeTop,
    width: opened.metrics.width - opened.metrics.safeLeft - opened.metrics.safeRight,
    height: opened.metrics.height - opened.metrics.safeTop - opened.metrics.safeBottom,
  };
  const inside = (rect) => rect && rect.x >= visible.x - 1 && rect.y >= visible.y - 1 && rect.x + rect.width <= visible.x + visible.width + 1 && rect.y + rect.height <= visible.y + visible.height + 1;
  assert(inside(opened.inputRect) && inside(opened.clearRect) && inside(opened.doneRect), `mobile: Description/Clear/Done escaped Visual Viewport ${JSON.stringify(opened)}`);
  assert(opened.doneRect.width >= 44 && opened.doneRect.height >= 44, "mobile: Done touch target is below 44px");
  assert(opened.inputFontSize >= 16, `mobile: Description font can trigger iOS zoom (${opened.inputFontSize}px)`);
  assert(opened.metrics.canvasBackingWidth === baseline.metrics.canvasBackingWidth && opened.metrics.canvasBackingHeight === baseline.metrics.canvasBackingHeight, "mobile: keyboard resized WebGL backing store");
  assert(opened.metrics.canvasRect.width === baseline.metrics.canvasRect.width && opened.metrics.canvasRect.height === baseline.metrics.canvasRect.height, "mobile: keyboard rescaled logical game Canvas");
  assert(opened.metrics.pageScrollX === 0 && opened.metrics.pageScrollY === 0, "mobile: focus scrolled page away from Canvas");
  const keyboardOpenScreenshot = join(destination, `${browserName}-b1-5-keyboard-open.png`);
  await page.screenshot({ path: keyboardOpenScreenshot });

  await input.fill("keyboard editable tex");
  await waitForState(page, "description", "keyboard editable tex", "mobile edited Description sync");
  await done.click();
  await page.evaluate(() => window.__forgeM1B1Test.clearVisualViewport());
  const closed = await waitForMobile(page, "closed", true, "mobile keyboard close/recovery");
  assert(closed.metrics.canvasBackingWidth === baseline.metrics.canvasBackingWidth && closed.metrics.canvasBackingHeight === baseline.metrics.canvasBackingHeight, "mobile: keyboard close changed stable Canvas backing");
  assert(closed.inputValue === "keyboard editable tex" && (await state(page)).description === "keyboard editable tex", "mobile: keyboard close lost Description");
  const keyboardClosedScreenshot = join(destination, `${browserName}-b1-5-keyboard-closed.png`);
  await page.screenshot({ path: keyboardClosedScreenshot });

  await page.setViewportSize({ width: 844, height: 343 });
  const toolbar = await waitForMobile(page, "canvas_height", 343, "Safari toolbar Canvas relayout");
  assert(toolbar.inputValue === "keyboard editable tex", "mobile: Safari toolbar resize lost Description");
  await page.setViewportSize({ width: 844, height: 390 });
  await waitForMobile(page, "canvas_height", 390, "Safari toolbar Canvas restore");

  for (let cycle = 0; cycle < 3; cycle += 1) {
    await page.setViewportSize({ width: 390, height: 844 });
    await waitForState(page, "screen", { screen: "portrait", phase: "portrait" }, `portrait cycle ${cycle + 1}`);
    assert(!(await input.isVisible()), `mobile: native Description leaked over portrait cycle ${cycle + 1}`);
    await page.setViewportSize({ width: 844, height: 390 });
    const landscape = await waitForState(page, "screen", { screen: "forge", phase: "idle" }, `landscape cycle ${cycle + 1}`);
    assert(landscape.description === "keyboard editable tex", `mobile: rotation cycle ${cycle + 1} lost Description`);
  }
  const finalState = await state(page);
  const countersAfter = {
    attack_count: finalState.attack_count,
    damage_event_count: (finalState.damage_events || []).length,
    projectile_spawn_count: finalState.projectile_spawn_count,
    projectile_finish_count: finalState.projectile_finish_count,
    impact_spawn_count: finalState.impact_spawn_count,
  };
  assert(JSON.stringify(countersAfter) === JSON.stringify(countersBefore), `mobile: viewport-only regression mutated combat counters ${JSON.stringify({ countersBefore, countersAfter })}`);
  report.mobile_regression = {
    viewport: "844x390",
    keyboard_visual_viewport: { width: 844, height: 190, offset_top: 92 },
    first_touch_focused: focused.metrics.inputFocused,
    description_preserved: finalState.description,
    safari_toolbar_height: toolbar.metrics.canvasRect.height,
    orientation_cycles: 3,
    counters_before: countersBefore,
    counters_after: countersAfter,
    screenshots: [keyboardOpenScreenshot, keyboardClosedScreenshot],
  };
}

const browser = await browserType.launch({ headless: true });
const report = {
  suite: "Weapon Physics B1.5 deterministic role and target regression",
  browser: browserName,
  viewport: { width: 844, height: 390 },
  target: targetUrl,
  provider_claim: "SIMULATED RESPONSE - no paid provider invocation",
  provider_free_text_marker: PROVIDER_FREE_TEXT_MARKER,
  captured_at: new Date().toISOString(),
  cases: [],
  console_errors: [],
};
let mobileRegressionExecuted = false;
let activeContext = null;
let activePage = null;
let activeCaseId = "startup";

try {
  const browserCases = [...matrix.role_cases, ...(matrix.compatibility_cases || [])];
  for (const roleCase of browserCases.filter((entry) => !roleFilter || entry.role_id === roleFilter || entry.id === roleFilter)) {
    activeCaseId = roleCase.id;
    const specFixture = serverSpecFor(roleCase);
    const context = await browser.newContext({
      ...playwright.devices["iPhone 15"],
      viewport: { width: 844, height: 390 },
      screen: { width: 844, height: 390 },
    });
    activeContext = context;
    await context.tracing.start({ screenshots: true, snapshots: true, sources: true });
    const page = await context.newPage();
    activePage = page;
    const consoleEntries = [];
    let interceptedRequests = 0;
    page.on("console", (message) => consoleEntries.push({ type: message.type(), text: message.text() }));
    page.on("pageerror", (error) => consoleEntries.push({ type: "error", text: error.message }));
    await page.route("**/api/compile-weapon", async (route) => {
      interceptedRequests += 1;
      const body = route.request().postDataJSON();
      await route.fulfill({ status: 200, contentType: "application/json", body: JSON.stringify(responseFor(body.request_id, specFixture)) });
    });

    const url = new URL(targetUrl);
    url.searchParams.set("qa", "m1b1");
    await page.goto(url.href, { waitUntil: "domcontentloaded", timeout: 30000 });
    await waitForState(page, "screen", { screen: "forge", phase: "idle" }, `${roleCase.id} forge`);
    if (!mobileRegressionExecuted) {
      await runMobileViewportRegression(page, report);
      mobileRegressionExecuted = true;
    }
    if (roleCase.role_id === "straight_ranged") {
      await page.evaluate(() => window.__forgeM1B1Test.setDeveloperMode(true));
      await waitForState(page, "developer", true, `${roleCase.id} Developer/Test mode`);
      const developerControls = await controls(page);
      assert(developerControls.pattern_buttons?.length === 5, `${roleCase.id}: Developer/Test path lost one of the five attack modes`);
      await tap(page, developerControls.pattern_buttons[1], `${roleCase.id} PROJECTILE role selector`);
      await waitForState(page, "selected_pattern", "straight_projectile", `${roleCase.id} selected pattern`);
      await page.evaluate(() => window.__forgeM1B1Test.setDeveloperMode(false));
      await waitForState(page, "developer", false, `${roleCase.id} normal-player presentation restored`);
    }
    const description = roleCase.description;
    await page.getByRole("textbox", { name: "Weapon description" }).fill(description);
    await waitForState(page, "description", description, `${roleCase.id} description sync`);
    await drawFixture(page, roleCase);
    await tap(page, (await controls(page)).forge, `${roleCase.id} FORGE`);
    const confirmation = await waitForState(page, "screen", { screen: "confirmation", phase: "result" }, `${roleCase.id} confirmation`);
    assert(interceptedRequests === 1, `${roleCase.id}: expected one intercepted provider-free request, got ${interceptedRequests}`);
    assertFiniteRole(roleCase, confirmation.role_profile, confirmation.spec);
    assert(JSON.stringify(confirmation.role_profile.audit_reasons) === JSON.stringify(confirmation.role_audit), `${roleCase.id}: top-level role audit diverges from profile`);
    assert(confirmation.result.provider_metadata.provider === PROVIDER && confirmation.result.provider_metadata.model === MODEL, `${roleCase.id}: provider fixture did not cross the normal validation path`);
    if (roleCase.player_hud_weakness) {
      assert(confirmation.confirmation_fields?.weakness === roleCase.player_hud_weakness, `${roleCase.id}: confirmation weakness did not use the project-owned role mapping`);
      assert(confirmation.hud_weakness === roleCase.player_hud_weakness, `${roleCase.id}: QA HUD weakness did not use the project-owned role mapping`);
      assert(confirmation.hud_weakness !== PROVIDER_FREE_TEXT_MARKER, `${roleCase.id}: provider free text reached the role HUD`);
    }
    const confirmationRole = JSON.stringify(confirmation.role_profile);

    let manualCorrectionPath = false;
    if (roleCase.role_id === "standard_melee") {
      await tap(page, (await controls(page)).modify, `${roleCase.id} MODIFY INTERPRETATION`);
      await waitForState(page, "modify_ready", true, `${roleCase.id} manual correction ready`);
      const modifyControls = await controls(page);
      assert(modifyControls.pattern_buttons?.length === 5, `${roleCase.id}: MODIFY did not expose five patterns`);
      await tap(page, modifyControls.pattern_buttons[0], `${roleCase.id} manual melee correction`);
      const corrected = await waitForState(page, "manual_correction", "melee_slash", `${roleCase.id} manual melee correction`);
      assert(corrected.role_profile.role_id === confirmation.role_profile.role_id, `${roleCase.id}: manual correction changed fixed role identity`);
      for (const field of ["cycle_seconds", "startup_seconds", "active_seconds", "commit_delay_seconds", "recovery_seconds", "effective_reach"]) {
        assert(Math.abs(corrected.role_profile[field] - confirmation.role_profile[field]) <= 0.002, `${roleCase.id}: manual correction drifted ${field}`);
      }
      manualCorrectionPath = true;
    }

    await tap(page, (await controls(page)).confirm, `${roleCase.id} CONFIRM`);
    const combat = await waitForState(page, "screen", { screen: "combat", phase: "combat" }, `${roleCase.id} combat`);
    assert(JSON.stringify(combat.role_profile) === confirmationRole, `${roleCase.id}: provider/confirmation/combat role derivation drifted`);
    if (roleCase.player_hud_weakness) {
      assert(combat.hud_weakness === roleCase.player_hud_weakness, `${roleCase.id}: normal-player combat HUD role weakness drifted`);
    }
    const scenarios = [];

    for (const scenario of matrix.scenario_order) {
      const configuration = scenarioConfiguration(combat.role_profile, confirmation.spec, scenario);
      await page.evaluate((payload) => window.__forgeGodotQaCallback?.("target_scenario", JSON.stringify(payload)), configuration);
      const isolated = await waitForState(page, "scenario", { kind: scenario, count: scenario === "group" ? 3 : 1 }, `${roleCase.id}/${scenario} isolation`);
      assert((isolated.held_visual?.cooldown ?? 1) <= 0.01, `${roleCase.id}/${scenario}: QA reset retained cooldown`);
      const attackBefore = isolated.attack_count;
      const started = Date.now();
      let opened;
      let commitCapturedAtMs = null;
      let movementObservation = null;
      if (scenario === "stationary" && ["straight_ranged", "piercing"].includes(roleCase.role_id)) {
        const attackResult = await attackWithMovementObservation(page, roleCase, isolated, attackBefore);
        opened = attackResult.opened;
        commitCapturedAtMs = attackResult.commitCapturedAtMs;
        movementObservation = attackResult.observation;
      } else {
        await tap(page, (await controls(page)).attack, `${roleCase.id}/${scenario} ATTACK`);
      }
      if (roleCase.role_id === "boomerang" && scenario === "stationary") {
        await tap(page, (await controls(page)).attack, `${roleCase.id}/${scenario} rapid ATTACK 2`);
        await tap(page, (await controls(page)).attack, `${roleCase.id}/${scenario} rapid ATTACK 3`);
      }
      if (!opened) opened = await waitForState(page, "attack_open", attackBefore, `${roleCase.id}/${scenario} commit`);
      const elapsedToCommitMs = (commitCapturedAtMs ?? Date.now()) - started;
      assert(opened.attack_events.some((event) => event.kind === "hit_window_open" && event.role_id === roleCase.role_id && Math.abs(event.commit_delay_seconds - combat.role_profile.commit_delay_seconds) <= 0.002), `${roleCase.id}/${scenario}: attack event role/commit audit missing`);
      if (!roleCase.role_id.endsWith("melee")) assert(elapsedToCommitMs + 100 >= combat.role_profile.commit_delay_seconds * 1000, `${roleCase.id}/${scenario}: projectile/blast spawned before derived commit`);
      if (scenario === "stationary" && !roleCase.role_id.endsWith("melee")) {
        await page.screenshot({ path: join(destination, `${roleCase.id}-stationary-active.png`) });
      }
      const settled = await waitForState(page, "settled", attackBefore, `${roleCase.id}/${scenario} complete cycle`, Math.max(30000, combat.role_profile.cycle_seconds * 1000 + 10000));
      const elapsedToSettleMs = Date.now() - started;
      assert(elapsedToSettleMs + 120 >= combat.role_profile.cycle_seconds * 1000, `${roleCase.id}/${scenario}: input cooldown ended before the derived cycle`);
      assert(settled.held_visual?.movement_locked === false, `${roleCase.id}/${scenario}: movement remained permanently locked after the complete cycle`);
      if (roleCase.role_id === "boomerang" && scenario === "stationary") {
        assert(settled.attack_count === attackBefore + 1 && settled.peak_active_projectiles <= 1, `${roleCase.id}: rapid taps created overlapping boomerangs`);
      }
      const evidence = summarizeScenario(roleCase, scenario, isolated, opened, settled, elapsedToCommitMs, elapsedToSettleMs, movementObservation);
      report.active_case = { id: roleCase.id, role_id: roleCase.role_id, scenarios: [...scenarios, evidence] };
      assertScenario(roleCase, combat.role_profile, confirmation.spec, evidence);
      scenarios.push(evidence);
      if (scenario === "group") await page.screenshot({ path: join(destination, `${roleCase.id}-group.png`) });
    }

    report.active_case = { id: roleCase.id, role_id: roleCase.role_id, scenarios };

    if (roleCase.role_id === "straight_ranged") {
      const stationary = scenarios.find((entry) => entry.scenario === "stationary");
      assert(stationary.held_visual.visible && stationary.visual_bundle?.projectile_kind === "arrow" && stationary.visual_bundle?.projectile_source === "procedural" && !stationary.visual_bundle?.hide_held_during_attack, `${roleCase.id}: bow did not retain held/procedural-arrow separation`);
    }
    if (roleCase.role_id === "thrown_blast") {
      const stationary = scenarios.find((entry) => entry.scenario === "stationary");
      const path = stationary.last_finished_projectile?.path_samples || [];
      assert(combat.role_profile.projectile_travel_model === "runtime_arc_path_samples" && combat.role_profile.projectile_travel_seconds === 0 && combat.role_profile.nominal_projectile_travel_seconds > 0, `${roleCase.id}: grenade profile misrepresented nominal travel as measured runtime travel`);
      assert(path.length >= 3 && stationary.last_finished_projectile?.impact_reason !== "none", `${roleCase.id}: grenade did not retain measured arc/detonation evidence`);
    }
    if (roleCase.role_id === "piercing") assert(combat.role_profile.projectile_hit_radius === 7, `${roleCase.id}: piercing collision path is not narrow`);
    if (roleCase.role_id === "direct_blast") {
      const group = scenarios.find((entry) => entry.scenario === "group");
      assert(combat.role_profile.projectile_travel_model === "none" && combat.role_profile.projectile_travel_seconds === 0, `${roleCase.id}: direct blast invented projectile travel`);
      assert(group.distinct_targets_hit >= 2 && scenarios.every((entry) => entry.projectile_spawn_count === 0 && entry.projectile_finish_count === 0), `${roleCase.id}: direct proximity blast created projectile lifecycle or lost group value`);
    }

    const serious = consoleEntries.filter((entry) => ["error", "warning"].includes(entry.type) && !knownConsoleEntry(entry));
    assert(serious.length === 0, `${roleCase.id}: application console errors ${JSON.stringify(serious)}`);
    report.console_errors.push(...serious);
    report.cases.push({
      id: roleCase.id,
      role_id: roleCase.role_id,
      provider_free_requests: interceptedRequests,
      developer_test_path: roleCase.role_id === "straight_ranged",
      manual_correction_path: manualCorrectionPath,
      spec: confirmation.spec,
      role_profile: confirmation.role_profile,
      role_audit: confirmation.role_audit,
      hud_weakness: combat.hud_weakness,
      movement_observations: scenarios.map((entry) => entry.movement_observation).filter(Boolean),
      piercing_hit_audit: roleCase.role_id === "piercing"
        ? scenarios.flatMap((entry) => entry.damage_events.map(
          ({ sequence, target, target_kind, hit_index, damage_multiplier, base_damage, requested_damage, amount }) =>
            ({ scenario: entry.scenario, sequence, target, target_kind, hit_index, damage_multiplier, base_damage, requested_damage, amount }),
        ))
        : [],
      scenarios,
      application_console_errors: serious.length,
    });
    delete report.active_case;
    await context.tracing.stop();
    await context.close();
    activeContext = null;
    activePage = null;
  }

  const byRole = Object.fromEntries(report.cases.map((entry) => [entry.role_id, entry]));
  if (!roleFilter) {
    assert(byRole.short_melee.role_profile.cycle_seconds < byRole.standard_melee.role_profile.cycle_seconds && byRole.standard_melee.role_profile.cycle_seconds < byRole.long_melee.role_profile.cycle_seconds, "melee role cycles are not short < standard < long");
    assert(byRole.short_melee.role_profile.effective_reach < byRole.standard_melee.role_profile.effective_reach && byRole.standard_melee.role_profile.effective_reach < byRole.long_melee.role_profile.effective_reach, "melee role reaches are not short < standard < long");
    assert(byRole.straight_ranged.role_profile.single_target_dps < byRole.short_melee.role_profile.single_target_dps, "straight ranged also received the highest sustained single-target value");
    assert(new Set(report.cases.map((entry) => entry.role_profile.single_target_dps)).size > 1, "role matrix incorrectly forced all roles to equal DPS");
    assert(byRole.piercing.role_profile.startup_seconds >= byRole.straight_ranged.role_profile.startup_seconds * 1.5, "Piercing startup is not significantly longer than Bow");
    assert(byRole.piercing.role_profile.cycle_seconds >= byRole.straight_ranged.role_profile.cycle_seconds * 1.2, "Piercing complete cycle is not significantly longer than Bow");
    report.bow_piercing_role_comparison = {
      bow: {
        startup_seconds: byRole.straight_ranged.role_profile.startup_seconds,
        cycle_seconds: byRole.straight_ranged.role_profile.cycle_seconds,
        damage: byRole.straight_ranged.spec.damage,
        movement_observations: byRole.straight_ranged.movement_observations,
        hud_weakness: byRole.straight_ranged.hud_weakness,
      },
      piercing: {
        startup_seconds: byRole.piercing.role_profile.startup_seconds,
        cycle_seconds: byRole.piercing.role_profile.cycle_seconds,
        damage: byRole.piercing.spec.damage,
        damage_multipliers: byRole.piercing.role_profile.piercing_damage_multipliers,
        movement_observations: byRole.piercing.movement_observations,
        hit_audit: byRole.piercing.piercing_hit_audit,
        hud_weakness: byRole.piercing.hud_weakness,
      },
      minimum_startup_ratio: 1.5,
      minimum_cycle_ratio: 1.2,
    };
  }
  assert(report.console_errors.length === 0, "application console errors were recorded");
  await writeFile(join(destination, "report.json"), JSON.stringify(report, null, 2));
  console.log(JSON.stringify(report, null, 2));
} catch (error) {
  report.failure = {
    case_id: activeCaseId,
    message: error instanceof Error ? error.message : String(error),
    stack: error instanceof Error ? error.stack : "",
  };
  if (activePage && !activePage.isClosed()) {
    await activePage.screenshot({ path: join(destination, `failure-${activeCaseId}.png`), fullPage: true }).catch(() => {});
  }
  if (activeContext) {
    await activeContext.tracing.stop({ path: join(destination, `failure-${activeCaseId}-trace.zip`) }).catch(() => {});
  }
  await writeFile(join(destination, "failure-report.json"), JSON.stringify(report, null, 2));
  throw error;
} finally {
  await browser.close();
}
