class_name WeaponSpec
extends RefCounted

const WEAPON_CLASSES: PackedStringArray = ["melee", "ranged"]
const WEAPON_FORMS: PackedStringArray = ["generic", "sword", "bow", "grenade", "boomerang", "spear"]
const DELIVERIES: PackedStringArray = ["held", "projectile", "thrown"]
const TRAJECTORIES: PackedStringArray = ["direct", "arc", "returning"]
const IMPACTS: PackedStringArray = ["contact", "delayed_or_contact", "piercing"]
const AREA_EFFECTS: PackedStringArray = ["none", "explosion"]
const ATTACK_PATTERNS: PackedStringArray = [
	"melee_slash", "straight_projectile", "boomerang", "area_blast", "piercing"
]
const ELEMENTS: PackedStringArray = ["normal", "fire", "ice", "electric"]
const SPECIAL_ABILITIES: PackedStringArray = [
	"none", "knockback_burst", "chain_arc", "return_strike", "splash_wave", "shield_break"
]
const STATUS_EFFECTS: PackedStringArray = ["none", "burn", "freeze", "shock", "knockback"]
const DRAWBACKS: PackedStringArray = [
	"none", "slow_recovery", "short_reach", "slow_projectile", "low_impact",
	"self_stagger", "narrow_arc", "cooldown_lock"
]
const MATERIALS: PackedStringArray = [
	"ink", "forged_metal", "ember_metal", "frozen_metal", "charged_metal"
]

var display_name := "Practice Sketchblade"
var weapon_class := "melee"
var weapon_form := "generic"
var delivery := "held"
var trajectory := "direct"
var impact := "contact"
var area_effect := "none"
var attack_pattern := "melee_slash"
var element := "normal"
var damage := 24
var attack_speed := 1.1
var attack_range := 118.0
var special_ability := "none"
var status_effect := "none"
var drawback := "short_reach"
var visual_material := "ink"
var power_score := 40
var projectile_speed := 560.0
var area_radius := 120.0
var pierce_count := 1
var return_speed := 680.0
var corrections: Array[String] = []
var budget_breakdown: Dictionary = {}


static func from_dict(data: Dictionary) -> WeaponSpec:
	var repaired := repair_dict(data)
	var values: Dictionary = repaired.values
	var spec := WeaponSpec.new()
	spec.display_name = values.name
	spec.weapon_class = values.weapon_class
	spec.weapon_form = values.weapon_form
	spec.delivery = values.delivery
	spec.trajectory = values.trajectory
	spec.impact = values.impact
	spec.area_effect = values.area_effect
	spec.attack_pattern = values.attack_pattern
	spec.element = values.element
	spec.damage = values.damage
	spec.attack_speed = values.attack_speed
	spec.attack_range = values.range
	spec.special_ability = values.special_ability
	spec.status_effect = values.status_effect
	spec.drawback = values.drawback
	spec.visual_material = values.visual_material
	spec.power_score = values.power_score
	spec.projectile_speed = values.projectile_speed
	spec.area_radius = values.area_radius
	spec.pierce_count = values.pierce_count
	spec.return_speed = values.return_speed
	spec.corrections.assign(repaired.corrections)
	return spec


