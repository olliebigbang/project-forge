import { createRequire } from "node:module";
import { mkdir, writeFile } from "node:fs/promises";
import { dirname, resolve } from "node:path";

const require = createRequire(import.meta.url);
const playwright = require(process.env.PLAYWRIGHT_MODULE_PATH || "playwright");
const AUTHORIZATION = "two-paid-blocker-calls";
const PROVIDER = "anthropic";
const MODEL = "claude-haiku-4-5-20251001";

if (process.env.M1B1_QA_ALLOW_LIVE_PROVIDER !== AUTHORIZATION) {
  throw new Error(`Live blocker evidence is disabled. Set M1B1_QA_ALLOW_LIVE_PROVIDER=${AUTHORIZATION} only after verifying Sites D1 and the USD 5 cap.`);
}

const [targetUrl = "", outputPath = "docs/evidence/m1b1-blockers/real-provider-grenade-bow.json"] = process.argv.slice(2);
if (!targetUrl.startsWith("https://")) throw new Error("A public HTTPS Sites URL is required.");
const parsedTarget = new URL(targetUrl);
if (parsedTarget.username || parsedTarget.password) throw new Error("Credentials are forbidden in the target URL.");
for (const key of parsedTarget.searchParams.keys()) {
  if (/(?:token|key|secret|auth|bypass|credential)/iu.test(key)) {
    throw new Error(`Sensitive query parameter '${key}' is forbidden in the target URL.`);
  }
}
const destination = resolve(outputPath);
await mkdir(dirname(destination), { recursive: true });

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

const sleep = (ms) => new Promise((resolvePromise) => setTimeout(resolvePromise, ms));
const browser = await playwright.chromium.launch({ headless: true });
const evidence = {
  suite: "M1B1 real Claude blocker evidence",
  generated_at: new Date().toISOString(),
  target: parsedTarget.href,
  provider: PROVIDER,
  model: MODEL,
  planned_provider_calls: 2,
  submitted_compile_requests: 0,
  blocked_duplicate_requests: 0,
  reported_provider_attempts: 0,
  reported_provider_attempts_status: "unknown_until_response",
  application_budget_usd: 5,
  d1_lifetime_budget_evidence: "Correlate request IDs with Sites Worker provider_budget=settled logs; static guard tests prove the USD 5 fail-closed cap.",
  cases: [],
};

