import {
  ALLOW_LISTS,
  MAX_POWER,
  balanceWeaponSpec,
  baseProfile,
  calculatePower,
  fallbackWeaponSpec,
  isSafeWeaponSpec,
  runtimeAllowListErrors,
  schemaValidationErrors,
} from "./weapon_contract.mjs";

export const REQUEST_LIMITS = Object.freeze({
  body_bytes: 8192,
  description_characters: 512,
  request_id_characters: 64,
  timeout_ms: 8000,
  maximum_attempts: 2,
});

const TRANSIENT_CODES = new Set([
  "provider_timeout",
  "network_unavailable",
  "provider_rate_limited",
  "backend_unavailable",
]);
const IDEMPOTENCY_TTL_MS = 5 * 60 * 1000;
const IDEMPOTENCY_LIMIT = 128;
const responseCache = new Map();

const SAFETY_RULES = Object.freeze([
  {
    reason: "code_request",
    expressions: [
      /(?:gdscript|javascript|python|shell|powershell).{0,24}(?:code|script|代码)/iu,
      /(?:execute|run|eval).{0,20}(?:code|script)/iu,
      /(?:输出|生成|执行).{0,12}(?:代码|脚本)/u,
    ],
  },
  {
    reason: "budget_bypass",
    expressions: [
      /(?:ignore|bypass|disable|skip).{0,24}(?:power|budget|schema|allow.?list|validation)/iu,
      /(?:忽略|绕过|关闭).{0,16}(?:预算|规则|校验|限制)/u,
      /unsupported.{0,20}(?:ability|module|weapon)/iu,
    ],
  },
  {
    reason: "prompt_injection",
    expressions: [
      /ignore.{0,20}(?:previous|above|system|developer).{0,20}(?:instruction|prompt|message)/iu,
      /(?:reveal|print|return|show).{0,20}(?:system prompt|developer message|hidden instruction)/iu,
      /(?:system prompt|developer message|admin\s*=|attack_pattern\s*=)/iu,
      /(?:忽略|泄露|显示).{0,16}(?:系统提示|开发者指令|隐藏指令)/u,
    ],
  },
  {
    reason: "unsafe_power_request",
    expressions: [
      /(?:infinite|unlimited|max(?:imum)?).{0,18}(?:damage|attack speed|power)/iu,
      /(?:one.?shot|instantly kill|kill everything|full.?screen kill|permanent invinc)/iu,
      /(?:no|without).{0,10}(?:weakness|drawback|cooldown|cost)/iu,
      /(?:无限|永久无敌|全屏秒杀|一击秒杀|没有任何弱点|没有弱点|无冷却)/u,
    ],
  },
  {
    reason: "known_ip_reference",
    expressions: [
      /(?:darth vader|lightsaber|star wars|mario|pokemon|pikachu|marvel|batman|harry potter)/iu,
      /(?:达斯维达|光剑|星球大战|马里奥|宝可梦|皮卡丘|漫威|蝙蝠侠|哈利波特)/u,
    ],
  },
  {
    reason: "unsafe_content",
    expressions: [
      /(?:bomb|explosive).{0,28}(?:tutorial|instructions|real people|civilian|bystander)/iu,
      /(?:harm|kill|attack).{0,20}(?:real people|civilian|bystander|school)/iu,
      /(?:炸弹|爆炸物).{0,18}(?:教程|制作方法|现实|路人|学校)/u,
      /(?:伤害|杀死|袭击).{0,12}(?:路人|现实人物|平民|学校)/u,
    ],
  },
]);

