extends SceneTree

var _failures: int = 0
var _assertions: int = 0
var _spike: BeltCombatSpike


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed_scene: PackedScene = load("res://scenes/belt_combat_spike.tscn") as PackedScene
	_check(packed_scene != null, "belt scene loads")
	if packed_scene == null:
		_finish()
		return
	_spike = packed_scene.instantiate() as BeltCombatSpike
	root.add_child(_spike)
	await process_frame
	await physics_frame
	_check(_spike.player != null, "player composes into the standalone scene")
	_check(_spike.enemies.size() == 1, "moving encounter starts with one enemy")
	_check(_spike.player.arena_bounds.has_point(_spike.player.global_position), "player starts inside arena")

	await _test_weapon_fixtures()
	await _test_player_and_developer_presentation()
	await _test_live_payload_identity_and_copy_boundary()
	await _test_invalid_live_payload_fails_closed()
	await _test_live_elements()
	await _test_xy_movement_and_bounds()
	await _test_assist_and_horizontal_lock()
	await _test_all_pattern_attack_directions()
	await _test_footprint_collision_and_defeated_passage()
	await _test_five_attack_adaptations()
	await _test_terminal_cleanup_and_retry()
	await _test_physics_tick_profiles()
	await _test_bounded_long_frame()
	await _test_compact_layouts()
	_finish()


func _test_weapon_fixtures() -> void:
	for pattern: String in BeltCombatSpike.ATTACK_PATTERNS:
		_check(_spike.select_weapon(pattern), "%s fixture equips" % pattern)
		var spec: WeaponSpec = _spike.player.current_spec
		_check(spec != null and spec.is_valid(), "%s fixture remains runtime valid" % pattern)
		_check(spec.power_score <= PowerBudget.MAX_POWER, "%s fixture remains budget bounded" % pattern)
		_check(
			_spike.player.current_role_profile.effective_reach == spec.attack_range,
			"%s role consumes authoritative reach" % pattern,
		)
	await physics_frame


func _test_player_and_developer_presentation() -> void:
	_check(_spike.developer_test_mode, "standalone belt scene is an explicit Developer/Test route")
	for pattern: String in BeltCombatSpike.ATTACK_PATTERNS:
		var developer_weapon_button: Control = _spike.find_child(
			"Weapon%s" % pattern.to_pascal_case(),
			true,
			false,
		) as Control
		_check(
			developer_weapon_button != null and developer_weapon_button.is_visible_in_tree(),
			"Developer/Test route retains %s fixture control" % pattern,
		)
	for encounter: String in BeltCombatSpike.ENCOUNTERS:
		var developer_encounter_button: Control = _spike.find_child(
			"Encounter%s" % encounter.to_pascal_case(),
			true,
			false,
		) as Control
		_check(
			developer_encounter_button != null and developer_encounter_button.is_visible_in_tree(),
			"Developer/Test route retains %s encounter control" % encounter,
		)

	var packed_scene: PackedScene = load("res://scenes/belt_combat_spike.tscn") as PackedScene
	var live_spike: BeltCombatSpike = packed_scene.instantiate() as BeltCombatSpike
	live_spike.developer_test_mode = false
	root.add_child(live_spike)
	await process_frame
	await physics_frame
	_check(
		live_spike.player.current_spec == null and not live_spike.player.combat_enabled,
		"normal-player belt waits fail-closed for a live routed payload",
	)
	_check(
		not live_spike.select_weapon("melee_slash"),
		"normal-player belt cannot select a deterministic weapon fixture",
	)
	for pattern: String in BeltCombatSpike.ATTACK_PATTERNS:
		var live_weapon_button: Control = live_spike.find_child(
			"Weapon%s" % pattern.to_pascal_case(),
			true,
			false,
		) as Control
		_check(
			live_weapon_button != null and not live_weapon_button.is_visible_in_tree(),
			"normal-player belt hides %s fixture control" % pattern,
		)
	for encounter: String in BeltCombatSpike.ENCOUNTERS:
		var live_encounter_button: Control = live_spike.find_child(
			"Encounter%s" % encounter.to_pascal_case(),
			true,
			false,
		) as Control
		_check(
			live_encounter_button != null and not live_encounter_button.is_visible_in_tree(),
			"normal-player belt hides %s encounter control" % encounter,
		)
	var live_source: Dictionary = _make_live_weapon("area_blast", "fire")
	_check(
		live_spike.equip_weapon(
			live_source.spec,
			live_source.strokes,
			live_source.geometry,
		),
		"normal-player belt accepts only the explicit live payload",
	)
	await physics_frame
	_check(
		live_spike.player.combat_enabled
		and live_spike.player.current_spec.attack_pattern == "area_blast",
		"normal-player belt enables combat only after live equip",
	)
	_check(
		not live_spike.select_weapon("boomerang")
		and live_spike.player.current_spec.attack_pattern == "area_blast",
		"fixture selection cannot overwrite the normal-player live weapon",
	)
	live_spike.queue_free()
	await process_frame


func _test_xy_movement_and_bounds() -> void:
	_spike.select_encounter("moving")
	await physics_frame
	var start: Vector2 = _spike.player.global_position
	_spike.set_touch_move(Vector2(1.0, -1.0))
	await _wait_physics_frames(8)
	_spike.set_touch_move(Vector2.ZERO)
	var moved: Vector2 = _spike.player.global_position - start
	_check(moved.x > 0.0 and moved.y < 0.0, "touch entry moves in both X and Y")
	_spike.player.global_position = _spike.player.arena_bounds.end + Vector2(500.0, 500.0)
	await physics_frame
	_check(
		_spike.player.global_position.x >= _spike.player.arena_bounds.position.x
		and _spike.player.global_position.x <= _spike.player.arena_bounds.end.x
		and _spike.player.global_position.y >= _spike.player.arena_bounds.position.y
		and _spike.player.global_position.y <= _spike.player.arena_bounds.end.y,
		"player clamps to the two-dimensional arena",
	)


