class_name BeltProjectile
extends Node2D

## Emitted for each bounded, successfully applied body hit.
signal hit_resolved(
	projectile: BeltProjectile,
	enemy: BeltEnemy,
	amount: int,
	hit_index: int,
	damage_multiplier: float,
)
## Emitted when thrown + arc delivery reaches contact or its locked ground point.
signal area_impact(projectile: BeltProjectile, impact_position: Vector2, direction: Vector2)
## Emitted exactly once before this projectile is queued for deletion.
signal finished(projectile: BeltProjectile)

const ARC_MIN_SECONDS: float = 0.38
const ARC_MAX_SECONDS: float = 0.92
const ARC_MAX_HEIGHT: float = 92.0
const MAX_LIFETIME_SECONDS: float = 4.0

var _spec: WeaponSpec
var _role_profile: WeaponRoleProfile
var _bundle: Dictionary = {}
var _strokes: Array[PackedVector2Array] = []
var _owner_player: BeltPlayer
var _direction: Vector2 = Vector2.RIGHT
var _start_position: Vector2 = Vector2.ZERO
var _locked_impact_position: Vector2 = Vector2.ZERO
var _distance_travelled: float = 0.0
var _elapsed: float = 0.0
var _arc_duration: float = ARC_MIN_SECONDS
var _returning: bool = false
var _finished: bool = false
var _visual: ProjectileVisual
var _hit_keys: Dictionary = {}
var _hit_count: int = 0
var _path_samples: Array[Dictionary] = []
var _hit_records: Array[Dictionary] = []
var _phase_events: Array[Dictionary] = []
var _last_path_sample_time: float = -1.0


func configure(
	spec: WeaponSpec,
	strokes: Array[PackedVector2Array],
	direction: Vector2,
	owner_player: BeltPlayer,
	impact_position: Vector2,
) -> void:
	_spec = spec
	_role_profile = WeaponRoleProfile.derive(spec)
	_bundle = WeaponVisualBundle.from_spec(spec)
	_strokes = StrokeFit.duplicate_strokes(strokes)
	_direction = direction.normalized() if direction.length_squared() > 0.001 else Vector2.RIGHT
	_owner_player = owner_player
	_locked_impact_position = impact_position


func _ready() -> void:
	add_to_group("belt_transient_attack")
	z_index = 5
	_start_position = global_position
	_visual = ProjectileVisual.new()
	_visual.name = "ProjectileVisual"
	_visual.configure(_bundle, _spec, _strokes)
	add_child(_visual)
	if _is_arc_delivery():
		var travel_distance: float = _start_position.distance_to(_locked_impact_position)
		_arc_duration = clampf(
			travel_distance / maxf(_spec.projectile_speed * 0.55, 1.0),
			ARC_MIN_SECONDS,
			ARC_MAX_SECONDS,
		)
	_update_visual_transform()
	_record_path_sample(true)


func _physics_process(delta: float) -> void:
	if _finished or _spec == null:
		return
	_elapsed += delta
	if _elapsed >= MAX_LIFETIME_SECONDS:
		_finish()
		return
	if _is_arc_delivery():
		_process_arc(delta)
		return
	_process_linear(delta)


func cancel_attack() -> void:
	if _finished:
		return
	_finished = true
	queue_free()


func qa_state() -> Dictionary:
	return {
		"pattern": _spec.attack_pattern if _spec != null else "",
		"position": {"x": global_position.x, "y": global_position.y},
		"direction": {"x": _direction.x, "y": _direction.y},
		"elapsed": _elapsed,
		"distance_travelled": _distance_travelled,
		"returning": _returning,
		"hit_count": _hit_count,
		"path_samples": _path_samples.duplicate(true),
		"hit_records": _hit_records.duplicate(true),
		"phase_events": _phase_events.duplicate(true),
		"uses_player_strokes": bool(_visual.qa_state().get("uses_player_strokes", false)) if is_instance_valid(_visual) else false,
	}


func _process_linear(delta: float) -> void:
	var speed: float = _spec.projectile_speed
	if _spec.attack_pattern == "boomerang" and _returning:
		speed = _spec.return_speed
		if is_instance_valid(_owner_player):
			var return_direction: Vector2 = global_position.direction_to(_owner_player.global_position)
			if return_direction.length_squared() > 0.001:
				_direction = return_direction
	var previous_position: Vector2 = global_position
	var next_position: Vector2 = previous_position + _direction * speed * delta
	_resolve_segment_hits(previous_position, next_position)
	global_position = next_position
	_distance_travelled += previous_position.distance_to(next_position)
	_update_visual_transform(delta)
	_record_path_sample()
	if _spec.attack_pattern == "boomerang":
		if not _returning and _distance_travelled >= _spec.attack_range * 0.52:
			_returning = true
			_distance_travelled = 0.0
			_phase_events.append({"phase": "return", "elapsed": _elapsed})
		elif (
			_returning
			and is_instance_valid(_owner_player)
			and global_position.distance_to(_owner_player.global_position) <= 38.0
		):
			_finish()
	elif _distance_travelled >= _spec.attack_range:
		_finish()


