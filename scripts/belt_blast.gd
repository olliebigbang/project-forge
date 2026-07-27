class_name BeltBlast
extends Node2D

## Emitted after the one authoritative blast damage sample is complete.
signal hits_complete(blast: BeltBlast, count: int, total_damage: int)
## Emitted once before the visual is queued for deletion.
signal finished(blast: BeltBlast)

const VISUAL_LIFETIME_SECONDS: float = 1.00
const EXPAND_SECONDS: float = 0.24
const FADE_START_SECONDS: float = 0.65
const GROUND_DEPTH_RATIO: float = 0.56

var _spec: WeaponSpec
var _direction: Vector2 = Vector2.RIGHT
var _damage_delay: float = 0.10
var _elapsed: float = 0.0
var _damage_applied: bool = false
var _finished: bool = false


func configure(spec: WeaponSpec, direction: Vector2) -> void:
	_spec = spec
	_direction = direction.normalized() if direction.length_squared() > 0.001 else Vector2.RIGHT
	var role_profile: WeaponRoleProfile = WeaponRoleProfile.derive(spec)
	_damage_delay = role_profile.blast_damage_delay_seconds


func _ready() -> void:
	add_to_group("belt_transient_attack")
	z_index = 4


func _process(delta: float) -> void:
	if _finished or _spec == null:
		return
	_elapsed += delta
	if not _damage_applied and _elapsed >= _damage_delay:
		_damage_applied = true
		_apply_damage()
	queue_redraw()
	if _elapsed >= VISUAL_LIFETIME_SECONDS:
		_finish()


func cancel_attack() -> void:
	if _finished:
		return
	_finished = true
	queue_free()


func qa_state() -> Dictionary:
	var radii: Vector2 = ground_radii()
	return {
		"position": {"x": global_position.x, "y": global_position.y},
		"elapsed": _elapsed,
		"damage_applied": _damage_applied,
		"radius": _spec.area_radius if _spec != null else 0.0,
		"radii": {"x": radii.x, "y": radii.y},
		"shape": "ground_ellipse",
	}


func ground_radii() -> Vector2:
	if _spec == null:
		return Vector2.ZERO
	return Vector2(_spec.area_radius, _spec.area_radius * GROUND_DEPTH_RATIO)


func _apply_damage() -> void:
	var count: int = 0
	var total_damage: int = 0
	var radii: Vector2 = ground_radii()
	for node: Node in get_tree().get_nodes_in_group("belt_enemy"):
		var enemy: BeltEnemy = node as BeltEnemy
		if enemy == null or enemy.is_defeated():
			continue
		var offset: Vector2 = enemy.global_position - global_position
		var normalized_distance_squared: float = (
			offset.x * offset.x / maxf(radii.x * radii.x, 0.001)
			+ offset.y * offset.y / maxf(radii.y * radii.y, 0.001)
		)
		if normalized_distance_squared > 1.0:
			continue
		var actual: int = enemy.take_damage(
			_spec.damage,
			_spec.status_effect,
			"area_blast",
			_direction,
		)
		if actual > 0:
			count += 1
			total_damage += actual
	hits_complete.emit(self, count, total_damage)


func _finish() -> void:
	if _finished:
		return
	_finished = true
	finished.emit(self)
	queue_free()


func _draw() -> void:
	if _spec == null:
		return
	var progress: float = clampf(_elapsed / EXPAND_SECONDS, 0.0, 1.0)
	var visibility: float = 1.0 - clampf(
		(_elapsed - FADE_START_SECONDS)
		/ maxf(VISUAL_LIFETIME_SECONDS - FADE_START_SECONDS, 0.001),
		0.0,
		1.0,
	)
	var color: Color = WeaponVisual._color_for_element(_spec.element)
	var final_radii: Vector2 = ground_radii()
	var radii: Vector2 = Vector2(
		lerpf(18.0, final_radii.x, progress),
		lerpf(10.0, final_radii.y, progress),
	)
	var outer: PackedVector2Array = _ellipse_points(radii, 48)
	var outer_closed: PackedVector2Array = outer.duplicate()
	outer_closed.append(outer[0])
	var inner: PackedVector2Array = _ellipse_points(radii * 0.68, 48)
	inner.append(inner[0])
	draw_colored_polygon(outer, Color(color, 0.10 * visibility))
	draw_polyline(outer_closed, Color(color, 0.9 * visibility), 8.0, true)
	draw_polyline(inner, Color(color, 0.45 * visibility), 4.0, true)


func _ellipse_points(radii: Vector2, point_count: int) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	for index: int in point_count:
		var angle: float = TAU * float(index) / float(point_count)
		points.append(Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	return points
