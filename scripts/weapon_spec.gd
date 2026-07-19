class_name WeaponSpec
extends RefCounted

const WEAPON_CLASSES: PackedStringArray = ["melee", "ranged"]
const ATTACK_PATTERNS: PackedStringArray = [
	"melee_slash", "straight_projectile", "boomerang", "area_blast", "piercing"
]
const M0_ATTACK_PATTERNS: PackedStringArray = ["melee_slash", "straight_projectile"]
const ELEMENTS: PackedStringArray = ["normal", "fire", "ice", "electric"]
const SPECIAL_ABILITIES: PackedStringArray = ["none", "knockback_burst", "front_shield", "chain_arc"]
const STATUS_EFFECTS: PackedStringArray = ["none", "burn", "freeze", "shock", "knockback"]
const DRAWBACKS: PackedStringArray = ["none", "slow_recovery", "short_reach", "slow_projectile", "low_impact"]
const MATERIALS: PackedStringArray = ["ink", "forged_metal", "ember_metal", "frozen_metal", "charged_metal"]

var display_name: String = "Practice Sketchblade"
var weapon_class: String = "melee"
var attack_pattern: String = "melee_slash"
var element: String = "normal"
var damage: int = 24
var attack_speed: float = 1.1
var attack_range: float = 118.0
var special_ability: String = "knockback_burst"
var status_effect: String = "knockback"
var drawback: String = "short_reach"
var visual_material: String = "ink"
var power_score: int = 62

static func from_dict(data: Dictionary) -> WeaponSpec:
	var spec := WeaponSpec.new()
	spec.display_name = _bounded_name(str(data.get("name", spec.display_name)))
	spec.weapon_class = _allowed(str(data.get("weapon_class", spec.weapon_class)), WEAPON_CLASSES, "melee")
	spec.attack_pattern = _allowed(str(data.get("attack_pattern", spec.attack_pattern)), ATTACK_PATTERNS, "melee_slash")
	spec.element = _allowed(str(data.get("element", spec.element)), ELEMENTS, "normal")
	spec.damage = clampi(int(data.get("damage", spec.damage)), 1, 100)
	spec.attack_speed = clampf(float(data.get("attack_speed", spec.attack_speed)), 0.2, 3.0)
	spec.attack_range = clampf(float(data.get("range", spec.attack_range)), 40.0, 900.0)
	spec.special_ability = _allowed(str(data.get("special_ability", spec.special_ability)), SPECIAL_ABILITIES, "none")
	spec.status_effect = _allowed(str(data.get("status_effect", spec.status_effect)), STATUS_EFFECTS, "none")
	spec.drawback = _allowed(str(data.get("drawback", spec.drawback)), DRAWBACKS, "none")
	spec.visual_material = _allowed(str(data.get("visual_material", spec.visual_material)), MATERIALS, "ink")
	spec.power_score = clampi(int(data.get("power_score", spec.power_score)), 1, 100)

	# M0 cannot execute later attack modules, so degrade them safely.
	if spec.attack_pattern not in M0_ATTACK_PATTERNS:
		spec.attack_pattern = "melee_slash"
		spec.weapon_class = "melee"
	if spec.attack_pattern == "straight_projectile":
		spec.weapon_class = "ranged"
	else:
		spec.weapon_class = "melee"
	return spec


static func fallback() -> WeaponSpec:
	return WeaponSpec.new()


func to_dict() -> Dictionary:
	return {
		"name": display_name,
		"weapon_class": weapon_class,
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
	}


func is_m0_valid() -> bool:
	return (
		not display_name.is_empty()
		and display_name.length() <= 48
		and weapon_class in WEAPON_CLASSES
		and attack_pattern in M0_ATTACK_PATTERNS
		and element in ELEMENTS
		and damage >= 1 and damage <= 100
		and attack_speed >= 0.2 and attack_speed <= 3.0
		and attack_range >= 40.0 and attack_range <= 900.0
		and special_ability in SPECIAL_ABILITIES
		and status_effect in STATUS_EFFECTS
		and drawback in DRAWBACKS
		and visual_material in MATERIALS
		and power_score >= 1 and power_score <= 100
	)


func attack_label() -> String:
	if attack_pattern == "straight_projectile":
		return "Straight projectile"
	return "Melee slash"


func effect_label() -> String:
	return "%s / %s" % [_title_case(element), _title_case(status_effect)]


func weakness_label() -> String:
	return _title_case(drawback)


static func _allowed(value: String, allowed: PackedStringArray, fallback_value: String) -> String:
	var normalized := value.strip_edges().to_lower()
	return normalized if normalized in allowed else fallback_value


static func _bounded_name(value: String) -> String:
	var clean := value.strip_edges()
	if clean.is_empty():
		return "Practice Sketchblade"
	return clean.left(48)


static func _title_case(value: String) -> String:
	return value.replace("_", " ").capitalize()

