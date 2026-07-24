class_name ForgePlayer
extends CharacterBody2D

signal attack_requested(spec: WeaponSpec, origin: Vector2, direction: Vector2, strokes: Array[PackedVector2Array])

const MOVE_SPEED := 310.0
const WEAPON_REST_POSITION := Vector2(18.0, -12.0)
const MAX_BUFFERED_ATTACKS := 1

var touch_axis := 0.0
var facing := 1.0
var current_spec: WeaponSpec
var current_strokes: Array[PackedVector2Array] = []
var current_geometry_profile: DrawingGeometryProfile
var current_role_profile: WeaponRoleProfile
var attack_cooldown := 0.0
var combat_enabled := true
var movement_bounds := Vector2(80.0, 1200.0)
var weapon_visual: WeaponVisual
var _attack_tween: Tween
var _attack_generation := 0
var _attack_buffered := false
var _accepted_attack_count := 0
var _melee_attack_facing := 0.0
var _detached_visual_count := 0
var _detached_generation := 0
var _diagnostic_label_visible := true
var _movement_locked := false
var _movement_lock_reason := "none"
var _movement_lock_generation := 0
var _last_attack_movement_locked_during_startup := false


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	var shape := CollisionShape2D.new()
	var body_shape := CapsuleShape2D.new()
	body_shape.radius = 22.0
	body_shape.height = 78.0
	shape.shape = body_shape
	add_child(shape)
	weapon_visual = WeaponVisual.new()
	weapon_visual.show_gameplay_markers = false
	weapon_visual.position = WEAPON_REST_POSITION
	weapon_visual.z_index = 2
	add_child(weapon_visual)
	queue_redraw()


func _physics_process(delta: float) -> void:
	attack_cooldown = maxf(attack_cooldown - delta, 0.0)
	if (
		attack_cooldown <= 0.0
		and _attack_buffered
		and is_zero_approx(_melee_attack_facing)
	):
		_attack_buffered = false
		_start_attack()
	var keyboard_axis := Input.get_axis("move_left", "move_right")
	var axis := clampf(keyboard_axis + touch_axis, -1.0, 1.0)
	if _movement_locked:
		axis = 0.0
	velocity = Vector2(axis * MOVE_SPEED, 0.0)
	if absf(axis) > 0.05 and is_zero_approx(_melee_attack_facing):
		facing = signf(axis)
	move_and_slide()
	global_position.x = clampf(global_position.x, movement_bounds.x, movement_bounds.y)
	weapon_visual.scale = Vector2(_visual_facing(), 1.0)
	if combat_enabled and Input.is_action_just_pressed("attack"):
		attack()


func equip(
	spec: WeaponSpec,
	strokes: Array[PackedVector2Array],
	geometry_profile: DrawingGeometryProfile = null,
) -> void:
	_attack_generation += 1
	current_spec = spec
	current_geometry_profile = geometry_profile
	current_role_profile = WeaponRoleProfile.derive(spec, geometry_profile)
	attack_cooldown = 0.0
	_attack_buffered = false
	current_strokes.clear()
	for stroke in strokes:
		current_strokes.append(stroke.duplicate())
	weapon_visual.configure(current_strokes, spec, current_geometry_profile)
	restore_held_weapon_now()


func set_touch_axis(value: float) -> void:
	touch_axis = clampf(value, -1.0, 1.0)


func set_combat_enabled(value: bool) -> void:
	combat_enabled = value
	if not combat_enabled:
		set_touch_axis(0.0)
		_attack_buffered = false
		_release_movement_lock()


func set_diagnostic_label_visible(value: bool) -> void:
	_diagnostic_label_visible = value
	queue_redraw()


func attack() -> void:
	if not combat_enabled or current_spec == null:
		return
	var role_profile := _active_role_profile()
	if role_profile != null and role_profile.role_id == "boomerang" and _detached_visual_count > 0:
		return
	if attack_cooldown > 0.0 or not is_zero_approx(_melee_attack_facing):
		if _is_held_melee():
			# A boolean is the complete one-slot queue: repeated taps while busy
			# cannot create overlapping hit windows or an unbounded attack burst.
			_attack_buffered = true
		return
	_start_attack()


func _start_attack() -> void:
	if not combat_enabled or current_spec == null or attack_cooldown > 0.0:
		return
	var direction := Vector2(facing, 0.0)
	var cycle_seconds := attack_cycle_seconds()
	attack_cooldown = cycle_seconds
	_accepted_attack_count += 1
	_attack_generation += 1
	var generation := _attack_generation
	_last_attack_movement_locked_during_startup = false
	if current_spec.delivery == "held" and current_spec.attack_pattern == "melee_slash":
		_play_melee_attack_motion(generation, direction)
		return
	_play_role_attack_motion(generation, direction)


func attack_cycle_seconds() -> float:
	if current_spec == null:
		return 0.0
	var role_profile := _active_role_profile()
	return role_profile.cycle_seconds if role_profile != null else 1.0 / maxf(current_spec.attack_speed, 0.2)


