class_name BeltCombatSpike
extends Node2D

## Emitted after the active encounter changes and all actors are reset.
signal encounter_changed(encounter_id: String)
## Emitted after the equipped local fixture changes.
signal weapon_changed(attack_pattern: String, role_id: String)
## Emitted exactly once per terminal transition.
signal outcome_changed(outcome: String)
## Integration hook: the spike never opens Forge or mutates committed input itself.
signal reforge_requested
## Explicit scene-router alias emitted after all Belt-local state is safely cleared.
signal forge_return_requested
## Stable event stream for UI integration and provider-free QA.
signal combat_event(kind: String, detail: Dictionary)

const ENCOUNTERS: PackedStringArray = ["moving", "shield", "group"]
const PLAYABLE_ENCOUNTER: String = "playable"
const ATTACK_PATTERNS: PackedStringArray = [
	"melee_slash",
	"straight_projectile",
	"boomerang",
	"area_blast",
	"piercing",
]
const ARENA_REFERENCE: Rect2 = Rect2(70.0, 238.0, 1140.0, 380.0)
const PLAYER_SPAWN_REFERENCE: Vector2 = Vector2(210.0, 458.0)
const NAVY: Color = Color("#07111f")
const PANEL: Color = Color("#10243a")
const TEXT: Color = Color("#edf4ff")
const MUTED: Color = Color("#9bb0cf")
const CYAN: Color = Color("#65d9ff")
const ORANGE: Color = Color("#ffb65c")

## True only for the standalone F6/explicit QA route. The live player route
## receives one external WeaponSpec and cannot select deterministic fixtures.
var developer_test_mode: bool = true
var forge_description_draft: String = ""
var current_encounter: String = "moving"
var current_pattern: String = "melee_slash"
var round_state: String = "active"
var player: BeltPlayer
var enemies: Array[BeltEnemy] = []

var _arena_actors: Node2D
var _fixture_specs: Dictionary = {}
var _fixture_strokes: Dictionary = {}
var _fixture_geometry: Dictionary = {}
var _hud_layer: CanvasLayer
var _hud_root: Control
var _title_label: Label
var _status_label: Label
var _health_label: Label
var _role_label: Label
var _outcome_panel: PanelContainer
var _outcome_label: Label
var _orientation_prompt: RotationPrompt
var _attack_button: Button
var _dodge_button: Button
var _ward_button: Button
var _retry_button: Button
var _reforge_button: Button
var _reward_row: HBoxContainer
var _ward_reward_button: Button
var _dodge_reward_button: Button
var _encounter_buttons: Dictionary = {}
var _weapon_buttons: Dictionary = {}
var _joystick: BeltJoystick
var _combat_event_sequence: int = 0
var _accepted_attack_count: int = 0
var _damage_event_count: int = 0
var _round_generation: int = 0
var _event_log: Array[Dictionary] = []
var _damage_events: Array[Dictionary] = []
var _web_callback: Variant
var _qa_css_size_override: Vector2 = Vector2.ZERO
var _last_layout_css_size: Vector2 = Vector2.ZERO
var _layout_refresh_elapsed: float = 0.0
var _equipment_source: String = "none"
var _route_payload_consumed: bool = false
var _next_attempt_reward: String = ""
var _active_attempt_reward: String = ""
var _reward_selected_this_victory: bool = false


func _ready() -> void:
	_arena_actors = Node2D.new()
	_arena_actors.name = "ArenaActors"
	_arena_actors.y_sort_enabled = true
	add_child(_arena_actors)
	player = BeltPlayer.new()
	player.name = "BeltPlayer"
	player.attack_committed.connect(_on_player_attack_committed)
	player.health_changed.connect(_on_player_health_changed)
	player.damaged.connect(_on_player_damaged)
	player.died.connect(_on_player_died)
	player.attack_request_resolved.connect(_on_attack_request_resolved)
	player.dodge_request_resolved.connect(_on_dodge_request_resolved)
	player.ward_request_resolved.connect(_on_ward_request_resolved)
	player.incoming_strike_resolved.connect(_on_incoming_strike_resolved)
	_arena_actors.add_child(player)
	if developer_test_mode:
		_build_local_weapon_fixtures()
	_build_hud()
	_install_web_qa_bridge()
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	if developer_test_mode:
		select_weapon(current_pattern)
	else:
		current_encounter = PLAYABLE_ENCOUNTER
	select_encounter(current_encounter)
	if not developer_test_mode:
		round_state = "awaiting_weapon"
		player.set_combat_enabled(false)
		for enemy: BeltEnemy in enemies:
			enemy.set_simulation_enabled(false)
		_status_label.text = "Preparing your forged weapon."
	_layout_for_viewport()
	_update_orientation_gate()
	set_process(true)
	queue_redraw()


func _exit_tree() -> void:
	set_process(false)
	if OS.has_feature("web"):
		JavaScriptBridge.eval(
			"""
			window.__forgeGodotBeltCombatCallback = null;
			if (window.__forgeBeltCombat) {
				window.__forgeBeltCombat._state = {};
				window.__forgeBeltCombat._controls = {};
			}
			""",
			true,
		)
	_web_callback = null


func _process(delta: float) -> void:
	if not is_inside_tree():
		return
	_refresh_ability_hud()
	if OS.has_feature("web"):
		_update_web_qa_state()
		_layout_refresh_elapsed += delta
		if _layout_refresh_elapsed >= 0.15:
			_layout_refresh_elapsed = 0.0
			var css_size: Vector2 = _effective_css_size(get_viewport_rect().size)
			if not css_size.is_equal_approx(_last_layout_css_size):
				_layout_for_viewport()
				_update_orientation_gate()


## Equips a repaired/runtime-valid weapon without mutating its numeric authority.
## This is the primary integration boundary for the existing Forge flow.
func equip_weapon(
	spec: WeaponSpec,
	strokes: Array[PackedVector2Array],
	geometry_profile: DrawingGeometryProfile = null,
) -> bool:
	if (
		not _is_runtime_valid_external_weapon(spec)
		or geometry_profile == null
		or not _external_strokes_are_drawable(strokes)
	):
		_clear_equipped_weapon()
		return false
	var belt_spec: WeaponSpec = WeaponRouteSnapshot.clone_weapon_spec(spec)
	var belt_strokes: Array[PackedVector2Array] = StrokeFit.duplicate_strokes(strokes)
	var belt_geometry: DrawingGeometryProfile = (
		WeaponRouteSnapshot.clone_geometry_profile(geometry_profile)
	)
	_fixture_specs["external"] = belt_spec
	_fixture_strokes["external"] = StrokeFit.duplicate_strokes(belt_strokes)
	_fixture_geometry["external"] = WeaponRouteSnapshot.clone_geometry_profile(
		belt_geometry,
	)
	_equipment_source = "live"
	current_pattern = belt_spec.attack_pattern
	player.equip_weapon(belt_spec, belt_strokes, belt_geometry)
	round_state = "active"
	player.set_combat_enabled(true)
	for enemy: BeltEnemy in enemies:
		if not enemy.is_defeated():
			enemy.set_simulation_enabled(true)
	_status_label.text = (
		"Move in X/Y. Attacks lightly assist toward the nearest live target."
	)
	_update_role_hud()
	_update_selected_buttons()
	_update_orientation_gate()
	weapon_changed.emit(spec.attack_pattern, player.current_role_profile.role_id)
	_record_event("weapon_equipped", {
		"pattern": spec.attack_pattern,
		"role_id": player.current_role_profile.role_id,
		"source": "external",
	})
	return true


func set_forge_description_draft(value: String) -> void:
	forge_description_draft = value.left(512)


func mark_route_payload_consumed() -> void:
	_route_payload_consumed = true


func _clear_equipped_weapon() -> void:
	_fixture_specs.erase("external")
	_fixture_strokes.erase("external")
	_fixture_geometry.erase("external")
	_equipment_source = "none"
	_route_payload_consumed = false
	if is_instance_valid(player):
		player.clear_weapon()
	for enemy: BeltEnemy in enemies:
		if is_instance_valid(enemy):
			enemy.set_simulation_enabled(false)
	round_state = "route_error"
	if is_instance_valid(_status_label):
		_status_label.text = "Weapon validation failed. Return to Forge."


func _is_runtime_valid_external_weapon(spec: WeaponSpec) -> bool:
	if spec == null or not spec.is_valid():
		return false
	var numeric_values: Array[float] = [
		spec.attack_speed,
		spec.attack_range,
		spec.projectile_speed,
		spec.area_radius,
		spec.return_speed,
	]
	for value: float in numeric_values:
		if is_nan(value) or is_inf(value):
			return false
	var calculated: Dictionary = PowerBudget.calculate(spec.to_dict())
	var total: float = float(calculated.get("total", PowerBudget.MAX_POWER + 1.0))
	return (
		not is_nan(total)
		and not is_inf(total)
		and total <= float(PowerBudget.MAX_POWER)
		and spec.power_score == int(ceil(total))
	)


