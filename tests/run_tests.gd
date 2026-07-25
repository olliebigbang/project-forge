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
	_test_weapon_semantics()
	_test_schema_runtime_parity()
	_test_drawing_summary()
	_test_c0_drawing_input_gate()
	_test_stroke_fit()
	_test_drawing_geometry_profiles()
	_test_weapon_role_balance_matrix()
	_test_role_entry_path_parity()
	await _test_role_runtime_behavior_oracles()
	await _test_piercing_bow_role_separation()
	await _test_element_combat_effect_events()
	_test_attack_pattern_touch_selector()
	_test_mobile_layout_policy()
	await _test_forge_reset_state()
	await _test_weapon_interpreter_response_context()
	_test_orientation_prompt_rule()
	await _test_player_combat_gate()
	_test_c0_player_health()
	await _test_c0_terminal_and_collision_invariants()
	_test_c0_enemy_state_machine()
	_test_c0_comparison_gate()
	await _test_rapid_melee_input_buffer()
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
		var actual_budget := PowerBudget.calculate(spec.to_dict())
		_expect(float(actual_budget.total) <= PowerBudget.MAX_POWER, "%s actual component sum stays within budget" % case_id)
		_expect(spec.power_score == int(ceil(float(actual_budget.total))), "%s score matches actual component sum" % case_id)
		_expect(bool(compiler.last_record.runtime_valid), "%s passes the complete runtime gate" % case_id)
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
	var actual_after := PowerBudget.calculate(spec.to_dict())
	_expect(float(actual_after.total) <= PowerBudget.MAX_POWER, "actual overpowered component sum is repaired under 100")
	_expect(float(balanced.after.total) == float(actual_after.total), "reported total is the actual calculated total")
	_expect(bool(balanced.within_budget), "within_budget derives from the actual total")
	_expect(spec.power_score == int(ceil(float(actual_after.total))), "power_score is the ceiling of the actual total")
	_expect(spec.drawback != "none", "overpowered input receives an explicit drawback")
	_expect(balanced.corrections.size() >= 2, "budget repair records tradeoff and stat correction")
	var parts := PowerBudget.calculate(spec.to_dict())
	var sum := 0.0
	for key: String in parts.keys():
		if key != "total": sum += float(parts[key])
	_expect(is_equal_approx(snappedf(maxf(sum, 1.0), 0.1), float(parts.total)), "power total equals explicit component sum")
	_expect(float(PowerBudget.PATTERN_COST.boomerang) != float(PowerBudget.PATTERN_COST.area_blast), "attack modules have distinct budget costs")
	var contradictory := WeaponSpec.fallback().to_dict()
	contradictory.merge({"attack_pattern":"straight_projectile", "weapon_class":"ranged", "range":900.0, "drawback":"short_reach"}, true)
	var semantic_balance := PowerBudget.balance(contradictory)
	_expect(float(semantic_balance.values.range) <= 180.0, "short_reach cannot claim credit while retaining long range")
	_expect(semantic_balance.corrections.size() > 0, "semantic drawback correction is recorded")
	var fake_projectile_drawback := WeaponSpec.fallback().to_dict()
	fake_projectile_drawback.merge({"attack_pattern":"melee_slash", "drawback":"slow_projectile", "damage":48}, true)
	var fake_drawback_balance := PowerBudget.balance(fake_projectile_drawback)
	_expect(fake_drawback_balance.values.drawback != "slow_projectile", "melee cannot receive unearned slow_projectile credit")
	_expect(_notes_contain(fake_drawback_balance.corrections, "has no projectile"), "invalid drawback replacement is audited")
	var slow_return := WeaponCompiler.new().compile("a returning boomerang", {}, "boomerang").to_dict()
	var fast_return := slow_return.duplicate(true)
	fast_return.return_speed = 1000.0
	_expect(float(PowerBudget.calculate(fast_return).total) > float(PowerBudget.calculate(slow_return).total), "boomerang return_speed has an explicit budget cost")
	var incompatible := WeaponSpec.fallback().to_dict()
	incompatible.merge({"attack_pattern":"melee_slash", "element":"normal", "special_ability":"return_strike", "status_effect":"freeze", "visual_material":"ember_metal"}, true)
	var compatibility_balance := PowerBudget.balance(incompatible)
	_expect(compatibility_balance.values.special_ability == "none", "pattern-incompatible ability is removed")
	_expect(compatibility_balance.values.status_effect == "none", "element-incompatible status is removed")
	_expect(compatibility_balance.values.visual_material == "forged_metal", "element-incompatible material is normalized")


func _test_weapon_semantics() -> void:
	var cases := [
		["a thrown grenade that explodes after landing", {"weapon_form":"grenade", "delivery":"thrown", "trajectory":"arc", "impact":"delayed_or_contact", "area_effect":"explosion", "attack_pattern":"area_blast", "weapon_class":"ranged"}],
		["a wooden bow firing arrows", {"weapon_form":"bow", "delivery":"projectile", "trajectory":"direct", "impact":"contact", "area_effect":"none", "attack_pattern":"straight_projectile", "weapon_class":"ranged"}],
		["a plain steel sword", {"weapon_form":"sword", "delivery":"held", "trajectory":"direct", "impact":"contact", "area_effect":"none", "attack_pattern":"melee_slash", "weapon_class":"melee"}],
		["a boomerang that returns", {"weapon_form":"boomerang", "delivery":"thrown", "trajectory":"returning", "impact":"contact", "area_effect":"none", "attack_pattern":"boomerang", "weapon_class":"ranged"}],
		["a spear that pierces shields", {"weapon_form":"spear", "delivery":"projectile", "trajectory":"direct", "impact":"piercing", "area_effect":"none", "attack_pattern":"piercing", "weapon_class":"ranged"}],
	]
	for entry: Array in cases:
		var spec := WeaponCompiler.new().compile(str(entry[0]), {"aspect_ratio": 2.0, "point_count": 12})
		var expected: Dictionary = entry[1]
		for field: String in expected:
			_expect(spec.to_dict()[field] == expected[field], "%s preserves %s=%s" % [spec.weapon_form, field, expected[field]])
		_expect(spec.display_name != "Practice Sketchblade" and spec.is_valid(), "%s produces a real validated semantic result" % spec.weapon_form)
	var grenade := WeaponCompiler.new().compile("a thrown grenade that explodes on contact").to_dict()
	var parts := PowerBudget.calculate(grenade)
	for field: String in ["delivery", "trajectory", "impact", "area_effect", "area_radius", "projectile_speed"]:
		_expect(float(parts[field]) > 0.0, "grenade pays explicit %s power cost" % field)


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
	_expect(schema.properties.weapon_form.enum == Array(WeaponSpec.WEAPON_FORMS), "schema weapon-form allow-list matches runtime")
	_expect(schema.properties.delivery.enum == Array(WeaponSpec.DELIVERIES), "schema delivery allow-list matches runtime")
	_expect(schema.properties.trajectory.enum == Array(WeaponSpec.TRAJECTORIES), "schema trajectory allow-list matches runtime")
	_expect(schema.properties.impact.enum == Array(WeaponSpec.IMPACTS), "schema impact allow-list matches runtime")
	_expect(schema.properties.area_effect.enum == Array(WeaponSpec.AREA_EFFECTS), "schema area-effect allow-list matches runtime")
	_expect(schema.properties.element.enum == Array(WeaponSpec.ELEMENTS), "schema element allow-list matches runtime")


func _test_drawing_summary() -> void:
	var strokes: Array[PackedVector2Array] = [PackedVector2Array([Vector2(10, 20), Vector2(110, 20), Vector2(210, 40)]), PackedVector2Array([Vector2(20, 80), Vector2(80, 100)])]
	var summary := DrawingCanvas.summarize_strokes(strokes, Vector2(400, 200))
	_expect(summary.point_count == 5 and summary.stroke_count == 2, "drawing summary counts points and strokes")
	_expect(float(summary.aspect_ratio) > 2.0 and float(summary.coverage) > 0.0, "drawing summary captures shape")
	var canvas := DrawingCanvas.new()
	canvas.strokes = StrokeFit.duplicate_strokes(strokes)
	var snapshot := canvas.get_strokes_snapshot()
	snapshot[0][0] = Vector2(999, 999)
	_expect(canvas.strokes[0][0] == Vector2(10, 20), "stroke snapshot does not mutate original canvas data")
	canvas.queue_free()


func _test_c0_drawing_input_gate() -> void:
	var canvas := DrawingCanvas.new()
	var empty_gate: Dictionary = canvas.forge_input_gate()
	_expect(
		not bool(empty_gate.get("accepted", true))
		and str(empty_gate.get("code", "")) == "empty",
		"C0 drawing gate rejects empty ink before compilation",
	)

	canvas.strokes = [PackedVector2Array([Vector2(40.0, 40.0)])]
	var single_point_gate: Dictionary = canvas.forge_input_gate()
	_expect(
		not bool(single_point_gate.get("accepted", true))
		and str(single_point_gate.get("code", "")) == "single_point"
		and int(single_point_gate.get("point_count", 0)) == 1,
		"C0 drawing gate rejects a one-point tap with an explicit reason",
	)

	canvas.strokes = [PackedVector2Array([
		Vector2(40.0, 40.0),
		Vector2(40.0, 40.0),
	])]
	var zero_length_gate: Dictionary = canvas.forge_input_gate()
	_expect(
		not bool(zero_length_gate.get("accepted", true))
		and str(zero_length_gate.get("code", "")) == "zero_path_length"
		and is_zero_approx(float(zero_length_gate.get("path_length", -1.0))),
		"C0 drawing gate rejects a multi-point zero-length path",
	)

	canvas.strokes = [PackedVector2Array([
		Vector2(40.0, 40.0),
		Vector2(46.0, 40.0),
	])]
	var preserved_micro_stroke: PackedVector2Array = canvas.strokes[0].duplicate()
	var micro_gate: Dictionary = canvas.forge_input_gate()
	_expect(
		not bool(micro_gate.get("accepted", true))
		and str(micro_gate.get("code", "")) == "micro_tap"
		and float(micro_gate.get("path_length", 100.0)) < DrawingCanvas.MIN_DRAWABLE_PATH_LENGTH,
		"C0 drawing gate rejects a real sub-threshold micro stroke",
	)
	_expect(
		canvas.strokes.size() == 1 and canvas.strokes[0] == preserved_micro_stroke,
		"C0 input rejection never rewrites or discards preserved ink",
	)

	var accepted_fixtures: Array[PackedVector2Array] = [
		PackedVector2Array([Vector2(40.0, 60.0), Vector2(54.0, 60.0)]),
		PackedVector2Array([Vector2(40.0, 90.0), Vector2(240.0, 90.0)]),
		PackedVector2Array([Vector2(30.0, 120.0), Vector2(590.0, 120.0)]),
		PackedVector2Array([Vector2(50.0, 180.0), Vector2(230.0, 30.0)]),
		PackedVector2Array([
			Vector2(40.0, 170.0),
			Vector2(100.0, 80.0),
			Vector2(210.0, 50.0),
			Vector2(320.0, 130.0),
		]),
	]
	var fixture_names: Array[String] = ["natural short", "standard", "long", "rotated", "curved"]
	for index: int in accepted_fixtures.size():
		canvas.strokes = [accepted_fixtures[index]]
		var accepted_gate: Dictionary = canvas.forge_input_gate()
		_expect(
			bool(accepted_gate.get("accepted", false))
			and str(accepted_gate.get("code", "")) == "accepted"
			and float(accepted_gate.get("path_length", 0.0)) >= DrawingCanvas.MIN_DRAWABLE_PATH_LENGTH,
			"C0 drawing gate accepts the %s fixture" % fixture_names[index],
		)
	canvas.queue_free()


