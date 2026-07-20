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
const DELIVERY_COST := {"held": 0.0, "projectile": 3.0, "thrown": 5.0}
const TRAJECTORY_COST := {"direct": 0.0, "arc": 4.0, "returning": 5.0}
const IMPACT_COST := {"contact": 0.0, "delayed_or_contact": 3.0, "piercing": 4.0}
const AREA_EFFECT_COST := {"none": 0.0, "explosion": 6.0}


static func balance(raw: Dictionary) -> Dictionary:
	var repaired := WeaponSpec.repair_dict(raw)
	var values: Dictionary = repaired.values
	var notes: Array[String] = []
	notes.assign(repaired.corrections)
	var before := calculate(values)
	_enforce_semantic_compatibility(values, notes)

	if _has_strong_capability(values) and values.drawback == "none":
		values.drawback = _matching_drawback(values)
		notes.append("budget: strong capability added tradeoff '%s'" % values.drawback)
	_enforce_drawback(values, notes)

	var current := calculate(values)
	current = _reduce_to_budget(values, notes, current)
	values.power_score = int(ceil(float(current.total)))
	current = calculate(values)
	var score_matches: bool = values.power_score == int(ceil(float(current.total)))
	var within_budget: bool = float(current.total) <= float(MAX_POWER) and score_matches
	return {
		"values": values,
		"before": before,
		"after": current,
		"corrections": notes,
		"within_budget": within_budget,
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
		"delivery": float(DELIVERY_COST.get(values.get("delivery", "held"), 0.0)),
		"trajectory": float(TRAJECTORY_COST.get(values.get("trajectory", "direct"), 0.0)),
		"impact": float(IMPACT_COST.get(values.get("impact", "contact"), 0.0)),
		"area_effect": float(AREA_EFFECT_COST.get(values.get("area_effect", "none"), 0.0)),
		"projectile_speed": 0.0,
		"return_speed": 0.0,
		"area_radius": 0.0,
		"piercing": 0.0,
		"drawback_credit": -float(DRAWBACK_CREDIT.get(values.get("drawback", "none"), 0.0)),
	}
	if values.get("delivery", "held") != "held":
		parts.projectile_speed = float(values.get("projectile_speed", 560.0)) / 200.0
	if values.get("attack_pattern") == "boomerang":
		parts.return_speed = float(values.get("return_speed", 680.0)) / 250.0
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
		or values.delivery == "thrown" or values.trajectory != "direct"
		or values.impact != "contact" or values.area_effect != "none"
	)


static func _matching_drawback(values: Dictionary) -> String:
	match values.attack_pattern:
		"boomerang": return "self_stagger"
		"area_blast": return "cooldown_lock"
		"piercing": return "narrow_arc"
		"straight_projectile": return "low_impact"
	if values.attack_speed > 1.6: return "low_impact"
	if values.range > 700.0 and values.attack_pattern in ["straight_projectile", "boomerang", "piercing"]: return "slow_projectile"
	return "slow_recovery"


static func _enforce_semantic_compatibility(values: Dictionary, notes: Array[String]) -> void:
	var pattern: String = values.attack_pattern
	var ability: String = values.special_ability
	var incompatible_ability: bool = (
		(ability == "return_strike" and pattern != "boomerang")
		or (ability == "splash_wave" and pattern != "area_blast")
		or (ability == "shield_break" and pattern != "piercing")
		or (ability == "knockback_burst" and pattern not in ["melee_slash", "area_blast"])
		or (ability == "chain_arc" and values.element != "electric")
	)
	if incompatible_ability:
		notes.append("compatibility: %s removed from %s/%s" % [ability, pattern, values.element])
		values.special_ability = "none"

	var expected_status: String = str({"fire": "burn", "ice": "freeze", "electric": "shock"}.get(values.element, "none"))
	if values.status_effect in ["burn", "freeze", "shock"] and values.status_effect != expected_status:
		notes.append("compatibility: status_effect %s normalized to %s for %s" % [values.status_effect, expected_status, values.element])
		values.status_effect = expected_status

	var expected_material: String = str({
		"normal": "forged_metal", "fire": "ember_metal",
		"ice": "frozen_metal", "electric": "charged_metal",
	}.get(values.element, "forged_metal"))
	if values.visual_material != "ink" and values.visual_material != expected_material:
		notes.append("compatibility: visual_material normalized to %s for %s" % [expected_material, values.element])
		values.visual_material = expected_material

	if values.drawback == "slow_projectile" and values.delivery == "held":
		values.drawback = _matching_drawback(values)
		notes.append("compatibility: slow_projectile replaced because %s has no projectile" % pattern)