func _test_five_attack_adaptations() -> void:
	await _test_melee()
	await _test_straight_projectile()
	await _test_boomerang()
	await _test_area_blast()
	await _test_piercing()


func _test_live_payload_identity_and_copy_boundary() -> void:
	_spike.select_encounter("moving")
	await physics_frame
	var source: Dictionary = _make_live_weapon("melee_slash", "ice")
	var spec: WeaponSpec = source.spec
	var strokes: Array[PackedVector2Array] = source.strokes
	var geometry: DrawingGeometryProfile = source.geometry
	var expected_spec: Dictionary = spec.to_dict().duplicate(true)
	var expected_corrections: Array[String] = spec.corrections.duplicate()
	var expected_budget: Dictionary = spec.budget_breakdown.duplicate(true)
	var expected_strokes: Array[PackedVector2Array] = StrokeFit.duplicate_strokes(strokes)
	var expected_geometry: Dictionary = geometry.to_dict().duplicate(true)
	_check(
		_spike.equip_weapon(spec, strokes, geometry),
		"runtime-valid live payload crosses the belt equip boundary",
	)
	await physics_frame
	_check(
		_spike.player.current_spec.to_dict() == expected_spec,
		"live belt equip preserves the exact repaired WeaponSpec fields",
	)
	_check(
		_spike.player.current_spec.corrections == expected_corrections,
		"live belt equip preserves exact repair reasons",
	)
	_check(
		_spike.player.current_spec.budget_breakdown == expected_budget,
		"live belt equip preserves exact PowerBudget breakdown",
	)
	_check(
		_strokes_equal(_spike.player.current_strokes, expected_strokes),
		"live belt equip preserves every original stroke point",
	)
	_check(
		_spike.player.current_geometry_profile.to_dict() == expected_geometry,
		"live belt equip preserves the frozen geometry and derived timing",
	)
	_check(
		_spike.player.current_spec != spec,
		"live belt owns a WeaponSpec copy rather than the route object",
	)
	_check(
		_spike.player.current_geometry_profile != geometry,
		"live belt owns a DrawingGeometryProfile copy rather than the route object",
	)

	spec.damage = 1
	spec.corrections.append("source mutated after route")
	geometry.effective_reach = DrawingGeometryProfile.MIN_EFFECTIVE_REACH
	strokes[0][0] = Vector2(999.0, 999.0)
	_check(
		_spike.player.current_spec.to_dict() == expected_spec
		and _spike.player.current_spec.corrections == expected_corrections,
		"source WeaponSpec mutation cannot rewrite the equipped live payload",
	)
	_check(
		_spike.player.current_geometry_profile.to_dict() == expected_geometry,
		"source geometry mutation cannot rewrite the equipped live profile",
	)
	_check(
		_strokes_equal(_spike.player.current_strokes, expected_strokes),
		"source stroke mutation cannot rewrite equipped player ink",
	)


func _test_invalid_live_payload_fails_closed() -> void:
	var valid_source: Dictionary = _make_live_weapon("straight_projectile", "normal")
	_check(
		_spike.equip_weapon(
			valid_source.spec,
			valid_source.strokes,
			valid_source.geometry,
		),
		"fail-closed probe starts from an explicitly live-equipped weapon",
	)
	await physics_frame
	_check(
		not _spike.equip_weapon(null, [], null),
		"missing live WeaponSpec is rejected",
	)
	await physics_frame
	_check(
		_spike.player.current_spec == null
		and _spike.player.current_strokes.is_empty()
		and not _spike.player.combat_enabled,
		"missing live payload clears the prior weapon and cannot retain a fixture",
	)
	_check(
		not _spike.request_attack(),
		"missing live payload cannot attack through a fallback",
	)

	var invalid_source: Dictionary = _make_live_weapon("boomerang", "electric")
	var over_budget: WeaponSpec = invalid_source.spec
	over_budget.power_score = PowerBudget.MAX_POWER + 1
	_check(
		not _spike.equip_weapon(
			over_budget,
			invalid_source.strokes,
			invalid_source.geometry,
		),
		"over-budget live WeaponSpec is rejected",
	)
	await physics_frame
	_check(
		_spike.player.current_spec == null
		and _spike.player.current_strokes.is_empty()
		and not _spike.player.combat_enabled,
		"over-budget payload fails closed without prior or fixture equipment",
	)


func _test_live_elements() -> void:
	var status_markers: Dictionary = {
		"normal": "KNOCKBACK",
		"fire": "BURN",
		"ice": "SLOWED",
		"electric": "STAGGER",
	}
	for element: String in WeaponSpec.ELEMENTS:
		_spike.select_encounter("moving")
		await physics_frame
		var enemy: BeltEnemy = _spike.enemies[0]
		enemy.set_simulation_enabled(false)
		var source: Dictionary = _make_live_weapon("melee_slash", element)
		_check(
			_spike.equip_weapon(source.spec, source.strokes, source.geometry),
			"%s live element payload equips" % element,
		)
		await physics_frame
		var center_y: float = _spike.player.arena_bounds.get_center().y
		_spike.player.global_position = Vector2(350.0, center_y)
		enemy.global_position = Vector2(430.0, center_y)
		await physics_frame
		var before: int = enemy.health
		_check(
			_spike.request_attack(),
			"%s live element attack is accepted" % element,
		)
		await _wait_seconds(_spike.player.current_role_profile.cycle_seconds + 0.08)
		var marker_found: bool = false
		for event: Dictionary in _spike.qa_state().get("damage_events", []):
			if str(event.get("note", "")).contains(str(status_markers[element])):
				marker_found = true
				break
		_check(enemy.health < before, "%s live element deals executable damage" % element)
		_check(
			_spike.player.current_spec.element == element,
			"%s live element remains exact after routing" % element,
		)
		_check(
			marker_found,
			"%s live element executes its deterministic status behavior" % element,
		)