func _test_stroke_fit() -> void:
	var shapes := {
		"wide bow": PackedVector2Array([Vector2(120, 140), Vector2(300, 100), Vector2(480, 140), Vector2(300, 180), Vector2(120, 140)]),
		"long spear": PackedVector2Array([Vector2(40, 300), Vector2(520, 330), Vector2(40, 360)]),
		"long blade": PackedVector2Array([Vector2(90, 70), Vector2(450, 115), Vector2(90, 160)]),
		"round grenade": PackedVector2Array([Vector2(180, 80), Vector2(260, 160), Vector2(180, 240), Vector2(100, 160), Vector2(180, 80)]),
		"square shield": PackedVector2Array([Vector2(70, 90), Vector2(290, 90), Vector2(290, 310), Vector2(70, 310), Vector2(70, 90)]),
	}
	var targets := [
		WeaponVisual.DEFAULT_TARGET_RECT,
		Rect2(Vector2.ZERO, Vector2(240, 90)),
		Rect2(Vector2(-50, -50), Vector2(100, 100)),
		Rect2(Vector2.ZERO, Vector2(72, 160)),
	]
	for shape_name: String in shapes:
		var source: Array[PackedVector2Array] = [shapes[shape_name]]
		var original := StrokeFit.duplicate_strokes(source)
		var source_aspect := StrokeFit.aspect_ratio(source)
		for target: Rect2 in targets:
			var transform := StrokeFit.fit_transform(source, target)
			var mapped := StrokeFit.map_strokes(source, target)
			var rendered_aspect := StrokeFit.aspect_ratio(mapped)
			var relative_error := absf(rendered_aspect / source_aspect - 1.0)
			_expect(relative_error <= 0.02, "%s aspect error %.4f is within 2%%" % [shape_name, relative_error])
			var fitted: Rect2 = transform.fitted_rect
			var limiting_padding := minf(
				(target.size.x - fitted.size.x) / (target.size.x * 2.0),
				(target.size.y - fitted.size.y) / (target.size.y * 2.0),
			)
			_expect(limiting_padding >= 0.079 and limiting_padding <= 0.121, "%s limiting padding stays at 8-12%%" % shape_name)
		_expect(source == original, "%s source strokes remain byte-for-byte unchanged" % shape_name)
		var translated: Array[PackedVector2Array] = []
		var shifted := PackedVector2Array()
		for point: Vector2 in source[0]: shifted.append(point + Vector2(600, 400))
		translated.append(shifted)
		var original_fit := StrokeFit.actual_bounds(StrokeFit.map_strokes(source, targets[0]))
		var translated_fit := StrokeFit.actual_bounds(StrokeFit.map_strokes(translated, targets[0]))
		_expect(original_fit.size.is_equal_approx(translated_fit.size), "%s ignores canvas blank-space offset" % shape_name)

	var origin_dot: Array[PackedVector2Array] = [PackedVector2Array([Vector2.ZERO])]
	var horizontal: Array[PackedVector2Array] = [PackedVector2Array([Vector2(10, 20), Vector2(210, 20)])]
	var vertical: Array[PackedVector2Array] = [PackedVector2Array([Vector2(30, 5), Vector2(30, 205)])]
	for edge_case: Array[PackedVector2Array] in [origin_dot, horizontal, vertical]:
		var edge_transform := StrokeFit.fit_transform(edge_case, targets[0])
		var edge_mapped := StrokeFit.map_strokes(edge_case, targets[0])
		_expect(bool(edge_transform.valid) and not edge_mapped.is_empty(), "single-axis stroke remains renderable")
		_expect(StrokeFit.actual_bounds(edge_mapped).position.x >= targets[0].position.x, "single-axis stroke remains inside target")

	var visual_role_cases := [
		["bow", "a wooden bow firing arrows", "arrow", "procedural", false, false],
		["grenade", "a thrown grenade that explodes after landing", "grenade", "player_strokes", true, true],
		["sword", "a plain steel sword", "none", "none", false, false],
		["boomerang", "a boomerang that returns", "boomerang", "player_strokes", true, false],
		["spear", "a spear that pierces shields", "spear", "procedural", false, false],
		["generic normal projectile", "a gun firing a normal projectile", "bullet", "procedural", false, false],
		["generic elemental projectile", "a fire wand firing a projectile", "energy", "procedural", false, false],
	]
	for role_case: Array in visual_role_cases:
		var role_spec := WeaponCompiler.new().compile(str(role_case[1]))
		var bundle := WeaponVisualBundle.from_spec(role_spec)
		_expect(str(bundle.projectile_kind) == str(role_case[2]), "%s selects projectile kind %s" % [role_case[0], role_case[2]])
		_expect(str(bundle.projectile_source) == str(role_case[3]), "%s selects projectile source %s" % [role_case[0], role_case[3]])
		_expect(bool(bundle.hide_held_during_attack) == bool(role_case[4]), "%s held visibility lifecycle is explicit" % role_case[0])
		_expect((str(bundle.impact_visual) == "explosion") == bool(role_case[5]), "%s impact visual is independent" % role_case[0])

	var drawn_projectile_cases := [
		["boomerang", "a boomerang that returns", shapes["wide bow"]],
		["grenade", "a thrown grenade that explodes after landing", shapes["round grenade"]],
	]
	for projectile_case: Array in drawn_projectile_cases:
		var projectile_spec := WeaponCompiler.new().compile(str(projectile_case[1]))
		var projectile_strokes: Array[PackedVector2Array] = [projectile_case[2]]
		var projectile := ForgeProjectile.new()
		projectile.configure(projectile_spec, projectile_strokes, Vector2.RIGHT)
		projectile._ready()
		var visual_transform := projectile._visual.global_transform
		_expect(is_equal_approx(visual_transform.x.length(), visual_transform.y.length()), "%s drawn projectile transform is uniform" % projectile_case[0])
		var visual_state := projectile._visual.qa_state()
		_expect(bool(visual_state.uses_player_strokes), "%s intentionally uses the player drawing" % projectile_case[0])
		_expect(float(visual_state.relative_aspect_error) <= 0.02, "%s projectile aspect error is within 2%%" % projectile_case[0])
		_expect(float(visual_state.pivot_error) <= 1.0, "%s rotates around its fitted stroke center" % projectile_case[0])
		projectile.free()

	for procedural_case: Array in [
		["a wooden bow firing arrows", "arrow"],
		["a spear that pierces shields", "spear"],
		["a gun firing a normal projectile", "bullet"],
		["a fire wand firing a projectile", "energy"],
	]:
		var procedural_spec := WeaponCompiler.new().compile(str(procedural_case[0]))
		var source_strokes: Array[PackedVector2Array] = [shapes["wide bow"]]
		var procedural := ForgeProjectile.new()
		procedural.configure(procedural_spec, source_strokes, Vector2.RIGHT)
		procedural._ready()
		var procedural_state := procedural.qa_visual_state()
		_expect(str(procedural_state.kind) == str(procedural_case[1]), "%s uses its deterministic projectile graphic" % procedural_case[1])
		_expect(str(procedural_state.source) == "procedural" and not bool(procedural_state.uses_player_strokes), "%s never copies the held drawing" % procedural_case[1])
		_expect(str(procedural_state.rotation_mode) == "face_velocity" and float(procedural_state.heading_error) <= 0.001, "%s faces velocity without tumbling" % procedural_case[1])
		procedural.free()


func _test_drawing_geometry_profiles() -> void:
	var canvas_size := Vector2(640.0, 300.0)
	var shapes := {
		"dagger": PackedVector2Array([Vector2(20, 145), Vector2(105, 140), Vector2(112, 150), Vector2(105, 160), Vector2(20, 155)]),
		"short sword": PackedVector2Array([Vector2(20, 145), Vector2(175, 135), Vector2(182, 150), Vector2(175, 165), Vector2(20, 155)]),
		"standard sword": PackedVector2Array([Vector2(20, 145), Vector2(315, 132), Vector2(326, 150), Vector2(315, 168), Vector2(20, 155)]),
		"full-canvas long sword": PackedVector2Array([Vector2(18, 145), Vector2(612, 130), Vector2(625, 150), Vector2(612, 170), Vector2(18, 155)]),
		"wide bow": PackedVector2Array([Vector2(20, 150), Vector2(320, 80), Vector2(620, 150), Vector2(320, 220), Vector2(20, 150)]),
		"long spear": PackedVector2Array([Vector2(18, 145), Vector2(620, 138), Vector2(635, 150), Vector2(620, 162), Vector2(18, 155)]),
		"round grenade": PackedVector2Array([Vector2(260, 75), Vector2(335, 150), Vector2(260, 225), Vector2(185, 150), Vector2(260, 75)]),
		"square shield": PackedVector2Array([Vector2(190, 75), Vector2(340, 75), Vector2(340, 225), Vector2(190, 225), Vector2(190, 75)]),
	}
	var profiles: Dictionary = {}
	for shape_name: String in shapes:
		var source: Array[PackedVector2Array] = [shapes[shape_name]]
		var original := StrokeFit.duplicate_strokes(source)
		var profile := DrawingGeometryProfile.from_snapshot(source, canvas_size)
		profiles[shape_name] = profile
		_expect(source == original, "%s geometry profiling preserves source strokes" % shape_name)
		_expect(profile.effective_reach >= DrawingGeometryProfile.MIN_EFFECTIVE_REACH and profile.effective_reach <= DrawingGeometryProfile.MAX_EFFECTIVE_REACH, "%s effective reach is bounded" % shape_name)

	var dagger: DrawingGeometryProfile = profiles["dagger"]
	var short_sword: DrawingGeometryProfile = profiles["short sword"]
	var standard: DrawingGeometryProfile = profiles["standard sword"]
	var long_sword: DrawingGeometryProfile = profiles["full-canvas long sword"]
	_expect(dagger.effective_reach < short_sword.effective_reach, "dagger is visibly shorter than short sword")
	_expect(short_sword.effective_reach < standard.effective_reach, "short sword reach is below standard sword")
	_expect(standard.effective_reach < long_sword.effective_reach, "standard sword reach is below full-canvas sword")
	_expect(long_sword.reach_profile == "extreme_long", "full-canvas long sword deterministically enters extreme-long tier")

	var specs: Array[WeaponSpec] = []
	for profile_entry: Array in [
		["short sword", short_sword],
		["standard sword", standard],
		["full-canvas long sword", long_sword],
	]:
		var shape_name: String = profile_entry[0]
		var profile: DrawingGeometryProfile = profile_entry[1]
		var spec := WeaponCompiler.new().compile("a plain steel sword")
		var damage_before := spec.damage
		profile.apply_to_spec(spec)
		specs.append(spec)
		var source: Array[PackedVector2Array] = [shapes[shape_name]]
		var fitted := StrokeFit.map_strokes(source, profile.held_target_rect())
		var bounds := StrokeFit.actual_bounds(fitted)
		_expect(is_equal_approx(bounds.position.x, 0.0), "%s grip remains pinned at local x=0" % profile.reach_profile)
		_expect(absf(bounds.end.x - spec.attack_range) <= 0.01, "%s visible tip equals effective range" % profile.reach_profile)
		_expect(spec.damage == damage_before, "%s reach adjustment leaves damage unchanged" % profile.reach_profile)
		_expect(float(spec.budget_breakdown.total) <= PowerBudget.MAX_POWER, "%s geometry stats remain inside PowerBudget" % profile.reach_profile)
		_expect(_notes_contain(spec.corrections, "physics B1:"), "%s physics/budget correction is audited" % profile.reach_profile)

	_expect(specs[0].attack_range < specs[1].attack_range and specs[1].attack_range < specs[2].attack_range, "runtime melee ranges are strictly monotonic")
	_expect(specs[0].attack_speed > specs[1].attack_speed and specs[1].attack_speed > specs[2].attack_speed, "runtime melee speeds are inversely monotonic")
	var short_cycle := 1.0 / specs[0].attack_speed
	var standard_cycle := 1.0 / specs[1].attack_speed
	var long_cycle := 1.0 / specs[2].attack_speed
	_expect(short_cycle < standard_cycle and standard_cycle < long_cycle, "complete attack cycles are short < standard < long")
	var test_target := Vector2(170.0, 0.0)
	_expect(not DrawingGeometryProfile.melee_reaches_point(Vector2.ZERO, test_target, Vector2.RIGHT, specs[0].attack_range), "short sword cannot hit a target beyond its visible tip")
	_expect(DrawingGeometryProfile.melee_reaches_point(Vector2.ZERO, test_target, Vector2.RIGHT, specs[2].attack_range), "long sword hits the same target within its visible tip")
	_test_weapon_physics_b1_matrix(canvas_size)

	var frozen := long_sword.to_dict()
	for _viewport_size in [Vector2(844, 390), Vector2(852, 393), Vector2(915, 412)]:
		_expect(long_sword.to_dict() == frozen, "frozen reach does not drift across landscape resize")


