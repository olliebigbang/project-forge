class_name BeltPlayer
extends CharacterBody2D

## Emitted exactly once when an accepted attack reaches its authoritative commit time.
signal attack_committed(
	spec: WeaponSpec,
	origin: Vector2,
	direction: Vector2,
	target_point: Vector2,
	strokes: Array[PackedVector2Array],
	attack_generation: int,
)
## Emitted whenever bounded player health changes.
signal health_changed(current: int, maximum: int)
## Emitted after non-zero incoming damage is applied.
signal damaged(amount: int, current: int)
## Emitted once when health reaches zero.
signal died
## Emitted when an attack request is accepted, buffered, or rejected.
signal attack_request_resolved(outcome: String)
## Emitted when DODGE is accepted or deterministically rejected.
signal dodge_request_resolved(outcome: String)
## Emitted when WARD is accepted or deterministically rejected.
signal ward_request_resolved(outcome: String)
## Emitted when an incoming strike is resolved by damage, dodge, or ward.
signal incoming_strike_resolved(outcome: String, amount: int)

const MAX_HEALTH: int = 100
const MOVE_SPEED: float = 255.0
const ARENA_SIDE_MARGIN: float = 30.0
const ARENA_HEAD_MARGIN: float = 82.0
const ARENA_FOOT_MARGIN: float = 42.0
const WEAPON_REST_POSITION: Vector2 = Vector2(20.0, -14.0)
const TARGET_ASSIST_DISTANCE: float = 520.0
const TARGET_ASSIST_Y_WEIGHT: float = 1.35
const TARGET_ASSIST_MAX_VERTICAL_RATIO: float = 0.65
const FOOTPRINT_RADIUS: float = 13.0
const FOOTPRINT_OFFSET: Vector2 = Vector2(0.0, 15.0)
const DEFAULT_DODGE_SECONDS: float = 0.22
const DEFAULT_DODGE_INVULNERABLE_SECONDS: float = 0.20
const DEFAULT_DODGE_COOLDOWN_SECONDS: float = 0.90
const DEFAULT_DODGE_SPEED: float = 620.0
const DEFAULT_WARD_SECONDS: float = 0.46

var arena_bounds: Rect2 = Rect2(70.0, 238.0, 1140.0, 380.0)
var health: int = MAX_HEALTH
var combat_enabled: bool = false
var facing: float = 1.0
var current_spec: WeaponSpec
var current_geometry_profile: DrawingGeometryProfile
var current_role_profile: WeaponRoleProfile
var current_strokes: Array[PackedVector2Array] = []
var weapon_visual: WeaponVisual

var _touch_move: Vector2 = Vector2.ZERO
var _target_candidates: Array[BeltEnemy] = []
var _assist_target: BeltEnemy
var _attack_elapsed: float = 0.0
var _attack_cycle: float = 0.0
var _attack_generation: int = 0
var _attack_active: bool = false
var _attack_committed: bool = false
var _attack_buffered: bool = false
var _attack_direction: Vector2 = Vector2.RIGHT
var _attack_target_point: Vector2 = Vector2.ZERO
var _detached_visual: bool = false
var _is_dead: bool = false
var _last_move_direction: Vector2 = Vector2.RIGHT
var _dodge_active: bool = false
var _dodge_remaining: float = 0.0
var _dodge_invulnerable_remaining: float = 0.0
var _dodge_cooldown_remaining: float = 0.0
var _dodge_direction: Vector2 = Vector2.RIGHT
var _dodge_cooldown_seconds: float = DEFAULT_DODGE_COOLDOWN_SECONDS
var _ward_remaining: float = 0.0
var _ward_charges: int = 1
var _configured_ward_charges: int = 1


func _ready() -> void:
	collision_layer = 1
	collision_mask = 8
	var collision_shape: CollisionShape2D = CollisionShape2D.new()
	var footprint_shape: CircleShape2D = CircleShape2D.new()
	footprint_shape.radius = FOOTPRINT_RADIUS
	collision_shape.shape = footprint_shape
	collision_shape.position = FOOTPRINT_OFFSET
	add_child(collision_shape)
	weapon_visual = WeaponVisual.new()
	weapon_visual.name = "HeldWeaponVisual"
	weapon_visual.show_gameplay_markers = false
	weapon_visual.position = WEAPON_REST_POSITION
	weapon_visual.z_index = 2
	add_child(weapon_visual)
	health_changed.emit(health, MAX_HEALTH)
	queue_redraw()