func _test_assist_and_horizontal_lock() -> void:
	_spike.select_encounter("group")
	_spike.select_weapon("piercing")
	await physics_frame
	for group_enemy: BeltEnemy in _spike.enemies:
		group_enemy.set_simulation_enabled(false)
	var arena_center: Vector2 = _spike.player.arena_bounds.get_center()
	_spike.player.global_position = arena_center
	_spike.player.facing = 1.0
	_spike.enemies[0].global_position = arena_center - Vector2(140.0, 0.0)
	_spike.enemies[1].global_position = arena_center - Vector2(180.0, 40.0)
	_spike.enemies[2].global_position = arena_center - Vector2(180.0, -40.0)
	await physics_frame
	_check(_spike.player.assist_target() == null, "assist rejects targets behind facing")
	var original_target: BeltEnemy = _spike.enemies[0]
	var replacement_target: BeltEnemy = _spike.enemies[1]
	original_target.global_position = arena_center + Vector2(220.0, 0.0)
	replacement_target.global_position = arena_center + Vector2(300.0, 80.0)
	await physics_frame
	_check(_spike.player.assist_target() == original_target, "assist selects a valid forward target")
	var before: Vector2 = _spike.player.global_position
	_spike.request_attack()
	var frozen_direction: Dictionary = _spike.player.qa_state().get("attack_direction", {})
	var frozen_target_point: Dictionary = _spike.player.qa_state().get("attack_target_point", {})
	_spike.set_touch_move(Vector2(1.0, 1.0))
	await _wait_physics_frames(5)
	_spike.set_touch_move(Vector2.ZERO)
	_check(
		is_equal_approx(_spike.player.global_position.x, before.x),
		"piercing startup locks horizontal movement",
	)
	_check(_spike.player.global_position.y > before.y, "piercing startup preserves belt-depth movement")
	_check(
		_spike.player.qa_state().get("attack_direction", {}) == frozen_direction,
		"piercing startup freezes attack direction",
	)
	original_target.qa_set_health(0)
	replacement_target.global_position = _spike.player.global_position + Vector2(90.0, 260.0)
	await physics_frame
	_check(
		_spike.player.assist_target() == replacement_target,
		"assist actually switches after the original locked target becomes invalid",
	)
	await _wait_until_projectile(48)
	var projectiles: Array = _spike.qa_state().get("projectiles", [])
	_check(not projectiles.is_empty(), "piercing commit creates a projectile")
	if not projectiles.is_empty():
		var path_samples: Array = projectiles[0].get("path_samples", [])
		var projectile_direction: Dictionary = projectiles[0].get("direction", {})
		var launch_origin: Vector2 = Vector2.ZERO
		if not path_samples.is_empty():
			launch_origin = Vector2(
				float(path_samples[0].get("x", 0.0)),
				float(path_samples[0].get("y", 0.0)),
			)
		var target_point: Vector2 = Vector2(
			float(frozen_target_point.get("x", 0.0)),
			float(frozen_target_point.get("y", 0.0)),
		)
		var expected_direction: Vector2 = launch_origin.direction_to(target_point)
		var actual_direction: Vector2 = Vector2(
			float(projectile_direction.get("x", 0.0)),
			float(projectile_direction.get("y", 0.0)),
		)
		_check(
			actual_direction.dot(expected_direction) >= 0.999,
			"projectile launches from its muzzle toward the target point locked at attack start",
		)
	_check(
		_spike.player.qa_state().get("attack_target_point", {}) == frozen_target_point,
		"projectile keeps the target point locked at attack start",
	)
	var vertical_ratio: float = (
		absf(float(frozen_direction.get("y", 0.0)))
		/ maxf(absf(float(frozen_direction.get("x", 0.0))), 0.001)
	)
	_check(
		vertical_ratio <= BeltPlayer.TARGET_ASSIST_MAX_VERTICAL_RATIO + 0.001,
		"assist bounds projectile vertical angle",
	)
	_spike.player.clear_attack_state()
	_spike.select_encounter("group")
	await physics_frame
	for group_enemy: BeltEnemy in _spike.enemies:
		group_enemy.set_simulation_enabled(false)
	_spike.player.global_position = arena_center
	_spike.player.facing = 1.0
	_spike.enemies[0].global_position = arena_center + Vector2(200.0, -20.0)
	_spike.enemies[1].global_position = arena_center + Vector2(200.0, 20.0)
	_spike.enemies[2].global_position = arena_center - Vector2(150.0, 0.0)
	await physics_frame
	_check(
		_spike.player.assist_target() == _spike.enemies[0],
		"equal assist scores resolve by stable enemy id",
	)
	await _test_bounded_diagonal_aim()
	await _test_straight_projectile_locked_target()


