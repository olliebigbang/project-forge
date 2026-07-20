import { validateWeaponSchema } from "./weapon_schema.mjs";

export const MAX_POWER = 100;

export const ALLOW_LISTS = Object.freeze({
  weapon_class: Object.freeze(["melee", "ranged"]),
  weapon_form: Object.freeze(["generic", "sword", "bow", "grenade", "boomerang", "spear"]),
  delivery: Object.freeze(["held", "projectile", "thrown"]),
  trajectory: Object.freeze(["direct", "arc", "returning"]),
  impact: Object.freeze(["contact", "delayed_or_contact", "piercing"]),
  area_effect: Object.freeze(["none", "explosion"]),
  attack_pattern: Object.freeze([
    "melee_slash",
    "straight_projectile",
    "boomerang",
    "area_blast",
    "piercing",
  ]),
  element: Object.freeze(["normal", "fire", "ice", "electric"]),
  special_ability: Object.freeze([
    "none",
    "knockback_burst",
    "chain_arc",
    "return_strike",
    "splash_wave",
    "shield_break",
  ]),
  status_effect: Object.freeze(["none", "burn", "freeze", "shock", "knockback"]),
  drawback: Object.freeze([
    "none",
    "slow_recovery",
    "short_reach",
    "slow_projectile",
    "low_impact",
    "self_stagger",
    "narrow_arc",
    "cooldown_lock",
  ]),
  visual_material: Object.freeze([
    "ink",
    "forged_metal",
    "ember_metal",
    "frozen_metal",
    "charged_metal",
  ]),
});

export const SPEC_FIELDS = Object.freeze([
  "name",
  "weapon_class",
  "weapon_form",
  "delivery",
  "trajectory",
  "impact",
  "area_effect",
  "attack_pattern",
  "element",
  "damage",
  "attack_speed",
  "range",
  "special_ability",
  "status_effect",
  "drawback",
  "visual_material",
  "power_score",
  "projectile_speed",
  "area_radius",
  "pierce_count",
  "return_speed",
]);

const DEFAULT_SPEC = Object.freeze({
  name: "Practice Sketchblade",
  weapon_class: "melee",
  weapon_form: "generic",
  delivery: "held",
  trajectory: "direct",
  impact: "contact",
  area_effect: "none",
  attack_pattern: "melee_slash",
  element: "normal",
  damage: 24,
  attack_speed: 1.1,
  range: 118,
  special_ability: "none",
  status_effect: "none",
  drawback: "short_reach",
  visual_material: "ink",
  power_score: 40,
  projectile_speed: 560,
  area_radius: 120,
  pierce_count: 1,
  return_speed: 680,
});

const PATTERN_COST = Object.freeze({
  melee_slash: 0,
  straight_projectile: 9,
  boomerang: 14,
  area_blast: 18,
  piercing: 17,
});
const ELEMENT_COST = Object.freeze({ normal: 0, fire: 6, ice: 9, electric: 11 });
const SPECIAL_COST = Object.freeze({
  none: 0,
  knockback_burst: 8,
  chain_arc: 12,
  return_strike: 10,
  splash_wave: 10,
  shield_break: 10,
});
const STATUS_COST = Object.freeze({ none: 0, burn: 6, freeze: 8, shock: 10, knockback: 4 });
const DRAWBACK_CREDIT = Object.freeze({
  none: 0,
  slow_recovery: 12,
  short_reach: 10,
  slow_projectile: 9,
  low_impact: 9,
  self_stagger: 14,
  narrow_arc: 8,
  cooldown_lock: 16,
});
const DELIVERY_COST = Object.freeze({ held: 0, projectile: 3, thrown: 5 });
const TRAJECTORY_COST = Object.freeze({ direct: 0, arc: 4, returning: 5 });
const IMPACT_COST = Object.freeze({ contact: 0, delayed_or_contact: 3, piercing: 4 });
const AREA_EFFECT_COST = Object.freeze({ none: 0, explosion: 6 });