func _test_weapon_physics_b1_matrix(canvas_size: Vector2) -> void:
	# These normalized spans reproduce the product owner's 1/4/8/16-grid
	# physical-iPhone samples at Range 72/92/120/199.
	var anchors: Array = CombatDerived.REACH_CYCLE_ANCHORS
	var expected_anchor_reaches: Array[float] = [72.0, 92.0, 120.0, 199.0, 228.0]
	var expected_anchor_cycles: Array[float] = [0.50, 0.60, 0.71, 0.95, 1.01]
	_expect(anchors.size() == expected_anchor_reaches.size(), "B1/B1.5 cadence curve retains five bounded reach anchors")
	for anchor_index: int in anchors.size():
		var anchor: Vector2 = anchors[anchor_index]
		_expect(
			is_equal_approx(anchor.x, expected_anchor_reaches[anchor_index])
			and is_equal_approx(anchor.y, expected_anchor_cycles[anchor_index]),
			"B1/B1.5 cadence anchor %d matches the bounded exposure candidate" % anchor_index,
		)
		if anchor_index > 0:
			var previous_anchor: Vector2 = anchors[anchor_index - 1]
			_expect(
				previous_anchor.x < anchor.x and previous_anchor.y < anchor.y,
				"B1/B1.5 cadence anchors remain strictly increasing at %d" % anchor_index,
			)
	var spans := {"1_grid": 0.18, "4_grid": 0.274872, "8_grid": 0.407692, "16_grid": 0.782436}
	var expected_reach_profiles := {
		"1_grid": "ultra_short", "4_grid": "short", "8_grid": "standard", "16_grid": "long",
	}
	var cross_axes := {"light": 0.05, "balanced": 0.14, "heavy": 0.28}
	var matrix: Dictionary = {}
	for reach_name: String in spans:
		matrix[reach_name] = {}
		for mass_name: String in cross_axes:
			var start_x := canvas_size.x * 0.03
			var end_x := start_x + canvas_size.x * float(spans[reach_name])
			var half_height := canvas_size.y * float(cross_axes[mass_name]) * 0.5
			var center_y := canvas_size.y * 0.5
			var stroke := PackedVector2Array([
				Vector2(start_x, center_y - half_height),
				Vector2(end_x - 8.0, center_y - half_height),
				Vector2(end_x, center_y),
				Vector2(end_x - 8.0, center_y + half_height),
				Vector2(start_x, center_y + half_height),
			])
			var source: Array[PackedVector2Array] = [stroke]
			var original := StrokeFit.duplicate_strokes(source)
			var profile := DrawingGeometryProfile.from_snapshot(source, canvas_size)
			var spec := WeaponCompiler.new().compile("a plain steel sword")
			var original_damage := spec.damage
			profile.apply_to_spec(spec)
			matrix[reach_name][mass_name] = {"profile": profile, "spec": spec}
			_expect(source == original, "%s/%s preserves source strokes" % [reach_name, mass_name])
			_expect(profile.reach_profile == expected_reach_profiles[reach_name], "%s/%s selects %s reach profile" % [reach_name, mass_name, expected_reach_profiles[reach_name]])
			_expect(profile.mass_profile == mass_name, "%s/%s selects independent mass profile" % [reach_name, mass_name])
			_expect(spec.damage == original_damage, "%s/%s leaves damage unchanged" % [reach_name, mass_name])
			_expect(spec.attack_range == profile.effective_reach, "%s/%s Range equals effective reach" % [reach_name, mass_name])
			var fitted := StrokeFit.map_strokes(source, profile.held_target_rect())
			_expect(absf(StrokeFit.actual_bounds(fitted).end.x - spec.attack_range) <= 0.01, "%s/%s visible tip equals Range" % [reach_name, mass_name])
			_expect(profile.combat_derived.startup_seconds > 0.0 and profile.combat_derived.active_seconds > 0.0 and profile.combat_derived.recovery_seconds > 0.0, "%s/%s exposes startup/active/recovery" % [reach_name, mass_name])
			_expect(is_equal_approx(profile.combat_derived.attack_speed, spec.attack_speed), "%s/%s attack_speed owns derived timing" % [reach_name, mass_name])
			_expect(float(spec.budget_breakdown.total) <= PowerBudget.MAX_POWER, "%s/%s remains within PowerBudget" % [reach_name, mass_name])
			_expect(profile.combat_derived.budget_effects.has("combined_delta"), "%s/%s records physics budget effect" % [reach_name, mass_name])
			var contact_model: Dictionary = profile.combat_derived.to_dict().contact_model
			_expect(contact_model.mode == "uniform_grip_to_tip" and contact_model.regions.is_empty() and not contact_model.sweet_spots_enabled, "%s/%s keeps B2 contact regions disabled" % [reach_name, mass_name])

	var ordered_reaches := ["1_grid", "4_grid", "8_grid", "16_grid"]
	for mass_name: String in cross_axes:
		for index in ordered_reaches.size() - 1:
			var current: DrawingGeometryProfile = matrix[ordered_reaches[index]][mass_name].profile
			var next: DrawingGeometryProfile = matrix[ordered_reaches[index + 1]][mass_name].profile
			_expect(current.effective_reach < next.effective_reach, "%s reach remains monotonic at %s -> %s" % [mass_name, ordered_reaches[index], ordered_reaches[index + 1]])
			_expect(current.combat_derived.hit_delay_seconds < next.combat_derived.hit_delay_seconds, "%s hit timing remains monotonic at %s -> %s" % [mass_name, ordered_reaches[index], ordered_reaches[index + 1]])
			_expect(current.combat_derived.cycle_seconds < next.combat_derived.cycle_seconds, "%s cycle remains monotonic at %s -> %s" % [mass_name, ordered_reaches[index], ordered_reaches[index + 1]])

	for reach_name: String in ordered_reaches:
		var light: DrawingGeometryProfile = matrix[reach_name].light.profile
		var balanced: DrawingGeometryProfile = matrix[reach_name].balanced.profile
		var heavy: DrawingGeometryProfile = matrix[reach_name].heavy.profile
		_expect(light.effective_reach == balanced.effective_reach and balanced.effective_reach == heavy.effective_reach, "%s mass axis does not change reach" % reach_name)
		_expect(light.combat_derived.hit_delay_seconds < balanced.combat_derived.hit_delay_seconds and balanced.combat_derived.hit_delay_seconds < heavy.combat_derived.hit_delay_seconds, "%s hit timing is light < balanced < heavy" % reach_name)
		_expect(light.combat_derived.cycle_seconds < balanced.combat_derived.cycle_seconds and balanced.combat_derived.cycle_seconds < heavy.combat_derived.cycle_seconds, "%s cycle is light < balanced < heavy" % reach_name)

	var fastest: DrawingGeometryProfile = matrix["1_grid"].light.profile
	var four_grid_light: DrawingGeometryProfile = matrix["4_grid"].light.profile
	var eight_grid_balanced: DrawingGeometryProfile = matrix["8_grid"].balanced.profile
	var sixteen_grid_balanced: DrawingGeometryProfile = matrix["16_grid"].balanced.profile
	var slowest: DrawingGeometryProfile = matrix["16_grid"].heavy.profile
	_expect(fastest.combat_derived.cycle_seconds >= 0.40 and fastest.combat_derived.cycle_seconds <= 0.46, "1-grid ultra-short/light cycle is inside the 0.40-0.46s exposure candidate window")
	_expect(four_grid_light.combat_derived.cycle_seconds >= 0.49 and four_grid_light.combat_derived.cycle_seconds <= 0.54, "4-grid short/light cycle is inside the 0.49-0.54s exposure candidate window")
	_expect(eight_grid_balanced.combat_derived.cycle_seconds >= 0.76 and eight_grid_balanced.combat_derived.cycle_seconds <= 0.80, "8-grid standard/balanced cycle is inside the 0.76-0.80s exposure candidate window")
	_expect(sixteen_grid_balanced.combat_derived.cycle_seconds >= 1.02 and sixteen_grid_balanced.combat_derived.cycle_seconds <= 1.07, "16-grid long/balanced cycle is inside the 1.02-1.07s exposure candidate window")
	_expect(slowest.combat_derived.cycle_seconds >= 1.16 and slowest.combat_derived.cycle_seconds <= 1.23, "16-grid long/heavy cycle is inside the 1.16-1.23s exposure candidate window")
	var cycle_ratio := slowest.combat_derived.cycle_seconds / fastest.combat_derived.cycle_seconds
	_expect(cycle_ratio >= 2.5 and cycle_ratio <= 3.0, "1-grid light to 16-grid heavy cycle ratio is inside the bounded 2.5-3.0x exposure window")
	var active_ratio := slowest.combat_derived.active_seconds / fastest.combat_derived.active_seconds
	_expect(active_ratio >= 3.0 and active_ratio < 4.0, "visible active timing remains distinct without retaining the old four-times extreme")
	_expect(fastest.combat_derived.cycle_seconds >= CombatDerived.MIN_CYCLE_SECONDS, "ultra-short cadence retains the safety floor")
	var public_fields: Dictionary = matrix["16_grid"].heavy.spec.to_dict()
	_expect(not public_fields.has("mass_profile") and not public_fields.has("combat_derived") and not public_fields.has("geometry_evidence"), "B1 does not expand the public WeaponSpec")
	_test_b1_5_exposure_fixture_cycles(canvas_size)
	_test_longitudinal_reach_mass_independence(canvas_size)


func _test_b1_5_exposure_fixture_cycles(canvas_size: Vector2) -> void:
	var boundary_spans := {"minimum": 0.0, "maximum": 1.0}
	var boundary_reaches := {"minimum": 72.0, "maximum": 228.0}
	var boundary_base_cycles := {"minimum": 0.50, "maximum": 1.01}
	for boundary_name: String in boundary_spans:
		var boundary_start := Vector2(canvas_size.x * 0.03, canvas_size.y * 0.45)
		var boundary_finish := boundary_start + Vector2(canvas_size.x * float(boundary_spans[boundary_name]), canvas_size.y * 0.10)
		var boundary_source: Array[PackedVector2Array] = [
			PackedVector2Array([boundary_start, boundary_finish]),
		]
		var boundary_profile := DrawingGeometryProfile.from_snapshot(boundary_source, canvas_size, "balanced")
		var boundary_spec := WeaponCompiler.new().compile("a plain steel sword")
		boundary_profile.apply_to_spec(boundary_spec)
		_expect(is_equal_approx(boundary_profile.effective_reach, float(boundary_reaches[boundary_name])), "%s geometry boundary clamps to the existing reach bound" % boundary_name)
		_expect(is_equal_approx(boundary_profile.combat_derived.base_cycle_seconds, float(boundary_base_cycles[boundary_name])), "%s reach boundary selects the bounded exposure anchor" % boundary_name)
		_expect(boundary_profile.combat_derived.cycle_seconds >= CombatDerived.MIN_CYCLE_SECONDS and boundary_profile.combat_derived.cycle_seconds <= CombatDerived.MAX_CYCLE_SECONDS, "%s cadence boundary retains the global cycle floor and ceiling" % boundary_name)

	var fixture_spans := {"short": 0.10, "standard": 0.42, "long": 0.88}
	var expected_reaches := {"short": 72.0, "standard": 123.0, "long": 220.0}
	var candidate_cycle_windows := {
		"short": Vector2(0.53, 0.57),
		"standard": Vector2(0.76, 0.80),
		"long": Vector2(1.08, 1.12),
	}
	var fixture_cycles: Dictionary = {}
	for fixture_name: String in fixture_spans:
		var start := Vector2(canvas_size.x * 0.06, canvas_size.y * 0.52)
		var finish := start + Vector2(canvas_size.x * float(fixture_spans[fixture_name]), canvas_size.y * 0.03)
		var source: Array[PackedVector2Array] = [
			PackedVector2Array([start, start.lerp(finish, 0.5), finish]),
		]
		var profile := DrawingGeometryProfile.from_snapshot(source, canvas_size, "balanced")
		var spec := WeaponCompiler.new().compile("a plain steel sword")
		var original_damage := spec.damage
		profile.apply_to_spec(spec)
		var cycle: float = profile.combat_derived.cycle_seconds
		var window: Vector2 = candidate_cycle_windows[fixture_name]
		fixture_cycles[fixture_name] = cycle
		_expect(profile.mass_profile == "balanced", "%s exposure fixture retains the controlled balanced mass axis" % fixture_name)
		_expect(is_equal_approx(profile.effective_reach, float(expected_reaches[fixture_name])), "%s exposure fixture retains its existing reach authority" % fixture_name)
		_expect(spec.damage == original_damage and spec.damage == 36, "%s exposure fixture leaves fixed melee damage at 36" % fixture_name)
		_expect(cycle >= window.x and cycle <= window.y, "%s balanced/slow-recovery cycle %.3f is inside %.2f-%.2fs" % [fixture_name, cycle, window.x, window.y])
		_expect(is_equal_approx(cycle, snappedf(1.0 / spec.attack_speed, 0.001)), "%s exposure fixture keeps attack_speed as the single complete-cycle authority" % fixture_name)
		_expect(profile.combat_derived.cycle_seconds >= CombatDerived.MIN_CYCLE_SECONDS and profile.combat_derived.cycle_seconds <= CombatDerived.MAX_CYCLE_SECONDS, "%s exposure fixture retains the global cycle bounds" % fixture_name)
		_expect(profile.combat_derived.to_dict().contact_model.regions.is_empty(), "%s exposure fixture does not enable B2 contact regions" % fixture_name)
	_expect(float(fixture_cycles.short) < float(fixture_cycles.standard) and float(fixture_cycles.standard) < float(fixture_cycles.long), "B1/B1.5 exposure fixtures retain short < standard < long cadence")