func _physics_process(delta: float) -> void:
	_update_attack_state(delta)
	_update_defensive_state(delta)
	if not combat_enabled or _is_dead:
		velocity = Vector2.ZERO
		_update_weapon_pose()
		return
	_refresh_assist_target()
	var keyboard_move: Vector2 = _keyboard_move_vector()
	var requested_move: Vector2 = (keyboard_move + _touch_move).limit_length(1.0)
	if _dodge_active:
		velocity = _dodge_direction * DEFAULT_DODGE_SPEED
		move_and_slide()
		clamp_to_arena()
		_update_weapon_pose()
		queue_redraw()
		return
	if _movement_locked_during_startup():
		# B1.5 Piercing commits horizontal position during startup only. Belt-depth
		# movement remains available, while _attack_direction stays frozen.
		requested_move.x = 0.0
	velocity = requested_move * MOVE_SPEED
	if requested_move.length_squared() > 0.0025 and not _attack_active:
		_last_move_direction = requested_move.normalized()
		if absf(requested_move.x) > 0.08:
			facing = signf(requested_move.x)
	move_and_slide()
	clamp_to_arena()
	if Input.is_action_just_pressed("attack"):
		request_attack()
	_update_weapon_pose()
	queue_redraw()


func equip_weapon(
	spec: WeaponSpec,
	strokes: Array[PackedVector2Array],
	geometry_profile: DrawingGeometryProfile = null,
) -> void:
	clear_attack_state()
	current_spec = WeaponRouteSnapshot.clone_weapon_spec(spec)
	current_geometry_profile = WeaponRouteSnapshot.clone_geometry_profile(
		geometry_profile,
	)
	current_role_profile = WeaponRoleProfile.derive(
		current_spec,
		current_geometry_profile,
	)
	current_strokes = StrokeFit.duplicate_strokes(strokes)
	weapon_visual.configure(
		current_strokes,
		current_spec,
		current_geometry_profile,
	)
	restore_held_visual()


func clear_weapon() -> void:
	set_combat_enabled(false)
	clear_attack_state()
	current_spec = null
	current_geometry_profile = null
	current_role_profile = null
	current_strokes.clear()
	if is_instance_valid(weapon_visual):
		weapon_visual.hide()


func set_touch_move(value: Vector2) -> void:
	_touch_move = value.limit_length(1.0)


func clamp_to_arena() -> void:
	global_position = Vector2(
		clampf(
			global_position.x,
			arena_bounds.position.x + ARENA_SIDE_MARGIN,
			arena_bounds.end.x - ARENA_SIDE_MARGIN,
		),
		clampf(
			global_position.y,
			arena_bounds.position.y + ARENA_HEAD_MARGIN,
			arena_bounds.end.y - ARENA_FOOT_MARGIN,
		),
	)


func touch_move() -> Vector2:
	return _touch_move


func set_target_candidates(candidates: Array[BeltEnemy]) -> void:
	_target_candidates = candidates.duplicate()
	_refresh_assist_target()


func set_combat_enabled(enabled: bool) -> void:
	combat_enabled = enabled and not _is_dead
	if not combat_enabled:
		_touch_move = Vector2.ZERO
		velocity = Vector2.ZERO
		_attack_buffered = false
		clear_defensive_transients()


func request_attack() -> bool:
	if not combat_enabled or _is_dead:
		attack_request_resolved.emit("blocked_terminal")
		return false
	if _dodge_active or _ward_remaining > 0.0:
		attack_request_resolved.emit("blocked_defending")
		return false
	if current_spec == null:
		attack_request_resolved.emit("blocked_missing_weapon")
		return false
	if _detached_visual:
		attack_request_resolved.emit("blocked_detached_weapon")
		return false
	if _attack_active:
		if _is_held_melee():
			_attack_buffered = true
			attack_request_resolved.emit("buffered")
		else:
			attack_request_resolved.emit("blocked_busy")
		return false
	_start_attack()
	attack_request_resolved.emit("accepted")
	return true