export function canonicalWeaponSemantics(form = "generic", pattern = "melee_slash") {
  const safeForm = ALLOW_LISTS.weapon_form.includes(form) ? form : "generic";
  const safePattern = ALLOW_LISTS.attack_pattern.includes(pattern) ? pattern : "melee_slash";
  const byForm = {
    sword: { attack_pattern: "melee_slash", delivery: "held", trajectory: "direct", impact: "contact", area_effect: "none" },
    bow: { attack_pattern: "straight_projectile", delivery: "projectile", trajectory: "direct", impact: "contact", area_effect: "none" },
    grenade: { attack_pattern: "area_blast", delivery: "thrown", trajectory: "arc", impact: "delayed_or_contact", area_effect: "explosion" },
    boomerang: { attack_pattern: "boomerang", delivery: "thrown", trajectory: "returning", impact: "contact", area_effect: "none" },
    spear: { attack_pattern: "piercing", delivery: "projectile", trajectory: "direct", impact: "piercing", area_effect: "none" },
  };
  const byPattern = {
    melee_slash: { attack_pattern: "melee_slash", delivery: "held", trajectory: "direct", impact: "contact", area_effect: "none" },
    straight_projectile: { attack_pattern: "straight_projectile", delivery: "projectile", trajectory: "direct", impact: "contact", area_effect: "none" },
    boomerang: { attack_pattern: "boomerang", delivery: "thrown", trajectory: "returning", impact: "contact", area_effect: "none" },
    area_blast: { attack_pattern: "area_blast", delivery: "held", trajectory: "direct", impact: "contact", area_effect: "explosion" },
    piercing: { attack_pattern: "piercing", delivery: "projectile", trajectory: "direct", impact: "piercing", area_effect: "none" },
  };
  return { weapon_form: safeForm, ...(byForm[safeForm] ?? byPattern[safePattern]) };
}

function clone(value) {
  return JSON.parse(JSON.stringify(value));
}

function finiteNumber(value) {
  if (typeof value === "number") return Number.isFinite(value) ? value : null;
  if (typeof value === "string" && value.trim() !== "") {
    const parsed = Number(value);
    return Number.isFinite(parsed) ? parsed : null;
  }
  return null;
}

function repairName(value, fallback, corrections) {
  if (value === undefined || value === null) {
    corrections.push("name: missing; default applied");
    return fallback;
  }
  const clean = String(value).trim();
  if (!clean) {
    corrections.push("name: empty; default applied");
    return fallback;
  }
  if ([...clean].length > 48) corrections.push("name: truncated to 48 characters");
  return [...clean].slice(0, 48).join("");
}

function repairEnum(field, value, allowed, fallback, corrections) {
  if (value === undefined || value === null) {
    corrections.push(`${field}: missing; default ${fallback} applied`);
    return fallback;
  }
  const normalized = String(value).trim().toLowerCase();
  if (!allowed.includes(normalized)) {
    corrections.push(`${field}: unsupported value repaired to ${fallback}`);
    return fallback;
  }
  return normalized;
}

function repairNumber(field, value, fallback, minimum, maximum, integer, corrections) {
  const parsed = finiteNumber(value);
  if (parsed === null) {
    corrections.push(`${field}: missing, non-numeric, or non-finite; default applied`);
    return fallback;
  }
  const normalized = integer ? Math.trunc(parsed) : parsed;
  const bounded = Math.min(maximum, Math.max(minimum, normalized));
  if (bounded !== normalized) corrections.push(`${field}: clamped to ${bounded}`);
  return bounded;
}