func _test_all_pattern_attack_directions() -> void:
	for pattern: String in BeltCombatSpike.ATTACK_PATTERNS:
		for horizontal_sign: float in [-1.0, 1.0]:
			_spike.select_encounter("moving")
			_spike.select_weapon(pattern)
			await physics_frame
			var enemy: BeltEnemy = _spike.enemies[0]
			enemy.set_simulation_enabled(false)
			var center: Vector2 = _spike.player.arena_bounds.get_center()
			var target_distance: float = 76.0 if pattern == "melee_slash" else 180.0
			_spike.player.global_position = center
			_spike.player.facing = horizontal_sign
			enemy.global_position = center + Vector2(horizontal_sign * target_distance, 0.0)
			await physics_frame
			var side_label: String = "left" if horizontal_sign < 0.0 else "right"
			_check(
				_spike.request_attack(),
				"%s/%s direction probe is accepted" % [pattern, side_label],
			)
			var frozen_data: Dictionary = _spike.player.qa_state().get("attack_direction", {})
			var frozen_direction: Vector2 = Vector2(
				float(frozen_data.get("x", 0.0)),
				float(frozen_data.get("y", 0.0)),
			).normalized()
			_check(
				signf(frozen_direction.x) == horizontal_sign,
				"%s/%s freezes the intended direction" % [pattern, side_label],
			)
			await _wait_physics_frames(2)
			var forward_data: Dictionary = (
				_spike.player.qa_state().get("weapon_visual_forward", {})
			)
			var held_forward: Vector2 = Vector2(
				float(forward_data.get("x", 0.0)),
				float(forward_data.get("y", 0.0)),
			).normalized()
			_check(
				held_forward.dot(frozen_direction) > 0.80,
				"%s/%s held visual follows the frozen direction" % [pattern, side_label],
			)
			var position_data: Dictionary = (
				_spike.player.qa_state().get("weapon_visual_position", {})
			)
			_check(
				signf(float(position_data.get("x", 0.0))) == horizontal_sign,
				"%s/%s held grip stays on the frozen side" % [pattern, side_label],
			)
			if pattern == "melee_slash":
				await _wait_until_transient_kind("slash", 48)
				var slash_direction: Vector2 = _transient_direction("slash")
				_check(
					slash_direction.dot(frozen_direction) >= 0.999,
					"%s/%s slash follows the frozen direction" % [pattern, side_label],
				)
			else:
				await _wait_until_projectile(64)
				var projectile_direction: Vector2 = _transient_direction("")
				_check(
					signf(projectile_direction.x) == horizontal_sign,
					"%s/%s outbound projectile follows the frozen side"
					% [pattern, side_label],
				)
				if pattern == "area_blast":
					await _wait_until_event("area_impact", 96)
					var impact_x: float = _latest_event_x("area_impact")
					_check(
						signf(impact_x - center.x) == horizontal_sign,
						"%s/%s impact effect stays on the frozen side"
						% [pattern, side_label],
					)


func _test_bounded_diagonal_aim() -> void:
	for pattern: String in ["straight_projectile", "piercing"]:
		_spike.select_encounter("moving")
		_spike.select_weapon(pattern)
		await physics_frame
		var enemy: BeltEnemy = _spike.enemies[0]
		enemy.set_simulation_enabled(false)
		var center: Vector2 = _spike.player.arena_bounds.get_center()
		_spike.player.global_position = center
		_spike.player.facing = 1.0
		enemy.global_position = center + Vector2(80.0, 250.0)
		await physics_frame
		var downward: Vector2 = _spike.player.aim_direction()
		enemy.global_position = center + Vector2(80.0, -250.0)
		await physics_frame
		var upward: Vector2 = _spike.player.aim_direction()
		_check(
			downward.y > 0.05 and upward.y < -0.05,
			"%s preserves useful upward and downward diagonal aim" % pattern,
		)
		_check(
			absf(downward.y / maxf(absf(downward.x), 0.001))
			<= BeltPlayer.TARGET_ASSIST_MAX_VERTICAL_RATIO + 0.001
			and absf(upward.y / maxf(absf(upward.x), 0.001))
			<= BeltPlayer.TARGET_ASSIST_MAX_VERTICAL_RATIO + 0.001,
			"%s bounds extreme vertical aim" % pattern,
		)
		_check(
			is_equal_approx(absf(downward.y), absf(upward.y)),
			"%s applies the same bound above and below the player" % pattern,
		)


func _test_straight_projectile_locked_target() -> void:
	_spike.select_encounter("group")
	_spike.select_weapon("straight_projectile")
	await physics_frame
	var center: Vector2 = _spike.player.arena_bounds.get_center()
	_spike.player.global_position = center
	_spike.player.facing = 1.0
	for enemy: BeltEnemy in _spike.enemies:
		enemy.set_simulation_enabled(false)
		enemy.global_position = center - Vector2(160.0, 0.0)
	var original_target: BeltEnemy = _spike.enemies[0]
	var replacement_target: BeltEnemy = _spike.enemies[1]
	original_target.global_position = center + Vector2(250.0, 0.0)
	replacement_target.global_position = center + Vector2(320.0, 80.0)
	await physics_frame
	_check(_spike.player.assist_target() == original_target, "straight shot selects the original target")
	_check(_spike.request_attack(), "straight shot accepts the locked-target probe")
	var frozen_target: Dictionary = _spike.player.qa_state().get("attack_target_point", {})
	original_target.qa_set_health(0)
	replacement_target.global_position = center + Vector2(90.0, 250.0)
	await physics_frame
	_check(
		_spike.player.assist_target() == replacement_target,
		"straight-shot assist switches while startup is active",
	)
	await _wait_until_projectile(36)
	var projectiles: Array = _spike.qa_state().get("projectiles", [])
	_check(not projectiles.is_empty(), "straight shot creates a projectile after the assist switch")
	if projectiles.is_empty():
		return
	var path_samples: Array = projectiles[0].get("path_samples", [])
	var projectile_direction_data: Dictionary = projectiles[0].get("direction", {})
	_check(not path_samples.is_empty(), "straight shot exposes its muzzle launch sample")
	if path_samples.is_empty():
		return
	var launch_origin: Vector2 = Vector2(
		float(path_samples[0].get("x", 0.0)),
		float(path_samples[0].get("y", 0.0)),
	)
	var target_point: Vector2 = Vector2(
		float(frozen_target.get("x", 0.0)),
		float(frozen_target.get("y", 0.0)),
	)
	var actual_direction: Vector2 = Vector2(
		float(projectile_direction_data.get("x", 0.0)),
		float(projectile_direction_data.get("y", 0.0)),
	)
	_check(
		actual_direction.dot(launch_origin.direction_to(target_point)) >= 0.999,
		"straight projectile keeps the target point locked at attack start",
	)


