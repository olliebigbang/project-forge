extends SceneTree

var _passed := 0
var _failed := 0
var _matrix_cases := 0


func _init() -> void:
	print("[TEST] Project Forge M1A deterministic compiler suite")
	_test_input_matrix()
	_test_determinism()
	_test_runtime_repair()
	_test_power_budget()
	_test_schema_runtime_parity()
	_test_drawing_summary()
	_test_target_rules()
	var result := {"matrix_cases": _matrix_cases, "passed": _passed, "failed": _failed}
	var output := FileAccess.open("user://m1a_test_results.json", FileAccess.WRITE)
	if output: output.store_string(JSON.stringify(result, "  "))
	print("[TEST] %d matrix cases; %d assertions passed, %d failed" % [_matrix_cases, _passed, _failed])
	quit(1 if _failed > 0 else 0)


func _test_input_matrix() -> void:
	var file := FileAccess.open("res://tests/m1a_input_matrix.json", FileAccess.READ)
	_expect(file != null, "input matrix is readable")
	if file == null: return
	var cases: Variant = JSON.parse_string(file.get_as_text())
	_expect(cases is Array, "input matrix parses as an array")
	if cases is not Array: return
	_matrix_cases = cases.size()
	_expect(_matrix_cases >= 20, "input matrix contains at least 20 cases")
	var patterns: Dictionary = {}
	var elements: Dictionary = {}
	for case: Dictionary in cases:
		var compiler := WeaponCompiler.new()
		var spec := compiler.compile(str(case.input), {"aspect_ratio": 2.0, "point_count": 16})
		var case_id: String = case.id
		_expect(spec.attack_pattern == case.pattern, "%s selects %s" % [case_id, case.pattern])
		_expect(spec.element == case.element, "%s selects %s" % [case_id, case.element])
		_expect(spec.is_valid(), "%s satisfies runtime validation" % case_id)
		_expect(spec.power_score <= PowerBudget.MAX_POWER, "%s stays within power budget" % case_id)
		_expect(not spec.has_strong_capability() or spec.drawback != "none", "%s strong capability has a tradeoff" % case_id)
		_expect(str(compiler.last_record.get("fallback_reason", "")) == str(case.get("fallback", "")), "%s records expected fallback reason" % case_id)
		patterns[spec.attack_pattern] = true
		elements[spec.element] = true
	_expect(patterns.size() == 5, "matrix covers all five attack patterns")
	_expect(elements.size() == 4, "matrix covers all four elements")


func _test_determinism() -> void:
	var first := WeaponCompiler.new().compile("a returning fire boomerang", {"aspect_ratio": 1.5, "point_count": 9})
	var second := WeaponCompiler.new().compile("a returning fire boomerang", {"aspect_ratio": 1.5, "point_count": 9})
	_expect(first.to_dict() == second.to_dict(), "identical input produces an identical WeaponSpec")
	_expect(first.budget_breakdown == second.budget_breakdown, "identical input produces an identical budget")


func _test_runtime_repair() -> void:
	var compiler := WeaponCompiler.new()
	var spec := compiler.compile_raw({
		"name": "X".repeat(90), "weapon_class": "wizard", "attack_pattern": "teleport",
		"element": "plasma", "damage": 9999, "attack_speed": -4, "range": INF,
		"special_ability": "god_mode", "status_effect": "forever_stun", "drawback": "none",
		"visual_material": "stolen_asset", "power_score": 900, "projectile_speed": NAN,
		"area_radius": -50, "pierce_count": 99, "return_speed": "not-a-number", "extra_payload": "discard me",
	})
	_expect(spec.is_valid(), "malformed raw data is repaired to a valid runtime object")
	_expect(spec.display_name.length() == 48, "overlong name is truncated")
	_expect(spec.attack_pattern == "melee_slash" and spec.weapon_class == "melee", "unsupported attack and class use safe fallback")
	_expect(spec.element == "normal", "unsupported element uses normal")
	_expect(spec.damage <= 100 and spec.attack_speed >= 0.2, "combat numbers are bounded")
	_expect(spec.attack_range >= 40 and spec.attack_range <= 900, "non-finite range is repaired")
	_expect(spec.projectile_speed >= 180 and spec.projectile_speed <= 900, "NaN projectile speed is repaired")
	_expect(spec.area_radius == 40 and spec.pierce_count <= 6, "module values are clamped")
	_expect(spec.corrections.size() >= 10, "repair reasons are retained")
	_expect(_notes_contain(spec.corrections, "unknown field discarded"), "unknown fields are explicitly discarded")

	var missing := compiler.compile_raw({})
	_expect(missing.is_valid(), "fully missing object recovers to fallback")
	_expect(missing.corrections.size() >= missing.to_dict().size(), "missing fields each produce a repair record")