export function repairWeaponSpec(data = {}) {
  const input = data && typeof data === "object" && !Array.isArray(data) ? data : {};
  const corrections = [];
  for (const key of Object.keys(input)) {
    if (!SPEC_FIELDS.includes(key)) corrections.push(`${key}: unknown field discarded`);
  }

  const values = clone(DEFAULT_SPEC);
  values.name = repairName(input.name, values.name, corrections);
  values.attack_pattern = repairEnum(
    "attack_pattern",
    input.attack_pattern,
    ALLOW_LISTS.attack_pattern,
    values.attack_pattern,
    corrections,
  );
  values.weapon_form = repairEnum(
    "weapon_form",
    input.weapon_form,
    ALLOW_LISTS.weapon_form,
    values.weapon_form,
    corrections,
  );
  const semantics = canonicalWeaponSemantics(values.weapon_form, values.attack_pattern);
  for (const field of ["attack_pattern", "delivery", "trajectory", "impact", "area_effect"]) {
    const allowed = ALLOW_LISTS[field];
    const repaired = repairEnum(field, input[field], allowed, semantics[field], corrections);
    values[field] = repaired;
    if (repaired !== semantics[field]) {
      corrections.push(`${field}: normalized to ${semantics[field]} for ${values.weapon_form}/${semantics.attack_pattern}`);
      values[field] = semantics[field];
    }
  }
  const expectedClass = values.delivery === "held" ? "melee" : "ranged";
  values.weapon_class = repairEnum(
    "weapon_class",
    input.weapon_class,
    ALLOW_LISTS.weapon_class,
    expectedClass,
    corrections,
  );
  if (values.weapon_class !== expectedClass) {
    corrections.push(`weapon_class: normalized to ${expectedClass} for ${values.attack_pattern}`);
    values.weapon_class = expectedClass;
  }
  values.element = repairEnum("element", input.element, ALLOW_LISTS.element, values.element, corrections);
  values.damage = repairNumber("damage", input.damage, values.damage, 1, 100, true, corrections);
  values.attack_speed = repairNumber(
    "attack_speed",
    input.attack_speed,
    values.attack_speed,
    0.2,
    3,
    false,
    corrections,
  );
  values.range = repairNumber("range", input.range, values.range, 40, 900, false, corrections);
  values.special_ability = repairEnum(
    "special_ability",
    input.special_ability,
    ALLOW_LISTS.special_ability,
    values.special_ability,
    corrections,
  );
  values.status_effect = repairEnum(
    "status_effect",
    input.status_effect,
    ALLOW_LISTS.status_effect,
    values.status_effect,
    corrections,
  );
  values.drawback = repairEnum(
    "drawback",
    input.drawback,
    ALLOW_LISTS.drawback,
    values.drawback,
    corrections,
  );
  values.visual_material = repairEnum(
    "visual_material",
    input.visual_material,
    ALLOW_LISTS.visual_material,
    values.visual_material,
    corrections,
  );
  values.power_score = repairNumber(
    "power_score",
    input.power_score,
    values.power_score,
    1,
    MAX_POWER,
    true,
    corrections,
  );
  values.projectile_speed = repairNumber(
    "projectile_speed",
    input.projectile_speed,
    values.projectile_speed,
    180,
    900,
    false,
    corrections,
  );
  values.area_radius = repairNumber(
    "area_radius",
    input.area_radius,
    values.area_radius,
    40,
    240,
    false,
    corrections,
  );
  values.pierce_count = repairNumber(
    "pierce_count",
    input.pierce_count,
    values.pierce_count,
    1,
    6,
    true,
    corrections,
  );
  values.return_speed = repairNumber(
    "return_speed",
    input.return_speed,
    values.return_speed,
    180,
    1000,
    false,
    corrections,
  );
  return { values, corrections };
}

export function calculatePower(values) {
  const parts = {
    damage: Number(values.damage ?? 24) * 0.55,
    attack_speed: Number(values.attack_speed ?? 1) * 10,
    range: Number(values.range ?? 100) / 45,
    attack_pattern: Number(PATTERN_COST[values.attack_pattern] ?? 0),
    element: Number(ELEMENT_COST[values.element] ?? 0),
    special_ability: Number(SPECIAL_COST[values.special_ability] ?? 0),
    status_effect: Number(STATUS_COST[values.status_effect] ?? 0),
    delivery: Number(DELIVERY_COST[values.delivery] ?? 0),
    trajectory: Number(TRAJECTORY_COST[values.trajectory] ?? 0),
    impact: Number(IMPACT_COST[values.impact] ?? 0),
    area_effect: Number(AREA_EFFECT_COST[values.area_effect] ?? 0),
    projectile_speed: 0,
    return_speed: 0,
    area_radius: 0,
    piercing: 0,
    drawback_credit: -Number(DRAWBACK_CREDIT[values.drawback] ?? 0),
  };
  if (values.delivery !== "held") {
    parts.projectile_speed = Number(values.projectile_speed ?? 560) / 200;
  }
  if (values.attack_pattern === "boomerang") {
    parts.return_speed = Number(values.return_speed ?? 680) / 250;
  }
  if (values.attack_pattern === "area_blast") {
    parts.area_radius = Number(values.area_radius ?? 120) / 30;
  }
  if (values.attack_pattern === "piercing") {
    parts.piercing = Number(values.pierce_count ?? 1) * 4;
  }
  const total = Object.values(parts).reduce((sum, value) => sum + value, 0);
  parts.total = Math.max(1, Math.round(total * 10) / 10);
  return parts;
}

