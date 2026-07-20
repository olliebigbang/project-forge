import {
  ALLOW_LISTS,
  MAX_POWER,
  balanceWeaponSpec,
  baseProfile,
  calculatePower,
  canonicalWeaponSemantics,
  isSafeWeaponSpec,
  runtimeAllowListErrors,
  schemaValidationErrors,
} from "./weapon_contract.mjs";
import {
  beginDurableRequest,
  completeDurableRequest,
  consumeDurableRateLimits,
  ensureDurableRequestGuard,
  hasDurableRequestGuard,
  releaseDurableRequest,
  waitForDurableResult,
} from "./durable_request_guard.mjs";
import { InterpreterError } from "./interpreter_error.mjs";
import {
  ANTHROPIC_MODEL,
  ANTHROPIC_PROVIDER,
  createAnthropicAdapter,
} from "./anthropic_weapon_adapter.mjs";
import {
  commitConservativeProviderBudget,
  lockProviderBudget,
  providerBudgetConfig,
  releaseProviderBudget,
  reserveProviderBudget,
  settleProviderBudget,
} from "./provider_budget_guard.mjs";

export { InterpreterError } from "./interpreter_error.mjs";

export const REQUEST_LIMITS = Object.freeze({
  body_bytes: 8192,
  description_characters: 512,
  request_id_characters: 64,
  session_id_characters: 64,
  timeout_ms: 8000,
  maximum_attempts: 2,
});

export const INGRESS_LIMITS = Object.freeze({
  session_requests_per_minute: 8,
  network_requests_per_minute: 60,
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
const RATE_WINDOW_MS = 60 * 1000;
const rateBuckets = new Map();
const LOCAL_PROVIDER_NAMES = new Set(["", "deterministic", "mock", "local"]);

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
    "area", "blast", "explosion", "explodes", "grenade", "throwing bomb", "hand bomb", "nova", "shockwave", "swarm", "crowd", "around me",
    "范围", "爆炸", "群攻", "一群", "周围", "冲击波", "雨云", "泡泡",
  ],
  piercing: [
    "piercing", "pierce", "pierces", "spear", "javelin", "lance", "drill", "passes through", "pass through", "through shields", "needle",
    "穿透", "贯穿", "破盾", "钻头", "穿过", "长矛",
  ],
  straight_projectile: [
    "projectile", "shoot", "shoots", "launcher", "arrow", "bow", "cannon", "gun", "wand", "ranged", "thrown straight",
    "投射", "发射", "射出", "弓", "箭", "远程", "炮", "鱼竿",
  ],
});

const WEAPON_FORM_KEYWORDS = Object.freeze({
  grenade: ["grenade", "throwing bomb", "hand bomb"],
  boomerang: ["boomerang", "bomerang", "returning crescent"],
  bow: ["bow", "longbow", "shortbow"],
  spear: ["spear", "javelin", "lance"],
  sword: ["sword", "blade", "katana", "sabre", "saber"],
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

async function readBoundedRequestText(request, maximumBytes) {
  if (!request.body) return { text: "", tooLarge: false };

  const reader = request.body.getReader();
  const decoder = new TextDecoder();
  const parts = [];
  let totalBytes = 0;
  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      const bytes = value instanceof Uint8Array ? value : new Uint8Array(value);
      if (bytes.byteLength > maximumBytes - totalBytes) {
        try {
          await reader.cancel("request_too_large");
        } catch {
          // The size decision is already final. A transport cancellation error
          // must not turn this fail-closed 413 into a provider-reachable path.
        }
        return { text: "", tooLarge: true };
      }
      totalBytes += bytes.byteLength;
      parts.push(decoder.decode(bytes, { stream: true }));
    }
    parts.push(decoder.decode());
    return { text: parts.join(""), tooLarge: false };
  } finally {
    reader.releaseLock();
  }
}

function stableStringify(value) {
  if (Array.isArray(value)) return `[${value.map(stableStringify).join(",")}]`;
  if (value && typeof value === "object") {
    return `{${Object.keys(value).sort().map((key) => `${JSON.stringify(key)}:${stableStringify(value[key])}`).join(",")}}`;
  }
  return JSON.stringify(value);
}