func attack_hit_delay_seconds() -> float:
	var role_profile := _active_role_profile()
	return role_profile.commit_delay_seconds if role_profile != null else attack_startup_seconds()


func attack_startup_seconds() -> float:
	var role_profile := _active_role_profile()
	return role_profile.startup_seconds if role_profile != null else attack_cycle_seconds() * 0.25


func attack_active_seconds() -> float:
	var role_profile := _active_role_profile()
	return role_profile.active_seconds if role_profile != null else attack_cycle_seconds() * 0.21


func attack_recovery_seconds() -> float:
	var role_profile := _active_role_profile()
	return role_profile.recovery_seconds if role_profile != null else maxf(attack_cycle_seconds() - attack_startup_seconds() - attack_active_seconds(), 0.0)


func _emit_attack(generation: int, direction: Vector2) -> void:
	_release_movement_lock(generation)
	if generation != _attack_generation or current_spec == null or not combat_enabled:
		return
	var bundle := WeaponVisualBundle.from_spec(current_spec)
	var projectile_kind := str(bundle.get("projectile_kind", "none"))
	var origin := weapon_visual.projectile_spawn_global(projectile_kind)
	if projectile_kind == "none":
		origin = weapon_visual.to_global(Vector2.ZERO)
	attack_requested.emit(current_spec, origin, direction, current_strokes)


func _play_melee_attack_motion(generation: int, direction: Vector2) -> void:
	if _attack_tween and _attack_tween.is_valid():
		_attack_tween.kill()
	_restore_weapon_pose()
	_melee_attack_facing = signf(direction.x)
	weapon_visual.scale = Vector2(_melee_attack_facing, 1.0)
	weapon_visual.rotation = -0.18 * _melee_attack_facing
	_attack_tween = create_tween()
	_attack_tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	var startup := attack_startup_seconds()
	var active := attack_active_seconds()
	var active_before_hit := active * CombatDerived.ACTIVE_HIT_FRACTION
	var active_after_hit := active - active_before_hit
	_attack_tween.tween_property(weapon_visual, "rotation", -0.48 * _melee_attack_facing, startup)
	_attack_tween.tween_property(weapon_visual, "rotation", 0.30 * _melee_attack_facing, active_before_hit)
	_attack_tween.tween_callback(func() -> void: _emit_attack(generation, direction))
	_attack_tween.tween_property(weapon_visual, "rotation", 0.48 * _melee_attack_facing, active_after_hit)
	_attack_tween.tween_property(weapon_visual, "rotation", 0.0, attack_recovery_seconds())
	_attack_tween.tween_callback(_restore_weapon_pose)


func _play_role_attack_motion(generation: int, direction: Vector2) -> void:
	if _attack_tween and _attack_tween.is_valid():
		_attack_tween.kill()
	_restore_weapon_pose()
	var attack_facing := signf(direction.x)
	var role_profile := _active_role_profile()
	if role_profile != null and role_profile.movement_locked_during_startup:
		_movement_locked = true
		_movement_lock_reason = "piercing_startup"
		_movement_lock_generation = generation
		_last_attack_movement_locked_during_startup = true
		velocity.x = 0.0
	_attack_tween = create_tween()
	_attack_tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_attack_tween.tween_property(weapon_visual, "rotation", -0.20 * attack_facing, attack_startup_seconds())
	_attack_tween.tween_callback(func() -> void: _emit_attack(generation, direction))
	_attack_tween.tween_property(weapon_visual, "rotation", 0.10 * attack_facing, attack_active_seconds())
	_attack_tween.tween_property(weapon_visual, "rotation", 0.0, attack_recovery_seconds())
	_attack_tween.tween_callback(func() -> void:
		if generation == _attack_generation:
			_restore_weapon_pose()
	)


func begin_detached_weapon_attack() -> void:
	_detached_visual_count += 1
	_detached_generation += 1
	weapon_visual.visible = false


func complete_detached_weapon_attack() -> void:
	_detached_visual_count = maxi(_detached_visual_count - 1, 0)
	var generation := _detached_generation
	while is_inside_tree() and (_detached_visual_count > 0 or attack_cooldown > 0.0):
		await get_tree().physics_frame
		if generation != _detached_generation:
			return
	if generation == _detached_generation and _detached_visual_count == 0:
		weapon_visual.visible = true
		_restore_weapon_pose()


func restore_held_weapon_now() -> void:
	_attack_generation += 1
	_attack_buffered = false
	if _attack_tween and _attack_tween.is_valid():
		_attack_tween.kill()
	_detached_generation += 1
	_detached_visual_count = 0
	if is_instance_valid(weapon_visual):
		weapon_visual.visible = true
		_restore_weapon_pose()