func _external_strokes_are_drawable(
	strokes: Array[PackedVector2Array],
) -> bool:
	if strokes.is_empty():
		return false
	var point_count: int = 0
	var path_length: float = 0.0
	for stroke: PackedVector2Array in strokes:
		for point_index: int in stroke.size():
			var point: Vector2 = stroke[point_index]
			if (
				is_nan(point.x)
				or is_inf(point.x)
				or is_nan(point.y)
				or is_inf(point.y)
			):
				return false
			point_count += 1
			if point_index > 0:
				path_length += stroke[point_index - 1].distance_to(point)
	if is_nan(path_length) or is_inf(path_length):
		return false
	return (
		point_count >= 2
		and path_length >= DrawingCanvas.MIN_DRAWABLE_PATH_LENGTH
	)


## Selects one of the three explicitly scoped test encounters.
func select_encounter(encounter_id: String) -> bool:
	if encounter_id not in ENCOUNTERS and encounter_id != PLAYABLE_ENCOUNTER:
		return false
	if encounter_id == PLAYABLE_ENCOUNTER and developer_test_mode:
		return false
	current_encounter = encounter_id
	_round_generation += 1
	_clear_transient_attacks()
	_event_log.clear()
	_damage_events.clear()
	_accepted_attack_count = 0
	_damage_event_count = 0
	for enemy: BeltEnemy in enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	enemies.clear()
	_spawn_encounter(encounter_id)
	var viewport_size: Vector2 = get_viewport_rect().size
	var scale_value: Vector2 = _arena_scale(viewport_size)
	player.arena_bounds = _scaled_arena(viewport_size)
	_active_attempt_reward = _next_attempt_reward
	_next_attempt_reward = ""
	match _active_attempt_reward:
		"ward_plus":
			player.configure_room_abilities(2, 1.0)
		"dodge_plus":
			player.configure_room_abilities(1, 0.72)
		_:
			player.configure_room_abilities(1, 1.0)
	player.reset_for_round(_scaled_point(PLAYER_SPAWN_REFERENCE, scale_value))
	player.set_target_candidates(enemies)
	round_state = "active"
	player.set_combat_enabled(true)
	for enemy: BeltEnemy in enemies:
		enemy.set_simulation_enabled(true)
	_outcome_panel.hide()
	_reward_selected_this_victory = false
	_refresh_health_hud()
	_update_selected_buttons()
	_update_orientation_gate()
	encounter_changed.emit(current_encounter)
	_record_event("encounter_selected", {
		"encounter": current_encounter,
		"enemy_count": enemies.size(),
	})
	return true


## Selects a deterministic provider-free fixture for standalone/F6 play.
func select_weapon(attack_pattern: String) -> bool:
	if not developer_test_mode:
		return false
	if attack_pattern not in ATTACK_PATTERNS:
		return false
	var spec: WeaponSpec = _fixture_specs.get(attack_pattern) as WeaponSpec
	var strokes_value: Variant = _fixture_strokes.get(attack_pattern, [])
	var strokes: Array[PackedVector2Array] = strokes_value as Array[PackedVector2Array]
	var geometry: DrawingGeometryProfile = (
		_fixture_geometry.get(attack_pattern) as DrawingGeometryProfile
	)
	if spec == null:
		return false
	current_pattern = attack_pattern
	_equipment_source = "fixture"
	player.equip_weapon(spec, strokes, geometry)
	_update_role_hud()
	_update_selected_buttons()
	weapon_changed.emit(spec.attack_pattern, player.current_role_profile.role_id)
	_record_event("weapon_selected", {
		"pattern": spec.attack_pattern,
		"role_id": player.current_role_profile.role_id,
	})
	return true


## Touch/UI integration entry. Values are normalized and can be updated each drag.
func set_touch_move(move_vector: Vector2) -> void:
	player.set_touch_move(move_vector)


## Touch/UI integration entry. Returns whether the authoritative player gate accepted it.
func request_attack() -> bool:
	return player.request_attack()


func request_dodge() -> bool:
	return player.request_dodge()


func request_ward() -> bool:
	return player.request_ward()


func select_reward(reward_id: String) -> bool:
	if (
		round_state != "victory"
		or _reward_selected_this_victory
		or reward_id not in ["ward_plus", "dodge_plus"]
	):
		return false
	_reward_selected_this_victory = true
	_next_attempt_reward = reward_id
	_record_event("reward_selected", {"reward": reward_id})
	retry_round()
	return true


## Restarts the current encounter with the currently equipped weapon.
func retry_round() -> void:
	select_encounter(current_encounter)
	_record_event("retry", {"encounter": current_encounter})


## Stops the round, clears attack state, and delegates Forge navigation to the integrator.
func request_reforge() -> void:
	_next_attempt_reward = ""
	_active_attempt_reward = ""
	_reward_selected_this_victory = false
	if round_state == "active":
		_set_terminal_state("reforge")
	else:
		_clear_touch_input()
		_clear_transient_attacks()
	reforge_requested.emit()
	forge_return_requested.emit()
	_record_event("reforge_requested", {})


## Scene-router friendly name for leaving this independent spike.
func exit_to_forge() -> void:
	request_reforge()


func qa_state() -> Dictionary:
	if not is_inside_tree():
		return {
			"screen": "belt_combat",
			"round_state": "detached",
			"combat_route": "detached",
		}
	var enemy_states: Array[Dictionary] = []
	for enemy: BeltEnemy in enemies:
		if is_instance_valid(enemy):
			enemy_states.append(enemy.qa_state())
	var transient_states: Array[Dictionary] = []
	var projectile_states: Array[Dictionary] = []
	var blast_states: Array[Dictionary] = []
	var arena_children: Array[Node] = []
	if is_instance_valid(_arena_actors):
		arena_children.assign(_arena_actors.get_children())
	for node: Node in arena_children:
		if not node.is_in_group("belt_transient_attack"):
			continue
		if node is BeltProjectile:
			var projectile_state: Dictionary = (node as BeltProjectile).qa_state()
			transient_states.append(projectile_state)
			projectile_states.append(projectile_state)
		elif node is BeltBlast:
			var blast_state: Dictionary = (node as BeltBlast).qa_state()
			transient_states.append(blast_state)
			blast_states.append(blast_state)
		elif node is ForgeSlashEffect:
			transient_states.append((node as ForgeSlashEffect).qa_state())
	var spec: WeaponSpec = player.current_spec
	var touch_vector: Vector2 = player.touch_move()
	var stroke_signature: Dictionary = _stroke_signature(player.current_strokes)
	return {
		"screen": "belt_combat",
		"combat_route": (
			"belt_live"
			if _equipment_source == "live"
			else ("belt_fixture" if _equipment_source == "fixture" else "belt_unarmed")
		),
		"developer_test_mode": developer_test_mode,
		"equipment_source": _equipment_source,
		"route_payload_consumed": _route_payload_consumed,
		"forge_description_length": forge_description_draft.length(),
		"round_state": round_state,
		"encounter": current_encounter,
		"active_attempt_reward": _active_attempt_reward,
		"next_attempt_reward": _next_attempt_reward,
		"reward_selected_this_victory": _reward_selected_this_victory,
		"fixture": current_encounter,
		"weapon_pattern": current_pattern,
		"weapon": spec.to_dict() if spec != null else {},
		"weapon_spec": spec.to_dict() if spec != null else {},
		"weapon_corrections": spec.corrections.duplicate() if spec != null else [],
		"weapon_budget": (
			spec.budget_breakdown.duplicate(true)
			if spec != null
			else {}
		),
		"geometry_profile": (
			player.current_geometry_profile.to_dict()
			if player.current_geometry_profile != null
			else {}
		),
		"stroke_signature": stroke_signature,
		"weapon_role": player.current_role_profile.to_dict() if player.current_role_profile != null else {},
		"player": player.qa_state(),
		"enemies": enemy_states,
		"active_enemy_count": _active_enemy_count(),
		"transients": transient_states,
		"projectiles": projectile_states,
		"blasts": blast_states,
		"combat_events": _event_log.duplicate(true),
		"active_transient_count": transient_states.size(),
		"path_events": _event_log.duplicate(true),
		"damage_events": _damage_events.duplicate(true),
		"metrics": {
			"accepted_attack_count": _accepted_attack_count,
			"damage_event_count": _damage_event_count,
			"event_count": _combat_event_sequence,
		},
		"cleanup": {
			"active_transient_count": transient_states.size(),
			"player_attack_active": player.attack_active(),
			"held_visible": bool(player.qa_state().get("held_visible", false)),
		},
		"touch": {"x": touch_vector.x, "y": touch_vector.y},
		"accepted_attack_count": _accepted_attack_count,
		"damage_event_count": _damage_event_count,
		"event_sequence": _combat_event_sequence,
		"round_generation": _round_generation,
		"physics_ticks_per_second": Engine.physics_ticks_per_second,
		"arena_bounds": _rect_dictionary(player.arena_bounds),
		"arena_css_bounds": _world_rect_to_css_dictionary(player.arena_bounds),
		"viewport": {
			"width": get_viewport_rect().size.x,
			"height": get_viewport_rect().size.y,
			"css_width": _effective_css_size(get_viewport_rect().size).x,
			"css_height": _effective_css_size(get_viewport_rect().size).y,
			"compact": _is_compact_landscape(_effective_css_size(get_viewport_rect().size)),
			"portrait": _is_portrait(_effective_css_size(get_viewport_rect().size)),
		},
		"layout": _layout_qa_state(),
		"y_sort_enabled": _arena_actors.y_sort_enabled,
		"fps_contract": "physics_delta_crossing; one commit flag; continuous segment hits",
	}