static func repair_dict(data: Dictionary) -> Dictionary:
	var notes: Array[String] = []
	var defaults := WeaponSpec.new().to_dict()
	var output := defaults.duplicate(true)
	for key: Variant in data.keys():
		if key not in defaults: notes.append("%s: unknown field discarded" % str(key))
	output.name = _repair_name(data.get("name"), defaults.name, notes)
	output.attack_pattern = _repair_enum("attack_pattern", data.get("attack_pattern"), ATTACK_PATTERNS, defaults.attack_pattern, notes)
	output.weapon_form = _repair_enum("weapon_form", data.get("weapon_form"), WEAPON_FORMS, defaults.weapon_form, notes)
	var semantics := canonical_semantics(output.weapon_form, output.attack_pattern)
	for field: String in ["attack_pattern", "delivery", "trajectory", "impact", "area_effect"]:
		var allowed: PackedStringArray = {
			"attack_pattern": ATTACK_PATTERNS,
			"delivery": DELIVERIES,
			"trajectory": TRAJECTORIES,
			"impact": IMPACTS,
			"area_effect": AREA_EFFECTS,
		}[field]
		var repaired := _repair_enum(field, data.get(field), allowed, str(semantics[field]), notes)
		output[field] = repaired
		if repaired != semantics[field]:
			notes.append("%s: normalized to %s for %s/%s" % [field, semantics[field], output.weapon_form, semantics.attack_pattern])
			output[field] = semantics[field]
	var expected_class := "melee" if output.delivery == "held" else "ranged"
	output.weapon_class = _repair_enum("weapon_class", data.get("weapon_class"), WEAPON_CLASSES, expected_class, notes)
	if output.weapon_class != expected_class:
		notes.append("weapon_class: normalized to %s for %s" % [expected_class, output.attack_pattern])
		output.weapon_class = expected_class
	output.element = _repair_enum("element", data.get("element"), ELEMENTS, defaults.element, notes)
	output.damage = _repair_int("damage", data.get("damage"), defaults.damage, 1, 100, notes)
	output.attack_speed = _repair_float("attack_speed", data.get("attack_speed"), defaults.attack_speed, 0.2, 3.0, notes)
	output.range = _repair_float("range", data.get("range"), defaults.range, 40.0, 900.0, notes)
	output.special_ability = _repair_enum("special_ability", data.get("special_ability"), SPECIAL_ABILITIES, defaults.special_ability, notes)
	output.status_effect = _repair_enum("status_effect", data.get("status_effect"), STATUS_EFFECTS, defaults.status_effect, notes)
	output.drawback = _repair_enum("drawback", data.get("drawback"), DRAWBACKS, defaults.drawback, notes)
	output.visual_material = _repair_enum("visual_material", data.get("visual_material"), MATERIALS, defaults.visual_material, notes)
	output.power_score = _repair_int("power_score", data.get("power_score"), defaults.power_score, 1, 100, notes)
	output.projectile_speed = _repair_float("projectile_speed", data.get("projectile_speed"), defaults.projectile_speed, 180.0, 900.0, notes)
	output.area_radius = _repair_float("area_radius", data.get("area_radius"), defaults.area_radius, 40.0, 240.0, notes)
	output.pierce_count = _repair_int("pierce_count", data.get("pierce_count"), defaults.pierce_count, 1, 6, notes)
	output.return_speed = _repair_float("return_speed", data.get("return_speed"), defaults.return_speed, 180.0, 1000.0, notes)
	return {"values": output, "corrections": notes}


static func fallback() -> WeaponSpec:
	return WeaponSpec.new()


func to_dict() -> Dictionary:
	return {
		"name": display_name,
		"weapon_class": weapon_class,
		"weapon_form": weapon_form,
		"delivery": delivery,
		"trajectory": trajectory,
		"impact": impact,
		"area_effect": area_effect,
		"attack_pattern": attack_pattern,
		"element": element,
		"damage": damage,
		"attack_speed": attack_speed,
		"range": attack_range,
		"special_ability": special_ability,
		"status_effect": status_effect,
		"drawback": drawback,
		"visual_material": visual_material,
		"power_score": power_score,
		"projectile_speed": projectile_speed,
		"area_radius": area_radius,
		"pierce_count": pierce_count,
		"return_speed": return_speed,
	}


func validation_errors() -> Array[String]:
	var errors: Array[String] = []
	if display_name.is_empty() or display_name.length() > 48: errors.append("name")
	if weapon_class not in WEAPON_CLASSES: errors.append("weapon_class")
	if weapon_form not in WEAPON_FORMS: errors.append("weapon_form")
	if delivery not in DELIVERIES: errors.append("delivery")
	if trajectory not in TRAJECTORIES: errors.append("trajectory")
	if impact not in IMPACTS: errors.append("impact")
	if area_effect not in AREA_EFFECTS: errors.append("area_effect")
	if attack_pattern not in ATTACK_PATTERNS: errors.append("attack_pattern")
	if element not in ELEMENTS: errors.append("element")
	if damage < 1 or damage > 100: errors.append("damage")
	if attack_speed < 0.2 or attack_speed > 3.0: errors.append("attack_speed")
	if attack_range < 40.0 or attack_range > 900.0: errors.append("range")
	if special_ability not in SPECIAL_ABILITIES: errors.append("special_ability")
	if status_effect not in STATUS_EFFECTS: errors.append("status_effect")
	if drawback not in DRAWBACKS: errors.append("drawback")
	if visual_material not in MATERIALS: errors.append("visual_material")
	if power_score < 1 or power_score > 100: errors.append("power_score")
	if projectile_speed < 180.0 or projectile_speed > 900.0: errors.append("projectile_speed")
	if area_radius < 40.0 or area_radius > 240.0: errors.append("area_radius")
	if pierce_count < 1 or pierce_count > 6: errors.append("pierce_count")
	if return_speed < 180.0 or return_speed > 1000.0: errors.append("return_speed")
	return errors


func is_valid() -> bool:
	return validation_errors().is_empty()


func is_m0_valid() -> bool:
	return is_valid()


func attack_label() -> String:
	return _title_case(attack_pattern)


func effect_label() -> String:
	return "%s / %s" % [_title_case(element), _title_case(status_effect)]


