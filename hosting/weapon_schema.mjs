// Runtime representation of schema/weapon_spec.schema.json. Parity tests fail if
// the checked-in portable Draft 2020-12 contract diverges from this server gate.
export const WEAPON_SPEC_SCHEMA = Object.freeze({
  $schema: "https://json-schema.org/draft/2020-12/schema",
  type: "object",
  additionalProperties: false,
  required: [
    "name", "weapon_class", "weapon_form", "delivery", "trajectory", "impact",
    "area_effect", "attack_pattern", "element", "damage", "attack_speed",
    "range", "special_ability", "status_effect", "drawback", "visual_material",
    "power_score", "projectile_speed", "area_radius", "pierce_count", "return_speed",
  ],
  properties: {
    name: { type: "string", minLength: 1, maxLength: 48 },
    weapon_class: { enum: ["melee", "ranged"] },
    weapon_form: { enum: ["generic", "sword", "bow", "grenade", "boomerang", "spear"] },
    delivery: { enum: ["held", "projectile", "thrown"] },
    trajectory: { enum: ["direct", "arc", "returning"] },
    impact: { enum: ["contact", "delayed_or_contact", "piercing"] },
    area_effect: { enum: ["none", "explosion"] },
    attack_pattern: { enum: ["melee_slash", "straight_projectile", "boomerang", "area_blast", "piercing"] },
    element: { enum: ["normal", "fire", "ice", "electric"] },
    damage: { type: "integer", minimum: 1, maximum: 100 },
    attack_speed: { type: "number", minimum: 0.2, maximum: 3 },
    range: { type: "number", minimum: 40, maximum: 900 },
    special_ability: { enum: ["none", "knockback_burst", "chain_arc", "return_strike", "splash_wave", "shield_break"] },
    status_effect: { enum: ["none", "burn", "freeze", "shock", "knockback"] },
    drawback: { enum: ["none", "slow_recovery", "short_reach", "slow_projectile", "low_impact", "self_stagger", "narrow_arc", "cooldown_lock"] },
    visual_material: { enum: ["ink", "forged_metal", "ember_metal", "frozen_metal", "charged_metal"] },
    power_score: { type: "integer", minimum: 1, maximum: 100 },
    projectile_speed: { type: "number", minimum: 180, maximum: 900 },
    area_radius: { type: "number", minimum: 40, maximum: 240 },
    pierce_count: { type: "integer", minimum: 1, maximum: 6 },
    return_speed: { type: "number", minimum: 180, maximum: 1000 },
  },
});

function valueMatchesType(value, type) {
  if (type === "object") return Boolean(value && typeof value === "object" && !Array.isArray(value));
  if (type === "string") return typeof value === "string";
  if (type === "number") return typeof value === "number" && Number.isFinite(value);
  if (type === "integer") return typeof value === "number" && Number.isFinite(value) && Number.isInteger(value);
  return true;
}

// The project schema intentionally uses a small, auditable Draft 2020-12 subset:
// type, required, properties, additionalProperties, enum, numeric bounds and
// string length. This evaluator enforces every keyword present in that schema.
export function validateSchema(schema, value, path = "$") {
  const errors = [];
  if (schema.type && !valueMatchesType(value, schema.type)) {
    return [`${path}:type:${schema.type}`];
  }
  if (schema.enum && !schema.enum.includes(value)) errors.push(`${path}:enum`);
  if (typeof value === "string") {
    const length = [...value].length;
    if (schema.minLength !== undefined && length < schema.minLength) errors.push(`${path}:minLength`);
    if (schema.maxLength !== undefined && length > schema.maxLength) errors.push(`${path}:maxLength`);
  }
  if (typeof value === "number" && Number.isFinite(value)) {
    if (schema.minimum !== undefined && value < schema.minimum) errors.push(`${path}:minimum`);
    if (schema.maximum !== undefined && value > schema.maximum) errors.push(`${path}:maximum`);
  }
  if (value && typeof value === "object" && !Array.isArray(value) && schema.properties) {
    const keys = Object.keys(value);
    for (const required of schema.required ?? []) {
      if (!Object.hasOwn(value, required)) errors.push(`${path}.${required}:required`);
    }
    if (schema.additionalProperties === false) {
      for (const key of keys) {
        if (!Object.hasOwn(schema.properties, key)) errors.push(`${path}.${key}:additionalProperties`);
      }
    }
    for (const [key, childSchema] of Object.entries(schema.properties)) {
      if (Object.hasOwn(value, key)) errors.push(...validateSchema(childSchema, value[key], `${path}.${key}`));
    }
  }
  return errors;
}

export function validateWeaponSchema(value) {
  return validateSchema(WEAPON_SPEC_SCHEMA, value);
}