func _test_footprint_collision_and_defeated_passage() -> void:
	_spike.select_encounter("moving")
	_spike.select_weapon("melee_slash")
	await physics_frame
	var enemy: BeltEnemy = _spike.enemies[0]
	enemy.set_simulation_enabled(false)
	var center: Vector2 = _spike.player.arena_bounds.get_center()
	_spike.player.global_position = center
	enemy.global_position = center + Vector2(42.0, 0.0)
	_spike.set_touch_move(Vector2.RIGHT)
	await _wait_physics_frames(18)
	_spike.set_touch_move(Vector2.ZERO)
	_check(
		_spike.player.global_position.x < enemy.global_position.x,
		"living enemy footprint still blocks direct movement",
	)

	_spike.player.global_position = center
	enemy.global_position = center + Vector2(42.0, 0.0)
	_spike.set_touch_move(Vector2(1.0, 0.75))
	await _wait_physics_frames(34)
	_spike.set_touch_move(Vector2.ZERO)
	_check(
		_spike.player.global_position.x > enemy.global_position.x
		and _spike.player.global_position.y > enemy.global_position.y,
		"small foot footprints let the player escape around a living enemy in depth",
	)

	_spike.player.global_position = center
	enemy.global_position = center + Vector2(42.0, 0.0)
	enemy.qa_set_health(0)
	await physics_frame
	_check(
		not bool(enemy.qa_state().get("collision_enabled", true)),
		"QA defeat immediately disables the corpse collision",
	)
	_spike.set_touch_move(Vector2.RIGHT)
	await _wait_physics_frames(18)
	_spike.set_touch_move(Vector2.ZERO)
	_check(
		_spike.player.global_position.x > enemy.global_position.x,
		"defeated enemy no longer blocks player movement",
	)

	enemy.reset_enemy()
	await physics_frame
	_check(
		bool(enemy.qa_state().get("collision_enabled", false)),
		"direct reset restores living collision",
	)
	enemy.take_damage(enemy.maximum_health)
	await physics_frame
	_check(
		not bool(enemy.qa_state().get("collision_enabled", true)),
		"direct lethal damage immediately disables corpse collision",
	)
	enemy.reset_enemy()
	enemy.qa_set_health(4)
	enemy.take_damage(1, "burn")
	await _wait_seconds(0.5)
	_check(
		enemy.is_defeated()
		and not bool(enemy.qa_state().get("collision_enabled", true)),
		"burn death immediately disables corpse collision",
	)

	_spike.retry_round()
	await process_frame
	await physics_frame
	enemy = _spike.enemies[0]
	enemy.set_simulation_enabled(false)
	_check(
		bool(enemy.qa_state().get("collision_enabled", false)),
		"Retry recreates a living enemy with collision enabled",
	)
	enemy.global_position = center + Vector2(42.0, 0.0)
	_spike.player.global_position = center
	await physics_frame
	_spike.set_touch_move(Vector2.RIGHT)
	await _wait_physics_frames(18)
	_spike.set_touch_move(Vector2.ZERO)
	_check(
		_spike.player.global_position.x < enemy.global_position.x,
		"enemy reset restores living collision",
	)


func _test_melee() -> void:
	_spike.select_encounter("moving")
	_check(_equip_live_weapon("melee_slash", "normal"), "live melee payload equips")
	await physics_frame
	var enemy: BeltEnemy = _spike.enemies[0]
	enemy.set_simulation_enabled(false)
	var arena_center_y: float = _spike.player.arena_bounds.get_center().y
	_spike.player.global_position = Vector2(350.0, arena_center_y)
	enemy.global_position = Vector2(440.0, arena_center_y)
	await physics_frame
	var before: int = enemy.health
	_check(_spike.request_attack(), "melee request is accepted")
	await _wait_seconds(_spike.player.current_role_profile.cycle_seconds + 0.12)
	_check(enemy.health < before, "melee uses authoritative reach on the belt plane")


func _test_straight_projectile() -> void:
	_spike.select_encounter("moving")
	_check(_equip_live_weapon("straight_projectile", "ice"), "live straight projectile payload equips")
	await physics_frame
	var enemy: BeltEnemy = _spike.enemies[0]
	enemy.set_simulation_enabled(false)
	var arena_center_y: float = _spike.player.arena_bounds.get_center().y
	_spike.player.global_position = Vector2(260.0, arena_center_y)
	enemy.global_position = Vector2(690.0, arena_center_y)
	await physics_frame
	var before: int = enemy.health
	_check(_spike.request_attack(), "straight projectile request is accepted")
	await _wait_seconds(1.0)
	_check(enemy.health < before, "straight projectile acquires and hits in two dimensions")


func _test_boomerang() -> void:
	_spike.select_encounter("shield")
	_check(_equip_live_weapon("boomerang", "electric"), "live boomerang payload equips")
	await physics_frame
	var enemy: BeltEnemy = _spike.enemies[0]
	enemy.set_simulation_enabled(false)
	var arena_center_y: float = _spike.player.arena_bounds.get_center().y
	_spike.player.global_position = Vector2(280.0, arena_center_y)
	enemy.global_position = Vector2(650.0, arena_center_y)
	await physics_frame
	_check(_spike.request_attack(), "boomerang request is accepted")
	await _wait_seconds(1.8)
	var finished_events: int = 0
	for event: Dictionary in _spike.qa_state().get("combat_events", []):
		if str(event.get("kind", "")) == "projectile_finished":
			finished_events += 1
	_check(finished_events == 1, "boomerang finishes exactly once")
	_check(bool(_spike.player.qa_state().get("held_visible", false)), "boomerang restores held ink")