async function runCase(kind) {
  const caseEvidence = {
    kind,
    status: "setup",
    submitted_compile_requests: 0,
    blocked_duplicate_requests: 0,
    reported_provider_attempts: "UNKNOWN",
  };
  evidence.cases.push(caseEvidence);
  const context = await browser.newContext({
    ...playwright.devices["iPhone 15"],
    viewport: { width: 844, height: 390 },
    screen: { width: 844, height: 390 },
  });
  const page = await context.newPage();
  const consoleEntries = [];
  page.on("console", (message) => consoleEntries.push({ type: message.type(), text: message.text() }));
  await page.route("**/api/compile-weapon", async (route) => {
    const request = route.request();
    const requestUrl = new URL(request.url());
    if (request.method() !== "POST" || requestUrl.pathname !== "/api/compile-weapon") {
      await route.continue();
      return;
    }
    if (caseEvidence.submitted_compile_requests >= 1 || evidence.submitted_compile_requests >= 2) {
      evidence.blocked_duplicate_requests += 1;
      caseEvidence.blocked_duplicate_requests += 1;
      await route.abort("blockedbyclient");
      return;
    }
    evidence.submitted_compile_requests += 1;
    caseEvidence.submitted_compile_requests += 1;
    try {
      const body = request.postDataJSON();
      caseEvidence.submitted_request_id = body?.request_id ?? "UNKNOWN";
    } catch {
      caseEvidence.submitted_request_id = "UNKNOWN";
    }
    await route.continue();
  });

  const url = new URL(parsedTarget.href);
  url.searchParams.set("qa", "m1b1");
  await page.goto(url.href, { waitUntil: "domcontentloaded", timeout: 45000 });
  const state = () => page.evaluate(() => window.__forgeM1B1Test?.state?.() || {});
  const controls = () => page.evaluate(() => window.__forgeM1B1Test?.controls?.() || {});
  const waitFor = async (predicate, label, timeout = 30000) => {
    const started = Date.now();
    let value = {};
    while (Date.now() - started < timeout) {
      value = await state();
      if (predicate(value)) return value;
      await sleep(60);
    }
    throw new Error(`${kind}: timeout waiting for ${label}: ${JSON.stringify(value)}`);
  };
  const tap = async (rect) => {
    assert(rect?.width > 0 && rect?.height > 0, `${kind}: control is hidden`);
    await page.touchscreen.tap(rect.x + rect.width / 2, rect.y + rect.height / 2);
  };

  await waitFor((value) => value.screen === "forge" && value.phase === "idle", "forge", 45000);
  const description = kind === "grenade"
    ? "a thrown grenade that flies in an arc and explodes after landing"
    : "a wooden longbow that fires a straight arrow projectile";
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

  const responsePromise = page.waitForResponse((response) => response.url().includes("/api/compile-weapon"), { timeout: 30000 });
  const requestStarted = performance.now();
  await tap((await controls()).forge);
  const response = await responsePromise;
  const observedMs = Math.round(performance.now() - requestStarted);
  const requestBody = response.request().postDataJSON();
  const responseBody = await response.json();
  const reportedAttempts = responseBody?.provider_metadata?.attempts;
  if (Number.isInteger(reportedAttempts) && reportedAttempts >= 0) {
    evidence.reported_provider_attempts += reportedAttempts;
    caseEvidence.reported_provider_attempts = reportedAttempts;
  }
  const confirmation = await waitFor(
    (value) => value.screen === "confirmation" && ["result", "error"].includes(value.phase),
    "provider terminal",
  );

  assert(response.status() === 200, `${kind}: HTTP ${response.status()}`);
  assert(caseEvidence.submitted_compile_requests === 1, `${kind}: expected exactly one compile POST; got ${caseEvidence.submitted_compile_requests}`);
  assert(caseEvidence.blocked_duplicate_requests === 0, `${kind}: duplicate compile POST was blocked`);
  assert(confirmation.phase === "result", `${kind}: explicit error ${confirmation.fallback_reason || confirmation.message}`);
  assert(requestBody.description === description, `${kind}: posted Description differs`);
  assert(confirmation.request_snapshot.description === description, `${kind}: frozen Description differs`);
  assert(requestBody.request_id === confirmation.request_snapshot.request_id, `${kind}: request ID differs`);
  assert(responseBody.request_id === requestBody.request_id, `${kind}: response request ID differs`);
  const drawingSummary = requestBody.drawing_summary;
  assert(drawingSummary && typeof drawingSummary === "object" && !Array.isArray(drawingSummary), `${kind}: drawing_summary missing`);
  for (const field of ["stroke_count", "point_count", "aspect_ratio", "coverage"]) {
    assert(Number.isFinite(drawingSummary[field]), `${kind}: drawing_summary.${field} is not numeric`);
  }
  assert(drawingSummary.stroke_count >= 1 && drawingSummary.point_count >= 2, `${kind}: drawing summary is empty`);
  assert(drawingSummary.aspect_ratio > 0 && drawingSummary.coverage > 0, `${kind}: drawing summary has no visible geometry`);
  assert(!Object.hasOwn(drawingSummary, "strokes"), `${kind}: raw strokes leaked to Worker`);
  assert(
    JSON.stringify(drawingSummary) === JSON.stringify(confirmation.request_snapshot.drawing_summary),
    `${kind}: posted and frozen drawing summaries differ`,
  );
  assert(responseBody.success === true && responseBody.provider_invoked === true, `${kind}: provider success flags missing`);
  assert(responseBody.provider_metadata?.provider === PROVIDER, `${kind}: provider mismatch`);
  assert(responseBody.provider_metadata?.model === MODEL, `${kind}: model mismatch`);
  assert(responseBody.provider_metadata?.attempts === 1, `${kind}: expected exactly one paid attempt`);
  assert(responseBody.latency_ms > 0 && observedMs > 0, `${kind}: latency missing`);
  assert(responseBody.confidence > 0, `${kind}: confidence missing`);
  assert(responseBody.schema_valid && responseBody.allow_list_valid && responseBody.power_valid && responseBody.runtime_valid, `${kind}: validation gate failed`);
  assert(responseBody.estimated_cost?.currency === "USD" && Number.isFinite(responseBody.estimated_cost?.amount), `${kind}: measured USD cost missing`);
  assert(responseBody.estimated_cost.amount >= 0 && responseBody.estimated_cost.amount < 5, `${kind}: cost is outside application budget`);

  const expected = kind === "grenade"
    ? { weapon_form: "grenade", delivery: "thrown", trajectory: "arc", impact: "delayed_or_contact", area_effect: "explosion", attack_pattern: "area_blast", weapon_class: "ranged" }
    : { weapon_form: "bow", delivery: "projectile", trajectory: "direct", impact: "contact", area_effect: "none", attack_pattern: "straight_projectile", weapon_class: "ranged" };
  for (const [field, value] of Object.entries(expected)) {
    assert(responseBody.weapon_spec?.[field] === value, `${kind}: ${field}=${responseBody.weapon_spec?.[field]}, expected ${value}`);
  }

  caseEvidence.status = "provider_confirmed";
  caseEvidence.description = description;
  caseEvidence.request = {
    request_id: requestBody.request_id,
    description: requestBody.description,
    drawing_summary: drawingSummary,
  };
  caseEvidence.response = {
    http_status: response.status(),
    success: responseBody.success,
    provider_invoked: responseBody.provider_invoked,
    provider_metadata: responseBody.provider_metadata,
    confidence: responseBody.confidence,
    latency_ms: responseBody.latency_ms,
    observed_ms: observedMs,
    estimated_cost: responseBody.estimated_cost,
    schema_valid: responseBody.schema_valid,
    allow_list_valid: responseBody.allow_list_valid,
    power_valid: responseBody.power_valid,
    runtime_valid: responseBody.runtime_valid,
    corrections: responseBody.corrections,
    weapon_spec: responseBody.weapon_spec,
    power_budget: responseBody.power_budget,
  };

  const screenshotRoot = dirname(destination);
  await page.screenshot({ path: resolve(screenshotRoot, `real-${kind}-confirmation.png`) });
  await tap((await controls()).confirm);
  let combat = await waitFor((value) => value.screen === "combat", "combat");
  const attackCount = combat.attack_count;
  await tap((await controls()).attack);
  const attacked = await waitFor((value) => value.attack_count > attackCount, "attack");
  assert(attacked.last_attack_pattern === expected.attack_pattern, `${kind}: runtime attack mismatch`);
  let flightEvidence = null;
  let impactEvidence = null;
  if (kind === "grenade") {
    const flight = await waitFor((value) => value.active_projectiles > 0 && value.active_area_blasts === 0, "visible thrown flight");
    assert(flight.visual_transforms.projectiles.length > 0, "grenade: projectile visual evidence missing");
    assert(flight.visual_transforms.projectiles.every((item) => item.absolute_delta <= 1e-6), "grenade: non-uniform projectile transform");
    flightEvidence = {
      active_projectiles: flight.active_projectiles,
      active_area_blasts: flight.active_area_blasts,
      projectile_origin: flight.projectile_origin,
      combat_message: flight.combat_message,
      visual_transforms: flight.visual_transforms.projectiles,
    };
    await page.screenshot({ path: resolve(screenshotRoot, "real-grenade-arc-flight.png") });
    const impact = await waitFor((value) => value.active_projectiles === 0 && value.active_area_blasts > 0, "landing explosion", 5000);
    assert(impact.area_impact_distance > 24, `grenade: landing effect did not move (${impact.area_impact_distance})`);
    impactEvidence = {
      active_projectiles: impact.active_projectiles,
      active_area_blasts: impact.active_area_blasts,
      projectile_origin: impact.projectile_origin,
      area_impact_position: impact.area_impact_position,
      area_impact_distance: impact.area_impact_distance,
      combat_message: impact.combat_message,
    };
    await page.screenshot({ path: resolve(screenshotRoot, "real-grenade-landing-explosion.png") });
  } else {
    const flight = await waitFor((value) => value.active_projectiles > 0, "bow projectile");
    assert(flight.visual_transforms.projectiles.length > 0, "bow: projectile visual evidence missing");
    assert(flight.visual_transforms.projectiles.every((item) => item.absolute_delta <= 1e-6), "bow: non-uniform projectile transform");
    flightEvidence = {
      active_projectiles: flight.active_projectiles,
      active_area_blasts: flight.active_area_blasts,
      projectile_origin: flight.projectile_origin,
      combat_message: flight.combat_message,
      visual_transforms: flight.visual_transforms.projectiles,
    };
    await page.screenshot({ path: resolve(screenshotRoot, "real-bow-projectile.png") });
  }

  const known = (entry) =>
    entry.text.includes("GPU stall due to ReadPixels") ||
    entry.text.includes("CONTEXT_LOST_WEBGL") ||
    entry.text.includes("glBlitFramebuffer") ||
    entry.text.includes("WEBGL_polygon_mode");
  const serious = consoleEntries.filter((entry) => ["error", "warning"].includes(entry.type) && !known(entry));
  assert(serious.length === 0, `${kind}: console errors ${JSON.stringify(serious)}`);

  caseEvidence.client = {
    request_snapshot: confirmation.request_snapshot,
    stroke_geometry: confirmation.stroke_geometry,
    confirmation_visual_transforms: confirmation.visual_transforms,
    held_visual_transform: combat.visual_transforms.held,
    attack_visual_transform: attacked.visual_transforms.held,
    attack_pattern_executed: attacked.last_attack_pattern,
    flight: flightEvidence,
    impact: impactEvidence,
  };
  caseEvidence.application_console_errors = 0;
  caseEvidence.status = "passed";
  await context.close();
}

