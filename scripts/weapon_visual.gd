class_name WeaponVisual
extends Node2D

var _strokes: Array[PackedVector2Array] = []
var _element := "normal"
var _attack_pattern := "melee_slash"
var _main_color := Color("#f8f2df")
var _configured := false


func configure(strokes: Array[PackedVector2Array], spec: WeaponSpec) -> void:
	_configured = true
	_strokes.clear()
	for stroke in strokes:
		_strokes.append(stroke.duplicate())
	_element = spec.element
	_attack_pattern = spec.attack_pattern
	_main_color = _color_for_element(_element)
	queue_redraw()


func _draw() -> void:
	if not _configured:
		return
	var glow := Color(_main_color, 0.22)
	if _strokes.is_empty():
		draw_line(Vector2.ZERO, Vector2(86, -6), glow, 12.0, true)
		draw_line(Vector2.ZERO, Vector2(86, -6), _main_color, 5.0, true)
		draw_circle(Vector2.ZERO, 7.0, Color("#202b3c"))
		return

	for stroke in _strokes:
		var points := PackedVector2Array()
		for normalized_point in stroke:
			var mapped := Vector2(
				lerpf(2.0, 108.0, normalized_point.x),
				lerpf(-42.0, 42.0, normalized_point.y)
			)
			points.append(mapped)
		if points.size() == 1:
			draw_circle(points[0], 4.0, _main_color)
		elif points.size() > 1:
			draw_polyline(points, glow, 11.0, true)
			draw_polyline(points, _main_color, 4.0, true)

	draw_circle(Vector2.ZERO, 8.0, Color("#152238"))
	draw_circle(Vector2.ZERO, 5.0, _main_color)
	if _attack_pattern == "straight_projectile":
		draw_line(Vector2(102, 0), Vector2(122, 0), _main_color, 3.0, true)
	elif _attack_pattern == "boomerang":
		draw_arc(Vector2(92, 0), 22, -2.4, 0.8, 16, _main_color, 5.0, true)
	elif _attack_pattern == "area_blast":
		draw_circle(Vector2(94, 0), 18, Color(_main_color, 0.16))
		draw_arc(Vector2(94, 0), 18, 0, TAU, 24, _main_color, 3.0, true)
	elif _attack_pattern == "piercing":
		draw_colored_polygon(PackedVector2Array([Vector2(128, 0), Vector2(102, -10), Vector2(102, 10)]), _main_color)


static func _color_for_element(element: String) -> Color:
	match element:
		"fire": return Color("#ff845e")
		"ice": return Color("#73dcff")
		"electric": return Color("#f5df63")
		_: return Color("#f8f2df")