function hasStrongCapability(values) {
  return (
    ["boomerang", "area_blast", "piercing"].includes(values.attack_pattern) ||
    values.element !== "normal" ||
    values.special_ability !== "none" ||
    values.damage > 45 ||
    values.attack_speed > 1.6 ||
    values.range > 700 ||
    values.area_radius > 130 ||
    values.pierce_count > 2 ||
    values.delivery === "thrown" ||
    values.trajectory !== "direct" ||
    values.impact !== "contact" ||
    values.area_effect !== "none"
  );
}

function matchingDrawback(values) {
  if (values.attack_pattern === "boomerang") return "self_stagger";
  if (values.attack_pattern === "area_blast") return "cooldown_lock";
  if (values.attack_pattern === "piercing") return "narrow_arc";
  if (values.attack_pattern === "straight_projectile") return "low_impact";
  if (values.attack_speed > 1.6) return "low_impact";
  if (values.range > 700 && ["straight_projectile", "boomerang", "piercing"].includes(values.attack_pattern)) {
    return "slow_projectile";
  }
  return "slow_recovery";
}

function enforceSemanticCompatibility(values, corrections) {
  const pattern = values.attack_pattern;
  const ability = values.special_ability;
  const incompatibleAbility =
    (ability === "return_strike" && pattern !== "boomerang") ||
    (ability === "splash_wave" && pattern !== "area_blast") ||
    (ability === "shield_break" && pattern !== "piercing") ||
    (ability === "knockback_burst" && !["melee_slash", "area_blast"].includes(pattern)) ||
    (ability === "chain_arc" && values.element !== "electric");
  if (incompatibleAbility) {
    corrections.push(`compatibility: ${ability} removed from ${pattern}/${values.element}`);
    values.special_ability = "none";
  }

  const expectedStatus = { fire: "burn", ice: "freeze", electric: "shock" }[values.element] ?? "none";
  if (["burn", "freeze", "shock"].includes(values.status_effect) && values.status_effect !== expectedStatus) {
    corrections.push(`compatibility: status_effect ${values.status_effect} normalized to ${expectedStatus} for ${values.element}`);
    values.status_effect = expectedStatus;
  }

  const expectedMaterial = {
    normal: "forged_metal",
    fire: "ember_metal",
    ice: "frozen_metal",
    electric: "charged_metal",
  }[values.element] ?? "forged_metal";
  if (values.visual_material !== "ink" && values.visual_material !== expectedMaterial) {
    corrections.push(`compatibility: visual_material normalized to ${expectedMaterial} for ${values.element}`);
    values.visual_material = expectedMaterial;
  }

  if (values.drawback === "slow_projectile" && values.delivery === "held") {
    values.drawback = matchingDrawback(values);
    corrections.push(`compatibility: slow_projectile replaced because ${pattern} has no projectile`);
  }
}

function enforceDrawback(values, corrections) {
  switch (values.drawback) {
    case "slow_recovery":
      if (values.attack_speed > 1.2) {
        corrections.push(`drawback: slow_recovery capped attack_speed ${values.attack_speed} -> 1.20`);
        values.attack_speed = 1.2;
      }
      break;
    case "short_reach":
      if (values.range > 180) {
        corrections.push(`drawback: short_reach capped range ${values.range} -> 180`);
        values.range = 180;
      }
      break;
    case "slow_projectile":
      if (values.projectile_speed > 420) {
        corrections.push(`drawback: slow_projectile capped projectile_speed ${values.projectile_speed} -> 420`);
        values.projectile_speed = 420;
      }
      break;
    case "low_impact":
      if (values.damage > 32) {
        corrections.push(`drawback: low_impact capped damage ${values.damage} -> 32`);
        values.damage = 32;
      }
      break;
    case "self_stagger":
      if (values.attack_speed > 1) {
        corrections.push(`drawback: self_stagger capped attack_speed ${values.attack_speed} -> 1.00`);
        values.attack_speed = 1;
      }
      break;
    case "narrow_arc":
      if (values.attack_pattern !== "piercing") {
        values.drawback = matchingDrawback(values);
        corrections.push("drawback: narrow_arc replaced because attack is not piercing");
        enforceDrawback(values, corrections);
      }
      break;
    case "cooldown_lock":
      if (values.attack_speed > 0.85) {
        corrections.push(`drawback: cooldown_lock capped attack_speed ${values.attack_speed} -> 0.85`);
        values.attack_speed = 0.85;
      }
      break;
    default:
      break;
  }
}