func request_dodge() -> bool:
	if not combat_enabled or _is_dead:
		dodge_request_resolved.emit("blocked_terminal")
		return false
	if _dodge_active or _ward_remaining > 0.0 or _attack_active:
		dodge_request_resolved.emit("blocked_busy")
		return false
	if _dodge_cooldown_remaining > 0.0:
		dodge_request_resolved.emit("blocked_cooldown")
		return false
	var requested_direction: Vector2 = (_keyboard_move_vector() + _touch_move).limit_length(1.0)
	if requested_direction.length_squared() <= 0.0025:
		requested_direction = _last_move_direction
	if requested_direction.length_squared() <= 0.0025:
		requested_direction = Vector2(facing, 0.0)
	_dodge_direction = requested_direction.normalized()
	if absf(_dodge_direction.x) > 0.08:
		facing = signf(_dodge_direction.x)
	_dodge_active = true
	_dodge_remaining = DEFAULT_DODGE_SECONDS
	_dodge_invulnerable_remaining = DEFAULT_DODGE_INVULNERABLE_SECONDS
	_dodge_cooldown_remaining = _dodge_cooldown_seconds
	collision_mask = 0
	dodge_request_resolved.emit("accepted")
	queue_redraw()
	return true


func request_ward() -> bool:
	if not combat_enabled or _is_dead:
		ward_request_resolved.emit("blocked_terminal")
		return false
	if _ward_charges <= 0:
		ward_request_resolved.emit("blocked_no_charges")
		return false
	if _ward_remaining > 0.0 or _dodge_active or _attack_active:
		ward_request_resolved.emit("blocked_busy")
		return false
	_ward_charges -= 1
	_ward_remaining = DEFAULT_WARD_SECONDS
	ward_request_resolved.emit("accepted")
	queue_redraw()
	return true


## Resolves one enemy strike without changing WeaponSpec or creating weapon hits.
func receive_enemy_strike(amount: int) -> String:
	if _is_dead or not combat_enabled or amount <= 0:
		incoming_strike_resolved.emit("blocked_terminal", 0)
		return "blocked_terminal"
	if _ward_remaining > 0.0:
		_ward_remaining = 0.0
		incoming_strike_resolved.emit("warded", 0)
		queue_redraw()
		return "warded"
	if _dodge_invulnerable_remaining > 0.0:
		incoming_strike_resolved.emit("dodged", 0)
		return "dodged"
	var actual: int = take_damage(amount)
	incoming_strike_resolved.emit("damaged", actual)
	return "damaged"


func configure_room_abilities(
	ward_charges_value: int = 1,
	dodge_cooldown_scale: float = 1.0,
) -> void:
	_configured_ward_charges = clampi(ward_charges_value, 1, 2)
	_dodge_cooldown_seconds = (
		DEFAULT_DODGE_COOLDOWN_SECONDS
		* clampf(dodge_cooldown_scale, 0.70, 1.0)
	)


func clear_defensive_transients() -> void:
	_dodge_active = false
	_dodge_remaining = 0.0
	_dodge_invulnerable_remaining = 0.0
	_ward_remaining = 0.0
	collision_mask = 8
	queue_redraw()


func take_damage(amount: int) -> int:
	if _is_dead or not combat_enabled or amount <= 0:
		return 0
	var actual: int = mini(amount, health)
	health -= actual
	damaged.emit(actual, health)
	health_changed.emit(health, MAX_HEALTH)
	if health == 0:
		_is_dead = true
		set_combat_enabled(false)
		clear_attack_state()
		died.emit()
	queue_redraw()
	return actual


func reset_for_round(spawn_position: Vector2) -> void:
	health = MAX_HEALTH
	_is_dead = false
	global_position = spawn_position
	clamp_to_arena()
	facing = 1.0
	clear_attack_state()
	clear_defensive_transients()
	_dodge_cooldown_remaining = 0.0
	_ward_charges = _configured_ward_charges
	_last_move_direction = Vector2.RIGHT
	restore_held_visual()
	health_changed.emit(health, MAX_HEALTH)
	queue_redraw()


func clear_attack_state() -> void:
	_attack_generation += 1
	_attack_active = false
	_attack_committed = false
	_attack_buffered = false
	_attack_elapsed = 0.0
	_attack_cycle = 0.0
	_attack_direction = Vector2(facing, 0.0)
	_attack_target_point = global_position + _attack_direction * TARGET_ASSIST_DISTANCE
	restore_held_visual()


func set_held_detached(detached: bool) -> void:
	_detached_visual = detached
	if is_instance_valid(weapon_visual):
		weapon_visual.visible = not detached