func _test_longitudinal_reach_mass_independence(canvas_size: Vector2) -> void:
	# All three inputs have the exact same x extrema. Only cross-axis thickness
	# changes, including a deliberately extreme heavy case that activated the old
	# ink-aspect reach cap. This test contains no browser/pointer sampling.
	var cross_axis_pixels := {"light": 12.0, "balanced": 45.0, "heavy": 280.0}
	var profiles: Dictionary = {}
	for expected_mass: String in cross_axis_pixels:
		var half_height := float(cross_axis_pixels[expected_mass]) * 0.5
		var center_y := canvas_size.y * 0.5
		var stroke := PackedVector2Array([
			Vector2(20.0, center_y - half_height),
			Vector2(520.0, center_y - half_height),
			Vector2(520.0, center_y + half_height),
			Vector2(20.0, center_y + half_height),
		])
		var source: Array[PackedVector2Array] = [stroke]
		var profile := DrawingGeometryProfile.from_snapshot(source, canvas_size)
		profiles[expected_mass] = profile
		_expect(profile.mass_profile == expected_mass, "%s cross-axis evidence selects its mass without Playwright" % expected_mass)
		_expect(is_equal_approx(profile.source_bounds.size.x, 500.0), "%s fixture preserves the identical longitudinal bound" % expected_mass)
		_expect(str(profile.physical_profile.to_dict().reach_basis) == "normalized_length_only", "%s reach declares longitudinal-only authority" % expected_mass)
		_expect(not bool(profile.physical_profile.to_dict().cross_axis_affects_reach), "%s cross-axis is excluded from reach" % expected_mass)

	var light: DrawingGeometryProfile = profiles.light
	var balanced: DrawingGeometryProfile = profiles.balanced
	var heavy: DrawingGeometryProfile = profiles.heavy
	_expect(is_equal_approx(light.normalized_length, balanced.normalized_length) and is_equal_approx(balanced.normalized_length, heavy.normalized_length), "identical longitudinal evidence stays identical across mass inputs")
	_expect(light.effective_reach == balanced.effective_reach and balanced.effective_reach == heavy.effective_reach, "light/balanced/heavy cannot change effective reach for identical longitudinal evidence")


func _test_weapon_role_balance_matrix() -> void:
	var file := FileAccess.open("res://tests/weapon_role_balance_matrix.json", FileAccess.READ)
	_expect(file != null, "B1.5 weapon-role matrix is readable")
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	_expect(parsed is Dictionary, "B1.5 weapon-role matrix parses as an object")
	if parsed is not Dictionary:
		return
	var matrix: Dictionary = parsed
	var scenarios: Array = matrix.get("scenario_order", [])
	_expect(scenarios == ["stationary", "moving", "shield", "group"], "B1.5 records each required target scenario independently")
	var cases: Array = matrix.get("role_cases", [])
	_expect(cases.size() == 7, "B1.5 matrix contains the seven authorized weapon roles")
	var roles: Dictionary = {}
	var patterns: Dictionary = {}
	var runtime_by_role: Dictionary = {}
	var canvas_size := Vector2(640.0, 300.0)
	for case: Dictionary in cases:
		var case_id := str(case.get("id", "missing-id"))
		var role_id := str(case.get("role_id", ""))
		var expected_pattern := str(case.get("attack_pattern", ""))
		var compiler := WeaponCompiler.new()
		var spec: WeaponSpec
		if case.has("validated_overrides"):
			var raw := WeaponSpec.fallback().to_dict()
			raw.merge(case.validated_overrides, true)
			spec = compiler.compile_raw(raw)
		else:
			spec = compiler.compile(str(case.get("description", "")), {"aspect_ratio": 2.0, "point_count": 12})
		_expect(spec.attack_pattern == expected_pattern, "%s executes the expected attack module" % case_id)
		_expect(spec.weapon_form == str(case.get("weapon_form", "")), "%s preserves its weapon-form semantics" % case_id)
		_expect(spec.element == str(case.get("element", "")), "%s preserves its element" % case_id)
		var geometry: Dictionary = case.get("geometry", {})
		var geometry_profile: DrawingGeometryProfile = null
		if spec.attack_pattern == "melee_slash":
			var normalized_span := float(geometry.get("normalized_span", 0.40))
			var cross_axis_load := float(geometry.get("cross_axis_load", 0.14))
			var start_x := canvas_size.x * 0.03
			var end_x := start_x + canvas_size.x * normalized_span
			var half_height := canvas_size.y * cross_axis_load * 0.5
			var center_y := canvas_size.y * 0.5
			var stroke := PackedVector2Array([
				Vector2(start_x, center_y - half_height),
				Vector2(end_x - 8.0, center_y - half_height),
				Vector2(end_x, center_y),
				Vector2(end_x - 8.0, center_y + half_height),
				Vector2(start_x, center_y + half_height),
			])
			var source: Array[PackedVector2Array] = [stroke]
			geometry_profile = DrawingGeometryProfile.from_snapshot(source, canvas_size)
			geometry_profile.apply_to_spec(spec)
			_expect(geometry_profile.mass_profile == str(geometry.get("mass_profile", "")), "%s keeps mass independent and auditable" % case_id)
		var role_profile := WeaponRoleProfile.derive(spec, geometry_profile)
		var role := role_profile.to_dict()
		var cycle_seconds := float(role.cycle_seconds)
		var travel_seconds := float(role.projectile_travel_seconds)
		_expect(spec.is_valid() and bool(compiler.last_record.runtime_valid), "%s remains runtime-valid" % case_id)
		_expect(spec.power_score <= PowerBudget.MAX_POWER, "%s remains within the explicit PowerBudget" % case_id)
		_expect(str(role.role_id) == role_id, "%s derives the expected internal role family" % case_id)
		_expect(str(role.authority) == "WeaponRoleProfile" and str(role.status) == "TO VALIDATE" and str(role.role_family_status) == "authorized_b1_5_role", "%s labels internal role authority without a production-balance claim" % case_id)
		_expect(is_finite(cycle_seconds) and cycle_seconds > 0.0, "%s exposes a finite positive complete cycle" % case_id)
		_expect(is_finite(spec.attack_range) and spec.attack_range > 0.0, "%s exposes finite positive reach/travel range" % case_id)
		_expect(is_finite(travel_seconds) and travel_seconds >= 0.0, "%s exposes finite auditable projectile travel" % case_id)
		_expect(Array(role.advantages).size() > 0 and Array(case.get("advantages", [])).size() > 0, "%s derives at least one role advantage" % case_id)
		_expect(Array(role.deterministic_costs).size() > 0 and Array(case.get("costs", [])).size() > 0 and spec.drawback != "none", "%s derives and executes at least one deterministic cost" % case_id)
		_expect(Array(role.audit_reasons).size() > 0 and str(role.audit_reasons[0]).contains(role_id), "%s retains its role derivation reason" % case_id)
		_expect(int(role.power_score) == spec.power_score and is_equal_approx(float(role.power_components.total), float(PowerBudget.calculate(spec.to_dict()).total)), "%s role audit agrees with the unchanged public PowerBudget" % case_id)
		var phase_sum := float(role.startup_seconds) + float(role.active_seconds) + float(role.recovery_seconds)
		_expect(is_equal_approx(phase_sum, cycle_seconds), "%s startup + active + recovery owns the complete cycle" % case_id)
		_expect(float(role.commit_delay_seconds) > 0.0 and float(role.commit_delay_seconds) <= cycle_seconds, "%s commit timing is finite and bounded by the cycle" % case_id)
		var repeated := WeaponRoleProfile.derive(WeaponSpec.from_dict(spec.to_dict()), geometry_profile).to_dict()
		_expect(role == repeated, "%s identical validated semantics and geometry derive identical serialized role output" % case_id)
		var public_spec := spec.to_dict()
		_expect(not public_spec.has("role_id") and not public_spec.has("weapon_role") and not public_spec.has("role_profile"), "%s keeps the internal role layer out of public WeaponSpec" % case_id)
		var case_scenarios: Dictionary = case.get("scenarios", {})
		for scenario: String in scenarios:
			_expect(case_scenarios.has(scenario) and Array(case_scenarios[scenario].get("evidence", [])).size() > 0, "%s records %s evidence without an aggregate substitute" % [case_id, scenario])
		_expect(str(role.moving_target_risk) in ["low", "medium", "high"], "%s moving-target risk is explicit and bounded" % case_id)
		_expect(str(role.shield_rule) in ["blocked_to_20_percent", "bypassed_by_area_blast", "outbound_blocked_return_bypasses", "bypassed_by_piercing"], "%s shield behavior is explicit" % case_id)
		_expect(int(role.body_hit_limit) == -1 or int(role.body_hit_limit) >= 1, "%s grouped-target body limit is explicit" % case_id)
		roles[role_id] = true
		patterns[spec.attack_pattern] = true
		runtime_by_role[role_id] = {
			"spec": spec,
			"role": role,
			"cycle_seconds": cycle_seconds,
			"travel_seconds": travel_seconds,
		}

	_expect(roles.keys().all(func(role: Variant) -> bool: return not str(role).is_empty()) and roles.size() == 7, "B1.5 role IDs are unique and non-empty")
	_expect(patterns.size() == 5, "B1.5 role cases retain all five executable attack modules")
	if runtime_by_role.has("short_melee") and runtime_by_role.has("standard_melee") and runtime_by_role.has("long_melee"):
		var short: WeaponSpec = runtime_by_role.short_melee.spec
		var standard: WeaponSpec = runtime_by_role.standard_melee.spec
		var long: WeaponSpec = runtime_by_role.long_melee.spec
		_expect(short.attack_range < standard.attack_range and standard.attack_range < long.attack_range, "B1.5 melee roles retain short < standard < long reach")
		_expect(float(runtime_by_role.short_melee.cycle_seconds) < float(runtime_by_role.standard_melee.cycle_seconds) and float(runtime_by_role.standard_melee.cycle_seconds) < float(runtime_by_role.long_melee.cycle_seconds), "B1.5 melee roles trade cadence for reach")
		_expect(short.damage == standard.damage and standard.damage == long.damage, "B1.5 does not leak length into melee damage or B2 contact behavior")
	if runtime_by_role.has("straight_ranged") and runtime_by_role.has("short_melee"):
		var ranged: WeaponSpec = runtime_by_role.straight_ranged.spec
		var short_melee: WeaponSpec = runtime_by_role.short_melee.spec
		_expect(ranged.attack_range > short_melee.attack_range, "straight ranged gains safety/range over short melee")
		_expect(ranged.damage * ranged.attack_speed < short_melee.damage * short_melee.attack_speed and ranged.drawback == "low_impact", "straight ranged does not also gain the highest sustained single-target value for free")
	if runtime_by_role.has("thrown_blast"):
		var blast: WeaponSpec = runtime_by_role.thrown_blast.spec
		_expect(blast.area_radius > 0.0 and blast.delivery == "thrown" and blast.trajectory == "arc", "thrown blast retains delayed arc delivery plus explicit group radius")
		_expect(float(runtime_by_role.thrown_blast.role.blast_damage_delay_seconds) > 0.0 and float(runtime_by_role.thrown_blast.cycle_seconds) > float(runtime_by_role.straight_ranged.cycle_seconds), "thrown blast pays explicit detonation delay and a slower complete cycle")
		_expect(int(runtime_by_role.thrown_blast.role.body_hit_limit) == -1, "thrown blast group value remains radius-limited rather than body-count limited")
	if runtime_by_role.has("boomerang"):
		var boomerang: WeaponSpec = runtime_by_role.boomerang.spec
		_expect(boomerang.return_speed > 0.0 and boomerang.special_ability == "return_strike", "boomerang retains a distinct budgeted return path")
		_expect(bool(runtime_by_role.boomerang.role.return_hit_opportunity) and int(runtime_by_role.boomerang.role.per_target_hit_limit) == 2 and int(runtime_by_role.boomerang.role.per_phase_per_target_limit) == 1, "boomerang has exactly bounded per-target outbound and return opportunities")
	if runtime_by_role.has("piercing"):
		var piercing: WeaponSpec = runtime_by_role.piercing.spec
		var piercing_role: Dictionary = runtime_by_role.piercing.role
		_expect(piercing.pierce_count > 1 and piercing.drawback == "narrow_arc", "piercing retains its schema-compatible bounded drawback enum")
		_expect(is_equal_approx(float(piercing_role.projectile_hit_radius), WeaponRoleProfile.NARROW_PROJECTILE_HIT_RADIUS), "piercing retains its diagnostic narrow collision geometry")
		_expect(int(piercing_role.body_hit_limit) == piercing.pierce_count, "piercing body-hit limit equals its bounded public pierce count")
		_expect(
			Array(piercing_role.get("piercing_damage_multipliers", [])) == [1.0, 0.7, 0.45],
			"piercing serializes the fixed first/second/third-body damage multipliers",
		)
		_expect(
			str(piercing_role.get("movement_lock_policy", "")) == "horizontal_during_startup"
			and bool(piercing_role.get("movement_locked_during_startup", false)),
			"piercing serializes its startup-only horizontal movement commitment",
		)

	var compatibility_cases: Array = matrix.get("compatibility_cases", [])
	_expect(compatibility_cases.size() == 1, "B1.5 retains one explicit direct-blast compatibility case outside the seven product roles")
	for compatibility_case: Dictionary in compatibility_cases:
		var compatibility_spec := WeaponCompiler.new().compile(str(compatibility_case.get("description", "")), {}, "area_blast")
		var compatibility_role := WeaponRoleProfile.derive(compatibility_spec).to_dict()
		_expect(str(compatibility_role.role_id) == "direct_blast", "held/direct area_blast is audited honestly as direct_blast")
		_expect(str(compatibility_role.role_family_status) == "compatibility_existing_path", "direct_blast is excluded from the seven authorized product roles")
		_expect(compatibility_spec.delivery == "held" and compatibility_spec.trajectory == "direct" and compatibility_spec.weapon_form == "generic", "direct_blast does not masquerade as a thrown grenade")
		_expect(Array(compatibility_role.advantages).size() > 0 and Array(compatibility_role.deterministic_costs).size() > 0, "direct_blast records its real radius advantage and proximity/cooldown cost")

	var element_cases: Array = matrix.get("element_execution_cases", [])
	var elements: Dictionary = {}
	var element_patterns: Dictionary = {}
	for element_case: Dictionary in element_cases:
		var element_spec := WeaponCompiler.new().compile(str(element_case.get("description", "")), {}, str(element_case.get("attack_pattern", "")))
		_expect(element_spec.is_valid(), "%s remains an executable element/module combination" % str(element_case.get("id", "element-case")))
		_expect(element_spec.attack_pattern == str(element_case.get("attack_pattern", "")) and element_spec.element == str(element_case.get("element", "")), "%s compiles the requested element and module" % str(element_case.get("id", "element-case")))
		elements[element_spec.element] = true
		element_patterns[element_spec.attack_pattern] = true
	_expect(elements.size() == 4, "B1.5 element smoke retains normal, fire, ice, and electric")
	_expect(element_patterns.size() == 5, "B1.5 element smoke touches all five executable modules")


