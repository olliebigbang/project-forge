class_name ForgeProjectile
extends Area2D

signal hit_target(target_name: String, damage: int)
signal hit_resolved(
	target_name: String,
	hit_index: int,
	damage_multiplier: float,
	base_damage: int,
	requested_damage: int,
	amount: int,
)
signal finished(pattern: String)
signal area_impact(impact_position: Vector2, direction: Vector2, impact_reason: String)

var _spec: WeaponSpec
var _role_profile: WeaponRoleProfile
var _bundle: Dictionary = {}
var _direction := Vector2.RIGHT
var _distance_travelled := 0.0
var _visual: ProjectileVisual
var _player: ForgePlayer
var _returning := false
var _hit_keys: Dictionary = {}
var _hit_count := 0
var _hit_records: Array[Dictionary] = []
var _strokes: Array[PackedVector2Array] = []
var _velocity := Vector2.ZERO
var _elapsed := 0.0
var _detonated := false
var _finish_emitted := false
var _path_samples: Array[Dictionary] = []
var _last_path_sample_elapsed := -1.0
var _landing_surface_y := INF
var _landing_center_y := INF
var _landing_radius := 0.0
var _landed_on_ground := false
var _impact_reason := "none"

const ARC_GRAVITY := 920.0
const ARC_MAX_LIFETIME := 1.5


func configure(
	spec: WeaponSpec,
	strokes: Array[PackedVector2Array],
	direction: Vector2,
	player: ForgePlayer = null,
	bundle: Dictionary = {},
	landing_surface_y: float = INF,
) -> void:
	_spec = spec
	_role_profile = WeaponRoleProfile.derive(spec)
	_bundle = bundle.duplicate(true) if not bundle.is_empty() else WeaponVisualBundle.from_spec(spec)
	_direction = direction.normalized()
	_player = player
	_strokes = StrokeFit.duplicate_strokes(strokes)
	_landing_surface_y = landing_surface_y


func _ready() -> void:
	collision_layer = 4
	collision_mask = 2
	monitoring = true
	var collider := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = _role_profile.projectile_hit_radius
	collider.shape = shape
	add_child(collider)
	body_entered.connect(_on_body_entered)
	_visual = ProjectileVisual.new()
	_visual.name = "ProjectileVisual"
	_visual.configure(_bundle, _spec, _strokes)
	add_child(_visual)
	if _spec.delivery == "thrown" and _spec.trajectory == "arc":
		_landing_radius = _visual.landing_radius()
		if not is_finite(_landing_surface_y):
			_landing_surface_y = global_position.y + 80.0
		_landing_center_y = _landing_surface_y - _landing_radius
		var upward_speed := minf(_spec.projectile_speed * 0.48, 330.0)
		var vertical_distance := maxf(_landing_center_y - global_position.y, 8.0)
		var flight_time := (upward_speed + sqrt(upward_speed * upward_speed + 2.0 * ARC_GRAVITY * vertical_distance)) / ARC_GRAVITY
		var horizontal_distance := clampf(_spec.attack_range * 0.50, 64.0, 180.0)
		var horizontal_speed := horizontal_distance / maxf(flight_time, 0.20)
		_velocity = _direction * horizontal_speed + Vector2.UP * upward_speed
	_apply_facing_rotation()
	_record_path_sample(true)


func _physics_process(delta: float) -> void:
	if _spec == null:
		return
	_elapsed += delta
	if _spec.delivery == "thrown" and _spec.trajectory == "arc":
		_velocity.y += ARC_GRAVITY * delta
		var arc_step := _velocity * delta
		position += arc_step
		_distance_travelled += absf(arc_step.x)
		_apply_rotation(delta)
		_record_path_sample()
		if _velocity.y >= 0.0 and global_position.y >= _landing_center_y:
			global_position.y = _landing_center_y
			_landed_on_ground = true
			_record_path_sample(true)
			_detonate("ground")
		elif _elapsed >= ARC_MAX_LIFETIME:
			# Fail visibly at the declared landing surface rather than exploding in
			# mid-air if an extreme repaired spec produces unexpected timing.
			global_position.y = _landing_center_y
			_landed_on_ground = true
			_record_path_sample(true)
			_detonate("ground")
		return

	var speed := _spec.projectile_speed
	if _spec.attack_pattern == "boomerang" and _returning:
		speed = _spec.return_speed
		if is_instance_valid(_player):
			_direction = global_position.direction_to(_player.global_position + Vector2(0, -14))
	var step := _direction * speed * delta
	_velocity = _direction * speed
	position += step
	_distance_travelled += step.length()
	_apply_rotation(delta)
	_record_path_sample()
	if _spec.attack_pattern == "boomerang":
		if not _returning and _distance_travelled >= _spec.attack_range * 0.52:
			_returning = true
			_distance_travelled = 0.0
		if _returning and is_instance_valid(_player) and global_position.distance_to(_player.global_position) < 42.0:
			_finish_and_free()
	elif _distance_travelled >= _spec.attack_range:
		_finish_and_free()