func _stroke_signature(strokes: Array[PackedVector2Array]) -> Dictionary:
	var point_count: int = 0
	var signature_parts: PackedStringArray = []
	for stroke: PackedVector2Array in strokes:
		signature_parts.append("s%d" % stroke.size())
		point_count += stroke.size()
		for point: Vector2 in stroke:
			signature_parts.append("%.4f,%.4f" % [point.x, point.y])
	return {
		"stroke_count": strokes.size(),
		"point_count": point_count,
		"sha256": "|".join(signature_parts).sha256_text(),
	}


func qa_command(command: String, payload: Dictionary = {}) -> void:
	match command:
		"encounter", "fixture":
			select_encounter(str(payload.get("id", payload.get("encounter", "moving"))))
		"weapon":
			select_weapon(str(payload.get("pattern", "melee_slash")))
		"move", "input":
			set_touch_move(Vector2(
				clampf(float(payload.get("x", 0.0)), -1.0, 1.0),
				clampf(float(payload.get("y", 0.0)), -1.0, 1.0),
			))
		"attack":
			request_attack()
		"dodge":
			request_dodge()
		"ward":
			request_ward()
		"reward":
			select_reward(str(payload.get("id", "")))
		"dodge_then_force_enemy_strike":
			set_touch_move(Vector2(
				clampf(float(payload.get("x", 1.0)), -1.0, 1.0),
				clampf(float(payload.get("y", 0.0)), -1.0, 1.0),
			))
			request_dodge()
			_qa_force_enemy_strike(str(payload.get("id", "")))
		"ward_then_force_enemy_strike":
			request_ward()
			_qa_force_enemy_strike(str(payload.get("id", "")))
		"force_enemy_strike":
			_qa_force_enemy_strike(str(payload.get("id", "")))
		"defeat_all":
			for enemy: BeltEnemy in enemies:
				if not enemy.is_defeated():
					enemy.take_damage(enemy.health)
		"retry", "reset":
			retry_round()
		"reforge":
			request_reforge()
		"damage_player":
			player.take_damage(clampi(int(payload.get("amount", 1)), 1, BeltPlayer.MAX_HEALTH))
		"set_player":
			var requested_player_position: Vector2 = Vector2(
				float(payload.get("x", player.global_position.x)),
				float(payload.get("y", player.global_position.y)),
			)
			player.global_position = Vector2(
				clampf(requested_player_position.x, player.arena_bounds.position.x, player.arena_bounds.end.x),
				clampf(requested_player_position.y, player.arena_bounds.position.y, player.arena_bounds.end.y),
			)
		"set_enemy_health":
			var enemy_id: String = str(payload.get("id", ""))
			for enemy: BeltEnemy in enemies:
				if enemy.enemy_id == enemy_id or enemy_id.is_empty():
					enemy.qa_set_health(int(payload.get("health", enemy.health)))
					if not enemy_id.is_empty():
						break
			_refresh_health_hud()
		"set_enemy":
			var positioned_enemy_id: String = str(payload.get("id", ""))
			for enemy: BeltEnemy in enemies:
				if enemy.enemy_id == positioned_enemy_id or positioned_enemy_id.is_empty():
					enemy.global_position = Vector2(
						clampf(float(payload.get("x", enemy.global_position.x)), player.arena_bounds.position.x, player.arena_bounds.end.x),
						clampf(float(payload.get("y", enemy.global_position.y)), player.arena_bounds.position.y, player.arena_bounds.end.y),
					)
					if payload.has("simulation_enabled"):
						enemy.set_simulation_enabled(bool(payload.get("simulation_enabled", true)))
					if not positioned_enemy_id.is_empty():
						break
		"pause_enemies":
			var simulation_enabled: bool = bool(payload.get("enabled", false))
			for enemy: BeltEnemy in enemies:
				enemy.set_simulation_enabled(simulation_enabled)
		"idle_until_defeat":
			set_touch_move(Vector2.ZERO)
			if not enemies.is_empty():
				enemies[0].global_position = player.global_position + Vector2(64.0, 0.0)
				enemies[0].set_simulation_enabled(true)
		"simulate_profile":
			Engine.physics_ticks_per_second = clampi(
				int(payload.get("fps", payload.get("physics_fps", 60))),
				30,
				120,
			)


func _qa_force_enemy_strike(strike_enemy_id: String) -> void:
	for enemy: BeltEnemy in enemies:
		if enemy.enemy_id == strike_enemy_id or strike_enemy_id.is_empty():
			enemy.global_position = player.global_position + Vector2(48.0, 0.0)
			enemy._set_phase(BeltEnemy.Phase.STRIKE, 0.24)
			# Resolve in the same QA callback so browser/JSBridge latency cannot
			# outlive the short DODGE/WARD windows. Normal combat still resolves
			# strikes in BeltEnemy physics.
			enemy._apply_strike()
			break


## Provider-free layout test hook. Web runtime reads visualViewport directly.
func qa_set_css_viewport_size(css_size: Vector2) -> void:
	_qa_css_size_override = css_size
	_layout_for_viewport()
	_update_orientation_gate()


func _build_local_weapon_fixtures() -> void:
	var compiler: MockAIService = MockAIService.new()
	var canvas_size: Vector2 = Vector2(760.0, 220.0)
	var descriptions: Dictionary = {
		"melee_slash": "a balanced normal sword",
		"straight_projectile": "a fast ice bow with straight arrows",
		"boomerang": "an electric returning boomerang",
		"area_blast": "a fire thrown grenade with an explosion",
		"piercing": "a normal piercing spear",
	}
	for pattern: String in ATTACK_PATTERNS:
		var strokes: Array[PackedVector2Array] = _fixture_strokes_for(pattern, canvas_size)
		var drawing_summary: Dictionary = DrawingCanvas.summarize_strokes(strokes, canvas_size)
		var spec: WeaponSpec = compiler.generate(
			str(descriptions.get(pattern, "balanced normal weapon")),
			drawing_summary,
			pattern,
		)
		var geometry: DrawingGeometryProfile = DrawingGeometryProfile.from_snapshot(
			strokes,
			canvas_size,
			"balanced",
		)
		if spec.delivery == "held" and spec.attack_pattern == "melee_slash":
			geometry.apply_to_spec(spec)
		_fixture_specs[pattern] = spec
		_fixture_strokes[pattern] = StrokeFit.duplicate_strokes(strokes)
		_fixture_geometry[pattern] = geometry


func _fixture_strokes_for(
	pattern: String,
	canvas_size: Vector2,
) -> Array[PackedVector2Array]:
	match pattern:
		"melee_slash":
			return [PackedVector2Array([
				Vector2(72.0, 112.0),
				Vector2(250.0, 104.0),
				Vector2(430.0, 92.0),
			])]
		"straight_projectile":
			return [
				PackedVector2Array([
					Vector2(120.0, 42.0),
					Vector2(86.0, 110.0),
					Vector2(120.0, 178.0),
				]),
				PackedVector2Array([
					Vector2(120.0, 42.0),
					Vector2(166.0, 110.0),
					Vector2(120.0, 178.0),
				]),
			]
		"boomerang":
			return [
				PackedVector2Array([
					Vector2(82.0, 164.0),
					Vector2(170.0, 52.0),
					Vector2(282.0, 64.0),
				]),
				PackedVector2Array([
					Vector2(82.0, 164.0),
					Vector2(186.0, 124.0),
					Vector2(282.0, 64.0),
				]),
			]
		"area_blast":
			var circle: PackedVector2Array = PackedVector2Array()
			for index: int in 18:
				var angle: float = TAU * float(index) / 17.0
				circle.append(Vector2(180.0, 110.0) + Vector2(cos(angle), sin(angle)) * 64.0)
			return [circle]
		"piercing":
			return [
				PackedVector2Array([
					Vector2(62.0, 118.0),
					Vector2(300.0, 108.0),
					Vector2(560.0, 92.0),
				]),
				PackedVector2Array([
					Vector2(500.0, 68.0),
					Vector2(566.0, 92.0),
					Vector2(504.0, 124.0),
				]),
			]
	return [PackedVector2Array([canvas_size * 0.2, canvas_size * 0.8])]