func _test_role_entry_path_parity() -> void:
	var description := "a plain steel sword"
	var drawing_summary := {"aspect_ratio": 2.0, "point_count": 12}
	var canvas_size := Vector2(640.0, 300.0)
	var stroke := PackedVector2Array([
		Vector2(20.0, 129.0), Vector2(273.0, 129.0), Vector2(281.0, 150.0),
		Vector2(273.0, 171.0), Vector2(20.0, 171.0),
	])
	var source: Array[PackedVector2Array] = [stroke]
	var geometry := DrawingGeometryProfile.from_snapshot(source, canvas_size)
	var semantic_spec := WeaponCompiler.new().compile(description, drawing_summary)
	var semantic_dict := semantic_spec.to_dict()

	var local_spec := WeaponSpec.from_dict(semantic_dict)
	geometry.apply_to_spec(local_spec)
	var local_projection := _role_parity_projection(local_spec, geometry)

	var interpreter := WeaponInterpreter.new()
	root.add_child(interpreter)
	interpreter.active_request_id = "role-parity-provider"
	var provider_validation := interpreter._validate_server_result({
		"success": true,
		"provider_invoked": true,
		"request_id": "role-parity-provider",
		"weapon_spec": semantic_dict,
		"confidence": 0.95,
		"corrections": [],
		"fallback_reason": "",
		"provider_metadata": {
			"provider": WeaponInterpreter.REQUIRED_PROVIDER,
			"model": WeaponInterpreter.REQUIRED_MODEL,
			"attempts": 1,
		},
		"estimated_cost": "UNKNOWN",
	})
	_expect(bool(provider_validation.get("ok", false)), "B1.5 provider entry accepts the fixed validated semantic fixture")
	var provider_spec := WeaponSpec.from_dict(provider_validation.result.weapon_spec)
	geometry.apply_to_spec(provider_spec)
	var provider_projection := _role_parity_projection(provider_spec, geometry)

	# These are the exact project-owned compiler calls used by the manual-repair
	# and Developer/Test handlers. Browser coverage below exercises the actual UI
	# handlers; this unit gate fixes their semantic/geometry input for strict data parity.
	var manual_compiler := WeaponCompiler.new()
	var manual_spec := manual_compiler.compile(description, drawing_summary, "melee_slash", true)
	geometry.apply_to_spec(manual_spec)
	var manual_projection := _role_parity_projection(manual_spec, geometry)
	var developer_compiler := WeaponCompiler.new()
	var developer_spec := developer_compiler.compile(description, drawing_summary, "melee_slash", true)
	geometry.apply_to_spec(developer_spec)
	var developer_projection := _role_parity_projection(developer_spec, geometry)

	_expect(local_projection == provider_projection, "fixed local and provider entries derive identical role/timing/reach/cost output")
	_expect(local_projection == manual_projection, "fixed local and manual-repair compiler entries derive identical role/timing/reach/cost output")
	_expect(local_projection == developer_projection, "fixed local and Developer/Test compiler entries derive identical role/timing/reach/cost output")
	_expect(str(local_projection.role_id) == "standard_melee" and str(local_projection.timing_authority) == "CombatDerived", "entry parity retains the B0/B1 melee timing authority")
	interpreter.queue_free()


func _role_parity_projection(spec: WeaponSpec, geometry: DrawingGeometryProfile) -> Dictionary:
	var role := WeaponRoleProfile.derive(spec, geometry).to_dict()
	return {
		"role_id": role.role_id,
		"timing_authority": "CombatDerived" if geometry != null and geometry.applies_to(spec) else "WeaponRoleProfile",
		"cycle_seconds": role.cycle_seconds,
		"startup_seconds": role.startup_seconds,
		"active_seconds": role.active_seconds,
		"commit_delay_seconds": role.commit_delay_seconds,
		"recovery_seconds": role.recovery_seconds,
		"effective_reach": role.effective_reach,
		"projectile_travel_seconds": role.projectile_travel_seconds,
		"projectile_travel_model": role.projectile_travel_model,
		"advantages": role.advantages,
		"deterministic_costs": role.deterministic_costs,
		"moving_target_risk": role.moving_target_risk,
		"shield_rule": role.shield_rule,
		"body_hit_limit": role.body_hit_limit,
		"drawback": spec.drawback,
		"weakness": spec.weakness_label(),
		"power_score": role.power_score,
	}


func _test_role_runtime_behavior_oracles() -> void:
	var raw := WeaponSpec.fallback().to_dict()
	raw.merge({
		"name": "Direct Blast Fixture", "weapon_class": "melee", "weapon_form": "generic",
		"delivery": "held", "trajectory": "direct", "impact": "contact",
		"area_effect": "explosion", "attack_pattern": "area_blast", "element": "normal",
		"damage": 34, "attack_speed": 0.7, "range": 220.0,
		"special_ability": "splash_wave", "status_effect": "none",
		"drawback": "cooldown_lock", "area_radius": 165.0,
	}, true)
	var direct_spec := WeaponCompiler.new().compile_raw(raw)
	var direct_role := WeaponRoleProfile.derive(direct_spec).to_dict()
	_expect(str(direct_role.role_id) == "direct_blast" and str(direct_role.projectile_travel_model) == "none", "direct_blast executes as a player-centred compatibility path without fake projectile travel")
	var near_group_a := TrainingDummy.new()
	var near_group_b := TrainingDummy.new()
	var near_shield := TrainingDummy.new()
	var far_target := TrainingDummy.new()
	near_group_a.configure("group", "DIRECT GROUP A", 100)
	near_group_b.configure("group", "DIRECT GROUP B", 100)
	near_shield.configure("shield", "DIRECT SHIELD", 100)
	far_target.configure("stationary", "DIRECT FAR", 100)
	root.add_child(near_group_a)
	root.add_child(near_group_b)
	root.add_child(near_shield)
	root.add_child(far_target)
	near_group_a.global_position = Vector2(50.0, 0.0)
	near_group_b.global_position = Vector2(105.0, 0.0)
	near_shield.global_position = Vector2(150.0, 0.0)
	far_target.global_position = Vector2(210.0, 0.0)
	var blast := ForgeAreaBlast.new()
	blast.configure(direct_spec, Vector2.RIGHT)
	root.add_child(blast)
	var completed: Array[int] = []
	blast.hits_complete.connect(func(count: int, total: int) -> void: completed.assign([count, total]))
	await blast.hits_complete
	_expect(completed == [3, direct_spec.damage * 3], "direct_blast actually damages every in-radius body once")
	_expect(near_shield.health == 100 - direct_spec.damage, "direct_blast actually bypasses shield reduction")
	_expect(far_target.health == 100, "direct_blast proximity cost actually excludes a body outside area_radius")
	for target: TrainingDummy in [near_group_a, near_group_b, near_shield, far_target]:
		target.queue_free()

	var piercing_spec := WeaponCompiler.new().compile("a spear that pierces shields")
	var projectile := ForgeProjectile.new()
	projectile.configure(piercing_spec, [], Vector2.RIGHT)
	root.add_child(projectile)
	await process_frame
	var collision: CollisionShape2D = null
	for child: Node in projectile.get_children():
		if child is CollisionShape2D:
			collision = child as CollisionShape2D
			break
	var circle: CircleShape2D = null
	if collision != null:
		circle = collision.shape as CircleShape2D
	_expect(circle != null and is_equal_approx(circle.radius, WeaponRoleProfile.NARROW_PROJECTILE_HIT_RADIUS), "piercing diagnostic collision geometry remains narrow without being its primary role cost")
	projectile.queue_free()
	await process_frame