func _process_arc(_delta: float) -> void:
	var previous_position: Vector2 = global_position
	var progress: float = clampf(_elapsed / maxf(_arc_duration, 0.001), 0.0, 1.0)
	global_position = _start_position.lerp(_locked_impact_position, progress)
	var arc_height: float = minf(
		ARC_MAX_HEIGHT,
		maxf(_start_position.distance_to(_locked_impact_position) * 0.30, 44.0),
	)
	if is_instance_valid(_visual):
		_visual.position.y = -sin(progress * PI) * arc_height
	_resolve_arc_contact(previous_position, global_position)
	_update_visual_transform()
	_record_path_sample()
	if not _finished and progress >= 1.0:
		area_impact.emit(self, global_position, _direction)
		_finish()


func _resolve_segment_hits(from: Vector2, to: Vector2) -> void:
	var candidates: Array[Dictionary] = []
	for node: Node in get_tree().get_nodes_in_group("belt_enemy"):
		var enemy: BeltEnemy = node as BeltEnemy
		if enemy == null or enemy.is_defeated():
			continue
		var phase_key: String = "return" if _returning else "out"
		var key: String = "%d:%s" % [enemy.get_instance_id(), phase_key]
		if _hit_keys.has(key):
			continue
		var closest: Vector2 = Geometry2D.get_closest_point_to_segment(
			enemy.global_position,
			from,
			to,
		)
		var hit_distance: float = enemy.global_position.distance_to(closest)
		if hit_distance > enemy.hit_radius() + _role_profile.projectile_hit_radius:
			continue
		var segment_length_squared: float = from.distance_squared_to(to)
		var along: float = 0.0
		if segment_length_squared > 0.001:
			along = clampf((closest - from).dot(to - from) / segment_length_squared, 0.0, 1.0)
		candidates.append({"enemy": enemy, "along": along, "key": key})
	candidates.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			return float(a.get("along", 0.0)) < float(b.get("along", 0.0))
	)
	for candidate: Dictionary in candidates:
		if _finished:
			return
		var enemy: BeltEnemy = candidate.get("enemy") as BeltEnemy
		if enemy == null or enemy.is_defeated():
			continue
		var key: String = str(candidate.get("key", ""))
		_hit_keys[key] = true
		_apply_body_hit(enemy)
		if _spec.attack_pattern == "straight_projectile":
			_finish()
		elif _spec.attack_pattern == "piercing" and _hit_count >= _role_profile.body_hit_limit:
			_finish()


func _resolve_arc_contact(from: Vector2, to: Vector2) -> void:
	if _finished:
		return
	for node: Node in get_tree().get_nodes_in_group("belt_enemy"):
		var enemy: BeltEnemy = node as BeltEnemy
		if enemy == null or enemy.is_defeated():
			continue
		var closest: Vector2 = Geometry2D.get_closest_point_to_segment(
			enemy.global_position,
			from,
			to,
		)
		if enemy.global_position.distance_to(closest) <= enemy.hit_radius() + 18.0:
			global_position = closest
			area_impact.emit(self, global_position, _direction)
			_finish()
			return


func _apply_body_hit(enemy: BeltEnemy) -> void:
	var hit_index: int = _hit_count + 1
	var multiplier: float = _role_profile.damage_multiplier_for_hit(hit_index)
	var requested_damage: int = _role_profile.damage_for_hit(_spec.damage, hit_index)
	var hit_direction: Vector2 = _direction
	var actual: int = enemy.take_damage(
		requested_damage,
		_spec.status_effect,
		_spec.attack_pattern,
		hit_direction,
	)
	if actual <= 0:
		return
	_hit_count += 1
	_hit_records.append({
		"enemy": enemy.enemy_id,
		"amount": actual,
		"hit_index": hit_index,
		"damage_multiplier": multiplier,
		"phase": "return" if _returning else "out",
		"elapsed": _elapsed,
	})
	hit_resolved.emit(self, enemy, actual, hit_index, multiplier)


func _update_visual_transform(delta: float = 0.0) -> void:
	if not is_instance_valid(_visual):
		return
	match str(_bundle.get("projectile_rotation_mode", "none")):
		"face_velocity":
			_visual.rotation = _direction.angle()
		"tumble":
			_visual.rotation += delta * 4.0 * (1.0 if _direction.x >= 0.0 else -1.0)
		"return_spin":
			_visual.rotation += delta * 9.0 * (1.0 if _direction.x >= 0.0 else -1.0)
		_:
			_visual.rotation = 0.0


func _is_arc_delivery() -> bool:
	return (
		_spec != null
		and _spec.delivery == "thrown"
		and _spec.trajectory == "arc"
		and _spec.area_effect == "explosion"
	)


func _record_path_sample(force: bool = false) -> void:
	if not force and _last_path_sample_time >= 0.0 and _elapsed - _last_path_sample_time < 0.05:
		return
	_last_path_sample_time = _elapsed
	_path_samples.append({
		"elapsed": _elapsed,
		"x": global_position.x,
		"y": global_position.y,
		"visual_y": _visual.position.y if is_instance_valid(_visual) else 0.0,
		"returning": _returning,
	})
	if _path_samples.size() > 48:
		_path_samples.pop_front()


func _finish() -> void:
	if _finished:
		return
	_finished = true
	_record_path_sample(true)
	finished.emit(self)
	queue_free()