static func _enforce_drawback(values: Dictionary, notes: Array[String]) -> void:
	match values.drawback:
		"slow_recovery":
			if values.attack_speed > 1.2:
				var old_speed: float = values.attack_speed
				values.attack_speed = 1.2
				notes.append("drawback: slow_recovery capped attack_speed %.2f -> 1.20" % old_speed)
		"short_reach":
			if values.range > 180.0:
				var old_range: float = values.range
				values.range = 180.0
				notes.append("drawback: short_reach capped range %.0f -> 180" % old_range)
		"slow_projectile":
			if values.projectile_speed > 420.0:
				var old_projectile_speed: float = values.projectile_speed
				values.projectile_speed = 420.0
				notes.append("drawback: slow_projectile capped projectile_speed %.0f -> 420" % old_projectile_speed)
		"low_impact":
			if values.damage > 32:
				var old_damage: int = values.damage
				values.damage = 32
				notes.append("drawback: low_impact capped damage %d -> 32" % old_damage)
		"self_stagger":
			if values.attack_speed > 1.0:
				var old_stagger_speed: float = values.attack_speed
				values.attack_speed = 1.0
				notes.append("drawback: self_stagger capped attack_speed %.2f -> 1.00" % old_stagger_speed)
		"narrow_arc":
			if values.attack_pattern != "piercing":
				values.drawback = _matching_drawback(values)
				notes.append("drawback: narrow_arc replaced because attack is not piercing")
				_enforce_drawback(values, notes)
		"cooldown_lock":
			if values.attack_speed > 0.85:
				var old_lock_speed: float = values.attack_speed
				values.attack_speed = 0.85
				notes.append("drawback: cooldown_lock capped attack_speed %.2f -> 0.85" % old_lock_speed)


static func _reduce_to_budget(values: Dictionary, notes: Array[String], initial: Dictionary) -> Dictionary:
	var current := initial
	if float(current.total) > MAX_POWER and values.damage > 1:
		var old_damage: int = values.damage
		var reduction := int(ceil((float(current.total) - MAX_POWER) / 0.55))
		values.damage = maxi(1, values.damage - reduction)
		notes.append("budget: damage reduced %d -> %d" % [old_damage, values.damage])
		current = calculate(values)
	if float(current.total) > MAX_POWER and values.attack_speed > 0.2:
		var old_speed: float = values.attack_speed
		var target_speed: float = values.attack_speed - (float(current.total) - MAX_POWER) / 10.0
		values.attack_speed = maxf(0.2, floorf(target_speed / 0.05) * 0.05)
		notes.append("budget: attack_speed reduced %.2f -> %.2f" % [old_speed, values.attack_speed])
		current = calculate(values)
	if float(current.total) > MAX_POWER and values.range > 40.0:
		var old_range: float = values.range
		values.range = maxf(40.0, floorf(values.range - (float(current.total) - MAX_POWER) * 45.0))
		notes.append("budget: range reduced %.0f -> %.0f" % [old_range, values.range])
		current = calculate(values)
	if float(current.total) > MAX_POWER and values.delivery != "held" and values.projectile_speed > 180.0:
		var old_projectile_speed: float = values.projectile_speed
		values.projectile_speed = maxf(180.0, floorf(values.projectile_speed - (float(current.total) - MAX_POWER) * 200.0))
		notes.append("budget: projectile_speed reduced %.0f -> %.0f" % [old_projectile_speed, values.projectile_speed])
		current = calculate(values)
	if float(current.total) > MAX_POWER and values.attack_pattern == "boomerang" and values.return_speed > 180.0:
		var old_return_speed: float = values.return_speed
		values.return_speed = maxf(180.0, floorf(values.return_speed - (float(current.total) - MAX_POWER) * 250.0))
		notes.append("budget: return_speed reduced %.0f -> %.0f" % [old_return_speed, values.return_speed])
		current = calculate(values)
	if float(current.total) > MAX_POWER and values.attack_pattern == "area_blast" and values.area_radius > 40.0:
		var old_radius: float = values.area_radius
		values.area_radius = maxf(40.0, floorf(values.area_radius - (float(current.total) - MAX_POWER) * 30.0))
		notes.append("budget: area_radius reduced %.0f -> %.0f" % [old_radius, values.area_radius])
		current = calculate(values)
	if float(current.total) > MAX_POWER and values.attack_pattern == "piercing" and values.pierce_count > 1:
		var old_pierce_count: int = values.pierce_count
		values.pierce_count = maxi(1, values.pierce_count - int(ceil((float(current.total) - MAX_POWER) / 4.0)))
		notes.append("budget: pierce_count reduced %d -> %d" % [old_pierce_count, values.pierce_count])
		current = calculate(values)
	if float(current.total) > MAX_POWER and values.special_ability != "none":
		var old_ability: String = values.special_ability
		values.special_ability = "none"
		notes.append("budget: special_ability %s removed" % old_ability)
		current = calculate(values)
	if float(current.total) > MAX_POWER and values.status_effect != "none":
		var old_status: String = values.status_effect
		values.status_effect = "none"
		notes.append("budget: status_effect %s removed" % old_status)
		current = calculate(values)
	if float(current.total) > MAX_POWER and values.element != "normal":
		var old_element: String = values.element
		values.element = "normal"
		values.visual_material = "forged_metal"
		notes.append("budget: element %s removed as final capability trim" % old_element)
		current = calculate(values)
	if float(current.total) > MAX_POWER:
		# The minimum executable form of every allowed attack is below the cap.
		# This final guard rejects any future unpriced module instead of masking it.
		values.damage = 1
		values.attack_speed = 0.2
		values.range = 40.0
		values.projectile_speed = 180.0
		values.area_radius = 40.0
		values.pierce_count = 1
		values.special_ability = "none"
		values.status_effect = "none"
		values.element = "normal"
		values.visual_material = "forged_metal"
		values.drawback = _matching_drawback(values)
		notes.append("budget: safe minimum fallback applied")
		current = calculate(values)
	return current