func _test_piercing_bow_role_separation() -> void:
	var bow_raw := WeaponSpec.fallback().to_dict()
	bow_raw.merge({
		"name": "Bow Role Regression", "weapon_class": "ranged", "weapon_form": "bow",
		"delivery": "projectile", "trajectory": "direct", "impact": "contact",
		"area_effect": "none", "attack_pattern": "straight_projectile", "element": "normal",
		"damage": 26, "attack_speed": 1.3, "range": 675.0,
		"special_ability": "none", "status_effect": "none", "drawback": "low_impact",
		"projectile_speed": 620.0, "pierce_count": 1,
	}, true)
	var piercing_raw := WeaponSpec.fallback().to_dict()
	piercing_raw.merge({
		"name": "Piercing Role Regression", "weapon_class": "ranged", "weapon_form": "spear",
		"delivery": "projectile", "trajectory": "direct", "impact": "piercing",
		"area_effect": "none", "attack_pattern": "piercing", "element": "normal",
		"damage": 29, "attack_speed": 1.05, "range": 700.0,
		"special_ability": "shield_break", "status_effect": "none", "drawback": "narrow_arc",
		"projectile_speed": 720.0, "pierce_count": 3,
	}, true)
	var bow_spec := WeaponCompiler.new().compile_raw(bow_raw)
	var piercing_spec := WeaponCompiler.new().compile_raw(piercing_raw)
	var bow_role := WeaponRoleProfile.derive(bow_spec).to_dict()
	var piercing_role := WeaponRoleProfile.derive(piercing_spec).to_dict()
	_expect(
		is_equal_approx(float(bow_role.cycle_seconds), 0.769)
		and is_equal_approx(float(bow_role.startup_seconds), 0.138)
		and bow_spec.damage == 26,
		"Bow retains its pre-Piercing-fix attack timing and base damage",
	)
	_expect(
		float(piercing_role.startup_seconds) >= float(bow_role.startup_seconds) * 1.5
		and float(piercing_role.cycle_seconds) >= float(bow_role.cycle_seconds) * 1.2,
		"Piercing startup and complete cycle are significantly longer than Bow",
	)
	_expect(
		Array(piercing_role.get("piercing_damage_multipliers", [])) == [1.0, 0.7, 0.45],
		"Piercing role owns the deterministic 100/70/45 percent damage schedule",
	)

	var bow_first := TrainingDummy.new()
	var bow_second := TrainingDummy.new()
	var bow_shield := TrainingDummy.new()
	bow_first.configure("group", "BOW FIRST", 100)
	bow_second.configure("group", "BOW SECOND", 100)
	bow_shield.configure("shield", "BOW SHIELD", 100)
	for target: TrainingDummy in [bow_first, bow_second, bow_shield]:
		root.add_child(target)
	var bow_projectile := ForgeProjectile.new()
	bow_projectile.configure(bow_spec, [], Vector2.RIGHT)
	root.add_child(bow_projectile)
	bow_projectile.monitoring = false
	await process_frame
	bow_projectile._on_body_entered(bow_first)
	bow_projectile._on_body_entered(bow_second)
	var bow_records: Array = bow_projectile.qa_visual_state().get("hit_records", [])
	_expect(
		bow_first.health == 74 and bow_second.health == 100 and bow_records.size() == 1,
		"Bow stops on the first body and cannot damage a second target from the same shot",
	)
	var bow_shield_projectile := ForgeProjectile.new()
	bow_shield_projectile.configure(bow_spec, [], Vector2.RIGHT)
	root.add_child(bow_shield_projectile)
	bow_shield_projectile.monitoring = false
	await process_frame
	bow_shield_projectile._on_body_entered(bow_shield)
	_expect(bow_shield.health == 94, "Bow retains frontal shield reduction at 20 percent rounded up")

	var piercing_targets: Array[TrainingDummy] = []
	for index in 4:
		var target := TrainingDummy.new()
		target.configure("group", "PIERCE %d" % (index + 1), 100)
		piercing_targets.append(target)
		root.add_child(target)
	var piercing_projectile := ForgeProjectile.new()
	piercing_projectile.configure(piercing_spec, [], Vector2.RIGHT)
	root.add_child(piercing_projectile)
	piercing_projectile.monitoring = false
	await process_frame
	for target: TrainingDummy in piercing_targets:
		piercing_projectile._on_body_entered(target)
	var hit_records: Array = piercing_projectile.qa_visual_state().get("hit_records", [])
	var record_projection: Array[Dictionary] = []
	for record: Dictionary in hit_records:
		record_projection.append({
			"hit_index": int(record.get("hit_index", 0)),
			"damage_multiplier": float(record.get("damage_multiplier", 0.0)),
			"base_damage": int(record.get("base_damage", 0)),
			"requested_damage": int(record.get("requested_damage", 0)),
			"amount": int(record.get("amount", 0)),
		})
	_expect(
		piercing_targets.map(func(target: TrainingDummy) -> int: return target.health) == [71, 80, 87, 100],
		"Piercing applies 29/20/13 damage to the first three bodies and zero to the fourth",
	)
	_expect(
		record_projection == [
			{"hit_index": 1, "damage_multiplier": 1.0, "base_damage": 29, "requested_damage": 29, "amount": 29},
			{"hit_index": 2, "damage_multiplier": 0.7, "base_damage": 29, "requested_damage": 20, "amount": 20},
			{"hit_index": 3, "damage_multiplier": 0.45, "base_damage": 29, "requested_damage": 13, "amount": 13},
		],
		"Piercing projectile serializes every bounded hit index, multiplier, base, request and actual damage",
	)
	var piercing_shield := TrainingDummy.new()
	piercing_shield.configure("shield", "PIERCE SHIELD", 100)
	root.add_child(piercing_shield)
	var piercing_shield_projectile := ForgeProjectile.new()
	piercing_shield_projectile.configure(piercing_spec, [], Vector2.RIGHT)
	root.add_child(piercing_shield_projectile)
	piercing_shield_projectile.monitoring = false
	await process_frame
	piercing_shield_projectile._on_body_entered(piercing_shield)
	var shield_records: Array = piercing_shield_projectile.qa_visual_state().get("hit_records", [])
	_expect(
		piercing_shield.health == 71
		and shield_records.size() == 1
		and int((shield_records[0] as Dictionary).get("amount", 0)) == 29,
		"Piercing first-hit damage still bypasses frontal shield reduction",
	)

	var bow_player := ForgePlayer.new()
	root.add_child(bow_player)
	bow_player.equip(bow_spec, [])
	bow_player.movement_bounds = Vector2(0.0, 1200.0)
	bow_player.global_position = Vector2(300.0, 0.0)
	bow_player.attack()
	bow_player.set_touch_axis(1.0)
	await bow_player.attack_requested
	var bow_commit_state := bow_player.held_visual_state()
	_expect(
		bow_player.global_position.x > 304.0
		and not bool(bow_commit_state.get("movement_locked", true))
		and not bool(bow_commit_state.get("last_attack_movement_locked_during_startup", true)),
		"Bow keeps horizontal movement during startup and is not changed by Piercing commitment",
	)
	bow_player.set_touch_axis(0.0)

	var piercing_player := ForgePlayer.new()
	root.add_child(piercing_player)
	piercing_player.equip(piercing_spec, [])
	piercing_player.movement_bounds = Vector2(0.0, 1200.0)
	piercing_player.global_position = Vector2(300.0, 0.0)
	piercing_player.attack()
	piercing_player.set_touch_axis(1.0)
	await physics_frame
	var locked_x := piercing_player.global_position.x
	var locked_state := piercing_player.held_visual_state()
	_expect(
		absf(locked_x - 300.0) <= 0.5
		and bool(locked_state.get("movement_locked", false))
		and str(locked_state.get("movement_lock_reason", "")) == "piercing_startup",
		"Piercing startup locks real horizontal player movement with an explicit reason",
	)
	await piercing_player.attack_requested
	var commit_state := piercing_player.held_visual_state()
	var resumed_position := false
	for _frame in 4:
		await physics_frame
		if piercing_player.global_position.x > locked_x + 1.0:
			resumed_position = true
			break
	var post_commit_state := piercing_player.held_visual_state()
	_expect(
		not bool(commit_state.get("movement_locked", true))
		and resumed_position
		and not bool(post_commit_state.get("movement_locked", true)),
		"Piercing movement resumes immediately after projectile commit",
	)
	var recovered := false
	for _frame in 180:
		await physics_frame
		var recovery_state := piercing_player.held_visual_state()
		if float(recovery_state.get("cooldown", 1.0)) <= 0.0:
			recovered = not bool(recovery_state.get("movement_locked", true))
			break
	var completed_state := piercing_player.held_visual_state()
	_expect(
		recovered
		and bool(completed_state.get("last_attack_movement_locked_during_startup", false))
		and not bool(completed_state.get("movement_locked", true)),
		"Piercing startup lock is observed, serialized and cannot persist through recovery",
	)
	piercing_player.set_touch_axis(0.0)

	for target: TrainingDummy in [bow_first, bow_second, bow_shield, piercing_shield]:
		target.queue_free()
	for target: TrainingDummy in piercing_targets:
		target.queue_free()
	# Every projectile above is already queued by its bounded finish path. Do not
	# materialize a typed array containing those freed instances during cleanup.
	bow_player.queue_free()
	piercing_player.queue_free()
	await process_frame


func _test_element_combat_effect_events() -> void:
	var normal := TrainingDummy.new()
	normal.configure("stationary", "ELEMENT NORMAL", 100)
	root.add_child(normal)
	var normal_events: Array[Dictionary] = []
	normal.damage_report.connect(func(label: String, amount: int, note: String) -> void: normal_events.append({"label": label, "amount": amount, "note": note}))
	normal.take_damage(10, "none", "straight_projectile", Vector2.RIGHT)
	_expect(normal.health == 90 and normal_events.size() == 1 and str(normal_events[0].note) == "NONE", "normal executes one unmodified combat damage event")

	var fire := TrainingDummy.new()
	fire.configure("stationary", "ELEMENT FIRE", 100)
	root.add_child(fire)
	var fire_health_events: Array[int] = []
	fire.health_changed.connect(func(current: int, _maximum: int) -> void: fire_health_events.append(current))
	fire.take_damage(10, "burn", "straight_projectile", Vector2.RIGHT)
	await fire.health_changed
	await fire.health_changed
	_expect(fire_health_events == [90, 87, 84] and fire.health == 84, "fire executes the immediate hit plus exactly two delayed burn damage events")

	var ice := TrainingDummy.new()
	ice.configure("moving", "ELEMENT ICE", 100)
	root.add_child(ice)
	var ice_events: Array[Dictionary] = []
	ice.damage_report.connect(func(_label: String, amount: int, note: String) -> void: ice_events.append({"amount": amount, "note": note}))
	ice.take_damage(10, "freeze", "straight_projectile", Vector2.RIGHT)
	await physics_frame
	_expect(ice_events.size() == 1 and str(ice_events[0].note).contains("SLOWED") and absf(ice.velocity.x) < ice.patrol_speed, "ice executes a damage event and reduces real moving-target velocity")

	var electric := TrainingDummy.new()
	electric.configure("moving", "ELEMENT ELECTRIC", 100)
	root.add_child(electric)
	var electric_events: Array[Dictionary] = []
	electric.damage_report.connect(func(_label: String, amount: int, note: String) -> void: electric_events.append({"amount": amount, "note": note}))
	electric.take_damage(10, "shock", "straight_projectile", Vector2.RIGHT)
	await physics_frame
	_expect(electric_events.size() == 1 and str(electric_events[0].note).contains("STAGGER") and electric.velocity.is_zero_approx(), "electric executes a damage event and actually staggers moving-target velocity to zero")

	for target: TrainingDummy in [normal, fire, ice, electric]:
		target.queue_free()
	await process_frame


func _test_attack_pattern_touch_selector() -> void:
	var selector := AttackPatternSelector.new()
	selector._ready()
	var buttons := selector.buttons()
	_expect(buttons.size() == 5, "touch selector exposes five persistent buttons")
	_expect(selector.selected_index == 0 and selector.selected_pattern() == "melee_slash", "touch selector defaults to melee slash")
	for index in AttackPatternSelector.PATTERNS.size():
		buttons[index].emit_signal(&"pressed")
		_expect(selector.selected_index == index, "touch selector selects %s" % AttackPatternSelector.PATTERNS[index])
		var active_count := 0
		for button in buttons:
			if button.button_pressed: active_count += 1
		_expect(active_count == 1, "touch selector keeps exactly one active button")
		_expect(buttons[index].text.begins_with("[X]"), "selected pattern has a visible check mark")
		_expect(buttons[index].custom_minimum_size.y >= 72.0, "regular selector keeps a generous touch target")
		_expect(selector.selected_idea() == AttackPatternSelector.IDEAS[index], "LOAD IDEA maps to the selected pattern")
		var compiler := WeaponCompiler.new()
		var spec := compiler.compile("conflicting boomerang blast text", {"aspect_ratio": 1.0}, selector.selected_pattern())
		_expect(spec.attack_pattern == selector.selected_pattern(), "M1A compile override produces the selected pattern")
		_expect(str(compiler.last_record.forced_attack_pattern) == selector.selected_pattern(), "compile audit records the M1A override")
	for step in 20:
		var index := step % AttackPatternSelector.PATTERNS.size()
		buttons[index].emit_signal(&"pressed")
		var active_count := 0
		for button in buttons:
			if button.button_pressed: active_count += 1
		_expect(selector.selected_index == index and active_count == 1, "rapid selector switch %d remains responsive and exclusive" % (step + 1))
	selector.queue_free()


