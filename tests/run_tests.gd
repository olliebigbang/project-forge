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
	_test_attack_pattern_touch_selector()
	_test_mobile_layout_policy()
	await _test_forge_reset_state()
	await _test_weapon_interpreter_response_context()
	_test_orientation_prompt_rule()
	_test_player_combat_gate()
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
		"request_id": "expected-request",
		"weapon_spec": balanced.values,
		"corrections": [],
	}
	var accepted: Dictionary = interpreter._validate_server_result(valid_response, "expected-request")
	_expect(bool(accepted.get("ok", false)), "matching server request_id passes client revalidation")
	var stale_response := valid_response.duplicate(true)
	stale_response.request_id = "stale-request"
	var rejected: Dictionary = interpreter._validate_server_result(stale_response, "expected-request")
	_expect(not bool(rejected.get("ok", false)) and rejected.reason == "stale_response", "mismatched server request_id is rejected")

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
	player.attack()
	_expect(emissions.size() == 1, "closing re-forge restores the equipped weapon")
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