func _spawn_encounter(encounter_id: String) -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	var scale_value: Vector2 = _arena_scale(viewport_size)
	var definitions: Array[Dictionary] = []
	match encounter_id:
		"playable":
			definitions = [
				{
					"id": "bruiser",
					"kind": "bruiser",
					"health": 155,
					"position": Vector2(900.0, 392.0),
					"formation": Vector2(24.0, -46.0),
				},
				{
					"id": "charger",
					"kind": "charger",
					"health": 112,
					"position": Vector2(1010.0, 536.0),
					"formation": Vector2(58.0, 54.0),
				},
			]
		"moving":
			definitions = [{
				"id": "runner",
				"kind": "moving",
				"health": 125,
				"position": Vector2(930.0, 420.0),
				"formation": Vector2.ZERO,
			}]
		"shield":
			definitions = [{
				"id": "shield_guard",
				"kind": "shield",
				"health": 150,
				"position": Vector2(910.0, 454.0),
				"formation": Vector2.ZERO,
			}]
		"group":
			definitions = [
				{
					"id": "group_a",
					"kind": "group",
					"health": 78,
					"position": Vector2(860.0, 360.0),
					"formation": Vector2(0.0, -52.0),
				},
				{
					"id": "group_b",
					"kind": "group",
					"health": 78,
					"position": Vector2(950.0, 456.0),
					"formation": Vector2(34.0, 0.0),
				},
				{
					"id": "group_c",
					"kind": "group",
					"health": 78,
					"position": Vector2(850.0, 552.0),
					"formation": Vector2(0.0, 52.0),
				},
			]
	for definition: Dictionary in definitions:
		var enemy: BeltEnemy = BeltEnemy.new()
		enemy.name = str(definition.get("id", "enemy")).to_pascal_case()
		enemy.arena_bounds = _scaled_arena(viewport_size)
		enemy.configure(
			str(definition.get("id", "enemy")),
			str(definition.get("kind", "moving")),
			int(definition.get("health", 100)),
			_scaled_point(definition.get("position", Vector2.ZERO), scale_value),
			_scaled_vector(definition.get("formation", Vector2.ZERO), scale_value),
		)
		enemy.set_target(player)
		enemy.phase_changed.connect(_on_enemy_phase_changed)
		enemy.damage_report.connect(_on_enemy_damage_report)
		enemy.defeated.connect(_on_enemy_defeated)
		enemy.strike_landed.connect(_on_enemy_strike_landed)
		enemy.strike_resolved.connect(_on_enemy_strike_resolved)
		_arena_actors.add_child(enemy)
		enemies.append(enemy)


func _on_player_attack_committed(
	spec: WeaponSpec,
	origin: Vector2,
	direction: Vector2,
	target_point: Vector2,
	strokes: Array[PackedVector2Array],
	attack_generation: int,
) -> void:
	if round_state != "active" or attack_generation != player.attack_generation():
		return
	_accepted_attack_count += 1
	_record_event("attack_committed", {
		"pattern": spec.attack_pattern,
		"generation": attack_generation,
		"direction": {"x": direction.x, "y": direction.y},
	})
	if spec.delivery == "thrown" and spec.trajectory == "arc":
		_launch_projectile(spec, origin, direction, target_point, strokes)
		return
	match spec.attack_pattern:
		"melee_slash":
			_launch_melee(spec, origin, direction)
		"area_blast":
			_launch_blast(spec, player.global_position, direction)
		"straight_projectile", "boomerang", "piercing":
			_launch_projectile(spec, origin, direction, target_point, strokes)


func _launch_melee(spec: WeaponSpec, origin: Vector2, direction: Vector2) -> void:
	var normalized_direction: Vector2 = (
		direction.normalized() if direction.length_squared() > 0.001 else Vector2(player.facing, 0.0)
	)
	var end: Vector2 = origin + normalized_direction * spec.attack_range
	var candidates: Array[Dictionary] = []
	for enemy: BeltEnemy in enemies:
		if not is_instance_valid(enemy) or enemy.is_defeated():
			continue
		var closest: Vector2 = Geometry2D.get_closest_point_to_segment(
			enemy.global_position,
			origin,
			end,
		)
		var lateral_distance: float = enemy.global_position.distance_to(closest)
		if lateral_distance > enemy.hit_radius() + 20.0:
			continue
		var along: float = origin.distance_to(closest)
		candidates.append({"enemy": enemy, "along": along})
	var slash: ForgeSlashEffect = ForgeSlashEffect.new()
	slash.color = WeaponVisual._color_for_element(spec.element)
	slash.direction = normalized_direction
	slash.reach = spec.attack_range
	slash.lifetime = clampf(player.current_role_profile.active_seconds, 0.16, 0.42)
	slash.global_position = origin
	slash.add_to_group("belt_transient_attack")
	_arena_actors.add_child(slash)
	if candidates.is_empty():
		_record_event("attack_whiff", {"pattern": spec.attack_pattern})
		_status_label.text = "Slash missed. Move in two dimensions or use reach."
		return
	candidates.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			return float(a.get("along", 0.0)) < float(b.get("along", 0.0))
	)
	var target: BeltEnemy = candidates[0].get("enemy") as BeltEnemy
	if target == null:
		return
	target.take_damage(spec.damage, spec.status_effect, spec.attack_pattern, normalized_direction)


func _launch_projectile(
	spec: WeaponSpec,
	origin: Vector2,
	direction: Vector2,
	target_point: Vector2,
	strokes: Array[PackedVector2Array],
) -> void:
	var bundle: Dictionary = WeaponVisualBundle.from_spec(spec)
	if str(bundle.get("projectile_kind", "none")) == "none":
		return
	# The target point is frozen when the attack starts. Rebuild the final
	# direction from the actual muzzle origin so the projectile neither retargets
	# during startup nor travels on a parallel line beside the locked target.
	var launch_direction: Vector2 = origin.direction_to(target_point)
	if launch_direction.length_squared() <= 0.001:
		launch_direction = (
			direction.normalized()
			if direction.length_squared() > 0.001
			else Vector2(player.facing, 0.0)
		)
	var impact_position: Vector2 = _projectile_impact_position(
		origin,
		launch_direction,
		target_point,
		spec,
	)
	var projectile: BeltProjectile = BeltProjectile.new()
	projectile.configure(spec, strokes, launch_direction, player, impact_position)
	projectile.global_position = origin
	projectile.hit_resolved.connect(_on_projectile_hit_resolved)
	projectile.area_impact.connect(_on_projectile_area_impact)
	projectile.finished.connect(_on_projectile_finished)
	_arena_actors.add_child(projectile)
	if bool(bundle.get("hide_held_during_attack", false)):
		player.set_held_detached(true)


func _projectile_impact_position(
	origin: Vector2,
	direction: Vector2,
	target_point: Vector2,
	spec: WeaponSpec,
) -> Vector2:
	var impact: Vector2 = target_point
	if impact.distance_squared_to(origin) <= 1.0:
		impact = origin + direction * clampf(spec.attack_range * 0.50, 72.0, 200.0)
	return Vector2(
		clampf(impact.x, player.arena_bounds.position.x, player.arena_bounds.end.x),
		clampf(impact.y, player.arena_bounds.position.y, player.arena_bounds.end.y),
	)


func _launch_blast(spec: WeaponSpec, origin: Vector2, direction: Vector2) -> void:
	if round_state != "active":
		return
	var blast: BeltBlast = BeltBlast.new()
	blast.configure(spec, direction)
	blast.global_position = origin
	blast.hits_complete.connect(_on_blast_hits_complete)
	_arena_actors.add_child(blast)


func _on_projectile_hit_resolved(
	_projectile: BeltProjectile,
	enemy: BeltEnemy,
	amount: int,
	hit_index: int,
	multiplier: float,
) -> void:
	_record_event("projectile_hit", {
		"enemy": enemy.enemy_id,
		"amount": amount,
		"hit_index": hit_index,
		"multiplier": multiplier,
	})


