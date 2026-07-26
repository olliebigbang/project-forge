class_name TrainingDummy
extends CharacterBody2D

signal health_changed(current: int, maximum: int)
signal defeated
signal damage_report(target_name: String, amount: int, note: String)

var target_kind := "stationary"
var target_label := "STATIONARY"
var max_health := 160
var health := 160
var patrol_width := 90.0
var patrol_speed := 72.0
var _home_x := 0.0
var _patrol_direction := 1.0
var _flash := 0.0
var _status_text := "READY"
var _resetting := false
var _slow_timer := 0.0
var _stagger_timer := 0.0
var _status_epoch := 0
var _feedback_revision := 0
var _diagnostic_labels_visible := true
var _burn_ticks_applied := 0
var last_damage_pattern: String = "none"
var last_damage_direction: Vector2 = Vector2.ZERO


func configure(kind: String, label_text: String, maximum_health: int = 160) -> void:
	target_kind = kind
	target_label = label_text
	max_health = maximum_health
	health = max_health


func _ready() -> void:
	collision_layer = 2
	collision_mask = 0
	add_to_group("test_targets")
	_home_x = global_position.x
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(62, 100) if target_kind != "group" else Vector2(46, 74)
	collider.shape = shape
	collider.position = Vector2(0, -8)
	add_child(collider)
	queue_redraw()


func _physics_process(delta: float) -> void:
	_flash = maxf(_flash - delta, 0.0)
	_slow_timer = maxf(_slow_timer - delta, 0.0)
	_stagger_timer = maxf(_stagger_timer - delta, 0.0)
	if target_kind == "moving" and not _resetting and _stagger_timer <= 0.0:
		var scale_factor := 0.35 if _slow_timer > 0.0 else 1.0
		velocity = Vector2(_patrol_direction * patrol_speed * scale_factor, 0)
		move_and_slide()
		if absf(global_position.x - _home_x) >= patrol_width:
			_patrol_direction *= -1.0
	else:
		velocity = Vector2.ZERO
	queue_redraw()


func take_damage(amount: int, status_effect: String = "none", attack_pattern: String = "melee_slash", hit_direction: Vector2 = Vector2.RIGHT) -> int:
	if _resetting: return 0
	last_damage_pattern = attack_pattern
	last_damage_direction = hit_direction
	var actual := maxi(amount, 1)
	var note := status_effect.to_upper()
	var shield_blocks := target_kind == "shield" and attack_pattern not in ["piercing", "area_blast"]
	if attack_pattern == "boomerang" and hit_direction.x < 0.0: shield_blocks = false
	if shield_blocks:
		actual = maxi(1, int(ceil(actual * 0.2)))
		note = "SHIELD BLOCK"
	if status_effect == "freeze":
		_slow_timer = 1.4
		note += " / SLOWED"
	elif status_effect == "shock":
		_stagger_timer = 0.55
		note += " / STAGGER"
	elif status_effect == "knockback":
		global_position.x += 18.0 * signf(hit_direction.x)
	if status_effect == "burn": _burn_over_time()
	_apply_damage(actual, note)
	damage_report.emit(target_label, actual, note)
	return actual


func _apply_damage(amount: int, note: String) -> void:
	if _resetting: return
	health = maxi(health - amount, 0)
	_flash = 0.16
	_status_text = "-%d  %s" % [amount, note]
	_feedback_revision += 1
	_clear_feedback_after_delay(_feedback_revision)
	health_changed.emit(health, max_health)
	if health == 0:
		_resetting = true
		_status_text = "TARGET DOWN"
		defeated.emit()
		_reset_after_delay()


func _burn_over_time() -> void:
	var burn_epoch := _status_epoch
	for tick in 2:
		await get_tree().create_timer(0.42).timeout
		if not is_instance_valid(self) or _resetting or burn_epoch != _status_epoch: return
		_burn_ticks_applied += 1
		_apply_damage(3, "BURN %d/2" % (tick + 1))


func _reset_after_delay() -> void:
	await get_tree().create_timer(1.25).timeout
	health = max_health
	_resetting = false
	_burn_ticks_applied = 0
	_status_text = "RESET"
	health_changed.emit(health, max_health)


