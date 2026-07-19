class_name ForgeProjectile
extends Area2D

signal hit_target(target_name: String, damage: int)
signal finished(pattern: String)

var _spec: WeaponSpec
var _direction := Vector2.RIGHT
var _distance_travelled := 0.0
var _visual: WeaponVisual
var _player: ForgePlayer
var _returning := false
var _hit_keys: Dictionary = {}
var _hit_count := 0
var _strokes: Array[PackedVector2Array] = []


func configure(spec: WeaponSpec, strokes: Array[PackedVector2Array], direction: Vector2, player: ForgePlayer = null) -> void:
	_spec = spec
	_direction = direction.normalized()
	_player = player
	for stroke in strokes: _strokes.append(stroke.duplicate())


func _ready() -> void:
	collision_layer = 4
	collision_mask = 2
	monitoring = true
	var collider := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 20.0 if _spec.attack_pattern == "boomerang" else 13.0
	collider.shape = shape
	add_child(collider)
	body_entered.connect(_on_body_entered)
	_visual = WeaponVisual.new()
	_visual.scale = Vector2(0.52, 0.52) if _spec.attack_pattern != "piercing" else Vector2(0.68, 0.32)
	_visual.rotation = 0.0 if _direction.x >= 0.0 else PI
	_visual.configure(_strokes, _spec)
	add_child(_visual)
	queue_redraw()


func _physics_process(delta: float) -> void:
	if _spec == null: return
	var speed := _spec.projectile_speed
	if _spec.attack_pattern == "boomerang" and _returning:
		speed = _spec.return_speed
		if is_instance_valid(_player):
			_direction = global_position.direction_to(_player.global_position + Vector2(0, -14))
	var step := _direction * speed * delta
	position += step
	_distance_travelled += step.length()
	rotation += delta * (9.0 if _spec.attack_pattern == "boomerang" else 2.2) * signf(_direction.x)
	if _spec.attack_pattern == "boomerang":
		if not _returning and _distance_travelled >= _spec.attack_range * 0.52:
			_returning = true
			_distance_travelled = 0.0
		if _returning and is_instance_valid(_player) and global_position.distance_to(_player.global_position) < 42.0:
			finished.emit(_spec.attack_pattern)
			queue_free()
	elif _distance_travelled >= _spec.attack_range:
		finished.emit(_spec.attack_pattern)
		queue_free()


func _on_body_entered(body: Node) -> void:
	if not body.has_method("take_damage") or _spec == null: return
	var phase := "return" if _returning else "out"
	var key := "%d:%s" % [body.get_instance_id(), phase]
	if _hit_keys.has(key): return
	_hit_keys[key] = true
	var actual: int = body.take_damage(_spec.damage, _spec.status_effect, _spec.attack_pattern, _direction)
	_hit_count += 1
	hit_target.emit(str(body.get("target_label")), actual)
	if _spec.attack_pattern == "straight_projectile":
		finished.emit(_spec.attack_pattern)
		queue_free()
	elif _spec.attack_pattern == "piercing" and _hit_count >= _spec.pierce_count:
		finished.emit(_spec.attack_pattern)
		queue_free()


func _draw() -> void:
	if _spec == null: return
	var color := WeaponVisual._color_for_element(_spec.element)
	if _spec.attack_pattern == "piercing":
		draw_line(Vector2(-50, 0), Vector2(58, 0), Color(color, 0.28), 18.0, true)
		draw_line(Vector2(-42, 0), Vector2(62, 0), color, 5.0, true)
		draw_colored_polygon(PackedVector2Array([Vector2(62, 0), Vector2(38, -12), Vector2(38, 12)]), color)
	elif _spec.attack_pattern == "boomerang":
		draw_arc(Vector2.ZERO, 30.0, -2.5, 0.8, 20, Color(color, 0.3), 13.0, true)
		draw_arc(Vector2.ZERO, 30.0, -2.5, 0.8, 20, color, 5.0, true)
	else:
		draw_line(Vector2(-36, 0), Vector2(18, 0), Color(color, 0.28), 12.0, true)
		draw_circle(Vector2(18, 0), 8.0, color)