const PATTERN_KEYWORDS = Object.freeze({
  boomerang: [
    "boomerang", "bomerang", "returning", "returns", "return strike", "comes back", "bounce back",
    "回旋", "飞回", "回来", "弹回来", "回力", "返回",
  ],
  area_blast: [
    "area", "blast", "explosion", "explodes", "nova", "shockwave", "swarm", "crowd", "around me",
    "范围", "爆炸", "群攻", "一群", "周围", "冲击波", "雨云", "泡泡",
  ],
  piercing: [
    "piercing", "pierce", "pierces", "drill", "passes through", "pass through", "through shields", "needle",
    "穿透", "贯穿", "破盾", "钻头", "穿过", "长矛",
  ],
  straight_projectile: [
    "projectile", "shoot", "shoots", "launcher", "arrow", "bow", "cannon", "gun", "wand", "ranged", "thrown straight",
    "投射", "发射", "射出", "弓", "箭", "远程", "炮", "鱼竿",
  ],
});

const ELEMENT_KEYWORDS = Object.freeze({
  fire: ["fire", "flame", "burn", "ember", "fir ", "flaming", "火", "火焰", "燃烧"],
  ice: ["ice", "frost", "freeze", "frozen", "冰", "冰冻", "冻结", "霜"],
  electric: ["electric", "lightning", "shock", "thunder", "volt", "电", "电击", "闪电", "雷"],
});

function jsonResponse(body, status = 200, extraHeaders = {}) {
  const headers = new Headers({
    "content-type": "application/json; charset=utf-8",
    "cache-control": "no-store",
    "x-content-type-options": "nosniff",
    ...extraHeaders,
  });
  return new Response(JSON.stringify(body), { status, headers });
}

function stableStringify(value) {
  if (Array.isArray(value)) return `[${value.map(stableStringify).join(",")}]`;
  if (value && typeof value === "object") {
    return `{${Object.keys(value).sort().map((key) => `${JSON.stringify(key)}:${stableStringify(value[key])}`).join(",")}}`;
  }
  return JSON.stringify(value);
}

function privacyFingerprint(value) {
  const input = stableStringify(value);
  let hash = 2166136261;
  for (let index = 0; index < input.length; index += 1) {
    hash ^= input.charCodeAt(index);
    hash = Math.imul(hash, 16777619);
  }
  return (hash >>> 0).toString(16).padStart(8, "0");
}

function pruneResponseCache(now = Date.now()) {
  for (const [key, entry] of responseCache) {
    if (now - entry.createdAt > IDEMPOTENCY_TTL_MS) responseCache.delete(key);
  }
  while (responseCache.size >= IDEMPOTENCY_LIMIT) responseCache.delete(responseCache.keys().next().value);
}

function codePointLength(value) {
  return [...String(value)].length;
}

function containsAny(text, keywords) {
  return keywords.some((keyword) => text.includes(keyword));
}

function boundedNumber(value, fallback, minimum, maximum, integer = false) {
  const parsed = Number(value);
  if (!Number.isFinite(parsed)) return fallback;
  const bounded = Math.min(maximum, Math.max(minimum, parsed));
  return integer ? Math.trunc(bounded) : bounded;
}

function normalizeDrawingSummary(value) {
  const input = value && typeof value === "object" && !Array.isArray(value) ? value : {};
  const aspect = boundedNumber(input.aspect_ratio, 1, 0.05, 20);
  const direction = ["horizontal", "vertical", "diagonal", "mixed"].includes(input.dominant_direction)
    ? input.dominant_direction
    : aspect >= 1.5
      ? "horizontal"
      : aspect <= 0.67
        ? "vertical"
        : "mixed";
  return {
    stroke_count: boundedNumber(input.stroke_count, 0, 0, 256, true),
    point_count: boundedNumber(input.point_count, 0, 0, 10000, true),
    aspect_ratio: aspect,
    coverage: boundedNumber(input.coverage, 0, 0, 1),
    dominant_direction: direction,
  };
}

function normalizeSupportedList(value, serverAllowed) {
  if (!Array.isArray(value)) return [...serverAllowed];
  const supported = [...new Set(value.map((item) => String(item).trim().toLowerCase()))]
    .filter((item) => serverAllowed.includes(item));
  return supported.length > 0 ? supported : [...serverAllowed];
}

export class InterpreterError extends Error {
  constructor(code, message, status = 502) {
    super(message);
    this.name = "InterpreterError";
    this.code = code;
    this.status = status;
  }
}