async function privacyFingerprint(value) {
  if (!globalThis.crypto?.subtle) {
    throw new InterpreterError("request_guard_unavailable", "Cryptographic hashing is unavailable.", 503);
  }
  const bytes = new TextEncoder().encode(stableStringify(value));
  const digest = new Uint8Array(await globalThis.crypto.subtle.digest("SHA-256", bytes));
  // 128 bits is enough for short-lived namespace and payload fingerprints while
  // avoiding storage of the caller IP, session ID, or original description.
  return [...digest.slice(0, 16)]
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

function pruneResponseCache(now = Date.now()) {
  for (const [key, entry] of responseCache) {
    if (now - entry.createdAt > IDEMPOTENCY_TTL_MS) responseCache.delete(key);
  }
  while (responseCache.size >= IDEMPOTENCY_LIMIT) {
    const completedKey = [...responseCache].find(([, entry]) => entry.result)?.[0];
    if (!completedKey) break;
    responseCache.delete(completedKey);
  }
}

function validateSessionId(value) {
  const sessionId = String(value ?? "").trim();
  if (
    sessionId.length < 16 ||
    sessionId.length > REQUEST_LIMITS.session_id_characters ||
    !/^[A-Za-z0-9_-]+$/u.test(sessionId)
  ) {
    throw new InterpreterError("invalid_session", "x-forge-session is missing or invalid.", 400);
  }
  return sessionId;
}

function consumeRateLimit(key, limit, now = Date.now()) {
  const current = rateBuckets.get(key);
  const bucket = !current || now - current.startedAt >= RATE_WINDOW_MS
    ? { startedAt: now, count: 0 }
    : current;
  bucket.count += 1;
  rateBuckets.set(key, bucket);
  return {
    allowed: bucket.count <= limit,
    retryAfter: Math.max(1, Math.ceil((bucket.startedAt + RATE_WINDOW_MS - now) / 1000)),
  };
}

function pruneRateBuckets(now = Date.now()) {
  for (const [key, bucket] of rateBuckets) {
    if (now - bucket.startedAt >= RATE_WINDOW_MS * 2) rateBuckets.delete(key);
  }
}

function safeIdentifier(value, fallback, maximum) {
  const text = String(value ?? "").trim();
  if (!text || !/^[A-Za-z0-9._:/-]+$/u.test(text)) return fallback;
  return text.slice(0, maximum);
}

function sanitizeEstimatedCost(value) {
  if (value === "UNKNOWN") return "UNKNOWN";
  if (!value || typeof value !== "object" || Array.isArray(value)) return "UNKNOWN";
  const amount = Number(value.amount);
  const currency = String(value.currency ?? "").trim().toUpperCase();
  if (!Number.isFinite(amount) || amount < 0 || amount > 100 || currency !== "USD") return "UNKNOWN";
  return { amount: Math.round(amount * 1e9) / 1e9, currency };
}

function safeCorrections(values) {
  const source = Array.isArray(values) ? values : [];
  return [...new Set(source.map((value) => String(value).slice(0, 160)))].slice(0, 64);
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

function abortableDelay(delayMs, signal) {
  return new Promise((resolve, reject) => {
    if (signal?.aborted) {
      reject(new InterpreterError("provider_timeout", "Provider request was aborted.", 504, true));
      return;
    }
    const onAbort = () => {
      clearTimeout(timeout);
      reject(new InterpreterError("provider_timeout", "Provider request was aborted.", 504, true));
    };
    const timeout = setTimeout(() => {
      signal?.removeEventListener("abort", onAbort);
      resolve();
    }, delayMs);
    signal?.addEventListener("abort", onAbort, { once: true });
  });
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

function detectWeaponForm(text) {
  for (const form of ["grenade", "boomerang", "bow", "spear", "sword"]) {
    if (containsAny(text, WEAPON_FORM_KEYWORDS[form])) return form;
  }
  return "generic";
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

function generatedName(pattern, element, drawing, form = "generic") {
  const elementName = { normal: "Ink", fire: "Ember", ice: "Frost", electric: "Volt" }[element] ?? "Ink";
  const formName = {
    grenade: "Arc Grenade",
    bow: "Longbow",
    sword: "Sketchsword",
    boomerang: "Returning Crescent",
    spear: "Shieldsplitter Spear",
  }[form];
  const patternName = {
    melee_slash: drawing.aspect_ratio > 1.7 ? "Longline Sketchblade" : "Sketchblade",
    straight_projectile: drawing.point_count >= 12 ? "Detailshot Darter" : "Linebolt Darter",
    boomerang: "Returning Crescent",
    area_blast: "Crowdbreaker Nova",
    piercing: "Shieldsplitter Lance",
  }[pattern] ?? "Sketchblade";
  return `${elementName} ${formName ?? patternName}`;
}

function semanticSummary(pattern, element, status, ability, semantics = {}) {
  const form = String(semantics.weapon_form ?? "generic").replaceAll("_", " ");
  const delivery = String(semantics.delivery ?? "held").replaceAll("_", " ");
  const pieces = [`a ${element} ${form === "generic" ? pattern.replaceAll("_", " ") : form}`, `${delivery} delivery`];
  if (semantics.trajectory && semantics.trajectory !== "direct") pieces.push(`${String(semantics.trajectory).replaceAll("_", " ")} trajectory`);
  if (semantics.area_effect && semantics.area_effect !== "none") pieces.push(`${String(semantics.area_effect).replaceAll("_", " ")} on impact`);
  if (status !== "none") pieces.push(`${status} status`);
  if (ability !== "none") pieces.push(`${ability.replaceAll("_", " ")} ability`);
  return `Interpreted as ${pieces.join(" with ")}.`;
}

export class DeterministicWeaponAdapter {
  constructor(options = {}) {
    this.provider = "deterministic_local";
    this.model = "m1b1-keyword-baseline";
    this.supportsAbort = true;
    this.scenario = options.scenario ?? "success";
    this.delayMs = Number(options.delayMs ?? 20);
  }

  async interpret(request, context = {}) {
    const scenario = context.scenario ?? this.scenario;
    if (scenario === "delayed_success") {
      await abortableDelay(Math.max(25, this.delayMs), context.signal);
    }
    if (scenario === "timeout") throw new InterpreterError("provider_timeout", "Provider timed out.", 504, true);
    if (scenario === "network_error") throw new InterpreterError("network_unavailable", "Network unavailable.", 503, true);
    if (scenario === "rate_limit") throw new InterpreterError("provider_rate_limited", "Provider rate limited.", 429, true);
    if (scenario === "backend_unavailable") throw new InterpreterError("backend_unavailable", "Backend unavailable.", 503, true);
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
    const weaponForm = detectWeaponForm(text);
    const semantics = canonicalWeaponSemantics(weaponForm, attackPattern);
    const element = detectElement(text, request.supported_elements, corrections);
    const profile = baseProfile(attackPattern);
    const status = elementStatus(element, profile.status_effect);
    let ability = profile.special_ability;
    if (element === "electric" && containsAny(text, ["chain", "crowd", "group", "一群", "群体"])) {
      ability = request.supported_abilities.includes("chain_arc") ? "chain_arc" : ability;
    }
    if (containsAny(text, ["shield me", "front shield", "挡住", "护盾"])) ability = "front_shield";
    return {
      intent: {
        name: generatedName(semantics.attack_pattern, element, request.drawing_summary, weaponForm),
        ...semantics,
        element,
        special_ability: ability,
        status_effect: status,
        drawback: profile.drawback,
      },
      interpretation_summary: semanticSummary(semantics.attack_pattern, element, status, ability, semantics),
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
    if (pattern) corrections.push("interpretation: unsupported attack_pattern repaired");
    pattern = request.supported_attack_patterns.includes("melee_slash")
      ? "melee_slash"
      : request.supported_attack_patterns[0];
    fallbackReason ||= "provider_output_repaired";
  }
  const explicitForm = detectWeaponForm(request.description.toLowerCase());
  let form = String(semantic.weapon_form ?? "generic").trim().toLowerCase();
  if (!ALLOW_LISTS.weapon_form.includes(form)) {
    if (form) corrections.push("interpretation: unsupported weapon_form repaired");
    form = "generic";
    fallbackReason ||= "provider_output_repaired";
  }
  if (explicitForm !== "generic" && form !== explicitForm) {
    corrections.push(`interpretation: explicit ${explicitForm} form restored`);
    form = explicitForm;
  }
  let semantics = canonicalWeaponSemantics(form, pattern);
  if (!request.supported_attack_patterns.includes(semantics.attack_pattern)) {
    corrections.push("interpretation: form-specific pattern unavailable; generic pattern retained");
    form = "generic";
    semantics = canonicalWeaponSemantics(form, pattern);
  }
  for (const field of ["attack_pattern", "delivery", "trajectory", "impact", "area_effect"]) {
    const supplied = String(semantic[field] ?? "").trim().toLowerCase();
    if (supplied && supplied !== semantics[field]) {
      corrections.push(`interpretation: ${field} normalized for ${form}`);
    }
  }
  pattern = semantics.attack_pattern;
  let element = String(semantic.element ?? "").trim().toLowerCase();
  if (!request.supported_elements.includes(element)) {
    if (element) corrections.push("interpretation: unsupported element repaired");
    element = request.supported_elements.includes("normal") ? "normal" : request.supported_elements[0];
    fallbackReason ||= "provider_output_repaired";
  }
  const raw = baseProfile(pattern);
  Object.assign(raw, semantics);
  // Provider free text is never reflected into executable/display output. Names,
  // summaries, corrections and audit labels are generated from allow-listed data.
  raw.name = generatedName(pattern, element, request.drawing_summary, form);
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
      corrections.push(`interpretation: unsupported ${field} ignored`);
      fallbackReason ||= "provider_output_repaired";
    }
  }

  const numericFields = ["damage", "attack_speed", "range", "power_score", "projectile_speed", "area_radius", "pierce_count", "return_speed"];
  for (const field of numericFields) {
    if (Object.hasOwn(semantic, field)) corrections.push(`interpretation: provider numeric field '${field}' ignored`);
  }
  for (const field of Object.keys(semantic)) {
    if (!["name", "weapon_form", "delivery", "trajectory", "impact", "area_effect", "attack_pattern", "element", "special_ability", "status_effect", "drawback", ...numericFields].includes(field)) {
      corrections.push("interpretation: unknown semantic field ignored");
    }
  }
  return { raw, corrections, fallbackReason };
}

function safeFallbackResponse(request, reason, startedAt, details = {}) {
  const corrections = safeCorrections([
    `fallback: ${reason}`,
    ...(details.corrections ?? []),
  ]);
  const latencyMs = Math.max(0, Date.now() - startedAt);
  const provider = safeIdentifier(details.provider, "none", 48);
  const attempts = boundedNumber(details.attempts, 0, 0, REQUEST_LIMITS.maximum_attempts, true);
  const providerInvoked = Boolean(details.providerInvoked ?? (attempts > 0 && provider !== "none"));
  return {
    success: false,
    provider_invoked: providerInvoked,
    request_id: request.request_id,
    weapon_spec: null,
    interpretation_summary: "Weapon interpretation failed. Your drawing and description were preserved for editing or retry.",
    confidence: 0,
    corrections,
    fallback_reason: reason,
    provider_metadata: {
      provider,
      model: safeIdentifier(details.model, "none", 80),
      attempts,
    },
    latency: { total_ms: latencyMs, provider_ms: details.providerMs ?? 0, attempts },
    latency_ms: latencyMs,
    estimated_cost: sanitizeEstimatedCost(details.estimatedCost),
    power_budget: {},
    schema_valid: false,
    allow_list_valid: false,
    power_valid: false,
    runtime_valid: false,
  };
}

async function invokeWithTimeout(adapter, request, context, timeoutMs) {
  const abortController = new AbortController();
  let timeout;
  let timedOut = false;
  const timeoutError = new InterpreterError(
    "provider_timeout",
    "Provider timed out.",
    504,
    // Cancellation stops cooperative transports, but cannot prove that an
    // upstream provider did not already accept/bill the request. A wrapper
    // timeout is therefore never automatically retried.
    false,
  );
  const timeoutPromise = new Promise((_, reject) => {
    timeout = setTimeout(
      () => {
        timedOut = true;
        abortController.abort(timeoutError);
        reject(timeoutError);
      },
      timeoutMs,
    );
  });
  try {
    return await Promise.race([
      adapter.interpret(request, { ...context, signal: abortController.signal }),
      timeoutPromise,
    ]);
  } catch (error) {
    if (timedOut) throw timeoutError;
    throw error;
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
  const configuredMaximumAttempts = boundedNumber(
    options.maximumAttempts,
    REQUEST_LIMITS.maximum_attempts,
    1,
    REQUEST_LIMITS.maximum_attempts,
    true,
  );
  const adapterMaximumAttempts = Number.isSafeInteger(adapter.maximumAttempts)
    ? boundedNumber(adapter.maximumAttempts, 1, 1, REQUEST_LIMITS.maximum_attempts, true)
    : REQUEST_LIMITS.maximum_attempts;
  const maximumAttempts = Math.min(configuredMaximumAttempts, adapterMaximumAttempts);
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
      if (
        !TRANSIENT_CODES.has(terminalError.code) ||
        !terminalError.retrySafe ||
        attempts >= maximumAttempts
      ) break;
    }
  }
  const providerMs = Math.max(0, Date.now() - providerStartedAt);
  if (terminalError || !adapterResult || typeof adapterResult !== "object") {
    const billing = typeof adapter.billingSnapshot === "function"
      ? adapter.billingSnapshot()
      : null;
    const estimatedCost = billing?.disposition === "measured"
      ? { amount: billing.actualMicroUsd / 1_000_000, currency: "USD" }
      : "UNKNOWN";
    return safeFallbackResponse(request, terminalError?.code ?? "invalid_provider_response", startedAt, {
      provider: adapter.provider ?? "unknown",
      model: adapter.model ?? "unknown",
      attempts,
      providerMs,
      estimatedCost,
      providerInvoked: attempts > 0,
    });
  }

  const normalized = semanticIntentToRaw(adapterResult.intent, request);
  const balanced = balanceWeaponSpec(normalized.raw, request.maximum_power_score);
  const corrections = safeCorrections([
    ...normalized.corrections,
    ...balanced.corrections,
  ]);
  const schemaErrors = schemaValidationErrors(balanced.values);
  const runtimeValid = isSafeWeaponSpec(balanced.values, request.maximum_power_score);
  if (schemaErrors.length > 0 || !balanced.within_budget || !runtimeValid) {
    return safeFallbackResponse(request, "post_validation_failed", startedAt, {
      provider: adapter.provider ?? "unknown",
      model: adapter.model ?? "unknown",
      attempts,
      providerMs,
      providerInvoked: true,
      corrections: [...corrections, ...schemaErrors.map((item) => `schema: ${item}`)],
      estimatedCost: adapterResult.estimated_cost,
    });
  }

  const latencyMs = Math.max(0, Date.now() - startedAt);
  const fallbackReason = normalized.fallbackReason;
  if (fallbackReason) {
    return safeFallbackResponse(request, fallbackReason, startedAt, {
      provider: adapter.provider ?? "unknown",
      model: adapter.model ?? "unknown",
      attempts,
      providerMs,
      providerInvoked: true,
      corrections,
      estimatedCost: adapterResult.estimated_cost,
    });
  }
  return {
    success: true,
    provider_invoked: true,
    request_id: request.request_id,
    weapon_spec: balanced.values,
    interpretation_summary: semanticSummary(
      balanced.values.attack_pattern,
      balanced.values.element,
      balanced.values.status_effect,
      balanced.values.special_ability,
      balanced.values,
    ),
    confidence: boundedNumber(adapterResult.confidence, 0, 0, 1),
    corrections,
    fallback_reason: fallbackReason,
    provider_metadata: {
      provider: safeIdentifier(adapter.provider, "unknown", 48),
      model: safeIdentifier(adapter.model, "unknown", 80),
      attempts,
    },
    latency: { total_ms: latencyMs, provider_ms: providerMs, attempts },
    latency_ms: latencyMs,
    estimated_cost: sanitizeEstimatedCost(adapterResult.estimated_cost),
    power_budget: balanced.after,
    schema_valid: true,
    allow_list_valid: true,
    power_valid: balanced.within_budget,
    runtime_valid: runtimeValid,
  };
}

export function resolveAdapter(env = {}, options = {}) {
  const provider = String(env.WEAPON_AI_PROVIDER ?? "").trim().toLowerCase();
  if (!provider) {
    throw new InterpreterError(
      "provider_unconfigured",
      "WEAPON_AI_PROVIDER must be configured explicitly.",
      503,
    );
  }
  if (provider === "deterministic" || provider === "mock" || provider === "local") {
    return new DeterministicWeaponAdapter();
  }
  if (provider === ANTHROPIC_PROVIDER) {
    if (String(env.WEAPON_AI_MODEL ?? "").trim() !== ANTHROPIC_MODEL) {
      throw new InterpreterError(
        "provider_model_mismatch",
        `Anthropic model must be pinned to '${ANTHROPIC_MODEL}'.`,
        503,
      );
    }
    return createAnthropicAdapter(env, { fetchImpl: options.fetchImpl });
  }
  throw new InterpreterError(
    "provider_unconfigured",
    `Provider adapter '${provider}' is not installed in the vendor-neutral build.`,
    503,
  );
}

function requiresDurableRequestGuard(env, options) {
  if (String(env.WEAPON_INTERPRETER_REQUIRE_DURABLE_GUARD ?? "").toLowerCase() === "true") {
    return true;
  }
  // A declared binding that is missing methods is an outage/misconfiguration,
  // never permission to downgrade silently to an isolate-local billing guard.
  if (Object.hasOwn(env, "DB")) return true;
  const configuredProvider = String(env.WEAPON_AI_PROVIDER ?? "").trim().toLowerCase();
  if (!LOCAL_PROVIDER_NAMES.has(configuredProvider)) return true;
  // Custom adapters exist only for server tests/integration. They require the
  // durable boundary unless a test explicitly opts into the memory harness.
  return Boolean(options.adapter) && options.allowMemoryGuardForTests !== true;
}

function minimalAudit(result, requestLength, providerBudget = { state: "not_required" }) {
  const safeCost = sanitizeEstimatedCost(result.estimated_cost);
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
    estimated_cost: safeCost === "UNKNOWN"
      ? "UNKNOWN"
      : { amount: safeCost.amount, currency: safeCost.currency },
    provider_budget: {
      state: safeIdentifier(providerBudget.state, "unknown", 48),
      actual_microusd: boundedNumber(
        providerBudget.actualMicroUsd,
        0,
        0,
        5_000_000,
        true,
      ),
    },
    runtime_valid: result.runtime_valid,
  };
}

function billingEstimatedCost(billing) {
  return billing?.disposition === "measured" && Number.isSafeInteger(billing.actualMicroUsd)
    ? { amount: billing.actualMicroUsd / 1_000_000, currency: "USD" }
    : "UNKNOWN";
}

async function finalizeProviderBudget(
  db,
  config,
  namespace,
  requestId,
  adapter,
) {
  let billing;
  try {
    billing = typeof adapter.billingSnapshot === "function"
      ? adapter.billingSnapshot()
      : { disposition: "unknown", actualMicroUsd: 0, usage: null };
  } catch {
    billing = { disposition: "unknown", actualMicroUsd: 0, usage: null };
  }

  let outcome;
  if (billing.disposition === "measured") {
    outcome = await settleProviderBudget(
      db,
      config,
      namespace,
      requestId,
      billing.actualMicroUsd,
      billing.usage,
    );
  } else if (billing.disposition === "not_billed" || billing.disposition === "not_invoked") {
    outcome = await releaseProviderBudget(db, config, namespace, requestId);
  } else {
    // A timeout, aborted transport, invalid 200 response or crashed worker may
    // already have incurred spend. Commit the full pre-authorized reservation;
    // it is never released later by a timer.
    outcome = await commitConservativeProviderBudget(db, config, namespace, requestId);
  }

  const successfulStates = new Set(["settled", "released", "conservative"]);
  if (!successfulStates.has(outcome?.state)) {
    try {
      await lockProviderBudget(db, config);
    } catch {
      // D1 failure already means the next paid request fails before invocation.
    }
    return {
      state: "settlement_failed",
      actualMicroUsd: billing.disposition === "measured" ? billing.actualMicroUsd : 0,
      estimatedCost: billingEstimatedCost(billing),
    };
  }
  return {
    state: outcome.state,
    actualMicroUsd: Number(outcome.actualMicroUsd ?? 0),
    estimatedCost: billingEstimatedCost(billing),
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
  let sessionId;
  try {
    sessionId = validateSessionId(request.headers.get("x-forge-session"));
  } catch (error) {
    return jsonResponse({ error: error.code ?? "invalid_session" }, error.status ?? 400);
  }
  const contentType = request.headers.get("content-type") ?? "";
  if (!contentType.toLowerCase().includes("application/json")) {
    return jsonResponse({ error: "content_type_must_be_json" }, 415);
  }
  const declaredLength = Number(request.headers.get("content-length") ?? 0);
  if (declaredLength > REQUEST_LIMITS.body_bytes) return jsonResponse({ error: "request_too_large" }, 413);
  const boundedBody = await readBoundedRequestText(request, REQUEST_LIMITS.body_bytes);
  if (boundedBody.tooLarge) {
    return jsonResponse({ error: "request_too_large" }, 413);
  }
  const bodyText = boundedBody.text;
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
  const networkAddress = String(request.headers.get("cf-connecting-ip") ?? "unattributed").slice(0, 96);
  let networkNamespace;
  let clientNamespace;
  try {
    networkNamespace = await privacyFingerprint({ networkAddress });
    // Idempotency follows the random client session even if a phone changes IP
    // between Wi-Fi and cellular. The network hash is used only for abuse quota.
    clientNamespace = await privacyFingerprint({ sessionId });
  } catch {
    return jsonResponse({ error: "request_guard_unavailable" }, 503, { "retry-after": "1" });
  }
  const durableGuard = hasDurableRequestGuard(env);
  if (requiresDurableRequestGuard(env, options) && !durableGuard) {
    return jsonResponse({ error: "request_guard_unavailable" }, 503, { "retry-after": "1" });
  }
  let rateDecision;
  try {
    if (durableGuard) {
      await ensureDurableRequestGuard(env.DB);
      rateDecision = await consumeDurableRateLimits(
        env.DB,
        `session:${clientNamespace}`,
        `network:${networkNamespace}`,
        INGRESS_LIMITS.session_requests_per_minute,
        INGRESS_LIMITS.network_requests_per_minute,
      );
    } else {
      pruneRateBuckets();
      const sessionRate = consumeRateLimit(
        `session:${clientNamespace}`,
        INGRESS_LIMITS.session_requests_per_minute,
      );
      const networkRate = consumeRateLimit(
        `network:${networkNamespace}`,
        INGRESS_LIMITS.network_requests_per_minute,
      );
      rateDecision = {
        allowed: sessionRate.allowed && networkRate.allowed,
        retryAfter: Math.max(sessionRate.retryAfter, networkRate.retryAfter),
      };
    }
  } catch {
    // Fail closed before a paid adapter can be invoked when the durable billing
    // guard is unavailable.
    return jsonResponse({ error: "request_guard_unavailable" }, 503, { "retry-after": "1" });
  }
  if (!rateDecision.allowed) {
    return jsonResponse(
      { error: "rate_limited" },
      429,
      { "retry-after": String(rateDecision.retryAfter) },
    );
  }

  const testMode = String(env.WEAPON_INTERPRETER_TEST_MODE ?? "").toLowerCase() === "true";
  const scenario = testMode ? String(payload.test_scenario ?? "success") : "success";
  let fingerprint;
  try {
    fingerprint = await privacyFingerprint({ ...safeRequest, test_scenario: scenario });
  } catch {
    return jsonResponse({ error: "request_guard_unavailable" }, 503, { "retry-after": "1" });
  }
  const cacheKey = `${clientNamespace}:${safeRequest.request_id}`;
  let durableOwnerToken = "";
  let memoryEntry;
  if (durableGuard) {
    try {
      const lease = await beginDurableRequest(
        env.DB,
        clientNamespace,
        safeRequest.request_id,
        fingerprint,
      );
      if (lease.state === "conflict") return jsonResponse({ error: "request_id_conflict" }, 409);
      if (lease.state === "complete") {
        return jsonResponse(lease.result, 200, {
          "x-forge-idempotent-replay": "true",
          "x-forge-idempotency-store": "durable",
        });
      }
      if (lease.state === "inflight") {
        const replay = await waitForDurableResult(
          env.DB,
          clientNamespace,
          safeRequest.request_id,
          fingerprint,
          REQUEST_LIMITS.timeout_ms * REQUEST_LIMITS.maximum_attempts + 2000,
        );
        if (replay.state === "complete") {
          return jsonResponse(replay.result, 200, {
            "x-forge-idempotent-replay": "true",
            "x-forge-idempotent-inflight": "true",
            "x-forge-idempotency-store": "durable",
          });
        }
        if (replay.state === "conflict") return jsonResponse({ error: "request_id_conflict" }, 409);
        return jsonResponse({ error: "request_in_progress" }, 409, { "retry-after": "1" });
      }
      if (lease.state !== "owner") {
        return jsonResponse({ error: "request_guard_unavailable" }, 503, { "retry-after": "1" });
      }
      durableOwnerToken = lease.ownerToken;
    } catch {
      return jsonResponse({ error: "request_guard_unavailable" }, 503, { "retry-after": "1" });
    }
  } else {
    pruneResponseCache();
    const cached = responseCache.get(cacheKey);
    if (cached) {
      if (cached.fingerprint !== fingerprint) return jsonResponse({ error: "request_id_conflict" }, 409);
      const wasInflight = !cached.result;
      try {
        const result = cached.result ?? await cached.promise;
        return jsonResponse(result, 200, {
          "x-forge-idempotent-replay": "true",
          ...(wasInflight ? { "x-forge-idempotent-inflight": "true" } : {}),
          "x-forge-idempotency-store": "memory",
        });
      } catch {
        responseCache.delete(cacheKey);
        return jsonResponse({ error: "internal_error" }, 500);
      }
    }
    if (responseCache.size >= IDEMPOTENCY_LIMIT) {
      return jsonResponse({ error: "backend_busy" }, 503, { "retry-after": "1" });
    }
  }

  const operation = (async () => {
    let adapter;
    let result;
    let budgetConfig = null;
    let budgetAudit = { state: "not_required", actualMicroUsd: 0 };
    const startedAt = Date.now();

    // Reject unsafe text before constructing a paid adapter or reserving any
    // provider spend. compileWeapon repeats this check as a defense in depth.
    const safetyReason = classifyInput(safeRequest.description);
    if (safetyReason) {
      result = safeFallbackResponse(safeRequest, safetyReason, startedAt);
      console.info(`[WeaponInterpreter] ${JSON.stringify(minimalAudit(
        result,
        safeRequest.description.length,
        budgetAudit,
      ))}`);
      return result;
    }

    try {
      adapter = options.adapter ?? resolveAdapter(env, { fetchImpl: options.fetchImpl });
    } catch (error) {
      result = safeFallbackResponse(safeRequest, error.code ?? "provider_unconfigured", startedAt);
      console.info(`[WeaponInterpreter] ${JSON.stringify(minimalAudit(
        result,
        safeRequest.description.length,
        budgetAudit,
      ))}`);
      return result;
    }

    if (adapter.requiresProviderBudget === true) {
      let reservation;
      try {
        if (!durableGuard) throw new Error("Durable D1 guard is required.");
        budgetConfig = providerBudgetConfig(env, adapter.provider, adapter.model);
        reservation = await reserveProviderBudget(
          env.DB,
          budgetConfig,
          clientNamespace,
          safeRequest.request_id,
        );
      } catch {
        reservation = { state: "unavailable" };
      }
      if (reservation.state !== "reserved") {
        const reason = reservation.state === "exhausted"
          ? "provider_budget_exhausted"
          : reservation.state === "previous_attempt"
            ? "provider_budget_previous_attempt"
            : "provider_budget_unavailable";
        budgetAudit = { state: reservation.state ?? "unavailable", actualMicroUsd: 0 };
        result = safeFallbackResponse(safeRequest, reason, startedAt, {
          provider: adapter.provider,
          model: adapter.model,
        });
        console.info(`[WeaponInterpreter] ${JSON.stringify(minimalAudit(
          result,
          safeRequest.description.length,
          budgetAudit,
        ))}`);
        return result;
      }
      budgetAudit = { state: "reserved", actualMicroUsd: 0 };
    }

    try {
      result = await compileWeapon(payload, {
        adapter,
        scenario,
        timeoutMs: options.timeoutMs,
        maximumAttempts: options.maximumAttempts,
      });
    } catch {
      result = safeFallbackResponse(safeRequest, "internal_error", startedAt, {
        provider: adapter.provider ?? "unknown",
        model: adapter.model ?? "unknown",
      });
    }

    if (budgetConfig) {
      let settlement;
      try {
        settlement = await finalizeProviderBudget(
          env.DB,
          budgetConfig,
          clientNamespace,
          safeRequest.request_id,
          adapter,
        );
      } catch {
        try {
          await lockProviderBudget(env.DB, budgetConfig);
        } catch {
          // The current operation still fails closed and keeps its reservation.
        }
        settlement = {
          state: "settlement_failed",
          actualMicroUsd: 0,
          estimatedCost: "UNKNOWN",
        };
      }
      budgetAudit = settlement;
      if (settlement.state === "settlement_failed") {
        result = safeFallbackResponse(safeRequest, "provider_budget_settlement_failed", startedAt, {
          provider: adapter.provider,
          model: adapter.model,
          attempts: result.provider_metadata?.attempts ?? 0,
          providerMs: result.latency?.provider_ms ?? 0,
          estimatedCost: settlement.estimatedCost,
        });
      }
    }
    console.info(`[WeaponInterpreter] ${JSON.stringify(minimalAudit(
      result,
      safeRequest.description.length,
      budgetAudit,
    ))}`);
    return result;
  })();
  if (!durableGuard) {
    memoryEntry = { fingerprint, promise: operation, createdAt: Date.now() };
    responseCache.set(cacheKey, memoryEntry);
  }
  try {
    const result = await operation;
    let durableStored = true;
    if (durableGuard) {
      durableStored = await completeDurableRequest(
        env.DB,
        clientNamespace,
        safeRequest.request_id,
        fingerprint,
        durableOwnerToken,
        result,
      );
    } else {
      memoryEntry.result = result;
      delete memoryEntry.promise;
      memoryEntry.createdAt = Date.now();
    }
    return jsonResponse(result, 200, {
      "x-forge-idempotency-store": durableGuard ? "durable" : "memory",
      ...(durableStored ? {} : { "x-forge-idempotency-warning": "completion_not_stored" }),
    });
  } catch {
    if (durableGuard) {
      try {
        await releaseDurableRequest(
          env.DB,
          clientNamespace,
          safeRequest.request_id,
          fingerprint,
          durableOwnerToken,
        );
      } catch {
        // The short lease prevents a permanent lock if D1 is temporarily down.
      }
    } else {
      responseCache.delete(cacheKey);
    }
    return jsonResponse({ error: "internal_error" }, 500);
  }
}

export function verifyResponse(result) {
  return {
    schema_errors: schemaValidationErrors(result?.weapon_spec),
    power: result?.weapon_spec ? calculatePower(result.weapon_spec) : null,
    runtime_valid: Boolean(result?.weapon_spec && isSafeWeaponSpec(result.weapon_spec)),
  };
}
