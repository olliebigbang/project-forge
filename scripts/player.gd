class_name ForgePlayer
extends CharacterBody2D

signal attack_requested(spec: WeaponSpec, origin: Vector2, direction: Vector2, strokes: Array[PackedVector2Array])

const MOVE_SPEED := 310.0
const WEAPON_REST_POSITION := Vector2(18.0, -12.0)

var touch_axis := 0.0
var facing := 1.0
var current_spec: WeaponSpec
var current_strokes: Array[PackedVector2Array] = []
var attack_cooldown := 0.0
var combat_enabled := true
var movement_bounds := Vector2(80.0, 1200.0)
var weapon_visual: WeaponVisual
var _attack_tween: Tween
var _detached_visual_count := 0
var _detached_generation := 0
var _diagnostic_label_visible := true


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
	var keyboard_axis := Input.get_axis("move_left", "move_right")
	var axis := clampf(keyboard_axis + touch_axis, -1.0, 1.0)
	velocity = Vector2(axis * MOVE_SPEED, 0.0)
	if absf(axis) > 0.05:
		facing = signf(axis)
	move_and_slide()
	global_position.x = clampf(global_position.x, movement_bounds.x, movement_bounds.y)
	weapon_visual.scale = Vector2(facing, 1.0)
	if combat_enabled and Input.is_action_just_pressed("attack"):
		attack()


func equip(spec: WeaponSpec, strokes: Array[PackedVector2Array]) -> void:
	current_spec = spec
	attack_cooldown = 0.0
	current_strokes.clear()
	for stroke in strokes:
		current_strokes.append(stroke.duplicate())
	weapon_visual.configure(current_strokes, spec)
	restore_held_weapon_now()


func set_touch_axis(value: float) -> void:
	touch_axis = clampf(value, -1.0, 1.0)


func set_combat_enabled(value: bool) -> void:
	combat_enabled = value
	if not combat_enabled:
		set_touch_axis(0.0)


func set_diagnostic_label_visible(value: bool) -> void:
	_diagnostic_label_visible = value
	queue_redraw()


func attack() -> void:
	if not combat_enabled or current_spec == null or attack_cooldown > 0.0:
		return
	var drawback_multiplier: float = {
		"slow_recovery": 1.25, "self_stagger": 1.30, "cooldown_lock": 1.45
	}.get(current_spec.drawback, 1.0)
	attack_cooldown = (1.0 / maxf(current_spec.attack_speed, 0.2)) * float(drawback_multiplier)
	_play_attack_motion()
	var direction := Vector2(facing, 0.0)
	var bundle := WeaponVisualBundle.from_spec(current_spec)
	var projectile_kind := str(bundle.get("projectile_kind", "none"))
	var origin := weapon_visual.projectile_spawn_global(projectile_kind)
	if projectile_kind == "none":
		origin = global_position + Vector2(28.0 * facing, -14.0)
	attack_requested.emit(current_spec, origin, direction, current_strokes)


func _play_attack_motion() -> void:
	if _attack_tween and _attack_tween.is_valid():
		_attack_tween.kill()
	_restore_weapon_pose()
	# Ranged and detached weapons keep an exact rest pose. Their visible attack
	# motion belongs to the projectile, not to a generic sword swing.
	if current_spec != null and (current_spec.delivery != "held" or current_spec.weapon_form == "bow"):
		return
	weapon_visual.rotation = -0.32 * facing
	_attack_tween = create_tween()
	_attack_tween.tween_property(weapon_visual, "rotation", 0.42 * facing, 0.10)
	_attack_tween.tween_property(weapon_visual, "rotation", 0.0, 0.13)
	_attack_tween.tween_callback(_restore_weapon_pose)


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
	_detached_generation += 1
	_detached_visual_count = 0
	if is_instance_valid(weapon_visual):
		weapon_visual.visible = true
		_restore_weapon_pose()


func held_visual_state() -> Dictionary:
	if not is_instance_valid(weapon_visual):
		return {}
	return {
		"visible": weapon_visual.visible,
		"local_position": {"x": weapon_visual.position.x, "y": weapon_visual.position.y},
		"global_position": {"x": weapon_visual.global_position.x, "y": weapon_visual.global_position.y},
		"rest_position": {"x": WEAPON_REST_POSITION.x, "y": WEAPON_REST_POSITION.y},
		"position_drift": weapon_visual.position.distance_to(WEAPON_REST_POSITION),
		"rotation": weapon_visual.rotation,
		"detached_count": _detached_visual_count,
		"cooldown": attack_cooldown,
	}


func _restore_weapon_pose() -> void:
	if not is_instance_valid(weapon_visual):
		return
	weapon_visual.position = WEAPON_REST_POSITION
	weapon_visual.rotation = 0.0
	weapon_visual.scale = Vector2(facing, 1.0)


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