func _on_projectile_area_impact(
	_projectile: BeltProjectile,
	impact_position: Vector2,
	direction: Vector2,
) -> void:
	if round_state != "active" or player.current_spec == null:
		return
	_launch_blast(player.current_spec, impact_position, direction)
	_record_event("area_impact", {
		"x": impact_position.x,
		"y": impact_position.y,
	})


func _on_projectile_finished(projectile: BeltProjectile) -> void:
	var finished_state: Dictionary = projectile.qa_state()
	if player.current_spec != null:
		var bundle: Dictionary = WeaponVisualBundle.from_spec(player.current_spec)
		if bool(bundle.get("hide_held_during_attack", false)):
			player.set_held_detached(false)
	_record_event("projectile_finished", {
		"pattern": finished_state.get("pattern", ""),
		"final_state": finished_state,
	})


func _on_blast_hits_complete(
	blast: BeltBlast,
	count: int,
	total_damage: int,
) -> void:
	_record_event("blast_hits", {
		"count": count,
		"total_damage": total_damage,
		"blast_state": blast.qa_state(),
	})
	if count == 0:
		_status_label.text = "Blast missed the moving belt targets."


func _on_player_health_changed(_current: int, _maximum: int) -> void:
	_refresh_health_hud()


func _on_player_damaged(amount: int, current: int) -> void:
	_damage_event_count += 1
	_damage_events.append({
		"target": "player",
		"amount": amount,
		"health": current,
		"sequence": _damage_event_count,
	})
	_status_label.text = "Enemy strike: -%d. Player HP %d." % [amount, current]
	_record_event("player_damaged", {"amount": amount, "health": current})


func _on_player_died() -> void:
	if round_state == "active":
		_set_terminal_state("defeat")


func _on_attack_request_resolved(outcome: String) -> void:
	if outcome == "accepted":
		_status_label.text = "Attack accepted; commit follows the authoritative role timing."
	elif outcome == "buffered":
		_status_label.text = "One melee attack buffered."


func _on_dodge_request_resolved(outcome: String) -> void:
	match outcome:
		"accepted":
			_status_label.text = "DODGE: brief invulnerability and enemy passage."
		"blocked_cooldown":
			var dodge_state: Dictionary = player.qa_state().get("dodge", {})
			_status_label.text = "DODGE BLOCKED: cooldown %.1fs." % float(
				dodge_state.get("cooldown_remaining", 0.0),
			)
		"blocked_busy":
			_status_label.text = "DODGE BLOCKED: finish the current action."
		"blocked_terminal":
			_status_label.text = "DODGE BLOCKED: the room is not active."
		_:
			_status_label.text = "DODGE BLOCKED: %s." % outcome
	_record_event("dodge_request", {"outcome": outcome})


func _on_ward_request_resolved(outcome: String) -> void:
	if outcome == "accepted":
		_status_label.text = "WARD active. Time it against one enemy strike."
	_record_event("ward_request", {"outcome": outcome})


func _on_incoming_strike_resolved(outcome: String, amount: int) -> void:
	if outcome == "warded":
		_status_label.text = "WARD! Strike negated; attacker forced into recovery."
	elif outcome == "dodged":
		_status_label.text = "DODGED. No damage."
	_record_event("incoming_strike_resolved", {
		"outcome": outcome,
		"amount": amount,
	})


func _on_enemy_phase_changed(
	enemy: BeltEnemy,
	phase_name: String,
	duration: float,
) -> void:
	if phase_name == "telegraph":
		_status_label.text = "%s telegraphs for %.2fs." % [enemy.enemy_id.to_upper(), duration]
	_record_event("enemy_phase", {
		"enemy": enemy.enemy_id,
		"phase": phase_name,
		"duration": duration,
	})


func _on_enemy_damage_report(enemy: BeltEnemy, amount: int, note: String) -> void:
	_damage_event_count += 1
	_damage_events.append({
		"target": enemy.enemy_id,
		"amount": amount,
		"health": enemy.health,
		"note": note,
		"sequence": _damage_event_count,
	})
	_status_label.text = "%s took %d (%s)." % [
		enemy.enemy_id.to_upper(),
		amount,
		note if not note.is_empty() else "CONTACT",
	]
	_refresh_health_hud()
	_record_event("enemy_damaged", {
		"enemy": enemy.enemy_id,
		"amount": amount,
		"note": note,
		"health": enemy.health,
	})


func _on_enemy_defeated(enemy: BeltEnemy) -> void:
	_record_event("enemy_defeated", {"enemy": enemy.enemy_id})
	if round_state == "active" and _active_enemy_count() == 0:
		_set_terminal_state("victory")


func _on_enemy_strike_landed(enemy: BeltEnemy, amount: int) -> void:
	_record_event("enemy_strike", {"enemy": enemy.enemy_id, "amount": amount})


func _on_enemy_strike_resolved(
	enemy: BeltEnemy,
	outcome: String,
	amount: int,
) -> void:
	_record_event("enemy_strike_resolved", {
		"enemy": enemy.enemy_id,
		"outcome": outcome,
		"amount": amount,
	})


func _set_terminal_state(outcome: String) -> void:
	if round_state != "active":
		return
	round_state = outcome
	_clear_touch_input()
	player.set_combat_enabled(false)
	player.clear_attack_state()
	for enemy: BeltEnemy in enemies:
		if is_instance_valid(enemy):
			enemy.set_simulation_enabled(false)
			enemy.clear_transient_status()
	_clear_transient_attacks()
	_outcome_label.text = (
		"VICTORY\nChoose one reward for the next attempt."
		if outcome == "victory"
		else (
			"DEFEAT\nRetry the same controlled encounter or request Reforge."
			if outcome == "defeat"
			else "REFORGE REQUESTED\nCommitted Forge input remains owned by the parent flow."
		)
	)
	_reward_row.visible = outcome == "victory"
	_outcome_panel.show()
	outcome_changed.emit(outcome)
	_record_event("round_terminal", {"outcome": outcome})


func _clear_transient_attacks() -> void:
	if is_instance_valid(_arena_actors):
		for node: Node in _arena_actors.get_children():
			if not node.is_in_group("belt_transient_attack"):
				continue
			if node.has_method("cancel_attack"):
				node.call("cancel_attack")
			else:
				node.queue_free()
	if is_instance_valid(player):
		player.clear_attack_state()


func _active_enemy_count() -> int:
	var count: int = 0
	for enemy: BeltEnemy in enemies:
		if is_instance_valid(enemy) and not enemy.is_defeated():
			count += 1
	return count


func _record_event(kind: String, detail: Dictionary) -> void:
	_combat_event_sequence += 1
	var event_detail: Dictionary = detail.duplicate(true)
	event_detail["kind"] = kind
	event_detail["sequence"] = _combat_event_sequence
	event_detail["round_state"] = round_state
	_event_log.append(event_detail.duplicate(true))
	if _event_log.size() > 128:
		_event_log.pop_front()
	combat_event.emit(kind, event_detail)


