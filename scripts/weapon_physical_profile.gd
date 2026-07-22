class_name WeaponPhysicalProfile
extends RefCounted

# B1 prototype values remain TO VALIDATE. Reach and mass are intentionally
# independent axes: horizontal span selects reach while cross-axis load selects
# mass. Neither axis changes damage.
const MIN_EFFECTIVE_REACH := 72.0
const NOMINAL_EFFECTIVE_REACH := 132.0
const MAX_EFFECTIVE_REACH := 228.0
const CURVE_START_SPAN := 0.18
const CURVE_END_SPAN := 0.92
const ULTRA_SHORT_MAX_REACH := 84.0
const SHORT_MAX_REACH := 104.0
const STANDARD_MAX_REACH := 160.0
const LONG_MAX_REACH := 202.0
const MAX_HELD_CROSS_AXIS := 104.0
const LIGHT_MAX_CROSS_AXIS := 0.08
const BALANCED_MAX_CROSS_AXIS := 0.20
const MASS_FACTORS := {"light": 0.82, "balanced": 1.0, "heavy": 1.22}

var evidence: GeometryEvidence
var reach_profile := "ultra_short"
var effective_reach := MIN_EFFECTIVE_REACH
var mass_profile := "light"
var mass_factor := 0.82


static func from_evidence(
	geometry: GeometryEvidence,
	controlled_mass_profile: String = "",
) -> WeaponPhysicalProfile:
	var profile := WeaponPhysicalProfile.new()
	profile.evidence = geometry
	var curve_t := clampf(
		(geometry.normalized_length - CURVE_START_SPAN) / (CURVE_END_SPAN - CURVE_START_SPAN),
		0.0,
		1.0,
	)
	var span_reach := lerpf(MIN_EFFECTIVE_REACH, MAX_EFFECTIVE_REACH, curve_t)
	# Preserve the accepted broad-shape safety cap without using mass to grant
	# reach. Within the controlled melee matrix, horizontal span remains the
	# reach axis and cross-axis load can vary independently.
	var aspect_safe_reach := maxf(MIN_EFFECTIVE_REACH, MAX_HELD_CROSS_AXIS * geometry.ink_aspect)
	profile.effective_reach = snappedf(
		clampf(minf(span_reach, aspect_safe_reach), MIN_EFFECTIVE_REACH, MAX_EFFECTIVE_REACH),
		1.0,
	)
	profile.reach_profile = profile._profile_for_reach(profile.effective_reach)
	profile.mass_profile = controlled_mass_profile if controlled_mass_profile in MASS_FACTORS else profile._mass_from_evidence()
	profile.mass_factor = float(MASS_FACTORS[profile.mass_profile])
	return profile


func to_dict() -> Dictionary:
	return {
		"reach_profile": reach_profile,
		"effective_reach": effective_reach,
		"mass_profile": mass_profile,
		"mass_factor": mass_factor,
		"authority": "PhysicalProfile",
		"threshold_status": "TO VALIDATE",
	}


func _profile_for_reach(reach: float) -> String:
	if reach < ULTRA_SHORT_MAX_REACH:
		return "ultra_short"
	if reach < SHORT_MAX_REACH:
		return "short"
	if reach < STANDARD_MAX_REACH:
		return "standard"
	if reach < LONG_MAX_REACH:
		return "long"
	return "extreme_long"


func _mass_from_evidence() -> String:
	if evidence.normalized_cross_axis < LIGHT_MAX_CROSS_AXIS:
		return "light"
	if evidence.normalized_cross_axis < BALANCED_MAX_CROSS_AXIS:
		return "balanced"
	return "heavy"