func _test_area_blast() -> void:
	_spike.select_encounter("group")
	_check(_equip_live_weapon("area_blast", "fire"), "live thrown-blast payload equips")
	await physics_frame
	var arena_center_y: float = _spike.player.arena_bounds.get_center().y
	_spike.player.global_position = Vector2(300.0, arena_center_y)
	var impact_center: Vector2 = Vector2(500.0, arena_center_y)
	var vertical_offsets: Array[float] = [-45.0, 45.0, 120.0]
	for index: int in _spike.enemies.size():
		var enemy: BeltEnemy = _spike.enemies[index]
		enemy.set_simulation_enabled(false)
		enemy.global_position = impact_center + Vector2(0.0, vertical_offsets[index])
	await physics_frame
	var before_total: int = _enemy_health_total()
	_check(_spike.request_attack(), "thrown blast request is accepted")
	await _wait_seconds(1.7)
	var damaged_count: int = 0
	for enemy: BeltEnemy in _spike.enemies:
		if enemy.health < enemy.maximum_health:
			damaged_count += 1
	_check(_enemy_health_total() < before_total, "grenade arc resolves into a separate blast")
	_check(
		damaged_count == 2,
		"ground ellipse hits only bodies inside its visible radii (actual %d)" % damaged_count,
	)
	var blast_event_found: bool = false
	for event: Dictionary in _spike.qa_state().get("combat_events", []):
		if str(event.get("kind", "")) != "blast_hits":
			continue
		var blast_state: Dictionary = event.get("blast_state", {})
		var radii: Dictionary = blast_state.get("radii", {})
		blast_event_found = (
			str(blast_state.get("shape", "")) == "ground_ellipse"
			and float(radii.get("x", 0.0)) > float(radii.get("y", 0.0))
		)
	_check(blast_event_found, "blast QA exposes the authoritative ground ellipse radii")


func _test_piercing() -> void:
	_spike.select_encounter("group")
	_check(_equip_live_weapon("piercing", "normal"), "live piercing payload equips")
	await physics_frame
	var arena_center_y: float = _spike.player.arena_bounds.get_center().y
	_spike.player.global_position = Vector2(250.0, arena_center_y)
	await physics_frame
	var shared_target: Vector2 = _spike.player.global_position + Vector2(390.0, -42.0)
	for index: int in _spike.enemies.size():
		var enemy: BeltEnemy = _spike.enemies[index]
		enemy.set_simulation_enabled(false)
		enemy.global_position = shared_target
	await physics_frame
	_check(_spike.request_attack(), "piercing request is accepted")
	await _wait_seconds(1.6)
	var damages: Array[int] = []
	for enemy: BeltEnemy in _spike.enemies:
		damages.append(enemy.maximum_health - enemy.health)
	_check(damages == [29, 20, 13], "piercing keeps 100/70/45 three-body damage")
	_check(
		not bool(_spike.player.qa_state().get("movement_locked", true)),
		"piercing startup movement lock clears after commit",
	)


func _test_terminal_cleanup_and_retry() -> void:
	_spike.select_encounter("moving")
	_spike.select_weapon("boomerang")
	await physics_frame
	_spike.request_attack()
	await _wait_seconds(0.5)
	_spike.player.take_damage(BeltPlayer.MAX_HEALTH)
	await process_frame
	var terminal_state: Dictionary = _spike.qa_state()
	_check(str(terminal_state.get("round_state", "")) == "defeat", "player HP reaches Defeat")
	_check(int(terminal_state.get("active_transient_count", -1)) == 0, "terminal state clears attacks")
	_check(not _spike.player.attack_active(), "terminal state clears player attack state")
	_spike.retry_round()
	await physics_frame
	_check(_spike.round_state == "active", "Retry starts the same encounter")
	_check(_spike.player.health == BeltPlayer.MAX_HEALTH, "Retry restores player health")
	_check(_spike.current_pattern == "boomerang", "Retry preserves the equipped weapon")
	_spike.set_touch_move(Vector2(1.0, 0.5))
	_spike.request_attack()
	await _wait_physics_frames(2)
	_spike.request_reforge()
	await process_frame
	var reforge_state: Dictionary = _spike.qa_state()
	var touch_state: Dictionary = reforge_state.get("touch", {})
	_check(_spike.round_state == "reforge", "Reforge enters a stable scene-router state")
	_check(int(reforge_state.get("active_transient_count", -1)) == 0, "Reforge clears transient attacks")
	_check(
		is_zero_approx(float(touch_state.get("x", 1.0)))
		and is_zero_approx(float(touch_state.get("y", 1.0))),
		"Reforge clears continuous touch input",
	)


func _test_physics_tick_profiles() -> void:
	var original_ticks: int = Engine.physics_ticks_per_second
	for ticks: int in [30, 60, 120]:
		Engine.physics_ticks_per_second = ticks
		_spike.select_encounter("moving")
		var source: Dictionary = _make_live_weapon("piercing", "electric")
		_check(
			_spike.equip_weapon(source.spec, source.strokes, source.geometry),
			"%d fps live payload equips" % ticks,
		)
		await physics_frame
		var expected_spec: Dictionary = _spike.player.current_spec.to_dict().duplicate(true)
		var expected_strokes: Array[PackedVector2Array] = StrokeFit.duplicate_strokes(
			_spike.player.current_strokes,
		)
		var expected_geometry: Dictionary = (
			_spike.player.current_geometry_profile.to_dict().duplicate(true)
		)
		_spike.enemies[0].set_simulation_enabled(false)
		var arena_center_y: float = _spike.player.arena_bounds.get_center().y
		_spike.player.global_position = Vector2(260.0, arena_center_y)
		_spike.enemies[0].global_position = Vector2(700.0, arena_center_y)
		await physics_frame
		_spike.request_attack()
		await _wait_physics_frames(
			ceili(_spike.player.current_role_profile.cycle_seconds * float(ticks)) + 4
		)
		_check(
			int(_spike.qa_state().get("accepted_attack_count", 0)) == 1,
			"%d fps produces exactly one attack commit" % ticks,
		)
		_check(not _spike.player.attack_active(), "%d fps cleans the attack state" % ticks)
		_check(
			_spike.player.current_spec.to_dict() == expected_spec
			and _strokes_equal(_spike.player.current_strokes, expected_strokes)
			and _spike.player.current_geometry_profile.to_dict() == expected_geometry,
			"%d fps preserves exact live payload identity" % ticks,
		)
	Engine.physics_ticks_per_second = original_ticks