func _build_hud() -> void:
	_hud_layer = CanvasLayer.new()
	_hud_layer.name = "HUD"
	add_child(_hud_layer)
	_hud_root = Control.new()
	_hud_root.name = "HUDRoot"
	_hud_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hud_layer.add_child(_hud_root)

	_title_label = _label("BELT COMBAT SPIKE", 24, TEXT)
	_title_label.name = "Title"
	_hud_root.add_child(_title_label)
	_health_label = _label("", 16, TEXT)
	_health_label.name = "Health"
	_hud_root.add_child(_health_label)
	_role_label = _label("", 13, MUTED)
	_role_label.name = "Role"
	_role_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hud_root.add_child(_role_label)
	_status_label = _label("Move in X/Y. Attacks lightly assist toward the nearest live target.", 14, MUTED)
	_status_label.name = "Status"
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud_root.add_child(_status_label)

	for encounter_id: String in ENCOUNTERS:
		var encounter_button: Button = _button(encounter_id.to_upper(), CYAN, 13)
		encounter_button.name = "Encounter%s" % encounter_id.to_pascal_case()
		encounter_button.pressed.connect(_on_encounter_button_pressed.bind(encounter_id))
		_hud_root.add_child(encounter_button)
		_encounter_buttons[encounter_id] = encounter_button

	var weapon_labels: Dictionary = {
		"melee_slash": "SLASH",
		"straight_projectile": "SHOT",
		"boomerang": "BOOMERANG",
		"area_blast": "BLAST",
		"piercing": "PIERCE",
	}
	for pattern: String in ATTACK_PATTERNS:
		var weapon_button: Button = _button(str(weapon_labels.get(pattern, pattern)), ORANGE, 12)
		weapon_button.name = "Weapon%s" % pattern.to_pascal_case()
		weapon_button.pressed.connect(_on_weapon_button_pressed.bind(pattern))
		_hud_root.add_child(weapon_button)
		_weapon_buttons[pattern] = weapon_button

	_joystick = BeltJoystick.new()
	_joystick.name = "MovementJoystick"
	_joystick.vector_changed.connect(set_touch_move)
	_hud_root.add_child(_joystick)

	_attack_button = _button("ATTACK", ORANGE, 18)
	_attack_button.name = "Attack"
	_attack_button.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	_attack_button.button_down.connect(request_attack)
	_hud_root.add_child(_attack_button)
	_dodge_button = _button("DODGE", CYAN, 14)
	_dodge_button.name = "Dodge"
	# DODGE resolves on a complete press/release gesture. Disabling a Button in
	# the same frame as button_down can swallow the real touch release and leave
	# mobile Godot's internal press pointer latched after the first use.
	_dodge_button.action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
	_dodge_button.pressed.connect(request_dodge)
	_hud_root.add_child(_dodge_button)
	_ward_button = _button("WARD ×1", CYAN, 14)
	_ward_button.name = "Ward"
	_ward_button.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	_ward_button.button_down.connect(request_ward)
	_hud_root.add_child(_ward_button)
	_retry_button = _button("RETRY", CYAN, 14)
	_retry_button.name = "Retry"
	_retry_button.pressed.connect(retry_round)
	_hud_root.add_child(_retry_button)
	_reforge_button = _button("REFORGE", ORANGE, 14)
	_reforge_button.name = "Reforge"
	_reforge_button.pressed.connect(request_reforge)
	_hud_root.add_child(_reforge_button)

	_outcome_panel = PanelContainer.new()
	_outcome_panel.name = "Outcome"
	_outcome_panel.add_theme_stylebox_override("panel", _panel_style(Color("#07111f", 0.94), CYAN, 2))
	_hud_root.add_child(_outcome_panel)
	var outcome_margin: MarginContainer = MarginContainer.new()
	for side: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		outcome_margin.add_theme_constant_override(side, 18)
	_outcome_panel.add_child(outcome_margin)
	var outcome_stack: VBoxContainer = VBoxContainer.new()
	outcome_stack.add_theme_constant_override("separation", 12)
	outcome_margin.add_child(outcome_stack)
	_outcome_label = _label("", 22, TEXT)
	_outcome_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	outcome_stack.add_child(_outcome_label)
	_reward_row = HBoxContainer.new()
	_reward_row.name = "RewardChoices"
	_reward_row.add_theme_constant_override("separation", 10)
	outcome_stack.add_child(_reward_row)
	_ward_reward_button = _button("WARD+  NEXT: 2 CHARGES", CYAN, 12)
	_ward_reward_button.name = "RewardWardPlus"
	_ward_reward_button.custom_minimum_size = Vector2(190.0, 48.0)
	_ward_reward_button.pressed.connect(select_reward.bind("ward_plus"))
	_reward_row.add_child(_ward_reward_button)
	_dodge_reward_button = _button("DODGE+  NEXT: FASTER", CYAN, 12)
	_dodge_reward_button.name = "RewardDodgePlus"
	_dodge_reward_button.custom_minimum_size = Vector2(190.0, 48.0)
	_dodge_reward_button.pressed.connect(select_reward.bind("dodge_plus"))
	_reward_row.add_child(_dodge_reward_button)
	_reward_row.hide()
	_outcome_panel.hide()

	_orientation_prompt = RotationPrompt.new()
	_orientation_prompt.name = "LandscapeRotationPrompt"
	_orientation_prompt.z_index = 500
	_orientation_prompt.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hud_root.add_child(_orientation_prompt)
	_orientation_prompt.hide()
	if not developer_test_mode:
		_title_label.text = "BELT COMBAT"
		for encounter_button_value: Variant in _encounter_buttons.values():
			var encounter_button: Button = encounter_button_value as Button
			if encounter_button != null:
				encounter_button.hide()
		for weapon_button_value: Variant in _weapon_buttons.values():
			var weapon_button: Button = weapon_button_value as Button
			if weapon_button != null:
				weapon_button.hide()


func _clear_touch_input() -> void:
	if is_instance_valid(_joystick):
		_joystick.reset_input()
	if is_instance_valid(player):
		player.set_touch_move(Vector2.ZERO)


func _on_encounter_button_pressed(encounter_id: String) -> void:
	select_encounter(encounter_id)


func _on_weapon_button_pressed(pattern: String) -> void:
	select_weapon(pattern)


func _on_viewport_size_changed() -> void:
	_layout_for_viewport()
	_update_orientation_gate()


func _layout_for_viewport() -> void:
	if not is_instance_valid(_hud_root) or not is_instance_valid(player):
		return
	var viewport_size: Vector2 = get_viewport_rect().size
	var css_size: Vector2 = _effective_css_size(viewport_size)
	_last_layout_css_size = css_size
	player.arena_bounds = _scaled_arena(viewport_size)
	player.clamp_to_arena()
	for enemy: BeltEnemy in enemies:
		if is_instance_valid(enemy):
			enemy.arena_bounds = player.arena_bounds
			enemy.clamp_to_arena()
	if _is_compact_landscape(css_size):
		_layout_compact_landscape(viewport_size, css_size)
	else:
		_layout_regular_landscape(viewport_size)
	queue_redraw()


func _layout_regular_landscape(viewport_size: Vector2) -> void:
	_ward_reward_button.custom_minimum_size = Vector2(190.0, 48.0)
	_dodge_reward_button.custom_minimum_size = Vector2(190.0, 48.0)
	_title_label.position = Vector2(20.0, 14.0)
	_title_label.size = Vector2(300.0, 34.0)
	_health_label.position = Vector2(20.0, 50.0)
	_health_label.size = Vector2(370.0, 28.0)
	_role_label.position = Vector2(20.0, 78.0)
	_role_label.size = Vector2(450.0, 48.0)
	var encounter_x: float = viewport_size.x - 318.0
	if developer_test_mode:
		for index: int in ENCOUNTERS.size():
			var encounter_button: Button = _encounter_buttons[ENCOUNTERS[index]] as Button
			encounter_button.position = Vector2(encounter_x + index * 101.0, 18.0)
			encounter_button.size = Vector2(94.0, 48.0)
	var weapon_start_x: float = maxf((viewport_size.x - 540.0) * 0.5, 360.0)
	if developer_test_mode:
		for index: int in ATTACK_PATTERNS.size():
			var weapon_button: Button = _weapon_buttons[ATTACK_PATTERNS[index]] as Button
			weapon_button.position = Vector2(weapon_start_x + index * 106.0, 76.0)
			weapon_button.size = Vector2(100.0, 44.0)
	_status_label.position = Vector2(250.0, viewport_size.y - 132.0)
	_status_label.size = Vector2(maxf(viewport_size.x - 500.0, 260.0), 32.0)
	var bottom_y: float = viewport_size.y - 92.0
	_joystick.position = Vector2(18.0, viewport_size.y - 130.0)
	_joystick.size = Vector2(112.0, 112.0)
	_attack_button.position = Vector2(viewport_size.x - 170.0, bottom_y - 4.0)
	_attack_button.size = Vector2(150.0, 78.0)
	_dodge_button.position = Vector2(viewport_size.x - 286.0, bottom_y + 8.0)
	_dodge_button.size = Vector2(108.0, 58.0)
	_ward_button.position = Vector2(viewport_size.x - 402.0, bottom_y + 8.0)
	_ward_button.size = Vector2(108.0, 58.0)
	_reforge_button.position = Vector2(viewport_size.x - 500.0, bottom_y + 8.0)
	_reforge_button.size = Vector2(90.0, 58.0)
	_retry_button.position = Vector2(viewport_size.x - 598.0, bottom_y + 8.0)
	_retry_button.size = Vector2(90.0, 58.0)
	_outcome_panel.position = Vector2(
		(viewport_size.x - 500.0) * 0.5,
		(viewport_size.y - 190.0) * 0.5,
	)
	_outcome_panel.size = Vector2(500.0, 190.0)


