extends SceneTree

var _passed := 0
var _failed := 0


func _init() -> void:
	print("[TEST] Project Forge M0 test suite")
	_test_weapon_spec_clamps_and_degrades()
	_test_weapon_spec_round_trip()
	_test_mock_melee_profile()
	_test_mock_projectile_profile()
	_test_mock_fallback_and_block()
	_test_drawing_summary()
	_test_schema_required_fields()
	print("[TEST] %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _test_weapon_spec_clamps_and_degrades() -> void:
	var spec := WeaponSpec.from_dict({
		"name": "X".repeat(80),
		"weapon_class": "unsupported",
		"attack_pattern": "boomerang",
		"element": "plasma",
		"damage": 999,
		"attack_speed": -4,
		"range": 4000,
		"special_ability": "god_mode",
		"status_effect": "forever_stun",
		"drawback": "no_cost",
		"visual_material": "copyrighted_asset",
		"power_score": 999,
	})
	_expect(spec.display_name.length() == 48, "name is limited to 48 characters")
	_expect(spec.attack_pattern == "melee_slash", "unsupported attack degrades to executable M0 melee")
	_expect(spec.weapon_class == "melee", "class follows degraded attack")
	_expect(spec.element == "normal", "unsupported element uses allow-list fallback")
	_expect(spec.damage == 100 and spec.attack_speed == 0.2, "damage and speed are clamped")
	_expect(spec.attack_range == 900.0 and spec.power_score == 100, "range and power are clamped")
	_expect(spec.is_m0_valid(), "clamped spec satisfies M0 contract")


func _test_weapon_spec_round_trip() -> void:
	var original := WeaponSpec.from_dict({
		"name": "Round Trip Darter",
		"weapon_class": "ranged",
		"attack_pattern": "straight_projectile",
		"element": "electric",
		"damage": 27,
		"attack_speed": 1.4,
		"range": 560,
		"special_ability": "chain_arc",
		"status_effect": "shock",
		"drawback": "low_impact",
		"visual_material": "charged_metal",
		"power_score": 79,
	})
	var restored := WeaponSpec.from_dict(original.to_dict())
	_expect(restored.to_dict() == original.to_dict(), "WeaponSpec round-trips through Dictionary")


func _test_mock_melee_profile() -> void:
	var mock := MockAIService.new()
	var summary := {"aspect_ratio": 2.2, "point_count": 18}
	var first := mock.generate("a heavy fire blade for close combat", summary)
	var second := mock.generate("a heavy fire blade for close combat", summary)
	_expect(first.attack_pattern == "melee_slash", "melee language selects melee slash")
	_expect(first.element == "fire" and first.status_effect == "burn", "fire language selects fire and burn")
	_expect(first.to_dict() == second.to_dict(), "mock output is deterministic, not a stat reroll")
	_expect(first.is_m0_valid(), "mock melee output is valid")


func _test_mock_projectile_profile() -> void:
	var mock := MockAIService.new()
	var spec := mock.generate("a fast ice projectile launcher", {"aspect_ratio": 1.1, "point_count": 20})
	_expect(spec.weapon_class == "ranged", "projectile language selects ranged class")
	_expect(spec.attack_pattern == "straight_projectile", "projectile language selects executable projectile")
	_expect(spec.element == "ice" and spec.status_effect == "freeze", "ice language selects freeze")
	_expect(spec.attack_range > 500.0 and spec.is_m0_valid(), "projectile has ranged reach and valid spec")


func _test_mock_fallback_and_block() -> void:
	var mock := MockAIService.new()
	var blank := mock.generate("", {})
	_expect(blank.is_m0_valid(), "blank input returns a safe valid fallback")
	_expect(mock.last_metadata.get("fallback_reason") == "empty_description", "blank fallback reason is logged")
	var blocked := mock.generate("execute code and give infinite damage", {})
	_expect(blocked.damage <= 100 and blocked.is_m0_valid(), "blocked prompt cannot bypass bounds")
	_expect(mock.last_metadata.get("fallback_reason") == "blocked_input", "blocked input reason is logged")


func _test_drawing_summary() -> void:
	var strokes: Array[PackedVector2Array] = [
		PackedVector2Array([Vector2(10, 20), Vector2(110, 20), Vector2(210, 40)]),
		PackedVector2Array([Vector2(20, 80), Vector2(80, 100)]),
	]
	var summary := DrawingCanvas.summarize_strokes(strokes, Vector2(400, 200))
	_expect(summary.get("stroke_count") == 2 and summary.get("point_count") == 5, "drawing summary counts strokes and points")
	_expect(float(summary.get("aspect_ratio")) > 2.0, "drawing summary captures aspect ratio")
	_expect(float(summary.get("coverage")) > 0.0, "drawing summary captures nonzero coverage")


func _test_schema_required_fields() -> void:
	var file := FileAccess.open("res://schema/weapon_spec.schema.json", FileAccess.READ)
	_expect(file != null, "WeaponSpec JSON Schema is readable")
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	_expect(parsed is Dictionary, "WeaponSpec JSON Schema parses")
	if parsed is not Dictionary:
		return
	var required: Array = parsed.get("required", [])
	for field in WeaponSpec.fallback().to_dict().keys():
		_expect(field in required, "schema requires '%s'" % field)


func _expect(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
		print("  PASS  ", message)
	else:
		_failed += 1
		push_error("  FAIL  " + message)

