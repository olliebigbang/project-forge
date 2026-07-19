class_name MobileLayoutPolicy
extends RefCounted

const COMPACT_MAX_CSS_HEIGHT := 430.0
const TARGET_TOUCH_CSS_HEIGHT := 46.0
const MIN_CANVAS_CSS_HEIGHT := 150.0
const CANVAS_HEIGHT_RATIO := 0.44


static func should_use_compact(css_size: Vector2) -> bool:
	return css_size.x > css_size.y and css_size.y < COMPACT_MAX_CSS_HEIGHT


static func compact_metrics(logical_size: Vector2, css_size: Vector2) -> Dictionary:
	var safe_css_width := maxf(css_size.x, 1.0)
	var scale := safe_css_width / maxf(logical_size.x, 1.0)
	var logical_per_css := 1.0 / maxf(scale, 0.01)
	var touch_css := 44.0 if css_size.y < 360.0 else TARGET_TOUCH_CSS_HEIGHT
	return {
		"touch_height": touch_css * logical_per_css,
		"canvas_height": maxf(MIN_CANVAS_CSS_HEIGHT, css_size.y * CANVAS_HEIGHT_RATIO) * logical_per_css,
		"outer_margin": 2.0 * logical_per_css,
		"inner_margin": 0.0,
		"separation": 1.0 * logical_per_css,
		"title_height": touch_css * logical_per_css,
		"back_width": 76.0 * logical_per_css,
		"description_label_width": 96.0 * logical_per_css,
		"reset_width": 86.0 * logical_per_css,
		"load_width": 106.0 * logical_per_css,
		"compile_width": 158.0 * logical_per_css,
		"title_font": roundi(15.0 * logical_per_css),
		"body_font": roundi(14.0 * logical_per_css),
		"input_font": roundi(16.0 * logical_per_css),
		"status_font": roundi(11.0 * logical_per_css),
	}