func _test_power_budget() -> void:
	var raw := WeaponSpec.fallback().to_dict()
	raw.merge({"attack_pattern":"piercing", "weapon_class":"ranged", "element":"electric", "damage":100, "attack_speed":3.0, "range":900.0, "special_ability":"chain_arc", "status_effect":"shock", "drawback":"none", "projectile_speed":900.0, "pierce_count":6}, true)
	var balanced := PowerBudget.balance(raw)
	var spec := WeaponSpec.from_dict(balanced.values)
	_expect(float(balanced.before.total) > PowerBudget.MAX_POWER, "overpowered input exceeds budget before repair")
	_expect(spec.power_score <= PowerBudget.MAX_POWER, "overpowered input is repaired under 100")
	_expect(spec.drawback != "none", "overpowered input receives an explicit drawback")
	_expect(balanced.corrections.size() >= 2, "budget repair records tradeoff and stat correction")
	var parts := PowerBudget.calculate(spec.to_dict())
	var sum := 0.0
	for key: String in parts.keys():
		if key != "total": sum += float(parts[key])
	_expect(is_equal_approx(snappedf(maxf(sum, 1.0), 0.1), float(parts.total)), "power total equals explicit component sum")
	_expect(float(PowerBudget.PATTERN_COST.boomerang) != float(PowerBudget.PATTERN_COST.area_blast), "attack modules have distinct budget costs")


func _test_schema_runtime_parity() -> void:
	var file := FileAccess.open("res://schema/weapon_spec.schema.json", FileAccess.READ)
	_expect(file != null, "WeaponSpec JSON Schema is readable")
	if file == null: return
	var schema: Variant = JSON.parse_string(file.get_as_text())
	_expect(schema is Dictionary, "WeaponSpec JSON Schema parses")
	if schema is not Dictionary: return
	var required: Array = schema.required
	var runtime_keys := WeaponSpec.fallback().to_dict().keys()
	_expect(required.size() == runtime_keys.size(), "schema and runtime require the same field count")
	for field: String in runtime_keys: _expect(field in required, "schema requires runtime field '%s'" % field)
	_expect(schema.properties.attack_pattern.enum == Array(WeaponSpec.ATTACK_PATTERNS), "schema attack allow-list matches runtime")
	_expect(schema.properties.element.enum == Array(WeaponSpec.ELEMENTS), "schema element allow-list matches runtime")


func _test_drawing_summary() -> void:
	var strokes: Array[PackedVector2Array] = [PackedVector2Array([Vector2(10, 20), Vector2(110, 20), Vector2(210, 40)]), PackedVector2Array([Vector2(20, 80), Vector2(80, 100)])]
	var summary := DrawingCanvas.summarize_strokes(strokes, Vector2(400, 200))
	_expect(summary.point_count == 5 and summary.stroke_count == 2, "drawing summary counts points and strokes")
	_expect(float(summary.aspect_ratio) > 2.0 and float(summary.coverage) > 0.0, "drawing summary captures shape")


func _test_target_rules() -> void:
	var shield := TrainingDummy.new()
	shield.configure("shield", "TEST SHIELD", 200)
	root.add_child(shield)
	var blocked := shield.take_damage(50, "none", "straight_projectile", Vector2.RIGHT)
	var pierced := shield.take_damage(50, "none", "piercing", Vector2.RIGHT)
	_expect(blocked == 10, "shield reduces frontal straight projectiles")
	_expect(pierced == 50, "piercing bypasses shield reduction")
	var mover := TrainingDummy.new()
	mover.configure("moving", "TEST MOVER", 100)
	root.add_child(mover)
	mover.take_damage(10, "freeze", "straight_projectile", Vector2.RIGHT)
	_expect(mover.health == 90, "ice hit damages moving target and arms slow state")
	shield.queue_free()
	mover.queue_free()


func _notes_contain(notes: Array[String], needle: String) -> bool:
	for note in notes:
		if note.contains(needle): return true
	return false


func _expect(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
		print("  PASS  ", message)
	else:
		_failed += 1
		push_error("  FAIL  " + message)