func _layout_compact_landscape(viewport_size: Vector2, css_size: Vector2) -> void:
	const MARGIN: float = 8.0
	const TOP_BUTTON_HEIGHT: float = 44.0
	var logical_per_css: Vector2 = Vector2(
		viewport_size.x / maxf(css_size.x, 1.0),
		viewport_size.y / maxf(css_size.y, 1.0),
	)
	_ward_reward_button.custom_minimum_size = Vector2(
		190.0 * logical_per_css.x,
		48.0 * logical_per_css.y,
	)
	_dodge_reward_button.custom_minimum_size = Vector2(
		190.0 * logical_per_css.x,
		48.0 * logical_per_css.y,
	)
	_apply_css_rect(_title_label, Rect2(MARGIN, 4.0, 280.0, 28.0), logical_per_css)
	_title_label.add_theme_font_size_override("font_size", 18)
	_apply_css_rect(_health_label, Rect2(MARGIN, 31.0, 345.0, 24.0), logical_per_css)
	_health_label.add_theme_font_size_override("font_size", 13)
	_apply_css_rect(_role_label, Rect2(MARGIN, 54.0, 390.0, 48.0), logical_per_css)
	_role_label.add_theme_font_size_override("font_size", 11)
	var encounter_width: float = minf(88.0, (css_size.x - 420.0) / 3.0 - 4.0)
	var encounter_start_x: float = css_size.x - MARGIN - encounter_width * 3.0 - 8.0
	if developer_test_mode:
		for index: int in ENCOUNTERS.size():
			var encounter_button: Button = _encounter_buttons[ENCOUNTERS[index]] as Button
			_apply_css_rect(
				encounter_button,
				Rect2(
					encounter_start_x + float(index) * (encounter_width + 4.0),
					4.0,
					encounter_width,
					TOP_BUTTON_HEIGHT,
				),
				logical_per_css,
			)
			encounter_button.add_theme_font_size_override("font_size", 11)
	var weapon_width: float = minf(82.0, (css_size.x - 410.0) / 5.0 - 3.2)
	var weapon_start_x: float = css_size.x - MARGIN - weapon_width * 5.0 - 16.0
	if developer_test_mode:
		for index: int in ATTACK_PATTERNS.size():
			var weapon_button: Button = _weapon_buttons[ATTACK_PATTERNS[index]] as Button
			_apply_css_rect(
				weapon_button,
				Rect2(
					weapon_start_x + float(index) * (weapon_width + 4.0),
					54.0,
					weapon_width,
					TOP_BUTTON_HEIGHT,
				),
				logical_per_css,
			)
			weapon_button.add_theme_font_size_override("font_size", 10)
	var controls_y: float = css_size.y - 104.0
	_apply_css_rect(_joystick, Rect2(MARGIN, controls_y, 96.0, 96.0), logical_per_css)
	_apply_css_rect(
		_status_label,
		Rect2(112.0, controls_y + 2.0, maxf(css_size.x - 590.0, 160.0), 42.0),
		logical_per_css,
	)
	_status_label.add_theme_font_size_override("font_size", 11)
	_apply_css_rect(
		_attack_button,
		Rect2(css_size.x - 104.0, controls_y + 12.0, 96.0, 76.0),
		logical_per_css,
	)
	_attack_button.add_theme_font_size_override("font_size", 15)
	_apply_css_rect(
		_dodge_button,
		Rect2(css_size.x - 202.0, controls_y + 24.0, 90.0, 52.0),
		logical_per_css,
	)
	_dodge_button.add_theme_font_size_override("font_size", 11)
	_apply_css_rect(
		_ward_button,
		Rect2(css_size.x - 296.0, controls_y + 24.0, 90.0, 52.0),
		logical_per_css,
	)
	_ward_button.add_theme_font_size_override("font_size", 11)
	_apply_css_rect(
		_reforge_button,
		Rect2(css_size.x - 382.0, controls_y + 24.0, 82.0, 52.0),
		logical_per_css,
	)
	_reforge_button.add_theme_font_size_override("font_size", 10)
	_apply_css_rect(
		_retry_button,
		Rect2(css_size.x - 468.0, controls_y + 24.0, 82.0, 52.0),
		logical_per_css,
	)
	_retry_button.add_theme_font_size_override("font_size", 10)
	var outcome_width: float = minf(css_size.x - 32.0, 460.0)
	_apply_css_rect(
		_outcome_panel,
		Rect2(
			(css_size.x - outcome_width) * 0.5,
			(css_size.y - 150.0) * 0.5,
			outcome_width,
			150.0,
		),
		logical_per_css,
	)


func _update_orientation_gate() -> void:
	if not is_instance_valid(_orientation_prompt):
		return
	var viewport_size: Vector2 = get_viewport_rect().size
	var portrait: bool = _is_portrait(_effective_css_size(viewport_size))
	_orientation_prompt.visible = portrait
	if portrait:
		_clear_touch_input()
		player.set_combat_enabled(false)
		for enemy: BeltEnemy in enemies:
			enemy.set_simulation_enabled(false)
	elif round_state == "active" and player.current_spec != null:
		player.set_combat_enabled(true)
		for enemy: BeltEnemy in enemies:
			if not enemy.is_defeated():
				enemy.set_simulation_enabled(true)
	else:
		player.set_combat_enabled(false)
		for enemy: BeltEnemy in enemies:
			enemy.set_simulation_enabled(false)


func _is_compact_landscape(viewport_size: Vector2) -> bool:
	return viewport_size.x > viewport_size.y and (
		viewport_size.x <= 960.0 or viewport_size.y <= 460.0
	)


func _is_portrait(viewport_size: Vector2) -> bool:
	return viewport_size.y > viewport_size.x


func _refresh_health_hud() -> void:
	if not is_instance_valid(_health_label) or not is_instance_valid(player):
		return
	var enemy_total: int = 0
	var enemy_maximum_total: int = 0
	for enemy: BeltEnemy in enemies:
		if is_instance_valid(enemy):
			enemy_total += enemy.health
			enemy_maximum_total += enemy.maximum_health
	_health_label.text = "YOU %d/%d    ENEMIES %d/%d    %s" % [
		player.health,
		BeltPlayer.MAX_HEALTH,
		enemy_total,
		enemy_maximum_total,
		current_encounter.to_upper(),
	]


func _refresh_ability_hud() -> void:
	if (
		not is_instance_valid(player)
		or not is_instance_valid(_dodge_button)
		or not is_instance_valid(_ward_button)
	):
		return
	var state: Dictionary = player.qa_state()
	var dodge: Dictionary = state.get("dodge", {})
	var ward: Dictionary = state.get("ward", {})
	var dodge_cooldown: float = float(dodge.get("cooldown_remaining", 0.0))
	var ward_charges: int = int(ward.get("charges", 0))
	_dodge_button.text = (
		"DODGE %.1f" % dodge_cooldown
		if dodge_cooldown > 0.05
		else "DODGE"
	)
	_ward_button.text = "WARD ×%d" % ward_charges
	var terminal: bool = round_state != "active" or player.is_dead()
	# Keep cooldown/busy DODGE presses routable so every rejected gesture emits
	# a deterministic blocked outcome. Only terminal state disables the control.
	_dodge_button.disabled = terminal
	_ward_button.disabled = terminal or ward_charges <= 0


func _update_role_hud() -> void:
	if not is_instance_valid(_role_label) or player.current_spec == null:
		return
	var role: WeaponRoleProfile = player.current_role_profile
	_role_label.text = "%s  |  REACH %.0f  |  SPEED %.2f  |  %s" % [
		role.role_id.replace("_", " ").to_upper(),
		player.current_spec.attack_range,
		player.current_spec.attack_speed,
		role.player_weakness_label,
	]


func _update_selected_buttons() -> void:
	for encounter_id: String in _encounter_buttons:
		var encounter_button: Button = _encounter_buttons[encounter_id] as Button
		encounter_button.disabled = encounter_id == current_encounter
	for pattern: String in _weapon_buttons:
		var weapon_button: Button = _weapon_buttons[pattern] as Button
		weapon_button.disabled = pattern == current_pattern


func _install_web_qa_bridge() -> void:
	if not OS.has_feature("web"):
		return
	_web_callback = JavaScriptBridge.create_callback(_on_web_qa_command)
	var browser_window: JavaScriptObject = JavaScriptBridge.get_interface("window")
	browser_window.__forgeGodotBeltCombatCallback = _web_callback
	JavaScriptBridge.eval(
		"""
		window.__forgeBeltCombat = window.__forgeBeltCombat || {
			_state: {},
			_controls: {},
			_update: function(payload) {
				this._state = payload.state || {};
				this._controls = payload.controls || {};
			},
			state: function() { return this._state; },
			controls: function() { return this._controls; },
			command: function(name, payload) {
				if (window.__forgeGodotBeltCombatCallback) {
					window.__forgeGodotBeltCombatCallback(String(name), JSON.stringify(payload || {}));
				}
			}
		};
		""",
		true,
	)