func _test_mobile_layout_policy() -> void:
	for css_size in [Vector2(844, 390), Vector2(852, 393), Vector2(915, 412), Vector2(734, 343)]:
		var logical_size := Vector2(1280.0, 1280.0 * css_size.y / css_size.x)
		var metrics: Dictionary = MobileLayoutPolicy.compact_metrics(logical_size, css_size)
		var scale: float = css_size.x / logical_size.x
		_expect(MobileLayoutPolicy.should_use_compact(css_size), "%dx%d enables Compact Landscape" % [css_size.x, css_size.y])
		_expect(float(metrics.touch_height) * scale >= 44.0 and float(metrics.touch_height) * scale <= 48.0, "%dx%d touch controls render at 44-48 CSS px" % [css_size.x, css_size.y])
		_expect(float(metrics.canvas_height) * scale >= 150.0, "%dx%d drawing canvas minimum is at least 150 CSS px" % [css_size.x, css_size.y])
		_expect(float(metrics.canvas_height) * scale >= css_size.y * 0.4, "%dx%d drawing canvas occupies at least 40 percent" % [css_size.x, css_size.y])
	_expect(not MobileLayoutPolicy.should_use_compact(Vector2(1280, 720)), "desktop viewport retains the regular layout")
	_expect(not MobileLayoutPolicy.should_use_compact(Vector2(844, 430)), "430 CSS px is outside the compact-height threshold")
	var selector := AttackPatternSelector.new()
	selector._ready()
	var compact: Dictionary = MobileLayoutPolicy.compact_metrics(Vector2(1280, 598), Vector2(734, 343))
	selector.set_compact(true, float(compact.touch_height), int(compact.body_font))
	_expect(selector.columns == 5, "compact selector uses one row of five buttons")
	for index in selector.buttons().size():
		var button: Button = selector.buttons()[index]
		_expect(button.text.contains(AttackPatternSelector.COMPACT_LABELS[index]), "compact selector uses readable short label %s" % AttackPatternSelector.COMPACT_LABELS[index])
	selector.queue_free()


func _test_forge_reset_state() -> void:
	var scene: PackedScene = load("res://scenes/main.tscn")
	var forge := scene.instantiate() as ProjectForgeMain
	root.add_child(forge)
	await process_frame
	forge.description_input.text = "loaded example"
	forge.loaded_idea_pattern = "boomerang"
	forge.pattern_selector.select_pattern(2, false)
	forge.drawing_canvas.strokes.append(PackedVector2Array([Vector2(10, 10), Vector2(60, 30)]))
	forge._clear_description()
	_expect(forge.description_input.text.is_empty(), "description X clears only the description")
	_expect(not forge.drawing_canvas.is_empty(), "description X preserves drawing strokes")
	_expect(forge.pattern_selector.selected_pattern() == "boomerang", "description X preserves the selected mode")
	forge.description_input.text = "another idea"
	forge._reset_forge()
	_expect(forge.description_input.text.is_empty(), "RESET clears the description")
	_expect(forge.drawing_canvas.is_empty(), "RESET clears drawing strokes")
	_expect(forge.loaded_idea_pattern.is_empty(), "RESET clears the loaded-example state")
	_expect(forge.pattern_selector.selected_pattern() == "boomerang", "RESET preserves the selected attack mode")
	_expect(forge.forge_status.text == "Canvas and description cleared", "RESET provides visible confirmation")
	forge.description_input.text = "editable after reset"
	forge.drawing_canvas.strokes.append(PackedVector2Array([Vector2(15, 15), Vector2(90, 45)]))
	_expect(forge.description_input.text == "editable after reset" and not forge.drawing_canvas.is_empty(), "RESET allows immediate text and drawing input")
	var confirmable := {
		"success": true, "provider_invoked": true, "fallback_reason": "",
		"weapon_spec": WeaponSpec.fallback().to_dict(), "runtime_valid": true,
		"confidence": 0.8,
		"provider_metadata": {"provider": "anthropic", "model": "claude-haiku-4-5-20251001", "attempts": 1},
	}
	_expect(forge._is_confirmable_result(confirmable), "real provider result is confirmable")
	var spoofed_provider := confirmable.duplicate(true)
	spoofed_provider.provider_metadata = {"provider": "deterministic_local", "model": "m1b1-keyword-baseline", "attempts": 1}
	_expect(not forge._is_confirmable_result(spoofed_provider), "deterministic local result cannot enter normal confirmation")
	var wrong_model := confirmable.duplicate(true)
	wrong_model.provider_metadata = {"provider": "anthropic", "model": "claude-sonnet-4-5", "attempts": 1}
	_expect(not forge._is_confirmable_result(wrong_model), "unpinned Anthropic model cannot enter normal confirmation")
	var explicit_error := confirmable.duplicate(true)
	explicit_error.success = false
	explicit_error.provider_invoked = false
	explicit_error.fallback_reason = "empty_description"
	explicit_error.weapon_spec = null
	explicit_error.confidence = 0.0
	explicit_error.provider_metadata = {"provider": "none", "model": "none", "attempts": 0}
	_expect(not forge._is_confirmable_result(explicit_error), "EMPTY DESCRIPTION/provider none/confidence zero is never confirmable")
	forge.queue_free()


func _test_weapon_interpreter_response_context() -> void:
	var interpreter := WeaponInterpreter.new()
	root.add_child(interpreter)
	await process_frame
	_expect(interpreter._session_id.length() == 32, "interpreter creates a 128-bit per-client idempotency namespace")
	interpreter.in_flight = true
	interpreter.active_request_id = "expected-request"
	interpreter._request_revision = 2
	var balanced := PowerBudget.balance(WeaponSpec.fallback().to_dict())
	var valid_response := {
		"success": true,
		"provider_invoked": true,
		"request_id": "expected-request",
		"weapon_spec": balanced.values,
		"corrections": [],
		"confidence": 0.8,
		"fallback_reason": "",
		"provider_metadata": {"provider": "anthropic", "model": "claude-haiku-4-5-20251001", "attempts": 1},
		"runtime_valid": true,
	}
	var accepted: Dictionary = interpreter._validate_server_result(valid_response, "expected-request")
	_expect(bool(accepted.get("ok", false)) and bool(accepted.result.get("success", false)), "matching successful server request passes client revalidation")
	var deterministic_response := valid_response.duplicate(true)
	deterministic_response.provider_metadata = {"provider": "deterministic_local", "model": "m1b1-keyword-baseline", "attempts": 1}
	var deterministic_rejected: Dictionary = interpreter._validate_server_result(deterministic_response, "expected-request")
	_expect(not bool(deterministic_rejected.get("ok", false)) and deterministic_rejected.reason == "provider_identity_mismatch", "client rejects deterministic provider spoof as non-AI")
	var model_mismatch_response := valid_response.duplicate(true)
	model_mismatch_response.provider_metadata = {"provider": "anthropic", "model": "claude-opus-4-5", "attempts": 1}
	var model_rejected: Dictionary = interpreter._validate_server_result(model_mismatch_response, "expected-request")
	_expect(not bool(model_rejected.get("ok", false)) and model_rejected.reason == "provider_identity_mismatch", "client rejects unpinned Anthropic model")
	var error_response := valid_response.duplicate(true)
	error_response.success = false
	error_response.provider_invoked = false
	error_response.weapon_spec = null
	error_response.confidence = 0.0
	error_response.fallback_reason = "empty_description"
	error_response.provider_metadata = {"provider": "none", "model": "none", "attempts": 0}
	var explicit_failure: Dictionary = interpreter._validate_server_result(error_response, "expected-request")
	_expect(bool(explicit_failure.get("ok", false)) and not bool(explicit_failure.result.runtime_valid) and explicit_failure.result.weapon_spec == null, "fallback is normalized to a non-equipable explicit error")
	var stale_response := valid_response.duplicate(true)
	stale_response.request_id = "stale-request"
	var rejected: Dictionary = interpreter._validate_server_result(stale_response, "expected-request")
	_expect(not bool(rejected.get("ok", false)) and rejected.reason == "stale_response", "mismatched server request_id is rejected")

	var web_request := HTTPRequest.new()
	interpreter.add_child(web_request)
	WeaponInterpreter.configure_http_request(web_request, true)
	_expect(not web_request.accept_gzip, "Web HTTPRequest disables duplicate gzip decompression")
	_expect(is_equal_approx(web_request.timeout, WeaponInterpreter.REQUEST_TIMEOUT_SECONDS), "Web HTTPRequest preserves the bounded timeout")
	web_request.queue_free()
	var native_request := HTTPRequest.new()
	interpreter.add_child(native_request)
	WeaponInterpreter.configure_http_request(native_request, false)
	_expect(native_request.accept_gzip, "native HTTPRequest keeps Godot gzip handling")
	native_request.queue_free()

	var stale_node := HTTPRequest.new()
	interpreter.add_child(stale_node)
	var before_ignored := interpreter.late_response_ignored
	interpreter._on_http_request_completed(
		HTTPRequest.RESULT_SUCCESS,
		200,
		PackedStringArray(),
		JSON.stringify(stale_response).to_utf8_buffer(),
		1,
		"stale-request",
		stale_node,
	)
	_expect(interpreter.in_flight and interpreter.active_request_id == "expected-request", "late request A cannot overwrite active request B")
	_expect(interpreter.late_response_ignored == before_ignored + 1, "late HTTP response is counted and discarded")
	interpreter.cancel()
	interpreter.queue_free()


func _test_orientation_prompt_rule() -> void:
	_expect(RotationPrompt.should_show_for(Vector2(390, 844)), "portrait viewport shows the rotate prompt")
	for viewport in [Vector2(844, 390), Vector2(852, 393), Vector2(915, 412)]:
		_expect(not RotationPrompt.should_show_for(viewport), "%dx%d landscape viewport hides the rotate prompt" % [viewport.x, viewport.y])
	var rotations := [Vector2(390, 844), Vector2(844, 390), Vector2(390, 844), Vector2(844, 390), Vector2(390, 844), Vector2(844, 390)]
	for index in rotations.size():
		_expect(RotationPrompt.should_show_for(rotations[index]) == (index % 2 == 0), "rotation transition %d has the expected prompt state" % (index + 1))


func _test_player_combat_gate() -> void:
	var player := ForgePlayer.new()
	var emissions: Array[int] = []
	player.attack_requested.connect(func(_spec: WeaponSpec, _origin: Vector2, _direction: Vector2, _strokes: Array[PackedVector2Array]): emissions.append(1))
	player.weapon_visual = WeaponVisual.new()
	player.add_child(player.weapon_visual)
	player.current_spec = WeaponSpec.fallback()
	root.add_child(player)
	player.set_combat_enabled(false)
	player.attack()
	_expect(emissions.is_empty(), "re-forge combat gate blocks the equipped weapon")
	player.set_combat_enabled(true)
	player.facing = 1.0
	player.attack()
	player.set_touch_axis(-1.0)
	await physics_frame
	var locked_state := player.held_visual_state()
	_expect(is_equal_approx(float(locked_state.attack_facing), 1.0), "melee attack freezes its starting direction")
	_expect(is_equal_approx(float(locked_state.visual_facing), 1.0), "reverse movement cannot flip the held weapon before the hit window")
	await create_timer(player.attack_hit_delay_seconds() + 0.08).timeout
	_expect(emissions.size() == 1, "closing re-forge restores the equipped weapon")
	var during_hit_state := player.held_visual_state()
	_expect(is_equal_approx(float(during_hit_state.visual_facing), 1.0), "melee hit direction stays aligned with the visible swing")
	await create_timer(maxf(player.attack_cycle_seconds() - player.attack_hit_delay_seconds(), 0.0) + 0.08).timeout
	await physics_frame
	var recovered_state := player.held_visual_state()
	_expect(is_zero_approx(float(recovered_state.attack_facing)), "melee direction lock clears after recovery")
	_expect(is_equal_approx(float(recovered_state.visual_facing), -1.0), "held reverse input becomes the visible facing after recovery")
	player.set_touch_axis(0.0)
	player.queue_free()