export function validateInterpreterRequest(payload) {
  if (!payload || typeof payload !== "object" || Array.isArray(payload)) {
    throw new InterpreterError("invalid_request", "Request body must be a JSON object.", 400);
  }
  const requestId = String(payload.request_id ?? "").trim();
  if (!requestId || requestId.length > REQUEST_LIMITS.request_id_characters || !/^[A-Za-z0-9._:-]+$/u.test(requestId)) {
    throw new InterpreterError("invalid_request_id", "request_id is missing or invalid.", 400);
  }
  if (typeof payload.description !== "string") {
    throw new InterpreterError("invalid_description", "description must be a string.", 400);
  }
  const description = payload.description.trim();
  const locale = String(payload.locale ?? "und").trim().slice(0, 16) || "und";
  return {
    request_id: requestId,
    description,
    locale,
    drawing_summary: normalizeDrawingSummary(payload.drawing_summary),
    supported_attack_patterns: normalizeSupportedList(
      payload.supported_attack_patterns,
      ALLOW_LISTS.attack_pattern,
    ),
    supported_elements: normalizeSupportedList(payload.supported_elements, ALLOW_LISTS.element),
    supported_abilities: normalizeSupportedList(
      payload.supported_abilities,
      ALLOW_LISTS.special_ability,
    ),
    maximum_power_score: boundedNumber(
      payload.maximum_power_score,
      MAX_POWER,
      1,
      MAX_POWER,
      true,
    ),
  };
}

export function classifyInput(description) {
  const normalized = String(description ?? "").trim().toLowerCase();
  if (!normalized) return "empty_description";
  if (codePointLength(normalized) > REQUEST_LIMITS.description_characters) return "description_too_long";
  for (const rule of SAFETY_RULES) {
    if (rule.expressions.some((expression) => expression.test(normalized))) return rule.reason;
  }
  return "";
}

function detectPattern(text, supportedPatterns) {
  for (const pattern of ["boomerang", "area_blast", "piercing", "straight_projectile"]) {
    if (supportedPatterns.includes(pattern) && containsAny(text, PATTERN_KEYWORDS[pattern])) return pattern;
  }
  return supportedPatterns.includes("melee_slash") ? "melee_slash" : supportedPatterns[0];
}

function detectElement(text, supportedElements, corrections) {
  const matches = Object.entries(ELEMENT_KEYWORDS)
    .filter(([element, words]) => supportedElements.includes(element) && containsAny(text, words))
    .map(([element]) => element);
  if (matches.length > 1) {
    corrections.push("interpretation: multiple elements normalized to normal");
    return supportedElements.includes("normal") ? "normal" : supportedElements[0];
  }
  return matches[0] ?? (supportedElements.includes("normal") ? "normal" : supportedElements[0]);
}

function elementStatus(element, fallback = "none") {
  return { fire: "burn", ice: "freeze", electric: "shock" }[element] ?? fallback;
}

function elementMaterial(element) {
  return {
    fire: "ember_metal",
    ice: "frozen_metal",
    electric: "charged_metal",
    normal: "forged_metal",
  }[element] ?? "forged_metal";
}

function generatedName(pattern, element, drawing) {
  const elementName = { normal: "Ink", fire: "Ember", ice: "Frost", electric: "Volt" }[element] ?? "Ink";
  const patternName = {
    melee_slash: drawing.aspect_ratio > 1.7 ? "Longline Sketchblade" : "Sketchblade",
    straight_projectile: drawing.point_count >= 12 ? "Detailshot Darter" : "Linebolt Darter",
    boomerang: "Returning Crescent",
    area_blast: "Crowdbreaker Nova",
    piercing: "Shieldsplitter Lance",
  }[pattern] ?? "Sketchblade";
  return `${elementName} ${patternName}`;
}