try {
  await runCase("grenade");
  await runCase("bow");
  assert(evidence.submitted_compile_requests === 2, `Expected two compile POSTs; observed ${evidence.submitted_compile_requests}`);
  assert(evidence.blocked_duplicate_requests === 0, `Blocked ${evidence.blocked_duplicate_requests} duplicate compile POST(s)`);
  assert(evidence.reported_provider_attempts === 2, `Expected two reported provider attempts; observed ${evidence.reported_provider_attempts}`);
  evidence.measured_cost_usd = evidence.cases.reduce((sum, item) => sum + item.response.estimated_cost.amount, 0);
  assert(evidence.measured_cost_usd < evidence.application_budget_usd, `Two-call total ${evidence.measured_cost_usd} reached or exceeded USD ${evidence.application_budget_usd}`);
  evidence.reported_provider_attempts_status = "confirmed_from_two_server_responses";
  evidence.passed = true;
} catch (error) {
  evidence.passed = false;
  evidence.failure = String(error?.message || error).slice(0, 500);
  throw error;
} finally {
  await writeFile(destination, `${JSON.stringify(evidence, null, 2)}\n`, "utf8");
  await browser.close();
}

console.log(JSON.stringify({
  passed: evidence.passed,
  submitted_compile_requests: evidence.submitted_compile_requests,
  blocked_duplicate_requests: evidence.blocked_duplicate_requests,
  reported_provider_attempts: evidence.reported_provider_attempts,
  measured_cost_usd: evidence.measured_cost_usd,
  cases: evidence.cases.filter((item) => item.response).map((item) => ({
    kind: item.kind,
    request_id: item.request.request_id,
    provider: item.response.provider_metadata.provider,
    model: item.response.provider_metadata.model,
    latency_ms: item.response.latency_ms,
    estimated_cost: item.response.estimated_cost,
    semantics: {
      weapon_form: item.response.weapon_spec.weapon_form,
      delivery: item.response.weapon_spec.delivery,
      trajectory: item.response.weapon_spec.trajectory,
      impact: item.response.weapon_spec.impact,
      area_effect: item.response.weapon_spec.area_effect,
      attack_pattern: item.response.weapon_spec.attack_pattern,
    },
  })),
}, null, 2));