func _apply_facing_rotation() -> void:
	if str(_bundle.get("projectile_rotation_mode", "none")) == "face_velocity":
		var heading := _velocity if _velocity.length_squared() > 0.001 else _direction
		rotation = heading.angle()


func _apply_rotation(delta: float) -> void:
	match str(_bundle.get("projectile_rotation_mode", "none")):
		"face_velocity": _apply_facing_rotation()
		"tumble": rotation += delta * 3.2 * signf(_direction.x)
		"return_spin": rotation += delta * 9.0 * signf(_direction.x)
		_: rotation = 0.0 if _direction.x >= 0.0 else PI


func _on_body_entered(body: Node) -> void:
	if _finish_emitted or not body.has_method("take_damage") or _spec == null:
		return
	if _spec.delivery == "thrown" and _spec.area_effect == "explosion":
		_detonate("contact")
		return
	var phase := "return" if _returning else "out"
	var key := "%d:%s" % [body.get_instance_id(), phase]
	if _hit_keys.has(key):
		return
	_hit_keys[key] = true
	var hit_index := _hit_count + 1
	var damage_multiplier := _role_profile.damage_multiplier_for_hit(hit_index)
	var requested_damage := _role_profile.damage_for_hit(_spec.damage, hit_index)
	var actual: int = body.take_damage(
		requested_damage,
		_spec.status_effect,
		_spec.attack_pattern,
		_direction,
	)
	if actual <= 0:
		return
	_hit_count += 1
	var hit_record := {
		"target": str(body.get("target_label")),
		"hit_index": hit_index,
		"damage_multiplier": damage_multiplier,
		"base_damage": _spec.damage,
		"requested_damage": requested_damage,
		"amount": actual,
		"damage_rounding_rule": _role_profile.damage_rounding_rule,
	}
	_hit_records.append(hit_record)
	hit_target.emit(str(body.get("target_label")), actual)
	hit_resolved.emit(
		str(body.get("target_label")),
		hit_index,
		damage_multiplier,
		_spec.damage,
		requested_damage,
		actual,
	)
	if _spec.attack_pattern == "straight_projectile":
		_finish_and_free()
	elif _spec.attack_pattern == "piercing" and _hit_count >= _role_profile.body_hit_limit:
		_finish_and_free()


func _detonate(reason: String) -> void:
	if _detonated:
		return
	_detonated = true
	_impact_reason = reason
	area_impact.emit(global_position, _direction, reason)
	_finish_and_free()


func _finish_and_free() -> void:
	if _finish_emitted:
		return
	_finish_emitted = true
	_record_path_sample(true)
	finished.emit(_spec.attack_pattern)
	queue_free()


func qa_visual_state() -> Dictionary:
	var visual_state: Dictionary = _visual.qa_state() if is_instance_valid(_visual) else {}
	var velocity_angle := _velocity.angle() if _velocity.length_squared() > 0.001 else _direction.angle()
	visual_state.merge({
		"instance_id": get_instance_id(),
		"position": {"x": global_position.x, "y": global_position.y},
		"velocity": {"x": _velocity.x, "y": _velocity.y},
		"rotation": rotation,
		"velocity_angle": velocity_angle,
		"heading_error": absf(wrapf(rotation - velocity_angle, -PI, PI)),
		"returning": _returning,
		"elapsed": _elapsed,
		"path_samples": _path_samples.duplicate(true),
		"impact_reason": _impact_reason,
		"landed_on_ground": _landed_on_ground,
		"landing_surface_y": _landing_surface_y,
		"landing_center_y": _landing_center_y,
		"landing_radius": _landing_radius,
		"landing_error": absf(global_position.y - _landing_center_y) if _landed_on_ground else -1.0,
		"hit_count": _hit_count,
		"hit_records": _hit_records.duplicate(true),
		"weapon_role": _role_profile.to_dict() if _role_profile != null else {},
		"role_profile": _role_profile.to_dict() if _role_profile != null else {},
	}, true)
	return visual_state


func _record_path_sample(force: bool = false) -> void:
	if not force and _last_path_sample_elapsed >= 0.0 and _elapsed - _last_path_sample_elapsed < 0.055:
		return
	_last_path_sample_elapsed = _elapsed
	_path_samples.append({
		"time": _elapsed,
		"x": global_position.x,
		"y": global_position.y,
		"rotation": rotation,
	})