function reduceToBudget(values, corrections, cap) {
  let current = calculatePower(values);
  if (current.total > cap && values.damage > 1) {
    const before = values.damage;
    values.damage = Math.max(1, values.damage - Math.ceil((current.total - cap) / 0.55));
    corrections.push(`budget: damage reduced ${before} -> ${values.damage}`);
    current = calculatePower(values);
  }
  if (current.total > cap && values.attack_speed > 0.2) {
    const before = values.attack_speed;
    const target = values.attack_speed - (current.total - cap) / 10;
    values.attack_speed = Math.max(0.2, Math.floor(target / 0.05) * 0.05);
    corrections.push(`budget: attack_speed reduced ${before.toFixed(2)} -> ${values.attack_speed.toFixed(2)}`);
    current = calculatePower(values);
  }
  if (current.total > cap && values.range > 40) {
    const before = values.range;
    values.range = Math.max(40, Math.floor(values.range - (current.total - cap) * 45));
    corrections.push(`budget: range reduced ${before} -> ${values.range}`);
    current = calculatePower(values);
  }
  if (
    current.total > cap &&
    values.delivery !== "held" &&
    values.projectile_speed > 180
  ) {
    const before = values.projectile_speed;
    values.projectile_speed = Math.max(
      180,
      Math.floor(values.projectile_speed - (current.total - cap) * 200),
    );
    corrections.push(`budget: projectile_speed reduced ${before} -> ${values.projectile_speed}`);
    current = calculatePower(values);
  }
  if (current.total > cap && values.attack_pattern === "boomerang" && values.return_speed > 180) {
    const before = values.return_speed;
    values.return_speed = Math.max(180, Math.floor(values.return_speed - (current.total - cap) * 250));
    corrections.push(`budget: return_speed reduced ${before} -> ${values.return_speed}`);
    current = calculatePower(values);
  }
  if (current.total > cap && values.attack_pattern === "area_blast" && values.area_radius > 40) {
    const before = values.area_radius;
    values.area_radius = Math.max(40, Math.floor(values.area_radius - (current.total - cap) * 30));
    corrections.push(`budget: area_radius reduced ${before} -> ${values.area_radius}`);
    current = calculatePower(values);
  }
  if (current.total > cap && values.attack_pattern === "piercing" && values.pierce_count > 1) {
    const before = values.pierce_count;
    values.pierce_count = Math.max(1, values.pierce_count - Math.ceil((current.total - cap) / 4));
    corrections.push(`budget: pierce_count reduced ${before} -> ${values.pierce_count}`);
    current = calculatePower(values);
  }
  for (const field of ["special_ability", "status_effect"]) {
    if (current.total > cap && values[field] !== "none") {
      corrections.push(`budget: ${field} ${values[field]} removed`);
      values[field] = "none";
      current = calculatePower(values);
    }
  }
  if (current.total > cap && values.element !== "normal") {
    corrections.push(`budget: element ${values.element} removed as final capability trim`);
    values.element = "normal";
    values.visual_material = "forged_metal";
    current = calculatePower(values);
  }
  if (current.total > cap) {
    Object.assign(values, {
      damage: 1,
      attack_speed: 0.2,
      range: 40,
      projectile_speed: 180,
      area_radius: 40,
      pierce_count: 1,
      special_ability: "none",
      status_effect: "none",
      element: "normal",
      visual_material: "forged_metal",
    });
    values.drawback = matchingDrawback(values);
    corrections.push("budget: safe minimum fallback applied");
    current = calculatePower(values);
  }
  return current;
}