func reset_target() -> void:
	_status_epoch += 1
	_feedback_revision += 1
	health = max_health
	_resetting = false
	_status_text = "READY"
	_slow_timer = 0.0
	_stagger_timer = 0.0
	_burn_ticks_applied = 0
	last_damage_pattern = "none"
	last_damage_direction = Vector2.ZERO
	health_changed.emit(health, max_health)
	queue_redraw()


func clear_transient_status() -> void:
	_status_epoch += 1
	_feedback_revision += 1
	_slow_timer = 0.0
	_stagger_timer = 0.0
	_burn_ticks_applied = 0
	_status_text = "READY"
	queue_redraw()


func qa_state() -> Dictionary:
	return {
		"label": target_label,
		"kind": target_kind,
		"health": health,
		"max_health": max_health,
		"position": {"x": global_position.x, "y": global_position.y},
		"home_x": _home_x,
		"velocity": {"x": velocity.x, "y": velocity.y},
		"slow_timer": _slow_timer,
		"stagger_timer": _stagger_timer,
		"burn_ticks_applied": _burn_ticks_applied,
		"last_damage_pattern": last_damage_pattern,
		"last_damage_direction": {"x": last_damage_direction.x, "y": last_damage_direction.y},
		"visible": visible,
	}


func set_arena_position(arena_position: Vector2) -> void:
	global_position = arena_position
	_home_x = arena_position.x


func set_presentation_active(active: bool, show_diagnostics: bool) -> void:
	visible = active
	_diagnostic_labels_visible = show_diagnostics
	collision_layer = 2 if active else 0
	set_physics_process(active)
	if not active:
		velocity = Vector2.ZERO
	queue_redraw()


func _clear_feedback_after_delay(revision: int) -> void:
	await get_tree().create_timer(0.9).timeout
	if revision == _feedback_revision and not _resetting:
		_status_text = "READY"
		queue_redraw()


func _draw() -> void:
	var base: Color = {
		"stationary": Color("#e4a75f"), "moving": Color("#71d6bc"),
		"shield": Color("#9a8cff"), "group": Color("#ff8fa4")
	}.get(target_kind, Color("#e4a75f"))
	var body_color: Color = Color("#fff4cf") if _flash > 0.0 else base
	var body_size := Vector2(54, 82) if target_kind != "group" else Vector2(38, 62)
	draw_line(Vector2(0, body_size.y * 0.45), Vector2(0, body_size.y * 0.68), Color("#72513e"), 9.0, true)
	draw_rect(Rect2(-body_size.x * 0.5, -body_size.y * 0.55, body_size.x, body_size.y), body_color, true)
	draw_circle(Vector2(0, -body_size.y * 0.78), body_size.x * 0.34, body_color)
	if target_kind == "moving":
		draw_line(Vector2(-30, 54), Vector2(30, 54), Color("#71d6bc"), 4.0, true)
		draw_colored_polygon(PackedVector2Array([Vector2(30, 54), Vector2(20, 48), Vector2(20, 60)]), Color("#71d6bc"))
	if target_kind == "shield":
		draw_arc(Vector2(-34, -5), 38, -1.45, 1.45, 24, Color("#c7beff"), 10.0, true)
		draw_line(Vector2(-34, -40), Vector2(-34, 30), Color("#7868d4"), 3.0, true)
	draw_rect(Rect2(-42, -108, 84, 8), Color("#17243b"), true)
	draw_rect(Rect2(-40, -106, 80.0 * float(health) / max_health, 4), Color("#60e69a"), true)
	if _diagnostic_labels_visible:
		draw_string(
			ThemeDB.fallback_font,
			Vector2(-64, -116),
			"%s  %d/%d" % [target_label, health, max_health],
			HORIZONTAL_ALIGNMENT_CENTER,
			128,
			11,
			Color("#edf4ff"),
		)
	if _diagnostic_labels_visible or _status_text not in ["READY", "RESET"]:
		draw_string(ThemeDB.fallback_font, Vector2(-62, 82), _status_text, HORIZONTAL_ALIGNMENT_CENTER, 124, 11, Color("#edf4ff"))
