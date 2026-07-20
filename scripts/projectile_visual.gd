class_name ProjectileVisual
extends Node2D

var _bundle: Dictionary = {}
var _spec: WeaponSpec
var _strokes: Array[PackedVector2Array] = []
var _stroke_visual: WeaponVisual


func configure(bundle: Dictionary, spec: WeaponSpec, strokes: Array[PackedVector2Array]) -> void:
	_bundle = bundle.duplicate(true)
	_spec = spec
	_strokes = StrokeFit.duplicate_strokes(strokes)
	if str(_bundle.get("projectile_source", "none")) == "player_strokes":
		_stroke_visual = WeaponVisual.new()
		_stroke_visual.name = "DetachedPlayerStrokeVisual"
		_stroke_visual.show_gameplay_markers = false
		_stroke_visual.configure_fit(_drawing_target_rect())
		_stroke_visual.configure(_strokes, spec)
		add_child(_stroke_visual)
	queue_redraw()


func qa_state() -> Dictionary:
	var source_aspect := StrokeFit.aspect_ratio(_strokes)
	var rendered_aspect := source_aspect
	var rendered_bounds := Rect2()
	var pivot_error := 0.0
	if is_instance_valid(_stroke_visual):
		var fitted := _stroke_visual.fitted_strokes()
		rendered_aspect = StrokeFit.aspect_ratio(fitted)
		rendered_bounds = StrokeFit.actual_bounds(fitted)
		pivot_error = rendered_bounds.get_center().length()
	return {
		"kind": str(_bundle.get("projectile_kind", "none")),
		"source": str(_bundle.get("projectile_source", "none")),
		"pivot_mode": str(_bundle.get("projectile_pivot", "geometry_center")),
		"rotation_mode": str(_bundle.get("projectile_rotation_mode", "none")),
		"uses_player_strokes": is_instance_valid(_stroke_visual),
		"source_aspect": source_aspect,
		"rendered_aspect": rendered_aspect,
		"relative_aspect_error": absf(rendered_aspect / maxf(source_aspect, 0.001) - 1.0) if is_instance_valid(_stroke_visual) else 0.0,
		"rendered_bounds_center": {"x": rendered_bounds.get_center().x, "y": rendered_bounds.get_center().y},
		"pivot_error": pivot_error,
	}


func fitted_strokes() -> Array[PackedVector2Array]:
	return _stroke_visual.fitted_strokes() if is_instance_valid(_stroke_visual) else []


func landing_radius() -> float:
	# A rotating drawn projectile lands when every possible orientation remains
	# above the floor. Measuring from the geometry-centred pivot prevents a
	# grenade from sinking into the floor or orbiting an external anchor.
	var radius := 0.0
	for stroke: PackedVector2Array in fitted_strokes():
		for point: Vector2 in stroke:
			radius = maxf(radius, point.length())
	return maxf(radius, 22.0)


func _drawing_target_rect() -> Rect2:
	match str(_bundle.get("projectile_kind", "none")):
		"grenade": return Rect2(Vector2(-34.0, -34.0), Vector2(68.0, 68.0))
		"boomerang": return Rect2(Vector2(-42.0, -34.0), Vector2(84.0, 68.0))
		_: return Rect2(Vector2(-38.0, -28.0), Vector2(76.0, 56.0))


func _draw() -> void:
	if _spec == null or str(_bundle.get("projectile_source", "none")) == "player_strokes":
		return
	var color := WeaponVisual._color_for_element(_spec.element)
	match str(_bundle.get("projectile_kind", "none")):
		"arrow":
			draw_line(Vector2(-34, 0), Vector2(27, 0), Color(color, 0.28), 8.0, true)
			draw_line(Vector2(-34, 0), Vector2(27, 0), color, 3.0, true)
			draw_colored_polygon(PackedVector2Array([Vector2(38, 0), Vector2(24, -8), Vector2(24, 8)]), color)
			draw_line(Vector2(-29, 0), Vector2(-39, -8), color, 3.0, true)
			draw_line(Vector2(-29, 0), Vector2(-39, 8), color, 3.0, true)
		"bullet":
			draw_line(Vector2(-19, 0), Vector2(14, 0), Color(color, 0.3), 13.0, true)
			draw_line(Vector2(-17, 0), Vector2(15, 0), color, 7.0, true)
			draw_colored_polygon(PackedVector2Array([Vector2(24, 0), Vector2(12, -6), Vector2(12, 6)]), color)
		"energy":
			draw_circle(Vector2.ZERO, 15.0, Color(color, 0.22))
			draw_circle(Vector2.ZERO, 9.0, color)
			draw_line(Vector2(-32, 0), Vector2(-13, 0), Color(color, 0.35), 8.0, true)
		"spear":
			draw_line(Vector2(-48, 0), Vector2(40, 0), Color(color, 0.25), 12.0, true)
			draw_line(Vector2(-48, 0), Vector2(42, 0), color, 4.0, true)
			draw_colored_polygon(PackedVector2Array([Vector2(58, 0), Vector2(36, -10), Vector2(36, 10)]), color)