func _test_c0_player_health() -> void:
	var player := ForgePlayer.new()
	var health_events: Array[int] = []
	var damage_events: Array[int] = []
	var death_events: Array[int] = []
	player.health_changed.connect(func(current: int, _maximum: int) -> void: health_events.append(current))
	player.damaged.connect(func(amount: int, _current: int) -> void: damage_events.append(amount))
	player.died.connect(func() -> void: death_events.append(1))
	root.add_child(player)
	player.set_combat_enabled(true)

	var first_damage: int = player.take_damage(25)
	_expect(
		first_damage == 25
		and player.health == 75
		and damage_events == [25],
		"C0 player health applies and audits bounded non-lethal damage",
	)
	var lethal_damage: int = player.take_damage(999)
	_expect(
		lethal_damage == 75
		and player.health == 0
		and player.is_dead
		and death_events.size() == 1
		and not player.combat_enabled,
		"C0 player death clamps at zero, emits once, and disables combat",
	)
	var ignored_damage: int = player.take_damage(20)
	_expect(
		ignored_damage == 0
		and player.health == 0
		and death_events.size() == 1
		and damage_events == [25, 75],
		"C0 dead player rejects duplicate damage and death transitions",
	)
	player.reset_health()
	player.set_combat_enabled(true)
	_expect(
		player.health == ForgePlayer.MAX_HEALTH
		and not player.is_dead
		and player.combat_enabled
		and health_events[-1] == ForgePlayer.MAX_HEALTH,
		"C0 Retry health reset restores one clean active player state",
	)
	player.queue_free()


func _test_c0_terminal_and_collision_invariants() -> void:
	const MIN_BODY_SEPARATION := 53.0
	var player := ForgePlayer.new()
	var attack_emissions: Array[int] = []
	player.attack_requested.connect(func(_spec: WeaponSpec, _origin: Vector2, _direction: Vector2, _strokes: Array[PackedVector2Array]) -> void: attack_emissions.append(1))
	root.add_child(player)
	await physics_frame
	player.current_spec = WeaponSpec.fallback()
	player.movement_bounds = Vector2(70.0, 1210.0)
	player.global_position = Vector2(240.0, 220.0)
	var terminal_position := player.global_position
	player.set_combat_enabled(false)
	player.set_touch_axis(1.0)
	player._physics_process(0.5)
	player.attack()
	_expect(
		player.global_position.is_equal_approx(terminal_position)
		and player.velocity.is_zero_approx()
		and attack_emissions.is_empty(),
		"C0 terminal combat gate rejects held touch movement and attack resolution",
	)

	player.set_touch_axis(0.0)
	player.set_combat_enabled(true)
	var enemy := CombatEnemy.new()
	enemy.configure_combat_enemy()
	enemy.set_target(player)
	root.add_child(enemy)
	enemy.set_presentation_active(true, false)
	enemy.set_simulation_enabled(false)

	player.global_position = Vector2(200.0, 220.0)
	enemy.set_arena_position(Vector2(300.0, 216.0))
	await physics_frame
	player.set_touch_axis(1.0)
	for _step in 20:
		player._physics_process(0.05)
	var left_separation := enemy.global_position.x - player.global_position.x
	_expect(
		player.global_position.x < enemy.global_position.x
		and left_separation >= MIN_BODY_SEPARATION - 0.5,
		"C0 sustained collision from the left preserves ordering and minimum body separation",
	)

	player.set_touch_axis(0.0)
	player.global_position = Vector2(400.0, 220.0)
	enemy.set_arena_position(Vector2(300.0, 216.0))
	await physics_frame
	player.set_touch_axis(-1.0)
	for _step in 20:
		player._physics_process(0.05)
	var right_separation := player.global_position.x - enemy.global_position.x
	_expect(
		player.global_position.x > enemy.global_position.x
		and right_separation >= MIN_BODY_SEPARATION - 0.5,
		"C0 sustained collision from the right preserves ordering and minimum body separation",
	)

	enemy.set_presentation_active(false, false)
	await physics_frame
	player.global_position.x = 70.0
	player.set_touch_axis(-1.0)
	for _step in 12:
		player._physics_process(0.05)
	var left_edge_position := player.global_position.x
	player.global_position.x = 1210.0
	player.set_touch_axis(1.0)
	for _step in 12:
		player._physics_process(0.05)
	var right_edge_position := player.global_position.x
	_expect(
		left_edge_position >= 70.0
		and right_edge_position <= 1210.0,
		"C0 sustained movement cannot cross either arena edge",
	)
	player.set_touch_axis(0.0)
	enemy.queue_free()
	player.queue_free()


func _test_c0_enemy_state_machine() -> void:
	var player := ForgePlayer.new()
	root.add_child(player)
	player.global_position = Vector2(200.0, 200.0)
	player.reset_health()
	player.set_combat_enabled(true)

	var enemy := CombatEnemy.new()
	enemy.configure_combat_enemy()
	enemy.set_target(player)
	var events: Array[Dictionary] = []
	var landed_damage: Array[int] = []
	enemy.combat_event.connect(func(kind: String, detail: Dictionary) -> void:
		var entry: Dictionary = detail.duplicate(true)
		entry["kind"] = kind
		events.append(entry)
	)
	enemy.strike_landed.connect(func(amount: int) -> void: landed_damage.append(amount))
	root.add_child(enemy)
	enemy.reset_combat(Vector2(270.0, 196.0))
	enemy.set_simulation_enabled(true)

	enemy._physics_process(0.016)
	_expect(
		enemy.state_name() == "telegraph"
		and is_equal_approx(float(enemy.qa_state().get("state_time_remaining", 0.0)), CombatEnemy.TELEGRAPH_SECONDS),
		"C0 enemy enters an observable deterministic telegraph in range",
	)
	enemy._physics_process(CombatEnemy.TELEGRAPH_SECONDS)
	_expect(enemy.state_name() == "strike", "C0 enemy telegraph commits to the strike phase")
	enemy._physics_process(0.01)
	var health_after_first_strike: int = player.health
	enemy._physics_process(0.01)
	_expect(
		health_after_first_strike == ForgePlayer.MAX_HEALTH - CombatEnemy.STRIKE_DAMAGE
		and player.health == health_after_first_strike
		and landed_damage == [CombatEnemy.STRIKE_DAMAGE],
		"C0 enemy applies at most one player damage event per strike",
	)
	enemy._physics_process(CombatEnemy.STRIKE_SECONDS)
	_expect(enemy.state_name() == "recover", "C0 enemy strike enters explicit recovery")
	enemy._physics_process(CombatEnemy.RECOVERY_SECONDS)
	_expect(enemy.state_name() == "approach", "C0 enemy recovery returns to approach")
	var observed_states: Array[String] = []
	for event: Dictionary in events:
		if str(event.get("kind", "")) == "enemy_state":
			observed_states.append(str(event.get("state", "")))
	_expect(
		"approach" in observed_states
		and "telegraph" in observed_states
		and "strike" in observed_states
		and "recover" in observed_states,
		"C0 enemy event audit preserves approach/telegraph/strike/recovery evidence",
	)

	enemy.take_damage(999, "none", "melee_slash", Vector2.RIGHT)
	_expect(
		enemy.health == 0
		and enemy.state_name() == "defeated"
		and not bool(enemy.qa_state().get("simulation_enabled", true)),
		"C0 enemy defeat stops its attack simulation",
	)
	enemy.reset_combat(Vector2(270.0, 196.0))
	_expect(
		enemy.health == enemy.max_health
		and enemy.state_name() == "inactive"
		and not bool(enemy.qa_state().get("strike_applied", true)),
		"C0 enemy Retry reset restores health and clears committed strike state",
	)
	enemy.queue_free()
	player.queue_free()


func _test_c0_comparison_gate() -> void:
	var short_dominates := _c0_short_triple_win_gate(
		{"time_to_first_hit_ms": 400, "ttk_ms": 1800, "damage_taken": 0},
		{"time_to_first_hit_ms": 500, "ttk_ms": 2200, "damage_taken": 20},
		{"time_to_first_hit_ms": 650, "ttk_ms": 2600, "damage_taken": 40},
	)
	_expect(short_dominates, "C0 comparison oracle detects a short-weapon triple win")
	var long_exposure_advantage := _c0_short_triple_win_gate(
		{"time_to_first_hit_ms": 400, "ttk_ms": 1800, "damage_taken": 40},
		{"time_to_first_hit_ms": 500, "ttk_ms": 2200, "damage_taken": 20},
		{"time_to_first_hit_ms": 650, "ttk_ms": 2600, "damage_taken": 0},
	)
	_expect(
		not long_exposure_advantage,
		"C0 comparison oracle passes when long reach buys a damage-exposure advantage",
	)


func _c0_short_triple_win_gate(
	short_metrics: Dictionary,
	standard_metrics: Dictionary,
	long_metrics: Dictionary,
) -> bool:
	return (
		float(short_metrics.get("time_to_first_hit_ms", INF)) < float(standard_metrics.get("time_to_first_hit_ms", INF))
		and float(short_metrics.get("time_to_first_hit_ms", INF)) < float(long_metrics.get("time_to_first_hit_ms", INF))
		and float(short_metrics.get("ttk_ms", INF)) < float(standard_metrics.get("ttk_ms", INF))
		and float(short_metrics.get("ttk_ms", INF)) < float(long_metrics.get("ttk_ms", INF))
		and float(short_metrics.get("damage_taken", INF)) < float(standard_metrics.get("damage_taken", INF))
		and float(short_metrics.get("damage_taken", INF)) < float(long_metrics.get("damage_taken", INF))
	)


func _test_rapid_melee_input_buffer() -> void:
	var canvas_size := Vector2(640.0, 300.0)
	var stroke := PackedVector2Array([
		Vector2(20.0, 144.0), Vector2(126.0, 144.0), Vector2(135.2, 150.0),
		Vector2(126.0, 156.0), Vector2(20.0, 156.0),
	])
	var source: Array[PackedVector2Array] = [stroke]
	var profile := DrawingGeometryProfile.from_snapshot(source, canvas_size, "light")
	var spec := WeaponCompiler.new().compile("a plain steel sword")
	profile.apply_to_spec(spec)
	var player := ForgePlayer.new()
	var emission_times: Array[int] = []
	player.attack_requested.connect(func(_spec: WeaponSpec, _origin: Vector2, _direction: Vector2, _strokes: Array[PackedVector2Array]): emission_times.append(Time.get_ticks_msec()))
	root.add_child(player)
	player.equip(spec, source, profile)
	var cycle := player.attack_cycle_seconds()
	_expect(cycle >= 0.40 and cycle <= 0.46, "rapid-input fixture uses the bounded ultra-short exposure cycle")
	player.attack()
	for _tap in 8:
		player.attack()
	var queued_state := player.held_visual_state()
	_expect(bool(queued_state.attack_buffered), "rapid repeated taps fill the one-slot attack buffer")
	_expect(int(queued_state.max_buffered_attacks) == 1 and int(queued_state.accepted_attack_count) == 1, "rapid taps cannot re-enter the authoritative attack gate")
	await create_timer(cycle * 2.0 + 0.20).timeout
	await physics_frame
	var completed_state := player.held_visual_state()
	_expect(emission_times.size() == 2, "one initial attack plus one buffered attack emits exactly two hit windows")
	_expect(int(completed_state.accepted_attack_count) == 2 and not bool(completed_state.attack_buffered), "the one-slot buffer drains once without a hidden third attack")
	if emission_times.size() == 2:
		var hit_gap_seconds := float(emission_times[1] - emission_times[0]) / 1000.0
		_expect(hit_gap_seconds >= cycle * 0.90, "buffered hit windows do not overlap")
	player.queue_free()


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
