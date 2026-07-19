class_name ForgeProjectile
extends Area2D

signal hit_target

var _spec: WeaponSpec
var _direction := Vector2.RIGHT
var _speed := 590.0
var _distance_travelled := 0.0
var _visual: WeaponVisual


func _ready() -> void:
	collision_layer = 4
	collision_mask = 2
	monitoring = true
	var collider := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 18.0
	collider.shape = shape
	add_child(collider)
	body_entered.connect(_on_body_entered)
	_visual = WeaponVisual.new()
	_visual.scale = Vector2(0.52, 0.52)
	_visual.rotation = 0.0 if _direction.x >= 0.0 else PI
	add_child(_visual)
	if _spec:
		_visual.configure(get_meta("forge_strokes", []), _spec)


func configure(spec: WeaponSpec, strokes: Array[PackedVector2Array], direction: Vector2) -> void:
	_spec = spec
	_direction = direction.normalized()
	set_meta("forge_strokes", strokes)


func _physics_process(delta: float) -> void:
	var step := _direction * _speed * delta
	position += step
	_distance_travelled += step.length()
	rotation += delta * 2.8 * _direction.x
	if _distance_travelled >= _spec.attack_range:
		queue_free()


func _on_body_entered(body: Node) -> void:
	if body.has_method("take_damage"):
		body.take_damage(_spec.damage, _spec.status_effect)
		hit_target.emit()
		queue_free()

