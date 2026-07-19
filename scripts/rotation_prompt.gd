class_name RotationPrompt
extends Control

const BACKGROUND := Color("#07101ee8")
const PANEL := Color("#12233b")
const ACCENT := Color("#65d9ff")
const TEXT := Color("#edf4ff")
const MUTED := Color("#b8c8df")
const CJK_FONT: FontFile = preload("res://assets/fonts/NotoSansSC-RotatePrompt.ttf")


static func should_show_for(viewport_size: Vector2) -> bool:
	return viewport_size.y > viewport_size.x


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	resized.connect(queue_redraw)
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BACKGROUND, true)
	var center := size * 0.5
	# Portrait Web viewports expand the logical height while retaining the 1280px
	# logical width. These dimensions keep both messages readable after Safari's
	# CSS down-scaling without exposing any controls beneath the prompt.
	var panel_size := Vector2(minf(size.x - 48.0, 760.0), 560.0)
	var panel_rect := Rect2(center - panel_size * 0.5, panel_size)
	draw_style_box(_panel_style(), panel_rect)

	# A tilted phone outline plus a curved arrow; vector-only so it is reliable in Web builds.
	draw_set_transform(center + Vector2(0, -78), -0.30)
	draw_rect(Rect2(-42, -76, 84, 152), ACCENT, false, 7.0)
	draw_line(Vector2(-17, -62), Vector2(17, -62), ACCENT, 5.0, true)
	draw_circle(Vector2(0, 60), 5.0, ACCENT)
	draw_set_transform(Vector2.ZERO, 0.0)
	draw_arc(center + Vector2(0, -78), 112.0, -0.15, 2.35, 36, ACCENT, 7.0, true)
	var arrow_tip := center + Vector2(-80, -1)
	draw_colored_polygon(PackedVector2Array([
		arrow_tip, arrow_tip + Vector2(7, -28), arrow_tip + Vector2(27, -8),
	]), ACCENT)

	draw_string(CJK_FONT, Vector2(panel_rect.position.x, center.y + 140), "请将手机旋转为横屏", HORIZONTAL_ALIGNMENT_CENTER, panel_rect.size.x, 52, TEXT)
	draw_string(ThemeDB.fallback_font, Vector2(panel_rect.position.x, center.y + 198), "Please rotate your phone to landscape", HORIZONTAL_ALIGNMENT_CENTER, panel_rect.size.x, 38, MUTED)


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL
	style.border_color = ACCENT
	style.set_border_width_all(4)
	style.set_corner_radius_all(18)
	return style
