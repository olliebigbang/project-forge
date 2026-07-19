class_name WeaponCompiler
extends RefCounted

const BLOCKED_KEYWORDS: PackedStringArray = [
	"system prompt", "reveal prompt", "execute code", "infinite damage", "god mode",
	"ignore instructions", "无限伤害", "执行代码", "忽略规则"
]

var last_record: Dictionary = {}


func compile(description: String, drawing_summary: Dictionary = {}) -> WeaponSpec:
	var started := Time.get_ticks_msec()
	var normalized := description.strip_edges().to_lower().left(512)
	var fallback_reason := ""
	if normalized.is_empty(): fallback_reason = "empty_description"
	elif _contains_any(normalized, BLOCKED_KEYWORDS): fallback_reason = "blocked_input"

	var raw := _fallback_profile() if not fallback_reason.is_empty() else _profile_for(normalized, drawing_summary)
	var balanced := PowerBudget.balance(raw)
	var spec := WeaponSpec.from_dict(balanced.values)
	spec.corrections.assign(balanced.corrections)
	spec.budget_breakdown = balanced.after.duplicate(true)
	last_record = {
		"timestamp_unix": int(Time.get_unix_time_from_system()),
		"mode": "deterministic_mock_m1a",
		"input": normalized.left(160),
		"drawing_summary": drawing_summary,
		"raw_spec": raw,
		"weapon_spec": spec.to_dict(),
		"budget_before": balanced.before,
		"budget_after": balanced.after,
		"corrections": spec.corrections,
		"fallback_reason": fallback_reason,
		"runtime_valid": _is_runtime_valid(spec, balanced),
		"elapsed_ms": maxi(Time.get_ticks_msec() - started, 0),
	}
	_log_record(last_record)
	print("[WeaponCompiler] ", JSON.stringify(last_record))
	return spec


func compile_raw(raw: Dictionary) -> WeaponSpec:
	var balanced := PowerBudget.balance(raw)
	var spec := WeaponSpec.from_dict(balanced.values)
	spec.corrections.assign(balanced.corrections)
	spec.budget_breakdown = balanced.after.duplicate(true)
	last_record = {
		"mode": "deterministic_raw_repair",
		"raw_spec": raw,
		"weapon_spec": spec.to_dict(),
		"budget_before": balanced.before,
		"budget_after": balanced.after,
		"corrections": spec.corrections,
		"runtime_valid": _is_runtime_valid(spec, balanced),
	}
	return spec


func _profile_for(text: String, drawing: Dictionary) -> Dictionary:
	var pattern := _detect_pattern(text)
	var element := _detect_element(text)
	var profile := _base_profile(pattern)
	profile.element = element
	profile.status_effect = _status_for(element, profile.status_effect)
	profile.visual_material = _material_for(element)
	profile.name = "%s %s" % [_element_name(element), _pattern_name(pattern, drawing)]
	if _contains_any(text, ["massive", "ultimate", "overpowered", "huge damage", "超强", "巨大", "无敌"]):
		profile.damage = 100
		profile.attack_speed = 2.8
		profile.range = 900.0
		profile.drawback = "none"
	if _contains_any(text, ["fast", "rapid", "quick", "高速", "快速"]):
		profile.attack_speed = minf(3.0, float(profile.attack_speed) + 0.4)
	if _contains_any(text, ["long range", "sniper", "远程", "超远"]):
		profile.range = 900.0
	return profile


