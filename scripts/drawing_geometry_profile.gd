class_name DrawingGeometryProfile
extends RefCounted

# Compatibility facade for the accepted M1B1.2 call sites. B0 now makes the
# internal authority chain explicit without expanding the public WeaponSpec.
const MIN_EFFECTIVE_REACH := WeaponPhysicalProfile.MIN_EFFECTIVE_REACH
const NOMINAL_EFFECTIVE_REACH := WeaponPhysicalProfile.NOMINAL_EFFECTIVE_REACH
const MAX_EFFECTIVE_REACH := WeaponPhysicalProfile.MAX_EFFECTIVE_REACH
const MAX_HELD_CROSS_AXIS := WeaponPhysicalProfile.MAX_HELD_CROSS_AXIS

var source_bounds := Rect2()
var canvas_size := Vector2.ONE
var normalized_length := 0.0
var normalized_height := 0.0
var ink_aspect := 1.0
var reach_profile := "short"
var effective_reach := MIN_EFFECTIVE_REACH
var mass_profile := "light"
var geometry_evidence: GeometryEvidence
var physical_profile: WeaponPhysicalProfile
var combat_derived: CombatDerived


static func from_snapshot(
	source: Array[PackedVector2Array],
	frozen_canvas_size: Vector2,
	controlled_mass_profile: String = "",
) -> DrawingGeometryProfile:
	var profile := DrawingGeometryProfile.new()
	profile.geometry_evidence = GeometryEvidence.from_snapshot(source, frozen_canvas_size)
	profile.physical_profile = WeaponPhysicalProfile.from_evidence(profile.geometry_evidence, controlled_mass_profile)
	profile.source_bounds = profile.geometry_evidence.source_bounds
	profile.canvas_size = profile.geometry_evidence.canvas_size
	profile.normalized_length = profile.geometry_evidence.normalized_length
	profile.normalized_height = profile.geometry_evidence.normalized_cross_axis
	profile.ink_aspect = profile.geometry_evidence.ink_aspect
	profile.effective_reach = profile.physical_profile.effective_reach
	profile.reach_profile = profile.physical_profile.reach_profile
	profile.mass_profile = profile.physical_profile.mass_profile
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
	combat_derived = CombatDerived.derive(physical_profile, original_speed, spec.drawback)
	spec.attack_speed = combat_derived.attack_speed
	var preliminary_budget := PowerBudget.calculate(spec.to_dict())
	if float(preliminary_budget.total) > PowerBudget.MAX_POWER and spec.attack_speed > 0.2:
		var allowed_speed := maxf(
			0.2,
			floorf((spec.attack_speed - (float(preliminary_budget.total) - PowerBudget.MAX_POWER) / 10.0) * 100.0) / 100.0,
		)
		combat_derived.cap_attack_speed(allowed_speed)
		spec.attack_speed = combat_derived.attack_speed
	combat_derived.record_budget_effects(original_range, original_speed, spec.attack_range, spec.attack_speed)
	var note := (
		"physics B1: %.3f span -> %s reach %.0f + %s mass; range %.0f -> %.0f, attack_speed %.2f -> %.2f, phases %.3f/%.3f/%.3f, budget delta %.2f; damage %d unchanged"
		% [normalized_length, reach_profile, effective_reach, mass_profile, original_range, spec.attack_range, original_speed, spec.attack_speed, combat_derived.startup_seconds, combat_derived.active_seconds, combat_derived.recovery_seconds, float(combat_derived.budget_effects.combined_delta), original_damage]
	)
	var retained: Array[String] = []
	for correction: String in spec.corrections:
		if not correction.begins_with("geometry: frozen ") and not correction.begins_with("physics B1: "):
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
		"mass_profile": mass_profile,
		"geometry_evidence": geometry_evidence.to_dict() if geometry_evidence != null else {},
		"physical_profile": physical_profile.to_dict() if physical_profile != null else {},
		"combat_derived": combat_derived.to_dict() if combat_derived != null else {},
		"threshold_status": "TO VALIDATE",
	}


func _rect_dict(rect: Rect2) -> Dictionary:
	return {
		"x": rect.position.x,
		"y": rect.position.y,
		"width": rect.size.x,
		"height": rect.size.y,
	}