func weakness_label() -> String:
	return _title_case(drawback)


func has_strong_capability() -> bool:
	return (
		attack_pattern in ["boomerang", "area_blast", "piercing"]
		or element != "normal"
		or special_ability != "none"
		or damage > 45 or attack_speed > 1.6 or attack_range > 700.0
		or area_radius > 130.0 or pierce_count > 2
		or delivery == "thrown" or trajectory != "direct"
		or impact != "contact" or area_effect != "none"
	)


static func canonical_semantics(form: String = "generic", pattern: String = "melee_slash") -> Dictionary:
	var safe_form := form if form in WEAPON_FORMS else "generic"
	var safe_pattern := pattern if pattern in ATTACK_PATTERNS else "melee_slash"
	var by_form := {
		"sword": {"attack_pattern": "melee_slash", "delivery": "held", "trajectory": "direct", "impact": "contact", "area_effect": "none"},
		"bow": {"attack_pattern": "straight_projectile", "delivery": "projectile", "trajectory": "direct", "impact": "contact", "area_effect": "none"},
		"grenade": {"attack_pattern": "area_blast", "delivery": "thrown", "trajectory": "arc", "impact": "delayed_or_contact", "area_effect": "explosion"},
		"boomerang": {"attack_pattern": "boomerang", "delivery": "thrown", "trajectory": "returning", "impact": "contact", "area_effect": "none"},
		"spear": {"attack_pattern": "piercing", "delivery": "projectile", "trajectory": "direct", "impact": "piercing", "area_effect": "none"},
	}
	var by_pattern := {
		"melee_slash": {"attack_pattern": "melee_slash", "delivery": "held", "trajectory": "direct", "impact": "contact", "area_effect": "none"},
		"straight_projectile": {"attack_pattern": "straight_projectile", "delivery": "projectile", "trajectory": "direct", "impact": "contact", "area_effect": "none"},
		"boomerang": {"attack_pattern": "boomerang", "delivery": "thrown", "trajectory": "returning", "impact": "contact", "area_effect": "none"},
		"area_blast": {"attack_pattern": "area_blast", "delivery": "held", "trajectory": "direct", "impact": "contact", "area_effect": "explosion"},
		"piercing": {"attack_pattern": "piercing", "delivery": "projectile", "trajectory": "direct", "impact": "piercing", "area_effect": "none"},
	}
	var result: Dictionary = (by_form.get(safe_form, by_pattern[safe_pattern]) as Dictionary).duplicate(true)
	result.weapon_form = safe_form
	return result


static func _repair_name(value: Variant, fallback_value: String, notes: Array[String]) -> String:
	if value == null:
		notes.append("name: missing; default applied")
		return fallback_value
	var clean := str(value).strip_edges()
	if clean.is_empty():
		notes.append("name: empty; default applied")
		return fallback_value
	if clean.length() > 48:
		notes.append("name: truncated to 48 characters")
	return clean.left(48)


static func _repair_enum(field: String, value: Variant, allowed: PackedStringArray, fallback_value: String, notes: Array[String]) -> String:
	if value == null:
		notes.append("%s: missing; default %s applied" % [field, fallback_value])
		return fallback_value
	var normalized := str(value).strip_edges().to_lower()
	if normalized not in allowed:
		notes.append("%s: unsupported value repaired to %s" % [field, fallback_value])
		return fallback_value
	return normalized


static func _repair_int(field: String, value: Variant, fallback_value: int, minimum: int, maximum: int, notes: Array[String]) -> int:
	if value == null or not (value is int or value is float or str(value).is_valid_int() or str(value).is_valid_float()):
		notes.append("%s: missing or non-numeric; default applied" % field)
		return fallback_value
	if value is float and (is_nan(value) or is_inf(value)):
		notes.append("%s: non-finite; default applied" % field)
		return fallback_value
	var parsed := int(float(value))
	var bounded := clampi(parsed, minimum, maximum)
	if bounded != parsed: notes.append("%s: clamped to %d" % [field, bounded])
	return bounded


static func _repair_float(field: String, value: Variant, fallback_value: float, minimum: float, maximum: float, notes: Array[String]) -> float:
	if value == null or not (value is int or value is float or str(value).is_valid_int() or str(value).is_valid_float()):
		notes.append("%s: missing or non-numeric; default applied" % field)
		return fallback_value
	var parsed := float(value)
	if is_nan(parsed) or is_inf(parsed):
		notes.append("%s: non-finite; default applied" % field)
		return fallback_value
	var bounded := clampf(parsed, minimum, maximum)
	if not is_equal_approx(bounded, parsed): notes.append("%s: clamped to %.2f" % [field, bounded])
	return bounded


static func _title_case(value: String) -> String:
	return value.replace("_", " ").capitalize()
