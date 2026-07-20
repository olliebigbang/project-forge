import assert from "node:assert/strict";
import { randomBytes } from "node:crypto";
import { mkdir, readFile, writeFile } from "node:fs/promises";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import {
  ALLOW_LISTS,
  MAX_POWER,
  isSafeWeaponSpec,
  runtimeAllowListErrors,
  schemaValidationErrors,
} from "../hosting/weapon_contract.mjs";

const AUTHORIZATION = "anthropic-haiku45-5usd-guarded";
const EXPECTED_PROVIDER = "anthropic";
const EXPECTED_MODEL = "claude-haiku-4-5-20251001";
const scriptDirectory = dirname(fileURLToPath(import.meta.url));
const repositoryRoot = resolve(scriptDirectory, "..");

if (process.env.M1B1_ALLOW_PAID_MATRIX !== AUTHORIZATION) {
  throw new Error(
    `Paid matrix is disabled. Set M1B1_ALLOW_PAID_MATRIX=${AUTHORIZATION} only after ` +
    "the D1 budget guard, provider account cap and deployment revision are verified.",
  );
}
const baseUrl = String(process.env.M1B1_BASE_URL ?? "").trim();
if (!baseUrl.startsWith("https://")) throw new Error("M1B1_BASE_URL must be an HTTPS preview URL.");
const origin = new URL(baseUrl).origin;
const endpoint = new URL("/api/compile-weapon", origin);
const outputPath = resolve(
  repositoryRoot,
  process.env.M1B1_MATRIX_OUTPUT ?? "artifacts/M1B1_REAL_PROVIDER_MATRIX.json",
);
const matrix = JSON.parse(await readFile(resolve(repositoryRoot, "tests/m1b1_input_matrix.json"), "utf8"))
  .filter((entry) => entry.category !== "transport");
assert.ok(matrix.length >= 40, `Live matrix requires at least 40 cases; found ${matrix.length}.`);

function descriptionFor(entry) {
  if (entry.description_repeat) return String(entry.description_repeat).repeat(Number(entry.repeat_count));
  return String(entry.description ?? "");
}

function requestPayload(entry) {
  return {
    description: descriptionFor(entry),
    drawing_summary: {
      stroke_count: 3,
      point_count: 24,
      aspect_ratio: 1.8,
      coverage: 0.28,
      dominant_direction: "horizontal",
    },
    locale: entry.locale ?? "en",
    request_id: `live-${entry.id.toLowerCase()}-${randomBytes(12).toString("hex")}`,
    supported_attack_patterns: [...ALLOW_LISTS.attack_pattern],
    supported_elements: [...ALLOW_LISTS.element],
    supported_abilities: [...ALLOW_LISTS.special_ability],
    maximum_power_score: MAX_POWER,
  };
}

function percentile(values, fraction) {
  if (values.length === 0) return null;
  const sorted = [...values].sort((a, b) => a - b);
  return sorted[Math.max(0, Math.ceil(sorted.length * fraction) - 1)];
}

function median(values) {
  if (values.length === 0) return null;
  const sorted = [...values].sort((a, b) => a - b);
  const middle = Math.floor(sorted.length / 2);
  return sorted.length % 2 === 0
    ? (sorted[middle - 1] + sorted[middle]) / 2
    : sorted[middle];
}

