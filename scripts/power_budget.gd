class_name PowerBudget
extends RefCounted

const MAX_POWER := 100
const PATTERN_COST := {
	"melee_slash": 0.0, "straight_projectile": 9.0, "boomerang": 14.0,
	"area_blast": 18.0, "piercing": 17.0,
}
const ELEMENT_COST := {"normal": 0.0, "fire": 6.0, "ice": 9.0, "electric": 11.0}
const SPECIAL_COST := {
	"none": 0.0, "knockback_burst": 8.0, "chain_arc": 12.0,
	"return_strike": 10.0, "splash_wave": 10.0, "shield_break": 10.0,
}
const STATUS_COST := {"none": 0.0, "burn": 6.0, "freeze": 8.0, "shock": 10.0, "knockback": 4.0}
const DRAWBACK_CREDIT := {
	"none": 0.0, "slow_recovery": 12.0, "short_reach": 10.0,
	"slow_projectile": 9.0, "low_impact": 9.0, "self_stagger": 14.0,
	"narrow_arc": 8.0, "cooldown_lock": 16.0,
}


static func balance(raw: Dictionary) -> Dictionary:
	var repaired := WeaponSpec.repair_dict(raw)
	var values: Dictionary = repaired.values
	var notes: Array[String] = []
	notes.assign(repaired.corrections)
	var before := calculate(values)

	if _has_strong_capability(values) and values.drawback == "none":
		values.drawback = _matching_drawback(values)
		notes.append("budget: strong capability added tradeoff '%s'" % values.drawback)

	var current := calculate(values)
	if float(current.total) > MAX_POWER:
		var old_damage: int = values.damage
		values.damage = maxi(1, int(floor(values.damage * 0.82)))
		notes.append("budget: damage reduced %d -> %d" % [old_damage, values.damage])
		current = calculate(values)
	if float(current.total) > MAX_POWER:
		var old_speed: float = values.attack_speed
		values.attack_speed = maxf(0.2, snappedf(values.attack_speed * 0.84, 0.05))
		notes.append("budget: attack_speed reduced %.2f -> %.2f" % [old_speed, values.attack_speed])
		current = calculate(values)
	if float(current.total) > MAX_POWER:
		var old_range: float = values.range
		values.range = maxf(40.0, snappedf(values.range * 0.82, 1.0))
		notes.append("budget: range reduced %.0f -> %.0f" % [old_range, values.range])
		current = calculate(values)
	if float(current.total) > MAX_POWER:
		values.drawback = "cooldown_lock"
		notes.append("budget: cooldown_lock added to pay remaining cost")
		current = calculate(values)
	if float(current.total) > MAX_POWER:
		var remaining := float(current.total) - MAX_POWER
		values.damage = maxi(1, values.damage - int(ceil(remaining / 0.55)))
		notes.append("budget: final damage clamp applied")
		current = calculate(values)

	values.power_score = clampi(int(ceil(float(current.total))), 1, MAX_POWER)
	current = calculate(values)
	current.total = values.power_score
	return {
		"values": values,
		"before": before,
		"after": current,
		"corrections": notes,
		"within_budget": values.power_score <= MAX_POWER,
	}


static func calculate(values: Dictionary) -> Dictionary:
	var parts := {
		"damage": float(values.get("damage", 24)) * 0.55,
		"attack_speed": float(values.get("attack_speed", 1.0)) * 10.0,
		"range": float(values.get("range", 100.0)) / 45.0,
		"attack_pattern": float(PATTERN_COST.get(values.get("attack_pattern", "melee_slash"), 0.0)),
		"element": float(ELEMENT_COST.get(values.get("element", "normal"), 0.0)),
		"special_ability": float(SPECIAL_COST.get(values.get("special_ability", "none"), 0.0)),
		"status_effect": float(STATUS_COST.get(values.get("status_effect", "none"), 0.0)),
		"projectile_speed": 0.0,
		"area_radius": 0.0,
		"piercing": 0.0,
		"drawback_credit": -float(DRAWBACK_CREDIT.get(values.get("drawback", "none"), 0.0)),
	}
	if values.get("attack_pattern") in ["straight_projectile", "boomerang", "piercing"]:
		parts.projectile_speed = float(values.get("projectile_speed", 560.0)) / 200.0
	if values.get("attack_pattern") == "area_blast":
		parts.area_radius = float(values.get("area_radius", 120.0)) / 30.0
	if values.get("attack_pattern") == "piercing":
		parts.piercing = float(values.get("pierce_count", 1)) * 4.0
	var total := 0.0
	for value: float in parts.values(): total += value
	parts.total = snappedf(maxf(total, 1.0), 0.1)
	return parts


static func _has_strong_capability(values: Dictionary) -> bool:
	return (
		values.attack_pattern in ["boomerang", "area_blast", "piercing"]
		or values.element != "normal" or values.special_ability != "none"
		or values.damage > 45 or values.attack_speed > 1.6 or values.range > 700.0
		or values.area_radius > 130.0 or values.pierce_count > 2
	)


static func _matching_drawback(values: Dictionary) -> String:
	match values.attack_pattern:
		"boomerang": return "self_stagger"
		"area_blast": return "cooldown_lock"
		"piercing": return "narrow_arc"
		"straight_projectile": return "low_impact"
	if values.attack_speed > 1.6: return "low_impact"
	if values.range > 700.0: return "slow_projectile"
	return "slow_recovery"