func restore_held_visual() -> void:
	_detached_visual = false
	if not is_instance_valid(weapon_visual):
		return
	if current_spec == null:
		weapon_visual.hide()
		return
	weapon_visual.visible = true
	_apply_weapon_transform(Vector2(facing, 0.0), 0.0)


func attack_origin(projectile_kind: String = "none") -> Vector2:
	if not is_instance_valid(weapon_visual):
		return global_position + Vector2(facing * 28.0, -20.0)
	if projectile_kind == "none":
		return weapon_visual.to_global(Vector2.ZERO)
	# Projectile authority remains independent from the held visual pose. This
	# preserves the previously validated muzzle/arc collision path while the
	# displayed ink rotates toward the frozen 2D attack direction.
	var local_origin: Vector2 = weapon_visual.projectile_spawn_local(projectile_kind)
	var legacy_scale: Vector2 = Vector2(local_origin.x * facing, local_origin.y)
	var legacy_rotation: float = _current_swing_offset() * facing
	return global_position + WEAPON_REST_POSITION + legacy_scale.rotated(legacy_rotation)


func aim_direction() -> Vector2:
	if is_instance_valid(_assist_target):
		var offset: Vector2 = _assist_target.global_position - global_position
		if offset.length_squared() > 0.001:
			var horizontal_sign: float = signf(offset.x)
			if is_zero_approx(horizontal_sign):
				horizontal_sign = facing
			var bounded_offset: Vector2 = Vector2(
				horizontal_sign * maxf(absf(offset.x), 1.0),
				clampf(
					offset.y,
					-absf(offset.x) * TARGET_ASSIST_MAX_VERTICAL_RATIO,
					absf(offset.x) * TARGET_ASSIST_MAX_VERTICAL_RATIO,
				),
			)
			if bounded_offset.length_squared() > 0.001:
				return bounded_offset.normalized()
	return Vector2(facing, 0.0)


func attack_generation() -> int:
	return _attack_generation


func attack_active() -> bool:
	return _attack_active


func attack_elapsed() -> float:
	return _attack_elapsed


func assist_target() -> BeltEnemy:
	return _assist_target


func is_dead() -> bool:
	return _is_dead


func qa_state() -> Dictionary:
	var weapon_forward: Vector2 = Vector2.ZERO
	var weapon_position: Vector2 = Vector2.ZERO
	var weapon_rotation: float = 0.0
	if is_instance_valid(weapon_visual):
		weapon_forward = Vector2.RIGHT.rotated(weapon_visual.rotation)
		weapon_position = weapon_visual.position
		weapon_rotation = weapon_visual.rotation
	return {
		"health": health,
		"max_health": MAX_HEALTH,
		"combat_enabled": combat_enabled,
		"is_dead": _is_dead,
		"position": {"x": global_position.x, "y": global_position.y},
		"movement_bounds": {
			"left": arena_bounds.position.x + ARENA_SIDE_MARGIN,
			"top": arena_bounds.position.y + ARENA_HEAD_MARGIN,
			"right": arena_bounds.end.x - ARENA_SIDE_MARGIN,
			"bottom": arena_bounds.end.y - ARENA_FOOT_MARGIN,
		},
		"velocity": {"x": velocity.x, "y": velocity.y},
		"collision_layer": collision_layer,
		"collision_mask": collision_mask,
		"touch_move": {"x": _touch_move.x, "y": _touch_move.y},
		"facing": facing,
		"attack_active": _attack_active,
		"attack_committed": _attack_committed,
		"attack_buffered": _attack_buffered,
		"attack_elapsed": _attack_elapsed,
		"attack_cycle": _attack_cycle,
		"attack_generation": _attack_generation,
		"attack_direction": {"x": _attack_direction.x, "y": _attack_direction.y},
		"attack_target_point": {
			"x": _attack_target_point.x,
			"y": _attack_target_point.y,
		},
		"movement_locked": _movement_locked_during_startup(),
		"assist_target": _assist_target.enemy_id if is_instance_valid(_assist_target) else "",
		"held_visible": weapon_visual.visible if is_instance_valid(weapon_visual) else false,
		"detached_visual": _detached_visual,
		"dodge": {
			"active": _dodge_active,
			"remaining": _dodge_remaining,
			"invulnerable_remaining": _dodge_invulnerable_remaining,
			"cooldown_remaining": _dodge_cooldown_remaining,
			"cooldown_seconds": _dodge_cooldown_seconds,
			"direction": {"x": _dodge_direction.x, "y": _dodge_direction.y},
		},
		"ward": {
			"active": _ward_remaining > 0.0,
			"remaining": _ward_remaining,
			"charges": _ward_charges,
			"configured_charges": _configured_ward_charges,
		},
		"weapon_visual_forward": {"x": weapon_forward.x, "y": weapon_forward.y},
		"weapon_visual_position": {"x": weapon_position.x, "y": weapon_position.y},
		"weapon_visual_rotation": weapon_rotation,
		"weapon_role": current_role_profile.to_dict() if current_role_profile != null else {},
	}