function semanticSummary(pattern, element, status, ability) {
  const pieces = [`a ${element} ${pattern.replaceAll("_", " ")}`];
  if (status !== "none") pieces.push(`${status} status`);
  if (ability !== "none") pieces.push(`${ability.replaceAll("_", " ")} ability`);
  return `Interpreted as ${pieces.join(" with ")}.`;
}

export class DeterministicWeaponAdapter {
  constructor(options = {}) {
    this.provider = "deterministic_local";
    this.model = "m1b1-keyword-baseline";
    this.scenario = options.scenario ?? "success";
    this.delayMs = Number(options.delayMs ?? 20);
  }

  async interpret(request, context = {}) {
    const scenario = context.scenario ?? this.scenario;
    if (scenario === "delayed_success") await new Promise((resolve) => setTimeout(resolve, Math.max(25, this.delayMs)));
    if (scenario === "timeout") throw new InterpreterError("provider_timeout", "Provider timed out.", 504);
    if (scenario === "network_error") throw new InterpreterError("network_unavailable", "Network unavailable.", 503);
    if (scenario === "rate_limit") throw new InterpreterError("provider_rate_limited", "Provider rate limited.", 429);
    if (scenario === "backend_unavailable") throw new InterpreterError("backend_unavailable", "Backend unavailable.", 503);
    if (scenario === "invalid_json") throw new InterpreterError("invalid_provider_response", "Provider returned invalid JSON.", 502);
    if (scenario === "missing_fields") return { intent: {}, confidence: 0, corrections: [] };
    if (scenario === "unsupported_ability") {
      return {
        intent: {
          name: "Admin Orbital Laser",
          attack_pattern: "teleport_strike",
          element: "plasma",
          special_ability: "orbital_laser",
          status_effect: "permanent_stun",
          drawback: "none",
          damage: 999999,
        },
        confidence: 0.1,
        corrections: [],
      };
    }

    const text = request.description.toLowerCase();
    const corrections = [];
    const attackPattern = detectPattern(text, request.supported_attack_patterns);
    const element = detectElement(text, request.supported_elements, corrections);
    const profile = baseProfile(attackPattern);
    const status = elementStatus(element, profile.status_effect);
    let ability = profile.special_ability;
    if (element === "electric" && containsAny(text, ["chain", "crowd", "group", "一群", "群体"])) {
      ability = request.supported_abilities.includes("chain_arc") ? "chain_arc" : ability;
    }
    if (containsAny(text, ["shield me", "front shield", "挡住", "护盾"])) {
      corrections.push("interpretation: requested defensive shield is not executable in M1B1 and was omitted");
    }
    return {
      intent: {
        name: generatedName(attackPattern, element, request.drawing_summary),
        attack_pattern: attackPattern,
        element,
        special_ability: ability,
        status_effect: status,
        drawback: profile.drawback,
      },
      interpretation_summary: semanticSummary(attackPattern, element, status, ability),
      confidence: text.length < 5 ? 0.35 : 0.88,
      corrections,
      provider_metadata: { provider: this.provider, model: this.model },
      estimated_cost: "UNKNOWN",
    };
  }
}