func _base_profile(pattern: String) -> Dictionary:
	var common := {
		"name": "Normal Sketchblade", "weapon_class": "melee", "attack_pattern": pattern,
		"element": "normal", "damage": 36, "attack_speed": 1.0, "range": 132.0,
		"special_ability": "knockback_burst", "status_effect": "knockback",
		"drawback": "slow_recovery", "visual_material": "forged_metal", "power_score": 1,
		"projectile_speed": 560.0, "area_radius": 120.0, "pierce_count": 1, "return_speed": 680.0,
	}
	match pattern:
		"straight_projectile":
			common.merge({"weapon_class": "ranged", "damage": 26, "attack_speed": 1.3, "range": 675.0, "special_ability": "none", "status_effect": "none", "drawback": "low_impact", "projectile_speed": 620.0}, true)
		"boomerang":
			common.merge({"weapon_class": "ranged", "damage": 30, "attack_speed": 0.95, "range": 620.0, "special_ability": "return_strike", "status_effect": "none", "drawback": "self_stagger", "projectile_speed": 520.0, "return_speed": 760.0}, true)
		"area_blast":
			common.merge({"weapon_class": "melee", "damage": 34, "attack_speed": 0.7, "range": 220.0, "special_ability": "splash_wave", "status_effect": "none", "drawback": "cooldown_lock", "area_radius": 165.0}, true)
		"piercing":
			common.merge({"weapon_class": "ranged", "damage": 29, "attack_speed": 1.05, "range": 700.0, "special_ability": "shield_break", "status_effect": "none", "drawback": "narrow_arc", "projectile_speed": 720.0, "pierce_count": 3}, true)
	return common


func _fallback_profile() -> Dictionary:
	return _base_profile("melee_slash")


func _detect_pattern(text: String) -> String:
	if _contains_any(text, ["boomerang", "returning", "return strike", "回旋", "飞回", "回力"]): return "boomerang"
	if _contains_any(text, ["area", "blast", "explosion", "nova", "swarm", "范围", "爆炸", "群攻"]): return "area_blast"
	if _contains_any(text, ["piercing", "pierce", "drill", "穿透", "贯穿", "破盾"]): return "piercing"
	if _contains_any(text, ["projectile", "shoot", "launcher", "arrow", "bow", "gun", "wand", "ranged", "投射", "发射", "远程"]): return "straight_projectile"
	return "melee_slash"


func _detect_element(text: String) -> String:
	if _contains_any(text, ["fire", "flame", "burn", "火", "燃烧"]): return "fire"
	if _contains_any(text, ["ice", "frost", "freeze", "冰", "冻结"]): return "ice"
	if _contains_any(text, ["electric", "lightning", "shock", "thunder", "电", "雷"]): return "electric"
	return "normal"


func _status_for(element: String, default_status: String) -> String:
	match element:
		"fire": return "burn"
		"ice": return "freeze"
		"electric": return "shock"
	return default_status


func _material_for(element: String) -> String:
	match element:
		"fire": return "ember_metal"
		"ice": return "frozen_metal"
		"electric": return "charged_metal"
	return "forged_metal"


func _element_name(element: String) -> String:
	return {"normal": "Ink", "fire": "Ember", "ice": "Frost", "electric": "Volt"}.get(element, "Ink")


func _pattern_name(pattern: String, drawing: Dictionary) -> String:
	var detailed := int(drawing.get("point_count", 0)) >= 12
	match pattern:
		"straight_projectile": return "Detailshot Darter" if detailed else "Linebolt Darter"
		"boomerang": return "Returning Crescent"
		"area_blast": return "Crowdbreaker Nova"
		"piercing": return "Shieldsplitter Lance"
	return "Longline Sketchblade" if float(drawing.get("aspect_ratio", 1.0)) > 1.7 else "Sketchblade"


func _contains_any(text: String, keywords: Variant) -> bool:
	for keyword: String in keywords:
		if text.contains(keyword): return true
	return false


func _log_record(record: Dictionary) -> void:
	var path := "user://m1a_generation_log.jsonl"
	var file := FileAccess.open(path, FileAccess.READ_WRITE)
	if file == null: file = FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.seek_end()
		file.store_line(JSON.stringify(record))


func _is_runtime_valid(spec: WeaponSpec, balanced: Dictionary) -> bool:
	var actual := PowerBudget.calculate(spec.to_dict())
	return (
		spec.is_valid() and bool(balanced.within_budget)
		and float(actual.total) <= PowerBudget.MAX_POWER
		and spec.power_score == int(ceil(float(actual.total)))
	)
