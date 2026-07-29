class_name WeaponRouteSnapshot
extends RefCounted

## Creates an isolated exact copy of a validated WeaponSpec. This deliberately
## copies runtime audit fields that WeaponSpec.from_dict() does not preserve.
static func clone_weapon_spec(source: WeaponSpec) -> WeaponSpec:
	if source == null:
		return null
	var clone: WeaponSpec = WeaponSpec.new()
	clone.display_name = source.display_name
	clone.weapon_class = source.weapon_class
	clone.weapon_form = source.weapon_form
	clone.delivery = source.delivery
	clone.trajectory = source.trajectory
	clone.impact = source.impact
	clone.area_effect = source.area_effect
	clone.attack_pattern = source.attack_pattern
	clone.element = source.element
	clone.damage = source.damage
	clone.attack_speed = source.attack_speed
	clone.attack_range = source.attack_range
	clone.special_ability = source.special_ability
	clone.status_effect = source.status_effect
	clone.drawback = source.drawback
	clone.visual_material = source.visual_material
	clone.power_score = source.power_score
	clone.projectile_speed = source.projectile_speed
	clone.area_radius = source.area_radius
	clone.pierce_count = source.pierce_count
	clone.return_speed = source.return_speed
	clone.corrections.assign(source.corrections)
	clone.budget_breakdown = source.budget_breakdown.duplicate(true)
	return clone


## Creates an isolated copy of the complete B0/B1 geometry authority chain.
static func clone_geometry_profile(
	source: DrawingGeometryProfile,
) -> DrawingGeometryProfile:
	if source == null:
		return null
	var clone: DrawingGeometryProfile = DrawingGeometryProfile.new()
	clone.source_bounds = source.source_bounds
	clone.canvas_size = source.canvas_size
	clone.normalized_length = source.normalized_length
	clone.normalized_height = source.normalized_height
	clone.ink_aspect = source.ink_aspect
	clone.ink_forward_sign = source.ink_forward_sign
	clone.visual_extent_ratio = source.visual_extent_ratio
	clone.visual_occupancy_ratio = source.visual_occupancy_ratio
	clone.visual_linear_extent = source.visual_linear_extent
	clone.visual_scale_multiplier = source.visual_scale_multiplier
	clone.visual_size_profile = source.visual_size_profile
	clone.reach_profile = source.reach_profile
	clone.effective_reach = source.effective_reach
	clone.mass_profile = source.mass_profile
	clone.geometry_evidence = _clone_geometry_evidence(source.geometry_evidence)
	clone.physical_profile = _clone_physical_profile(
		source.physical_profile,
		clone.geometry_evidence,
	)
	clone.combat_derived = _clone_combat_derived(source.combat_derived)
	return clone


static func _clone_geometry_evidence(source: GeometryEvidence) -> GeometryEvidence:
	if source == null:
		return null
	var clone: GeometryEvidence = GeometryEvidence.new()
	clone.source_strokes = StrokeFit.duplicate_strokes(source.source_strokes)
	clone.source_bounds = source.source_bounds
	clone.canvas_size = source.canvas_size
	clone.normalized_length = source.normalized_length
	clone.normalized_cross_axis = source.normalized_cross_axis
	clone.ink_aspect = source.ink_aspect
	clone.stroke_count = source.stroke_count
	clone.point_count = source.point_count
	clone.normalized_path_load = source.normalized_path_load
	return clone


static func _clone_physical_profile(
	source: WeaponPhysicalProfile,
	evidence: GeometryEvidence,
) -> WeaponPhysicalProfile:
	if source == null:
		return null
	var clone: WeaponPhysicalProfile = WeaponPhysicalProfile.new()
	clone.evidence = evidence
	clone.reach_profile = source.reach_profile
	clone.effective_reach = source.effective_reach
	clone.mass_profile = source.mass_profile
	clone.mass_factor = source.mass_factor
	return clone


static func _clone_combat_derived(source: CombatDerived) -> CombatDerived:
	if source == null:
		return null
	var clone: CombatDerived = CombatDerived.new()
	clone.attack_speed = source.attack_speed
	clone.handling_multiplier = source.handling_multiplier
	clone.base_cycle_seconds = source.base_cycle_seconds
	clone.cycle_seconds = source.cycle_seconds
	clone.startup_seconds = source.startup_seconds
	clone.active_seconds = source.active_seconds
	clone.hit_delay_seconds = source.hit_delay_seconds
	clone.recovery_seconds = source.recovery_seconds
	clone.reach_load = source.reach_load
	clone.mass_load = source.mass_load
	clone.budget_effects = source.budget_effects.duplicate(true)
	return clone
