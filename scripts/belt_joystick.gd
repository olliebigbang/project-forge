class_name BeltJoystick
extends Control

## Continuous, dead-zone filtered eight-direction movement vector.
signal vector_changed(value: Vector2)

@export var dead_zone: float = 0.16

var value: Vector2 = Vector2.ZERO
var _active_touch_index: int = -1
var _mouse_active: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	clip_contents = true
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch_event: InputEventScreenTouch = event
		if touch_event.pressed and _active_touch_index < 0:
			_active_touch_index = touch_event.index
			_update_from_local(touch_event.position)
			accept_event()
		elif touch_event.index == _active_touch_index and (not touch_event.pressed or touch_event.canceled):
			_clear_input()
			accept_event()
		return
	if event is InputEventScreenDrag:
		var drag_event: InputEventScreenDrag = event
		if drag_event.index == _active_touch_index:
			_update_from_local(drag_event.position)
			accept_event()
		return
	if event is InputEventMouseButton:
		var mouse_button: InputEventMouseButton = event
		if mouse_button.button_index != MOUSE_BUTTON_LEFT:
			return
		_mouse_active = mouse_button.pressed
		if _mouse_active:
			_update_from_local(mouse_button.position)
		else:
			_clear_input()
		accept_event()
		return
	if event is InputEventMouseMotion and _mouse_active:
		var mouse_motion: InputEventMouseMotion = event
		_update_from_local(mouse_motion.position)
		accept_event()


func reset_input() -> void:
	_clear_input()


func _notification(what: int) -> void:
	if (
		what == NOTIFICATION_WM_WINDOW_FOCUS_OUT
		or what == NOTIFICATION_EXIT_TREE
		or (what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree())
	):
		_clear_input()


func _update_from_local(local_position: Vector2) -> void:
	var center: Vector2 = size * 0.5
	var radius: float = maxf(minf(size.x, size.y) * 0.5 - 8.0, 1.0)
	var raw: Vector2 = ((local_position - center) / radius).limit_length(1.0)
	var magnitude: float = raw.length()
	if magnitude <= dead_zone:
		_set_value(Vector2.ZERO)
		return
	var remapped_magnitude: float = inverse_lerp(dead_zone, 1.0, magnitude)
	_set_value(raw.normalized() * remapped_magnitude)


func _set_value(next_value: Vector2) -> void:
	next_value = next_value.limit_length(1.0)
	if value.is_equal_approx(next_value):
		return
	value = next_value
	vector_changed.emit(value)
	queue_redraw()


func _clear_input() -> void:
	_active_touch_index = -1
	_mouse_active = false
	_set_value(Vector2.ZERO)


func _draw() -> void:
	var center: Vector2 = size * 0.5
	var radius: float = maxf(minf(size.x, size.y) * 0.5 - 8.0, 1.0)
	draw_circle(center, radius, Color("#0d1b2d", 0.86))
	draw_arc(center, radius, 0.0, TAU, 32, Color("#65d9ff", 0.72), 2.0, true)
	draw_circle(center + value * radius * 0.62, radius * 0.28, Color("#65d9ff", 0.88))