function semanticIntentToRaw(intent, request) {
  const corrections = [];
  const semantic = intent && typeof intent === "object" && !Array.isArray(intent) ? intent : {};
  let fallbackReason = "";
  if (Object.keys(semantic).length === 0) fallbackReason = "invalid_provider_response";
  let pattern = String(semantic.attack_pattern ?? "").trim().toLowerCase();
  if (!request.supported_attack_patterns.includes(pattern)) {
    if (pattern) corrections.push(`interpretation: unsupported attack_pattern '${pattern}' repaired`);
    pattern = "melee_slash";
    fallbackReason ||= "provider_output_repaired";
  }
  let element = String(semantic.element ?? "").trim().toLowerCase();
  if (!request.supported_elements.includes(element)) {
    if (element) corrections.push(`interpretation: unsupported element '${element}' repaired`);
    element = "normal";
    fallbackReason ||= "provider_output_repaired";
  }
  const raw = baseProfile(pattern);
  raw.name = typeof semantic.name === "string" && semantic.name.trim()
    ? semantic.name.trim()
    : generatedName(pattern, element, request.drawing_summary);
  raw.element = element;
  raw.visual_material = elementMaterial(element);
  raw.status_effect = elementStatus(element, raw.status_effect);

  for (const field of ["special_ability", "status_effect", "drawback"]) {
    if (semantic[field] === undefined) continue;
    const value = String(semantic[field]).trim().toLowerCase();
    const allowed = ALLOW_LISTS[field];
    if (allowed.includes(value) && (field !== "special_ability" || request.supported_abilities.includes(value))) {
      raw[field] = value;
    } else {
      corrections.push(`interpretation: unsupported ${field} '${value}' ignored`);
      fallbackReason ||= "provider_output_repaired";
    }
  }

  const numericFields = ["damage", "attack_speed", "range", "power_score", "projectile_speed", "area_radius", "pierce_count", "return_speed"];
  for (const field of numericFields) {
    if (Object.hasOwn(semantic, field)) corrections.push(`interpretation: provider numeric field '${field}' ignored`);
  }
  for (const field of Object.keys(semantic)) {
    if (!["name", "attack_pattern", "element", "special_ability", "status_effect", "drawback", ...numericFields].includes(field)) {
      corrections.push(`interpretation: unknown semantic field '${field}' ignored`);
    }
  }
  return { raw, corrections, fallbackReason };
}

function safeFallbackResponse(request, reason, startedAt, details = {}) {
  const balanced = balanceWeaponSpec(fallbackWeaponSpec(), request.maximum_power_score);
  const corrections = [
    `fallback: ${reason}`,
    ...(details.corrections ?? []),
    ...balanced.corrections,
  ];
  const latencyMs = Math.max(0, Date.now() - startedAt);
  return {
    request_id: request.request_id,
    weapon_spec: balanced.values,
    interpretation_summary: "A safe practice weapon was substituted because the request could not be interpreted safely.",
    confidence: 0,
    corrections,
    fallback_reason: reason,
    provider_metadata: {
      provider: details.provider ?? "none",
      model: details.model ?? "none",
      attempts: details.attempts ?? 0,
    },
    latency: { total_ms: latencyMs, provider_ms: details.providerMs ?? 0, attempts: details.attempts ?? 0 },
    latency_ms: latencyMs,
    estimated_cost: "UNKNOWN",
    power_budget: balanced.after,
    schema_valid: schemaValidationErrors(balanced.values).length === 0,
    allow_list_valid: runtimeAllowListErrors(balanced.values).length === 0,
    power_valid: balanced.within_budget,
    runtime_valid: isSafeWeaponSpec(balanced.values, request.maximum_power_score),
  };
}

async function invokeWithTimeout(adapter, request, context, timeoutMs) {
  let timeout;
  const timeoutPromise = new Promise((_, reject) => {
    timeout = setTimeout(
      () => reject(new InterpreterError("provider_timeout", "Provider timed out.", 504)),
      timeoutMs,
    );
  });
  try {
    return await Promise.race([adapter.interpret(request, context), timeoutPromise]);
  } finally {
    clearTimeout(timeout);
  }
}

