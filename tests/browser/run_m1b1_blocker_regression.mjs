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
};

function responseFor(requestId, kind) {
  return {
    success: true,
    provider_invoked: true,
    request_id: requestId,
    weapon_spec: specs[kind],
    interpretation_summary: kind === "grenade"
      ? "A thrown grenade follows a visible arc, then explodes at its landing point."
      : "A bow launches a direct straight projectile.",
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
  const description = kind === "grenade"
    ? "a thrown grenade that explodes after landing"
    : "a wooden bow firing arrows";
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
  for (const point of points.slice(1)) await page.mouse.move(point.x, point.y, { steps: 3 });
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
    if (["name", "power_score"].includes(field)) continue;
    assert(confirmation.spec[field] === expected, `${kind}: ${field} mismatch; got ${confirmation.spec[field]}, expected ${expected}`);
  }
  await page.screenshot({ path: join(destination, `${browserName}-${kind}-confirmation.png`) });

  await tap((await controls()).confirm);
  const combat = await waitFor((value) => value.screen === "combat", "combat");
  assert(combat.stroke_geometry.relative_aspect_error <= 0.02, `${kind}: combat aspect error exceeds 2%`);
  assert(combat.visual_transforms.held.absolute_delta <= 1e-6, `${kind}: held parent is non-uniform`);
  await page.screenshot({ path: join(destination, `${browserName}-${kind}-combat-held.png`) });
  const beforeAttack = combat.attack_count;
  await tap((await controls()).attack);
  const attacked = await waitFor((value) => value.attack_count > beforeAttack, "attack");
  assert(attacked.last_attack_pattern === specs[kind].attack_pattern, `${kind}: wrong attack module`);
  assert(attacked.visual_transforms.held.absolute_delta <= 1e-6, `${kind}: attack animation parent is non-uniform`);
  if (kind === "grenade") {
    const flight = await waitFor((value) => value.active_projectiles > 0, "grenade flight");
    assert(flight.active_area_blasts === 0, "grenade exploded before its visible flight");
    assert(flight.visual_transforms.projectiles.length > 0, "grenade: projectile visual evidence missing");
    assert(flight.visual_transforms.projectiles.every((item) => item.absolute_delta <= 1e-6), "grenade: projectile parent is non-uniform");
    assert(flight.combat_message.includes("visible arc"), `grenade: missing flight message ${flight.combat_message}`);
    await page.screenshot({ path: join(destination, `${browserName}-${kind}-arc-flight.png`) });
    const impact = await waitFor((value) => value.active_projectiles === 0 && value.active_area_blasts > 0, "grenade landing explosion", 5000);
    assert(impact.area_impact_distance > 24, `grenade: explosion did not move away from throw origin (${impact.area_impact_distance})`);
	await sleep(140);
	const visibleImpact = await state();
	assert(visibleImpact.active_area_blasts > 0, "grenade: landing explosion ended before visual evidence capture");
    await page.screenshot({ path: join(destination, `${browserName}-${kind}-landing-explosion.png`) });
  } else {
    const flight = await waitFor((value) => value.active_projectiles > 0, "bow projectile");
    assert(flight.visual_transforms.projectiles.length > 0, "bow: projectile visual evidence missing");
    assert(flight.visual_transforms.projectiles.every((item) => item.absolute_delta <= 1e-6), "bow: projectile parent is non-uniform");
    await page.screenshot({ path: join(destination, `${browserName}-${kind}-projectile.png`) });
    assert(flight.combat_message.includes("Straight projectile"), `bow: missing direct projectile message ${flight.combat_message}`);
  }

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
    },
  });
  await context.close();
}

try {
  await runCase("bow");
  await runCase("grenade");
  await writeFile(join(destination, `${browserName}-report.json`), `${JSON.stringify(evidence, null, 2)}\n`, "utf8");
  console.log(JSON.stringify(evidence, null, 2));
} finally {
  await browser.close();
}