func _start_attack() -> void:
	_attack_generation += 1
	_attack_active = true
	_attack_committed = false
	_attack_elapsed = 0.0
	_attack_cycle = maxf(current_role_profile.cycle_seconds, 0.001)
	_attack_direction = aim_direction()
	var target_distance: float = TARGET_ASSIST_DISTANCE
	if is_instance_valid(_assist_target):
		target_distance = global_position.distance_to(_assist_target.global_position)
	elif current_spec != null:
		target_distance = current_spec.attack_range
	_attack_target_point = global_position + _attack_direction * maxf(target_distance, 1.0)
	if absf(_attack_direction.x) > 0.08:
		facing = signf(_attack_direction.x)


func _update_defensive_state(delta: float) -> void:
	_dodge_cooldown_remaining = maxf(_dodge_cooldown_remaining - delta, 0.0)
	_dodge_invulnerable_remaining = maxf(
		_dodge_invulnerable_remaining - delta,
		0.0,
	)
	_ward_remaining = maxf(_ward_remaining - delta, 0.0)
	if not _dodge_active:
		return
	_dodge_remaining = maxf(_dodge_remaining - delta, 0.0)
	if _dodge_remaining <= 0.0:
		_dodge_active = false
		_dodge_invulnerable_remaining = 0.0
		collision_mask = 8
		velocity = Vector2.ZERO
		queue_redraw()


func _update_attack_state(delta: float) -> void:
	if not _attack_active or current_spec == null or current_role_profile == null:
		return
	var previous_elapsed: float = _attack_elapsed
	_attack_elapsed = minf(_attack_elapsed + delta, _attack_cycle)
	var commit_time: float = clampf(
		current_role_profile.commit_delay_seconds,
		0.0,
		_attack_cycle,
	)
	if (
		not _attack_committed
		and previous_elapsed < commit_time
		and _attack_elapsed >= commit_time
	):
		_attack_committed = true
		var bundle: Dictionary = WeaponVisualBundle.from_spec(current_spec)
		var projectile_kind: String = str(bundle.get("projectile_kind", "none"))
		attack_committed.emit(
			current_spec,
			attack_origin(projectile_kind),
			_attack_direction,
			_attack_target_point,
			StrokeFit.duplicate_strokes(current_strokes),
			_attack_generation,
		)
	if _attack_elapsed < _attack_cycle:
		return
	_attack_active = false
	_attack_committed = false
	_attack_elapsed = 0.0
	_attack_cycle = 0.0
	restore_held_visual()
	if _attack_buffered and combat_enabled and not _is_dead:
		_attack_buffered = false
		_start_attack()


func _movement_locked_during_startup() -> bool:
	return (
		_attack_active
		and current_role_profile != null
		and current_role_profile.movement_locked_during_startup
		and _attack_elapsed < current_role_profile.startup_seconds
	)


func _refresh_assist_target() -> void:
	var best: BeltEnemy
	var best_score: float = INF
	var forward: Vector2 = Vector2(facing, 0.0)
	for candidate: BeltEnemy in _target_candidates:
		if not is_instance_valid(candidate) or candidate.is_defeated():
			continue
		var offset: Vector2 = candidate.global_position - global_position
		var distance: float = offset.length()
		if distance > TARGET_ASSIST_DISTANCE or distance <= 0.001:
			continue
		var normalized: Vector2 = offset / distance
		if normalized.dot(forward) < 0.05:
			continue
		var score: float = absf(offset.x) + absf(offset.y) * TARGET_ASSIST_Y_WEIGHT
		if (
			score < best_score
			or (
				is_equal_approx(score, best_score)
				and (
					best == null
					or candidate.enemy_id.naturalnocasecmp_to(best.enemy_id) < 0
				)
			)
		):
			best_score = score
			best = candidate
	_assist_target = best