export async function compileWeapon(requestInput, options = {}) {
  const startedAt = Date.now();
  const request = validateInterpreterRequest(requestInput);
  const safetyReason = classifyInput(request.description);
  if (safetyReason) return safeFallbackResponse(request, safetyReason, startedAt);

  const adapter = options.adapter ?? new DeterministicWeaponAdapter();
  const timeoutMs = boundedNumber(options.timeoutMs, REQUEST_LIMITS.timeout_ms, 50, 15000, true);
  const maximumAttempts = boundedNumber(
    options.maximumAttempts,
    REQUEST_LIMITS.maximum_attempts,
    1,
    REQUEST_LIMITS.maximum_attempts,
    true,
  );
  let attempts = 0;
  let providerStartedAt = Date.now();
  let adapterResult;
  let terminalError;
  while (attempts < maximumAttempts) {
    attempts += 1;
    try {
      adapterResult = await invokeWithTimeout(
        adapter,
        request,
        { scenario: options.scenario, attempt: attempts },
        timeoutMs,
      );
      terminalError = null;
      break;
    } catch (error) {
      terminalError = error instanceof InterpreterError
        ? error
        : new InterpreterError("backend_unavailable", "Interpreter adapter failed.", 503);
      if (!TRANSIENT_CODES.has(terminalError.code) || attempts >= maximumAttempts) break;
    }
  }
  const providerMs = Math.max(0, Date.now() - providerStartedAt);
  if (terminalError || !adapterResult || typeof adapterResult !== "object") {
    return safeFallbackResponse(request, terminalError?.code ?? "invalid_provider_response", startedAt, {
      provider: adapter.provider ?? "unknown",
      model: adapter.model ?? "unknown",
      attempts,
      providerMs,
    });
  }

  const normalized = semanticIntentToRaw(adapterResult.intent, request);
  const balanced = balanceWeaponSpec(normalized.raw, request.maximum_power_score);
  const corrections = [
    ...(Array.isArray(adapterResult.corrections) ? adapterResult.corrections.map(String) : []),
    ...normalized.corrections,
    ...balanced.corrections,
  ];
  const schemaErrors = schemaValidationErrors(balanced.values);
  const runtimeValid = isSafeWeaponSpec(balanced.values, request.maximum_power_score);
  if (schemaErrors.length > 0 || !balanced.within_budget || !runtimeValid) {
    return safeFallbackResponse(request, "post_validation_failed", startedAt, {
      provider: adapter.provider ?? "unknown",
      model: adapter.model ?? "unknown",
      attempts,
      providerMs,
      corrections: [...corrections, ...schemaErrors.map((item) => `schema: ${item}`)],
    });
  }

  const providerMetadata = adapterResult.provider_metadata && typeof adapterResult.provider_metadata === "object"
    ? adapterResult.provider_metadata
    : {};
  const latencyMs = Math.max(0, Date.now() - startedAt);
  const fallbackReason = normalized.fallbackReason;
  return {
    request_id: request.request_id,
    weapon_spec: balanced.values,
    interpretation_summary: String(
      adapterResult.interpretation_summary ||
      semanticSummary(
        balanced.values.attack_pattern,
        balanced.values.element,
        balanced.values.status_effect,
        balanced.values.special_ability,
      ),
    ).slice(0, 240),
    confidence: boundedNumber(adapterResult.confidence, 0, 0, 1),
    corrections,
    fallback_reason: fallbackReason,
    provider_metadata: {
      provider: String(providerMetadata.provider ?? adapter.provider ?? "unknown").slice(0, 48),
      model: String(providerMetadata.model ?? adapter.model ?? "unknown").slice(0, 80),
      attempts,
    },
    latency: { total_ms: latencyMs, provider_ms: providerMs, attempts },
    latency_ms: latencyMs,
    estimated_cost: adapterResult.estimated_cost ?? "UNKNOWN",
    power_budget: balanced.after,
    schema_valid: true,
    allow_list_valid: true,
    power_valid: balanced.within_budget,
    runtime_valid: runtimeValid,
  };
}

export function resolveAdapter(env = {}) {
  const provider = String(env.WEAPON_AI_PROVIDER ?? "deterministic").trim().toLowerCase();
  if (!provider || provider === "deterministic" || provider === "mock" || provider === "local") {
    return new DeterministicWeaponAdapter();
  }
  throw new InterpreterError(
    "provider_unconfigured",
    `Provider adapter '${provider}' is not installed in the vendor-neutral build.`,
    503,
  );
}

