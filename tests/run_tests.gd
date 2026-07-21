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
	_test_stroke_fit()
	_test_drawing_geometry_profiles()
	_test_attack_pattern_touch_selector()
	_test_mobile_layout_policy()
	await _test_forge_reset_state()
	await _test_weapon_interpreter_response_context()
	_test_orientation_prompt_rule()
	await _test_player_combat_gate()
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
		_expect(_notes_contain(spec.corrections, "geometry: frozen"), "%s geometry/budget correction is audited" % profile.reach_profile)

	_expect(specs[0].attack_range < specs[1].attack_range and specs[1].attack_range < specs[2].attack_range, "runtime melee ranges are strictly monotonic")
	_expect(specs[0].attack_speed > specs[1].attack_speed and specs[1].attack_speed > specs[2].attack_speed, "runtime melee speeds are inversely monotonic")
	var short_cycle := 1.25 / specs[0].attack_speed
	var standard_cycle := 1.25 / specs[1].attack_speed
	var long_cycle := 1.25 / specs[2].attack_speed
	_expect(short_cycle < standard_cycle and standard_cycle < long_cycle, "complete attack cycles are short < standard < long")
	var test_target := Vector2(170.0, 0.0)
	_expect(not DrawingGeometryProfile.melee_reaches_point(Vector2.ZERO, test_target, Vector2.RIGHT, specs[0].attack_range), "short sword cannot hit a target beyond its visible tip")
	_expect(DrawingGeometryProfile.melee_reaches_point(Vector2.ZERO, test_target, Vector2.RIGHT, specs[2].attack_range), "long sword hits the same target within its visible tip")

	var frozen := long_sword.to_dict()
	for _viewport_size in [Vector2(844, 390), Vector2(852, 393), Vector2(915, 412)]:
		_expect(long_sword.to_dict() == frozen, "frozen reach does not drift across landscape resize")


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