export function balanceWeaponSpec(raw, maximumPowerScore = MAX_POWER) {
  const cap = Math.max(1, Math.min(MAX_POWER, Math.trunc(Number(maximumPowerScore) || MAX_POWER)));
  const repaired = repairWeaponSpec(raw);
  const values = repaired.values;
  const corrections = [...repaired.corrections];
  const before = calculatePower(values);
  enforceSemanticCompatibility(values, corrections);
  if (hasStrongCapability(values) && values.drawback === "none") {
    values.drawback = matchingDrawback(values);
    corrections.push(`budget: strong capability added tradeoff '${values.drawback}'`);
  }
  enforceDrawback(values, corrections);
  const after = reduceToBudget(values, corrections, cap);
  values.power_score = Math.ceil(after.total);
  const finalPower = calculatePower(values);
  return {
    values,
    before,
    after: finalPower,
    corrections,
    within_budget: finalPower.total <= cap && values.power_score === Math.ceil(finalPower.total),
    maximum_power_score: cap,
  };
}

export function schemaValidationErrors(spec) {
  return validateWeaponSchema(spec);
}

export function runtimeAllowListErrors(spec) {
  if (!spec || typeof spec !== "object" || Array.isArray(spec)) return ["root"];
  const errors = [];
  for (const field of Object.keys(ALLOW_LISTS)) {
    if (!ALLOW_LISTS[field].includes(spec[field])) errors.push(field);
  }
  return errors;
}

export function isSafeWeaponSpec(spec, maximumPowerScore = MAX_POWER) {
  if (schemaValidationErrors(spec).length > 0 || runtimeAllowListErrors(spec).length > 0) return false;
  const power = calculatePower(spec);
  const cap = Math.max(1, Math.min(MAX_POWER, Math.trunc(Number(maximumPowerScore) || MAX_POWER)));
  return power.total <= cap && spec.power_score === Math.ceil(power.total);
}

export function fallbackWeaponSpec() {
  return balanceWeaponSpec(DEFAULT_SPEC).values;
}

export function baseProfile(pattern = "melee_slash") {
  const selected = ALLOW_LISTS.attack_pattern.includes(pattern) ? pattern : "melee_slash";
  const common = {
    name: "Normal Sketchblade",
    weapon_class: "melee",
    weapon_form: "generic",
    delivery: "held",
    trajectory: "direct",
    impact: "contact",
    area_effect: "none",
    attack_pattern: selected,
    element: "normal",
    damage: 36,
    attack_speed: 1,
    range: 132,
    special_ability: "knockback_burst",
    status_effect: "knockback",
    drawback: "slow_recovery",
    visual_material: "forged_metal",
    power_score: 1,
    projectile_speed: 560,
    area_radius: 120,
    pierce_count: 1,
    return_speed: 680,
  };
  const variants = {
    straight_projectile: {
      weapon_class: "ranged",
      delivery: "projectile",
      damage: 26,
      attack_speed: 1.3,
      range: 675,
      special_ability: "none",
      status_effect: "none",
      drawback: "low_impact",
      projectile_speed: 620,
    },
    boomerang: {
      weapon_class: "ranged",
      weapon_form: "boomerang",
      delivery: "thrown",
      trajectory: "returning",
      damage: 30,
      attack_speed: 0.95,
      range: 620,
      special_ability: "return_strike",
      status_effect: "none",
      drawback: "self_stagger",
      projectile_speed: 520,
      return_speed: 760,
    },
    area_blast: {
      weapon_class: "melee",
      area_effect: "explosion",
      damage: 34,
      attack_speed: 0.7,
      range: 220,
      special_ability: "splash_wave",
      status_effect: "none",
      drawback: "cooldown_lock",
      area_radius: 165,
    },
    piercing: {
      weapon_class: "ranged",
      delivery: "projectile",
      impact: "piercing",
      damage: 29,
      attack_speed: 1.05,
      range: 700,
      special_ability: "shield_break",
      status_effect: "none",
      drawback: "narrow_arc",
      projectile_speed: 720,
      pierce_count: 3,
    },
  };
  return Object.assign(common, variants[selected] ?? {});
}
