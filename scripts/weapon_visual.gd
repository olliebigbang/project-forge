class_name WeaponVisual
extends Node2D

const DEFAULT_TARGET_RECT := Rect2(Vector2(2.0, -46.0), Vector2(118.0, 92.0))

var _strokes: Array[PackedVector2Array] = []
var _element := "normal"
var _attack_pattern := "melee_slash"
var _main_color := Color("#f8f2df")
var _configured := false
var fit_target_rect := DEFAULT_TARGET_RECT
var fit_padding := StrokeFit.DEFAULT_PADDING
var show_gameplay_markers := true
var geometry_profile: DrawingGeometryProfile


func configure(
	strokes: Array[PackedVector2Array],
	spec: WeaponSpec,
	profile: DrawingGeometryProfile = null,
) -> void:
	_configured = true
	_strokes.clear()
	for stroke in strokes:
		_strokes.append(stroke.duplicate())
	_element = spec.element
	_attack_pattern = spec.attack_pattern
	_main_color = _color_for_element(_element)
	geometry_profile = profile
	# A null profile is used by detached projectile visuals after they configure
	# their own geometry-centred target rect. Do not overwrite that role-specific
	# fit. Held/review visuals always pass the frozen profile explicitly.
	if profile != null:
		fit_target_rect = profile.held_target_rect(fit_padding) if profile.applies_to(spec) else DEFAULT_TARGET_RECT
	queue_redraw()


func configure_fit(target_rect: Rect2, padding_fraction: float = StrokeFit.DEFAULT_PADDING) -> void:
	fit_target_rect = target_rect
	fit_padding = clampf(padding_fraction, StrokeFit.MIN_PADDING, StrokeFit.MAX_PADDING)
	queue_redraw()


func fitted_strokes() -> Array[PackedVector2Array]:
	return StrokeFit.map_strokes(_strokes, fit_target_rect, fit_padding)


func fitted_bounds() -> Rect2:
	return StrokeFit.actual_bounds(fitted_strokes())


func projectile_spawn_global(projectile_kind: String) -> Vector2:
	return to_global(projectile_spawn_local(projectile_kind))


func projectile_spawn_local(projectile_kind: String) -> Vector2:
	var bounds := fitted_bounds()
	if bounds == Rect2():
		return Vector2(58.0, 0.0)
	var local_origin := bounds.get_center()
	if projectile_kind in ["arrow", "bullet", "energy", "spear"]:
		local_origin.x += bounds.size.x * 0.34 + 8.0
	return local_origin


func _draw() -> void:
	if not _configured:
		return
	var glow := Color(_main_color, 0.22)
	if _strokes.is_empty():
		draw_line(Vector2.ZERO, Vector2(86, -6), glow, 12.0, true)
		draw_line(Vector2.ZERO, Vector2(86, -6), _main_color, 5.0, true)
		draw_circle(Vector2.ZERO, 7.0, Color("#202b3c"))
		return

	var fitted := fitted_strokes()
	for points: PackedVector2Array in fitted:
		if points.size() == 1:
			draw_circle(points[0], 4.0, _main_color)
		elif points.size() > 1:
			draw_polyline(points, glow, 11.0, true)
			draw_polyline(points, _main_color, 4.0, true)

	if not show_gameplay_markers:
		return
	var fitted_bounds_value := StrokeFit.actual_bounds(fitted)
	var tip := Vector2(108.0, 0.0) if fitted_bounds_value == Rect2() else Vector2(fitted_bounds_value.position.x + fitted_bounds_value.size.x, fitted_bounds_value.get_center().y)
	draw_circle(Vector2.ZERO, 8.0, Color("#152238"))
	draw_circle(Vector2.ZERO, 5.0, _main_color)
	if _attack_pattern == "straight_projectile":
		draw_line(tip, tip + Vector2(20, 0), _main_color, 3.0, true)
	elif _attack_pattern == "boomerang":
		draw_arc(tip, 22, -2.4, 0.8, 16, _main_color, 5.0, true)
	elif _attack_pattern == "area_blast":
		draw_circle(tip, 18, Color(_main_color, 0.16))
		draw_arc(tip, 18, 0, TAU, 24, _main_color, 3.0, true)
	elif _attack_pattern == "piercing":
		draw_colored_polygon(PackedVector2Array([tip + Vector2(26, 0), tip + Vector2(0, -10), tip + Vector2(0, 10)]), _main_color)


static func _color_for_element(element: String) -> Color:
	match element:
		"fire": return Color("#ff845e")
		"ice": return Color("#73dcff")
		"electric": return Color("#f5df63")
		_: return Color("#f8f2df")
