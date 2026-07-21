class_name DrawingCanvas
extends Control

signal drawing_changed

const BACKGROUND := Color("#0c192a")
const GRID := Color("#172b43")
const INK := Color("#f8f2df")
const ACCENT := Color("#65d9ff")

var strokes: Array[PackedVector2Array] = []
var _drawing := false
var _active_pointer := -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	focus_mode = Control.FOCUS_NONE
	resized.connect(queue_redraw)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if not Rect2(Vector2.ZERO, size).has_point(event.position):
				return
			_begin_stroke(event.position, -1)
		else:
			_end_stroke(-1)
		accept_event()
	elif event is InputEventMouseMotion and _drawing and _active_pointer == -1:
		_add_point(event.position)
		accept_event()
	elif event is InputEventScreenTouch:
		if event.pressed:
			if not Rect2(Vector2.ZERO, size).has_point(event.position):
				return
			_begin_stroke(event.position, event.index)
		else:
			_end_stroke(event.index)
		accept_event()
	elif event is InputEventScreenDrag and _drawing and event.index == _active_pointer:
		_add_point(event.position)
		accept_event()


func clear_drawing() -> void:
	strokes.clear()
	_drawing = false
	_active_pointer = -1
	queue_redraw()
	drawing_changed.emit()


func is_empty() -> bool:
	return strokes.is_empty()


func get_normalized_strokes() -> Array[PackedVector2Array]:
	return StrokeFit.normalize_preserving_aspect(strokes)


func get_strokes_snapshot() -> Array[PackedVector2Array]:
	return StrokeFit.duplicate_strokes(strokes)


func drawing_summary() -> Dictionary:
	return summarize_strokes(strokes, size)


static func summarize_strokes(source: Array[PackedVector2Array], canvas_size: Vector2) -> Dictionary:
	var point_count := 0
	var minimum := Vector2(INF, INF)
	var maximum := Vector2(-INF, -INF)
	for stroke in source:
		for point in stroke:
			point_count += 1
			minimum = minimum.min(point)
			maximum = maximum.max(point)
	if point_count == 0:
		return {"stroke_count": 0, "point_count": 0, "aspect_ratio": 1.0, "coverage": 0.0}
	var bounds := maximum - minimum
	var safe_height := maxf(bounds.y, 1.0)
	var canvas_area := maxf(canvas_size.x * canvas_size.y, 1.0)
	return {
		"stroke_count": source.size(),
		"point_count": point_count,
		"aspect_ratio": bounds.x / safe_height,
		"coverage": (bounds.x * bounds.y) / canvas_area,
	}


func _begin_stroke(position: Vector2, pointer: int) -> void:
	if _drawing:
		return
	_drawing = true
	_active_pointer = pointer
	strokes.append(PackedVector2Array([_clamp_point(position)]))
	queue_redraw()


func _add_point(position: Vector2) -> void:
	if strokes.is_empty():
		return
	var stroke := strokes[-1]
	var point := _clamp_point(position)
	if stroke.is_empty() or stroke[-1].distance_to(point) >= 3.0:
		stroke.append(point)
		strokes[-1] = stroke
		queue_redraw()


func _end_stroke(pointer: int) -> void:
	if not _drawing or pointer != _active_pointer:
		return
	_drawing = false
	_active_pointer = -1
	drawing_changed.emit()
	queue_redraw()


func _clamp_point(point: Vector2) -> Vector2:
	return Vector2(clampf(point.x, 0.0, size.x), clampf(point.y, 0.0, size.y))


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BACKGROUND, true)
	for x in range(0, int(size.x) + 1, 64):
		draw_line(Vector2(x, 0), Vector2(x, size.y), GRID, 1.0)
	for y in range(0, int(size.y) + 1, 64):
		draw_line(Vector2(0, y), Vector2(size.x, y), GRID, 1.0)
	draw_rect(Rect2(Vector2.ONE, size - Vector2(2, 2)), Color("#2c4864"), false, 2.0)
	for stroke in strokes:
		if stroke.size() == 1:
			draw_circle(stroke[0], 5.0, INK)
		elif stroke.size() > 1:
			draw_polyline(stroke, Color(ACCENT, 0.18), 11.0, true)
			draw_polyline(stroke, INK, 5.0, true)
	if strokes.is_empty():
		var font := ThemeDB.fallback_font
		draw_string(font, Vector2(22, 36), "DRAW YOUR WEAPON", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("#7189a5"))