func _on_web_qa_command(arguments: Array) -> void:
	if not is_inside_tree() or arguments.is_empty():
		return
	var command: String = str(arguments[0])
	var payload: Dictionary = {}
	if arguments.size() > 1:
		var parsed: Variant = JSON.parse_string(str(arguments[1]))
		if parsed is Dictionary:
			payload = parsed
	qa_command(command, payload)


func _update_web_qa_state() -> void:
	if (
		not OS.has_feature("web")
		or not is_inside_tree()
		or not is_instance_valid(_hud_root)
	):
		return
	var controls: Dictionary = {
		"attack": _control_css_rect(_attack_button),
		"dodge": _control_css_rect(_dodge_button),
		"ward": _control_css_rect(_ward_button),
		"retry": _control_css_rect(_retry_button),
		"reforge": _control_css_rect(_reforge_button),
		"joystick": _control_css_rect(_joystick),
		"reward_ward_plus": _control_css_rect(_ward_reward_button),
		"reward_dodge_plus": _control_css_rect(_dodge_reward_button),
	}
	var encounter_controls: Dictionary = {}
	for encounter_id: String in _encounter_buttons:
		encounter_controls[encounter_id] = _control_css_rect(_encounter_buttons[encounter_id] as Control)
	controls["encounters"] = encounter_controls
	var weapon_controls: Dictionary = {}
	for pattern: String in _weapon_buttons:
		weapon_controls[pattern] = _control_css_rect(_weapon_buttons[pattern] as Control)
	controls["weapons"] = weapon_controls
	JavaScriptBridge.eval(
		"window.__forgeBeltCombat && window.__forgeBeltCombat._update(%s);" % JSON.stringify({
			"state": qa_state(),
			"controls": controls,
		}),
		true,
	)


func _control_rect(control: Control) -> Dictionary:
	if control == null:
		return {}
	var rect: Rect2 = control.get_global_rect()
	return {
		"x": rect.position.x,
		"y": rect.position.y,
		"width": rect.size.x if control.is_visible_in_tree() else 0.0,
		"height": rect.size.y if control.is_visible_in_tree() else 0.0,
	}


func _control_css_rect(control: Control) -> Dictionary:
	if control == null:
		return {}
	var logical_rect: Rect2 = control.get_global_rect()
	var viewport_size: Vector2 = get_viewport_rect().size
	var css_size: Vector2 = _effective_css_size(viewport_size)
	var css_per_logical: Vector2 = Vector2(
		css_size.x / maxf(viewport_size.x, 1.0),
		css_size.y / maxf(viewport_size.y, 1.0),
	)
	return {
		"x": logical_rect.position.x * css_per_logical.x,
		"y": logical_rect.position.y * css_per_logical.y,
		"width": logical_rect.size.x * css_per_logical.x if control.is_visible_in_tree() else 0.0,
		"height": logical_rect.size.y * css_per_logical.y if control.is_visible_in_tree() else 0.0,
	}


func _layout_qa_state() -> Dictionary:
	var encounter_layout: Dictionary = {}
	for encounter_id: String in _encounter_buttons:
		encounter_layout[encounter_id] = _control_css_rect(_encounter_buttons[encounter_id] as Control)
	var weapon_layout: Dictionary = {}
	for pattern: String in _weapon_buttons:
		weapon_layout[pattern] = _control_css_rect(_weapon_buttons[pattern] as Control)
	return {
		"joystick": _control_css_rect(_joystick),
		"attack": _control_css_rect(_attack_button),
		"dodge": _control_css_rect(_dodge_button),
		"ward": _control_css_rect(_ward_button),
		"retry": _control_css_rect(_retry_button),
		"reforge": _control_css_rect(_reforge_button),
		"status": _control_css_rect(_status_label),
		"outcome": _control_css_rect(_outcome_panel),
		"reward_ward_plus": _control_css_rect(_ward_reward_button),
		"reward_dodge_plus": _control_css_rect(_dodge_reward_button),
		"encounters": encounter_layout,
		"weapons": weapon_layout,
	}


func _arena_scale(viewport_size: Vector2) -> Vector2:
	return Vector2(
		viewport_size.x / 1280.0,
		viewport_size.y / 720.0,
	)


func _scaled_arena(viewport_size: Vector2) -> Rect2:
	var css_size: Vector2 = _effective_css_size(viewport_size)
	if _is_compact_landscape(css_size):
		var controls_y: float = css_size.y - 104.0
		var logical_per_css: Vector2 = Vector2(
			viewport_size.x / maxf(css_size.x, 1.0),
			viewport_size.y / maxf(css_size.y, 1.0),
		)
		var css_rect: Rect2 = Rect2(
			# Keep the actor origin far enough above the arena border that the
			# player's feet and enemy body extents stay inside at Safari's
			# shortest landscape viewport.
			Vector2(56.0, 101.0),
			Vector2(maxf(css_size.x - 112.0, 320.0), maxf(controls_y - 119.0, 120.0)),
		)
		return Rect2(
			css_rect.position * logical_per_css,
			css_rect.size * logical_per_css,
		)
	var scale_value: Vector2 = _arena_scale(viewport_size)
	return Rect2(
		_scaled_point(ARENA_REFERENCE.position, scale_value),
		_scaled_vector(ARENA_REFERENCE.size, scale_value),
	)


func _scaled_point(point: Vector2, scale_value: Vector2) -> Vector2:
	return Vector2(point.x * scale_value.x, point.y * scale_value.y)


func _scaled_vector(vector: Vector2, scale_value: Vector2) -> Vector2:
	return Vector2(vector.x * scale_value.x, vector.y * scale_value.y)


func _apply_css_rect(control: Control, css_rect: Rect2, logical_per_css: Vector2) -> void:
	control.position = css_rect.position * logical_per_css
	control.size = css_rect.size * logical_per_css


func _effective_css_size(viewport_size: Vector2) -> Vector2:
	if _qa_css_size_override != Vector2.ZERO:
		return _qa_css_size_override
	if not OS.has_feature("web"):
		return viewport_size
	var encoded: Variant = JavaScriptBridge.eval(
		"""
		JSON.stringify({
			width: window.visualViewport ? window.visualViewport.width : window.innerWidth,
			height: window.visualViewport ? window.visualViewport.height : window.innerHeight
		})
		""",
		true,
	)
	var parsed: Variant = JSON.parse_string(str(encoded))
	if parsed is Dictionary:
		var width: float = float(parsed.get("width", viewport_size.x))
		var height: float = float(parsed.get("height", viewport_size.y))
		if width > 0.0 and height > 0.0:
			return Vector2(width, height)
	return viewport_size


func _rect_dictionary(rect: Rect2) -> Dictionary:
	return {
		"x": rect.position.x,
		"y": rect.position.y,
		"width": rect.size.x,
		"height": rect.size.y,
	}


func _world_rect_to_css_dictionary(rect: Rect2) -> Dictionary:
	var viewport_size: Vector2 = get_viewport_rect().size
	var css_size: Vector2 = _effective_css_size(viewport_size)
	var css_per_logical: Vector2 = Vector2(
		css_size.x / maxf(viewport_size.x, 1.0),
		css_size.y / maxf(viewport_size.y, 1.0),
	)
	return {
		"x": rect.position.x * css_per_logical.x,
		"y": rect.position.y * css_per_logical.y,
		"width": rect.size.x * css_per_logical.x,
		"height": rect.size.y * css_per_logical.y,
	}


func _label(text_value: String, font_size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _button(text_value: String, accent: Color, font_size: int) -> Button:
	var button: Button = Button.new()
	button.text = text_value
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_color_override("font_color", TEXT)
	button.add_theme_color_override("font_pressed_color", NAVY)
	button.add_theme_color_override("font_disabled_color", TEXT)
	button.add_theme_stylebox_override("normal", _panel_style(PANEL, Color(accent, 0.76), 1))
	button.add_theme_stylebox_override("pressed", _panel_style(accent, accent, 1))
	button.add_theme_stylebox_override("disabled", _panel_style(Color("#24354a"), accent, 2))
	return button


func _panel_style(background: Color, border: Color, width: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(8)
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	return style


func _draw() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, viewport_size), NAVY, true)
	var arena: Rect2 = _scaled_arena(viewport_size)
	draw_rect(arena, Color("#10243a"), true)
	var lane_height: float = arena.size.y / 4.0
	for index: int in 5:
		var y: float = arena.position.y + lane_height * float(index)
		draw_line(
			Vector2(arena.position.x, y),
			Vector2(arena.end.x, y),
			Color("#2b4662", 0.46),
			1.0,
		)
	draw_rect(arena, Color("#35516f"), false, 2.0)
