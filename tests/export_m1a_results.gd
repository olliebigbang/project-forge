extends SceneTree


func _init() -> void:
	var matrix_file := FileAccess.open("res://tests/m1a_input_matrix.json", FileAccess.READ)
	if matrix_file == null:
		push_error("Cannot read M1A matrix")
		quit(1)
		return
	var cases: Array = JSON.parse_string(matrix_file.get_as_text())
	var records: Array[Dictionary] = []
	var passed := 0
	for case: Dictionary in cases:
		var compiler := WeaponCompiler.new()
		var spec := compiler.compile(str(case.input), {"aspect_ratio": 2.0, "point_count": 16})
		var ok: bool = (
			spec.attack_pattern == case.pattern and spec.element == case.element
			and spec.is_valid() and spec.power_score <= PowerBudget.MAX_POWER
			and (not spec.has_strong_capability() or spec.drawback != "none")
			and str(compiler.last_record.get("fallback_reason", "")) == str(case.get("fallback", ""))
		)
		if ok: passed += 1
		records.append({
			"id": case.id,
			"input": case.input,
			"expected": {"attack_pattern": case.pattern, "element": case.element, "fallback": case.get("fallback", "")},
			"weapon_spec": spec.to_dict(),
			"budget": spec.budget_breakdown,
			"corrections": spec.corrections,
			"fallback_reason": compiler.last_record.get("fallback_reason", ""),
			"passed": ok,
		})
	var fault_compiler := WeaponCompiler.new()
	var fault_spec := fault_compiler.compile_raw({
		"name": "", "weapon_class": "wizard", "attack_pattern": "teleport", "element": "plasma",
		"damage": 10000, "attack_speed": -8, "range": INF, "special_ability": "god_mode",
		"status_effect": "forever", "drawback": "none", "visual_material": "unknown",
		"power_score": 999, "projectile_speed": NAN, "area_radius": -1,
		"pierce_count": 999, "return_speed": "invalid", "unknown_field": true,
	})
	var result := {
		"milestone": "M1A deterministic weapon compiler",
		"matrix_case_count": cases.size(),
		"matrix_passed": passed,
		"matrix_failed": cases.size() - passed,
		"records": records,
		"fault_injection": {
			"runtime_valid": fault_spec.is_valid(),
			"weapon_spec": fault_spec.to_dict(),
			"budget": fault_spec.budget_breakdown,
			"corrections": fault_spec.corrections,
		},
	}
	var output := FileAccess.open("res://artifacts/m1a_acceptance_results.json", FileAccess.WRITE)
	if output == null:
		push_error("Cannot write M1A acceptance artifact")
		quit(1)
		return
	output.store_string(JSON.stringify(result, "  ", false))
	print("[EXPORT] wrote %d/%d passing M1A records" % [passed, cases.size()])
	quit(0 if passed == cases.size() else 1)
