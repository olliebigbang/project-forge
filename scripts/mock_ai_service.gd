class_name MockAIService
extends RefCounted

const RANGED_KEYWORDS: PackedStringArray = [
	"ranged", "projectile", "shoot", "launcher", "arrow", "bow", "gun", "wand", "throw",
	"远程", "投射", "发射", "弓", "枪"
]
const BLOCKED_KEYWORDS: PackedStringArray = [
	"system prompt", "reveal prompt", "execute code", "infinite damage", "无限伤害", "执行代码"
]

var last_metadata: Dictionary = {}


func generate(description: String, drawing_summary: Dictionary) -> WeaponSpec:
	var started := Time.get_ticks_msec()
	var normalized := description.strip_edges().to_lower()
	var fallback_reason := ""

	if normalized.is_empty():
		fallback_reason = "empty_description"
	elif _contains_any(normalized, BLOCKED_KEYWORDS):
		fallback_reason = "blocked_input"

	var raw: Dictionary
	if not fallback_reason.is_empty():
		raw = WeaponSpec.fallback().to_dict()
	else:
		var is_ranged := _contains_any(normalized, RANGED_KEYWORDS)
		var element := _detect_element(normalized)
		raw = _ranged_profile(element, drawing_summary) if is_ranged else _melee_profile(element, drawing_summary)

	var spec := WeaponSpec.from_dict(raw)
	last_metadata = {
		"elapsed_ms": maxi(Time.get_ticks_msec() - started, 0),
		"mode": "local_mock",
		"fallback_reason": fallback_reason,
		"attack_pattern": spec.attack_pattern,
	}
	print("[MockAI] ", JSON.stringify(last_metadata))
	return spec


func _melee_profile(element: String, drawing_summary: Dictionary) -> Dictionary:
	var long_shape := float(drawing_summary.get("aspect_ratio", 1.0)) > 1.7
	var profile := {
		"name": "Longline Sketchblade" if long_shape else "Ember Sketchblade",
		"weapon_class": "melee",
		"attack_pattern": "melee_slash",
		"element": element,
		"damage": 38,
		"attack_speed": 0.85,
		"range": 132.0 if long_shape else 112.0,
		"special_ability": "knockback_burst",
		"status_effect": _status_for(element, "knockback"),
		"drawback": "slow_recovery",
		"visual_material": _material_for(element),
		"power_score": 78,
	}
	return profile


func _ranged_profile(element: String, drawing_summary: Dictionary) -> Dictionary:
	var detailed := int(drawing_summary.get("point_count", 0)) >= 12
	var profile := {
		"name": "Detailshot Darter" if detailed else "Frostline Darter",
		"weapon_class": "ranged",
		"attack_pattern": "straight_projectile",
		"element": element,
		"damage": 24,
		"attack_speed": 1.25,
		"range": 760.0,
		"special_ability": "chain_arc" if element == "electric" else "none",
		"status_effect": _status_for(element, "none"),
		"drawback": "low_impact",
		"visual_material": _material_for(element),
		"power_score": 74,
	}
	return profile


func _detect_element(text: String) -> String:
	if _contains_any(text, ["fire", "flame", "burn", "火", "燃烧"]):
		return "fire"
	if _contains_any(text, ["ice", "frost", "freeze", "冰", "冻结"]):
		return "ice"
	if _contains_any(text, ["electric", "lightning", "shock", "电", "雷"]):
		return "electric"
	return "normal"


func _status_for(element: String, default_status: String) -> String:
	match element:
		"fire": return "burn"
		"ice": return "freeze"
		"electric": return "shock"
		_: return default_status


func _material_for(element: String) -> String:
	match element:
		"fire": return "ember_metal"
		"ice": return "frozen_metal"
		"electric": return "charged_metal"
		_: return "forged_metal"


func _contains_any(text: String, keywords: Variant) -> bool:
	for keyword: String in keywords:
		if text.contains(keyword):
			return true
	return false
