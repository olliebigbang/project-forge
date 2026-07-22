class_name DrawingGeometryProfile
extends RefCounted

# TO VALIDATE: these bounded prototype anchors and tier thresholds require
# physical-device combat feel testing before they become production balance.
const MIN_EFFECTIVE_REACH := 72.0
const NOMINAL_EFFECTIVE_REACH := 132.0
const MAX_EFFECTIVE_REACH := 228.0
const CURVE_START_SPAN := 0.18
const CURVE_END_SPAN := 0.92
const SHORT_MAX_REACH := 104.0
const STANDARD_MAX_REACH := 160.0
const LONG_MAX_REACH := 202.0
const MAX_HELD_CROSS_AXIS := 104.0
const RANGE_SPEED_EXCHANGE := 450.0

var source_bounds := Rect2()
var canvas_size := Vector2.ONE
var normalized_length := 0.0
var normalized_height := 0.0
var ink_aspect := 1.0
var reach_profile := "short"
var effective_reach := MIN_EFFECTIVE_REACH


static func from_snapshot(source: Array[PackedVector2Array], frozen_canvas_size: Vector2) -> DrawingGeometryProfile:
	var profile := DrawingGeometryProfile.new()
	profile.source_bounds = StrokeFit.actual_bounds(source)
	profile.canvas_size = Vector2(maxf(frozen_canvas_size.x, 1.0), maxf(frozen_canvas_size.y, 1.0))
	profile.normalized_length = clampf(profile.source_bounds.size.x / profile.canvas_size.x, 0.0, 1.0)
	profile.normalized_height = clampf(profile.source_bounds.size.y / profile.canvas_size.y, 0.0, 1.0)
	profile.ink_aspect = profile.source_bounds.size.x / maxf(profile.source_bounds.size.y, 1.0)
	var curve_t := clampf(
		(profile.normalized_length - CURVE_START_SPAN) / (CURVE_END_SPAN - CURVE_START_SPAN),
		0.0,
		1.0,
	)
	var span_reach := lerpf(MIN_EFFECTIVE_REACH, MAX_EFFECTIVE_REACH, curve_t)
	# A broad shield-like drawing must not become a screen-filling invisible spear.
	# This keeps the visible cross-axis bounded while elongated drawings retain
	# their requested reach.
	var aspect_safe_reach := maxf(MIN_EFFECTIVE_REACH, MAX_HELD_CROSS_AXIS * profile.ink_aspect)
	profile.effective_reach = snappedf(clampf(minf(span_reach, aspect_safe_reach), MIN_EFFECTIVE_REACH, MAX_EFFECTIVE_REACH), 1.0)
	profile.reach_profile = profile._profile_for_reach(profile.effective_reach)
	return profile


static func melee_reaches_point(
	grip: Vector2,
	target: Vector2,
	direction: Vector2,
	reach: float,
	half_cross_axis: float = 82.0,
) -> bool:
	var safe_direction := direction.normalized()
	if safe_direction.is_zero_approx():
		return false
	var offset := target - grip
	var forward := offset.dot(safe_direction)
	var perpendicular := absf(offset.cross(safe_direction))
	return forward >= 0.0 and forward <= reach and perpendicular < half_cross_axis


func applies_to(spec: WeaponSpec) -> bool:
	return spec != null and spec.delivery == "held" and spec.attack_pattern == "melee_slash"


func apply_to_spec(spec: WeaponSpec) -> void:
	if not applies_to(spec):
		return
	var original_damage := spec.damage
	var original_range := spec.attack_range
	var original_speed := spec.attack_speed
	spec.attack_range = effective_reach
	# PowerBudget prices range at range/45 and speed at speed*10. Exchanging
	# 450 px per 1.0 speed keeps geometry from granting free power while making
	# short weapons faster and long weapons slower.
	var exchanged_speed := original_speed + (original_range - effective_reach) / RANGE_SPEED_EXCHANGE
	spec.attack_speed = snappedf(clampf(exchanged_speed, 0.2, _drawback_speed_cap(spec.drawback)), 0.01)
	var note := (
		"geometry: frozen %.3f canvas span -> %s reach %.0f; range %.0f -> %.0f, attack_speed %.2f -> %.2f; damage %d unchanged"
		% [normalized_length, reach_profile, effective_reach, original_range, spec.attack_range, original_speed, spec.attack_speed, original_damage]
	)
	var retained: Array[String] = []
	for correction: String in spec.corrections:
		if not correction.begins_with("geometry: frozen "):
			retained.append(correction)
	retained.append(note)
	spec.corrections = retained
	spec.damage = original_damage
	spec.budget_breakdown = PowerBudget.calculate(spec.to_dict())
	spec.power_score = int(ceil(float(spec.budget_breakdown.total)))


func held_target_rect(padding_fraction: float = StrokeFit.DEFAULT_PADDING) -> Rect2:
	var padding := clampf(padding_fraction, StrokeFit.MIN_PADDING, StrokeFit.MAX_PADDING)
	var inner_fraction := 1.0 - padding * 2.0
	var safe_aspect := maxf(ink_aspect, 0.001)
	var inner_height := minf(effective_reach / safe_aspect, MAX_HELD_CROSS_AXIS)
	var outer_size := Vector2(effective_reach / inner_fraction, maxf(inner_height, 1.0) / inner_fraction)
	# The padding inset starts at x=0, pinning actual ink bounds to the grip.
	return Rect2(Vector2(-outer_size.x * padding, -outer_size.y * 0.5), outer_size)


func to_dict() -> Dictionary:
	return {
		"source_bounds": _rect_dict(source_bounds),
		"canvas_size": {"x": canvas_size.x, "y": canvas_size.y},
		"normalized_length": normalized_length,
		"normalized_height": normalized_height,
		"ink_aspect": ink_aspect,
		"reach_profile": reach_profile,
		"effective_reach": effective_reach,
		"threshold_status": "TO VALIDATE",
	}


func _profile_for_reach(reach: float) -> String:
	if reach < SHORT_MAX_REACH:
		return "short"
	if reach < STANDARD_MAX_REACH:
		return "standard"
	if reach < LONG_MAX_REACH:
		return "long"
	return "extreme_long"


func _drawback_speed_cap(drawback: String) -> float:
	return float({
		"slow_recovery": 1.2,
		"self_stagger": 1.0,
		"cooldown_lock": 0.85,
	}.get(drawback, 3.0))


func _rect_dict(rect: Rect2) -> Dictionary:
	return {
		"x": rect.position.x,
		"y": rect.position.y,
		"width": rect.size.x,
		"height": rect.size.y,
	}