function minimalAudit(result, requestLength) {
  return {
    event: "weapon_interpretation",
    request_id: result.request_id,
    input_length: requestLength,
    provider: result.provider_metadata?.provider ?? "unknown",
    model: result.provider_metadata?.model ?? "unknown",
    attempts: result.provider_metadata?.attempts ?? 0,
    latency_ms: result.latency_ms,
    fallback_reason: result.fallback_reason,
    correction_count: result.corrections?.length ?? 0,
    estimated_cost: result.estimated_cost,
    runtime_valid: result.runtime_valid,
  };
}

export async function handleCompileWeapon(request, env = {}, options = {}) {
  if (request.method !== "POST") {
    return jsonResponse({ error: "method_not_allowed" }, 405, { allow: "POST" });
  }
  const url = new URL(request.url);
  const origin = request.headers.get("origin");
  if (origin) {
    try {
      if (new URL(origin).host !== url.host) return jsonResponse({ error: "cross_origin_forbidden" }, 403);
    } catch {
      return jsonResponse({ error: "invalid_origin" }, 403);
    }
  }
  const contentType = request.headers.get("content-type") ?? "";
  if (!contentType.toLowerCase().includes("application/json")) {
    return jsonResponse({ error: "content_type_must_be_json" }, 415);
  }
  const declaredLength = Number(request.headers.get("content-length") ?? 0);
  if (declaredLength > REQUEST_LIMITS.body_bytes) return jsonResponse({ error: "request_too_large" }, 413);
  const bodyText = await request.text();
  if (new TextEncoder().encode(bodyText).byteLength > REQUEST_LIMITS.body_bytes) {
    return jsonResponse({ error: "request_too_large" }, 413);
  }
  let payload;
  try {
    payload = JSON.parse(bodyText);
  } catch {
    return jsonResponse({ error: "invalid_json" }, 400);
  }

  let safeRequest;
  try {
    safeRequest = validateInterpreterRequest(payload);
  } catch (error) {
    const status = error instanceof InterpreterError ? error.status : 400;
    const code = error instanceof InterpreterError ? error.code : "invalid_request";
    return jsonResponse({ error: code }, status);
  }
  pruneResponseCache();
  const fingerprint = privacyFingerprint({ ...payload, request_id: undefined });
  const cached = responseCache.get(safeRequest.request_id);
  if (cached) {
    if (cached.fingerprint !== fingerprint) return jsonResponse({ error: "request_id_conflict" }, 409);
    return jsonResponse(cached.result, 200, { "x-forge-idempotent-replay": "true" });
  }

  let adapter;
  try {
    adapter = options.adapter ?? resolveAdapter(env);
  } catch (error) {
    const result = safeFallbackResponse(safeRequest, error.code ?? "provider_unconfigured", Date.now());
    console.info(`[WeaponInterpreter] ${JSON.stringify(minimalAudit(result, safeRequest.description.length))}`);
    responseCache.set(safeRequest.request_id, { fingerprint, result, createdAt: Date.now() });
    return jsonResponse(result, 200);
  }

  try {
    const testMode = String(env.WEAPON_INTERPRETER_TEST_MODE ?? "").toLowerCase() === "true";
    const scenario = testMode ? String(payload.test_scenario ?? "success") : "success";
    const result = await compileWeapon(payload, {
      adapter,
      scenario,
      timeoutMs: options.timeoutMs,
      maximumAttempts: options.maximumAttempts,
    });
    console.info(`[WeaponInterpreter] ${JSON.stringify(minimalAudit(result, String(payload.description ?? "").length))}`);
    responseCache.set(safeRequest.request_id, { fingerprint, result, createdAt: Date.now() });
    return jsonResponse(result, 200);
  } catch (error) {
    const status = error instanceof InterpreterError ? error.status : 500;
    const code = error instanceof InterpreterError ? error.code : "internal_error";
    return jsonResponse({ error: code }, status);
  }
}

export function verifyResponse(result) {
  return {
    schema_errors: schemaValidationErrors(result?.weapon_spec),
    power: result?.weapon_spec ? calculatePower(result.weapon_spec) : null,
    runtime_valid: Boolean(result?.weapon_spec && isSafeWeaponSpec(result.weapon_spec)),
  };
}
