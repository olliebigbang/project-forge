class_name ForgePlayer
extends CharacterBody2D

signal attack_requested(spec: WeaponSpec, origin: Vector2, direction: Vector2, strokes: Array[PackedVector2Array])

const MOVE_SPEED := 310.0

var touch_axis := 0.0
var facing := 1.0
var current_spec: WeaponSpec
var current_strokes: Array[PackedVector2Array] = []
var attack_cooldown := 0.0
var combat_enabled := true
var movement_bounds := Vector2(80.0, 1200.0)
var weapon_visual: WeaponVisual
var _attack_tween: Tween


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
	weapon_visual.position = Vector2(18, -12)
	weapon_visual.z_index = 2
	add_child(weapon_visual)
	queue_redraw()


func _physics_process(delta: float) -> void:
	attack_cooldown = maxf(attack_cooldown - delta, 0.0)
	var keyboard_axis := Input.get_axis("move_left", "move_right")
	var axis := clampf(keyboard_axis + touch_axis, -1.0, 1.0)
	velocity = Vector2(axis * MOVE_SPEED, 0.0)
	if absf(axis) > 0.05:
		facing = signf(axis)
	move_and_slide()
	global_position.x = clampf(global_position.x, movement_bounds.x, movement_bounds.y)
	weapon_visual.scale.x = facing
	if combat_enabled and Input.is_action_just_pressed("attack"):
		attack()


func equip(spec: WeaponSpec, strokes: Array[PackedVector2Array]) -> void:
	current_spec = spec
	attack_cooldown = 0.0
	current_strokes.clear()
	for stroke in strokes:
		current_strokes.append(stroke.duplicate())
	weapon_visual.configure(current_strokes, spec)


func set_touch_axis(value: float) -> void:
	touch_axis = clampf(value, -1.0, 1.0)


func set_combat_enabled(value: bool) -> void:
	combat_enabled = value
	if not combat_enabled:
		set_touch_axis(0.0)


func attack() -> void:
	if not combat_enabled or current_spec == null or attack_cooldown > 0.0:
		return
	var drawback_multiplier: float = {
		"slow_recovery": 1.25, "self_stagger": 1.30, "cooldown_lock": 1.45
	}.get(current_spec.drawback, 1.0)
	attack_cooldown = (1.0 / maxf(current_spec.attack_speed, 0.2)) * float(drawback_multiplier)
	_play_attack_motion()
	var direction := Vector2(facing, 0.0)
	attack_requested.emit(current_spec, global_position + Vector2(28.0 * facing, -14.0), direction, current_strokes)


func _play_attack_motion() -> void:
	if _attack_tween and _attack_tween.is_valid():
		_attack_tween.kill()
	weapon_visual.rotation = -0.32 * facing
	_attack_tween = create_tween()
	_attack_tween.tween_property(weapon_visual, "rotation", 0.42 * facing, 0.10)
	_attack_tween.tween_property(weapon_visual, "rotation", 0.0, 0.13)


func _draw() -> void:
	# Deliberately simple M0 placeholder art.
	draw_circle(Vector2(0, -43), 18.0, Color("#ffd6a3"))
	draw_circle(Vector2(-6, -47), 2.5, Color("#172033"))
	draw_circle(Vector2(6, -47), 2.5, Color("#172033"))
	draw_rect(Rect2(-20, -25, 40, 58), Color("#4f7cff"), true)
	draw_line(Vector2(-8, 32), Vector2(-15, 53), Color("#dce8ff"), 8.0, true)
	draw_line(Vector2(8, 32), Vector2(15, 53), Color("#dce8ff"), 8.0, true)
	draw_line(Vector2(-16, -12), Vector2(-32, 6), Color("#ffd6a3"), 7.0, true)
	draw_string(ThemeDB.fallback_font, Vector2(-48, 78), "TEST PILOT", HORIZONTAL_ALIGNMENT_CENTER, 96, 14, Color("#aebed7"))