func held_visual_state() -> Dictionary:
	if not is_instance_valid(weapon_visual):
		return {}
	var bounds := weapon_visual.fitted_bounds()
	return {
		"visible": weapon_visual.visible,
		"local_position": {"x": weapon_visual.position.x, "y": weapon_visual.position.y},
		"global_position": {"x": weapon_visual.global_position.x, "y": weapon_visual.global_position.y},
		"rest_position": {"x": WEAPON_REST_POSITION.x, "y": WEAPON_REST_POSITION.y},
		"position_drift": weapon_visual.position.distance_to(WEAPON_REST_POSITION),
		"rotation": weapon_visual.rotation,
		"detached_count": _detached_visual_count,
		"cooldown": attack_cooldown,
		"attack_buffered": _attack_buffered,
		"max_buffered_attacks": MAX_BUFFERED_ATTACKS,
		"accepted_attack_count": _accepted_attack_count,
		"movement_locked": _movement_locked,
		"movement_lock_reason": _movement_lock_reason,
		"movement_lock_generation": _movement_lock_generation,
		"last_attack_movement_locked_during_startup": _last_attack_movement_locked_during_startup,
		"visible_reach": bounds.position.x + bounds.size.x,
		"fitted_bounds": {
			"x": bounds.position.x,
			"y": bounds.position.y,
			"width": bounds.size.x,
			"height": bounds.size.y,
		},
		"attack_speed": current_spec.attack_speed if current_spec != null else 0.0,
		"attack_cycle_seconds": attack_cycle_seconds(),
		"startup_seconds": attack_startup_seconds(),
		"active_seconds": attack_active_seconds(),
		"hit_delay_seconds": attack_hit_delay_seconds(),
		"recovery_seconds": attack_recovery_seconds(),
		"startup_angular_speed_rad_per_second": 0.30 / maxf(attack_startup_seconds(), 0.001),
		"active_angular_speed_rad_per_second": 0.96 / maxf(attack_active_seconds(), 0.001),
		"facing": facing,
		"attack_facing": _melee_attack_facing,
		"visual_facing": _visual_facing(),
		"geometry_profile": current_geometry_profile.to_dict() if current_geometry_profile != null else {},
		"weapon_role": weapon_role_state(),
	}


func weapon_role_state() -> Dictionary:
	var role_profile := _active_role_profile()
	return role_profile.to_dict() if role_profile != null else {}


func reset_qa_attack_state() -> void:
	restore_held_weapon_now()
	attack_cooldown = 0.0
	_accepted_attack_count = 0
	_last_attack_movement_locked_during_startup = false


func _active_role_profile() -> WeaponRoleProfile:
	if current_role_profile == null and current_spec != null:
		current_role_profile = WeaponRoleProfile.derive(current_spec, current_geometry_profile)
	return current_role_profile


func _restore_weapon_pose() -> void:
	_release_movement_lock()
	if not is_instance_valid(weapon_visual):
		return
	_melee_attack_facing = 0.0
	weapon_visual.position = WEAPON_REST_POSITION
	weapon_visual.rotation = 0.0
	weapon_visual.scale = Vector2(facing, 1.0)


func _release_movement_lock(generation: int = -1) -> bool:
	if generation >= 0 and _movement_lock_generation != generation:
		return false
	var was_locked := _movement_locked
	_movement_locked = false
	_movement_lock_reason = "none"
	_movement_lock_generation = 0
	return was_locked


func _visual_facing() -> float:
	if not is_zero_approx(_melee_attack_facing):
		return _melee_attack_facing
	return facing


func _melee_combat_derived() -> CombatDerived:
	if current_spec == null or current_geometry_profile == null:
		return null
	if current_spec.delivery != "held" or current_spec.attack_pattern != "melee_slash":
		return null
	var timing := current_geometry_profile.combat_derived
	if timing == null or not is_equal_approx(timing.attack_speed, current_spec.attack_speed):
		return null
	return timing


func _is_held_melee() -> bool:
	return (
		current_spec != null
		and current_spec.delivery == "held"
		and current_spec.attack_pattern == "melee_slash"
	)


func _draw() -> void:
	# Deliberately simple M0 placeholder art.
	draw_circle(Vector2(0, -43), 18.0, Color("#ffd6a3"))
	draw_circle(Vector2(-6, -47), 2.5, Color("#172033"))
	draw_circle(Vector2(6, -47), 2.5, Color("#172033"))
	draw_rect(Rect2(-20, -25, 40, 58), Color("#4f7cff"), true)
	draw_line(Vector2(-8, 32), Vector2(-15, 53), Color("#dce8ff"), 8.0, true)
	draw_line(Vector2(8, 32), Vector2(15, 53), Color("#dce8ff"), 8.0, true)
	draw_line(Vector2(-16, -12), Vector2(-32, 6), Color("#ffd6a3"), 7.0, true)
	if _diagnostic_label_visible:
		draw_string(ThemeDB.fallback_font, Vector2(-48, 78), "TEST PILOT", HORIZONTAL_ALIGNMENT_CENTER, 96, 14, Color("#aebed7"))