func _keyboard_move_vector() -> Vector2:
	var horizontal: float = Input.get_axis("move_left", "move_right")
	var vertical: float = 0.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		vertical -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		vertical += 1.0
	return Vector2(horizontal, vertical).limit_length(1.0)


func _update_weapon_pose() -> void:
	if not is_instance_valid(weapon_visual) or _detached_visual:
		return
	if not _attack_active or current_role_profile == null:
		_apply_weapon_transform(Vector2(facing, 0.0), 0.0)
		return
	_apply_weapon_transform(_attack_direction, _current_swing_offset())


func _current_swing_offset() -> float:
	if not _attack_active or current_role_profile == null:
		return 0.0
	var startup: float = maxf(current_role_profile.startup_seconds, 0.001)
	var active_end: float = startup + current_role_profile.active_seconds
	if _attack_elapsed < startup:
		return lerpf(0.0, -0.38, _attack_elapsed / startup)
	if _attack_elapsed < active_end:
		var active_progress: float = (
			(_attack_elapsed - startup)
			/ maxf(current_role_profile.active_seconds, 0.001)
		)
		return lerpf(-0.38, 0.44, active_progress)
	var recovery_progress: float = (
		(_attack_elapsed - active_end)
		/ maxf(current_role_profile.recovery_seconds, 0.001)
	)
	return lerpf(0.44, 0.0, recovery_progress)


func _apply_weapon_transform(direction: Vector2, swing_offset: float) -> void:
	var safe_direction: Vector2 = direction.normalized()
	if safe_direction.length_squared() <= 0.001:
		safe_direction = Vector2(facing, 0.0)
	# Player ink is fitted grip-to-tip along local +X. Rotate that one canonical
	# geometry toward the frozen attack vector instead of combining a negative
	# X scale with another directional rotation (which mirrors left attacks twice).
	weapon_visual.position = Vector2(
		WEAPON_REST_POSITION.x * (1.0 if safe_direction.x >= 0.0 else -1.0),
		WEAPON_REST_POSITION.y,
	)
	weapon_visual.rotation = safe_direction.angle() + swing_offset
	weapon_visual.scale = Vector2.ONE


func _is_held_melee() -> bool:
	return (
		current_spec != null
		and current_spec.delivery == "held"
		and current_spec.attack_pattern == "melee_slash"
	)


func _draw() -> void:
	var shadow_scale: float = clampf(
		1.0 - (global_position.y - arena_bounds.position.y) / maxf(arena_bounds.size.y, 1.0) * 0.18,
		0.78,
		1.0,
	)
	draw_ellipse(
		Vector2(0.0, 18.0),
		25.0 * shadow_scale,
		8.0,
		Color("#03070d", 0.34),
	)
	var body_color: Color = Color("#33415f") if _is_dead else Color("#4f7cff")
	draw_circle(Vector2(0.0, -48.0), 17.0, Color("#ffd6a3"))
	draw_rect(Rect2(-18.0, -32.0, 36.0, 52.0), body_color, true)
	draw_line(Vector2(-8.0, 18.0), Vector2(-14.0, 39.0), Color("#dce8ff"), 7.0, true)
	draw_line(Vector2(8.0, 18.0), Vector2(14.0, 39.0), Color("#dce8ff"), 7.0, true)
	draw_rect(Rect2(-28.0, -78.0, 56.0, 6.0), Color("#17243b"), true)
	draw_rect(
		Rect2(-27.0, -77.0, 54.0 * float(health) / float(MAX_HEALTH), 4.0),
		Color("#65d9ff"),
		true,
	)
	if _dodge_active:
		draw_circle(Vector2.ZERO, 34.0, Color("#65d9ff", 0.22))
		draw_line(
			-_dodge_direction * 16.0,
			-_dodge_direction * 58.0,
			Color("#65d9ff", 0.62),
			8.0,
			true,
		)
	if _ward_remaining > 0.0:
		var ward_direction: Vector2 = Vector2(facing, 0.0)
		var ward_angle: float = ward_direction.angle()
		draw_arc(
			ward_direction * 20.0 + Vector2(0.0, -13.0),
			38.0,
			ward_angle - 1.1,
			ward_angle + 1.1,
			20,
			Color("#a9f0ff"),
			8.0,
			true,
		)