const rows = [];
for (const entry of matrix) {
  const payload = requestPayload(entry);
  const startedAt = performance.now();
  let status = 0;
  let result = null;
  let transportError = "";
  try {
    const response = await fetch(endpoint, {
      method: "POST",
      headers: {
        "content-type": "application/json",
        origin,
        "x-forge-session": randomBytes(16).toString("hex"),
      },
      body: JSON.stringify(payload),
    });
    status = response.status;
    result = await response.json();
  } catch (error) {
    transportError = String(error?.message ?? error).slice(0, 160);
  }
  const observedMs = Math.round(performance.now() - startedAt);
  const schemaErrors = schemaValidationErrors(result?.weapon_spec);
  const allowListErrors = runtimeAllowListErrors(result?.weapon_spec);
  const runtimeValid = Boolean(result?.weapon_spec && isSafeWeaponSpec(result.weapon_spec, MAX_POWER));
  const provider = result?.provider_metadata?.provider ?? "none";
  const model = result?.provider_metadata?.model ?? "none";
  const providerInvoked = provider === EXPECTED_PROVIDER;
  const cost = result?.estimated_cost && typeof result.estimated_cost === "object"
    ? Number(result.estimated_cost.amount)
    : null;
  const expectedFallback = entry.expected_fallback_reason ?? "";
  const fallbackMatches = expectedFallback
    ? result?.fallback_reason === expectedFallback
    : result?.fallback_reason === "";
  const patternCorrect = !entry.accuracy_eligible ||
    result?.weapon_spec?.attack_pattern === entry.expected_pattern;
  const elementCorrect = !entry.accuracy_eligible ||
    result?.weapon_spec?.element === entry.expected_element;
  const costValid = !providerInvoked || (
    Number.isFinite(cost) && cost >= 0 && cost <= 5 && result.estimated_cost.currency === "USD"
  );
  const providerValid = !providerInvoked || model === EXPECTED_MODEL;
  const passed = status === 200 && !transportError && schemaErrors.length === 0 &&
    allowListErrors.length === 0 && runtimeValid && fallbackMatches && costValid && providerValid &&
    patternCorrect && elementCorrect;
  rows.push({
    id: entry.id,
    category: entry.category,
    locale: entry.locale,
    accuracy_eligible: Boolean(entry.accuracy_eligible),
    status,
    transport_error: transportError,
    provider,
    model,
    attempts: Number(result?.provider_metadata?.attempts ?? 0),
    attack_pattern: result?.weapon_spec?.attack_pattern ?? "",
    element: result?.weapon_spec?.element ?? "",
    fallback_reason: result?.fallback_reason ?? "",
    correction_count: Array.isArray(result?.corrections) ? result.corrections.length : 0,
    latency_ms: Number(result?.latency_ms ?? observedMs),
    observed_ms: observedMs,
    estimated_cost_usd: cost,
    schema_valid: schemaErrors.length === 0,
    allow_list_valid: allowListErrors.length === 0,
    runtime_valid: runtimeValid,
    pattern_correct: patternCorrect,
    element_correct: elementCorrect,
    passed,
  });
}

const eligible = rows.filter((row) => row.accuracy_eligible);
const providerRows = rows.filter((row) => row.provider === EXPECTED_PROVIDER);
const successfulProviderRows = providerRows.filter((row) => !row.fallback_reason);
const providerLatencies = successfulProviderRows.map((row) => row.latency_ms);
const totalCostUsd = providerRows.reduce((sum, row) => sum + (row.estimated_cost_usd ?? 0), 0);
const patternAccuracy = eligible.filter((row) => row.pattern_correct).length / eligible.length;
const elementAccuracy = eligible.filter((row) => row.element_correct).length / eligible.length;
const summary = {
  suite: "M1B1 real Anthropic text matrix",
  generated_at: new Date().toISOString(),
  base_origin: origin,
  provider: EXPECTED_PROVIDER,
  model: EXPECTED_MODEL,
  case_count: rows.length,
  passed: rows.filter((row) => row.passed).length,
  failed: rows.filter((row) => !row.passed).length,
  eligible_accuracy_cases: eligible.length,
  pattern_accuracy: patternAccuracy,
  element_accuracy: elementAccuracy,
  schema_pass_rate: rows.filter((row) => row.schema_valid).length / rows.length,
  allow_list_pass_rate: rows.filter((row) => row.allow_list_valid).length / rows.length,
  runtime_pass_rate: rows.filter((row) => row.runtime_valid).length / rows.length,
  provider_call_count: providerRows.length,
  provider_success_count: successfulProviderRows.length,
  median_provider_latency_ms: median(providerLatencies),
  p95_provider_latency_ms: percentile(providerLatencies, 0.95),
  measured_cost_usd: Math.round(totalCostUsd * 1_000_000_000) / 1_000_000_000,
  application_budget_usd: 5,
};
const artifact = { summary, rows };
await mkdir(dirname(outputPath), { recursive: true });
await writeFile(outputPath, `${JSON.stringify(artifact, null, 2)}\n`, "utf8");
console.log(JSON.stringify(summary, null, 2));
console.log(`Evidence: ${outputPath}`);

const gatePassed =
  summary.failed === 0 &&
  summary.schema_pass_rate === 1 &&
  summary.allow_list_pass_rate === 1 &&
  summary.runtime_pass_rate === 1 &&
  patternAccuracy >= 0.9 &&
  elementAccuracy >= 0.9 &&
  summary.median_provider_latency_ms <= 5000 &&
  summary.p95_provider_latency_ms <= 10000 &&
  totalCostUsd <= 5;
if (!gatePassed) process.exitCode = 1;