func _test_bounded_long_frame() -> void:
	var fine_steps: Array[float] = []
	for _index: int in 12:
		fine_steps.append(0.01)
	var fine_result: Dictionary = await _manual_projectile_profile(fine_steps)
	var long_result: Dictionary = await _manual_projectile_profile([0.12])
	_check(
		int(fine_result.get("hit_count", -1)) == 1
		and int(long_result.get("hit_count", -1)) == 1,
		"fine and bounded 0.12s long-frame paths each resolve one body hit",
	)
	_check(
		int(fine_result.get("damage", -1)) == int(long_result.get("damage", -2)),
		"bounded long frame preserves authoritative damage",
	)
	_check(
		bool(fine_result.get("finished", false))
		and bool(long_result.get("finished", false)),
		"bounded long frame preserves terminal projectile state",
	)
	_check(
		int(fine_result.get("active_transients", -1)) == 0
		and int(long_result.get("active_transients", -1)) == 0,
		"bounded long frame preserves transient cleanup",
	)
	_check(
		fine_result.get("weapon_spec", {}) == long_result.get("weapon_spec", {})
		and fine_result.get("geometry_profile", {}) == long_result.get("geometry_profile", {})
		and fine_result.get("stroke_signature", {}) == long_result.get("stroke_signature", {}),
		"bounded long frame preserves exact live payload identity",
	)


func _manual_projectile_profile(step_deltas: Array) -> Dictionary:
	_spike.select_encounter("moving")
	_check(
		_equip_live_weapon("straight_projectile", "fire"),
		"bounded-frame live projectile payload equips",
	)
	await physics_frame
	var enemy: BeltEnemy = _spike.enemies[0]
	enemy.set_simulation_enabled(false)
	var center: Vector2 = _spike.player.arena_bounds.get_center()
	_spike.player.global_position = center
	enemy.global_position = center + Vector2(60.0, 0.0)
	await physics_frame
	var projectile: BeltProjectile = BeltProjectile.new()
	projectile.process_mode = Node.PROCESS_MODE_DISABLED
	var empty_strokes: Array[PackedVector2Array] = []
	projectile.configure(
		_spike.player.current_spec,
		empty_strokes,
		Vector2.RIGHT,
		_spike.player,
		enemy.global_position,
	)
	projectile.global_position = center
	_spike.add_child(projectile)
	await process_frame
	for delta_value: Variant in step_deltas:
		if not is_instance_valid(projectile) or projectile.is_queued_for_deletion():
			break
		projectile._physics_process(float(delta_value))
	var projectile_state: Dictionary = (
		projectile.qa_state()
		if is_instance_valid(projectile)
		else {}
	)
	var finished: bool = (
		not is_instance_valid(projectile)
		or projectile.is_queued_for_deletion()
	)
	if is_instance_valid(projectile) and not projectile.is_queued_for_deletion():
		projectile.cancel_attack()
	await process_frame
	return {
		"hit_count": int(projectile_state.get("hit_count", 0)),
		"damage": enemy.maximum_health - enemy.health,
		"finished": finished,
		"active_transients": get_nodes_in_group("belt_transient_attack").size(),
		"weapon_spec": _spike.player.current_spec.to_dict().duplicate(true),
		"geometry_profile": _spike.player.current_geometry_profile.to_dict().duplicate(true),
		"stroke_signature": _stroke_signature(_spike.player.current_strokes),
	}


func _test_compact_layouts() -> void:
	for compact_size: Vector2i in [
		Vector2i(844, 390),
		Vector2i(852, 393),
		Vector2i(915, 412),
	]:
		_spike.qa_set_css_viewport_size(Vector2(compact_size))
		await process_frame
		await process_frame
		var state: Dictionary = _spike.qa_state()
		var layout: Dictionary = state.get("layout", {})
		for control_name: String in ["joystick", "attack", "retry", "reforge"]:
			var rect: Rect2 = _dictionary_rect(layout.get(control_name, {}))
			_check(rect.size.x >= 44.0 and rect.size.y >= 44.0, "%s keeps %s touch target" % [compact_size, control_name])
			_check(
				rect.end.x <= float(compact_size.x) + 0.1 and rect.end.y <= float(compact_size.y) + 0.1,
				"%s keeps %s on screen" % [compact_size, control_name],
			)
		var arena: Rect2 = _dictionary_rect(state.get("arena_css_bounds", {}))
		var joystick_rect: Rect2 = _dictionary_rect(layout.get("joystick", {}))
		_check(arena.end.y <= joystick_rect.position.y + 0.1, "%s keeps the arena above touch controls" % compact_size)
		for collection_name: String in ["encounters", "weapons"]:
			var collection: Dictionary = layout.get(collection_name, {})
			for control_id: String in collection:
				var top_rect: Rect2 = _dictionary_rect(collection[control_id])
				_check(top_rect.size.y >= 43.95, "%s keeps %s/%s touch height" % [compact_size, collection_name, control_id])
				_check(top_rect.end.x <= float(compact_size.x) + 0.1, "%s keeps %s/%s on screen" % [compact_size, collection_name, control_id])
	_spike.qa_set_css_viewport_size(Vector2(390.0, 844.0))
	await process_frame
	_check(bool(_spike.qa_state().get("viewport", {}).get("portrait", false)), "portrait gate activates")
	_check(not _spike.player.combat_enabled, "portrait gate freezes combat")
	_spike.qa_set_css_viewport_size(Vector2(844.0, 390.0))
	await process_frame
	_check(not bool(_spike.qa_state().get("viewport", {}).get("portrait", true)), "landscape restore clears portrait gate")
	_check(_spike.player.combat_enabled, "landscape restore resumes active combat")
	_spike.qa_set_css_viewport_size(Vector2.ZERO)
	await process_frame


func _equip_live_weapon(pattern: String, element: String) -> bool:
	var source: Dictionary = _make_live_weapon(pattern, element)
	return _spike.equip_weapon(source.spec, source.strokes, source.geometry)


func _make_live_weapon(pattern: String, element: String) -> Dictionary:
	var canvas_size: Vector2 = Vector2(760.0, 220.0)
	var strokes: Array[PackedVector2Array] = _live_strokes_for(pattern)
	var drawing_summary: Dictionary = DrawingCanvas.summarize_strokes(strokes, canvas_size)
	var descriptions: Dictionary = {
		"melee_slash": "a %s balanced sword" % element,
		"straight_projectile": "a %s fast bow with straight arrows" % element,
		"boomerang": "a %s returning boomerang" % element,
		"area_blast": "a %s thrown grenade with an explosion" % element,
		"piercing": "a %s piercing spear" % element,
	}
	var compiler: MockAIService = MockAIService.new()
	var spec: WeaponSpec = compiler.generate(
		str(descriptions.get(pattern, "a %s balanced weapon" % element)),
		drawing_summary,
		pattern,
	)
	var geometry: DrawingGeometryProfile = DrawingGeometryProfile.from_snapshot(
		strokes,
		canvas_size,
		"balanced",
	)
	if geometry.applies_to(spec):
		geometry.apply_to_spec(spec)
	return {
		"spec": spec,
		"strokes": StrokeFit.duplicate_strokes(strokes),
		"geometry": geometry,
	}


func _live_strokes_for(pattern: String) -> Array[PackedVector2Array]:
	match pattern:
		"straight_projectile":
			return [
				PackedVector2Array([
					Vector2(110.0, 48.0),
					Vector2(76.0, 110.0),
					Vector2(110.0, 172.0),
				]),
				PackedVector2Array([
					Vector2(110.0, 48.0),
					Vector2(164.0, 110.0),
					Vector2(110.0, 172.0),
				]),
			]
		"boomerang":
			return [PackedVector2Array([
				Vector2(84.0, 166.0),
				Vector2(176.0, 58.0),
				Vector2(292.0, 70.0),
				Vector2(194.0, 124.0),
				Vector2(84.0, 166.0),
			])]
		"area_blast":
			return [PackedVector2Array([
				Vector2(112.0, 72.0),
				Vector2(168.0, 48.0),
				Vector2(224.0, 72.0),
				Vector2(240.0, 132.0),
				Vector2(196.0, 174.0),
				Vector2(132.0, 166.0),
				Vector2(104.0, 112.0),
				Vector2(112.0, 72.0),
			])]
		"piercing":
			return [PackedVector2Array([
				Vector2(70.0, 116.0),
				Vector2(310.0, 106.0),
				Vector2(520.0, 96.0),
			])]
		_:
			return [PackedVector2Array([
				Vector2(72.0, 116.0),
				Vector2(268.0, 106.0),
				Vector2(472.0, 92.0),
			])]


func _strokes_equal(
	left: Array[PackedVector2Array],
	right: Array[PackedVector2Array],
) -> bool:
	if left.size() != right.size():
		return false
	for index: int in left.size():
		if left[index] != right[index]:
			return false
	return true


func _stroke_signature(strokes: Array[PackedVector2Array]) -> Dictionary:
	var point_count: int = 0
	var parts: PackedStringArray = []
	for stroke: PackedVector2Array in strokes:
		parts.append("s%d" % stroke.size())
		point_count += stroke.size()
		for point: Vector2 in stroke:
			parts.append("%.4f,%.4f" % [point.x, point.y])
	return {
		"stroke_count": strokes.size(),
		"point_count": point_count,
		"sha256": "|".join(parts).sha256_text(),
	}


func _dictionary_rect(value: Variant) -> Rect2:
	var data: Dictionary = value if value is Dictionary else {}
	return Rect2(
		float(data.get("x", 0.0)),
		float(data.get("y", 0.0)),
		float(data.get("width", 0.0)),
		float(data.get("height", 0.0)),
	)


func _enemy_health_total() -> int:
	var total: int = 0
	for enemy: BeltEnemy in _spike.enemies:
		total += enemy.health
	return total


func _wait_physics_frames(frame_count: int) -> void:
	for _index: int in frame_count:
		await physics_frame


func _wait_until_projectile(max_frames: int) -> void:
	for _index: int in max_frames:
		if not Array(_spike.qa_state().get("projectiles", [])).is_empty():
			return
		await physics_frame


func _wait_until_transient_kind(kind: String, max_frames: int) -> void:
	for _index: int in max_frames:
		for transient: Dictionary in _spike.qa_state().get("transients", []):
			if str(transient.get("kind", "")) == kind:
				return
		await physics_frame


func _wait_until_event(kind: String, max_frames: int) -> void:
	for _index: int in max_frames:
		for event: Dictionary in _spike.qa_state().get("combat_events", []):
			if str(event.get("kind", "")) == kind:
				return
		await physics_frame


func _transient_direction(kind: String) -> Vector2:
	var states: Array = (
		_spike.qa_state().get("transients", [])
		if not kind.is_empty()
		else _spike.qa_state().get("projectiles", [])
	)
	for state_value: Variant in states:
		if not state_value is Dictionary:
			continue
		var state: Dictionary = state_value
		if not kind.is_empty() and str(state.get("kind", "")) != kind:
			continue
		var direction_data: Dictionary = state.get("direction", {})
		return Vector2(
			float(direction_data.get("x", 0.0)),
			float(direction_data.get("y", 0.0)),
		).normalized()
	return Vector2.ZERO


func _latest_event_x(kind: String) -> float:
	var events: Array = _spike.qa_state().get("combat_events", [])
	for index: int in range(events.size() - 1, -1, -1):
		var event_value: Variant = events[index]
		if event_value is Dictionary and str(event_value.get("kind", "")) == kind:
			return float(event_value.get("x", 0.0))
	return 0.0


func _wait_seconds(seconds: float) -> void:
	var elapsed: float = 0.0
	while elapsed < seconds:
		await physics_frame
		elapsed += 1.0 / float(Engine.physics_ticks_per_second)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if condition:
		return
	_failures += 1
	push_error("FAIL belt combat: %s" % message)


func _finish() -> void:
	print("Belt combat spike: %d assertions, %d failed" % [_assertions, _failures])
	quit(0 if _failures == 0 else 1)
