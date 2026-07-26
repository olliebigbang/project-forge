class_name CombatDerived
extends RefCounted

# B1/B1.5 bounded exposure candidate. These reach/cycle anchors are joined with
# smoothstep interpolation, so cadence remains one bounded nonlinear authority
# rather than a raw inverse of reach or a role-specific timing override. Values
# pass the C0 Chromium/WebKit strategy matrix and remain TO VALIDATE on physical
# hardware.
const REACH_CYCLE_ANCHORS := [
	Vector2(72.0, 0.50),
	Vector2(92.0, 0.60),
	Vector2(120.0, 0.71),
	Vector2(199.0, 0.95),
	Vector2(228.0, 1.01),
]
const MASS_CYCLE_MULTIPLIERS := {"light": 0.78, "balanced": 1.0, "heavy": 1.14}
const MIN_CYCLE_SECONDS := 0.25
const MAX_CYCLE_SECONDS := 2.40
const ACTIVE_HIT_FRACTION := 0.62

var attack_speed := 1.0
var handling_multiplier := 1.0
var base_cycle_seconds := 1.0
var cycle_seconds := 1.0
var startup_seconds := 0.24
var active_seconds := 0.18
var hit_delay_seconds := 0.35
var recovery_seconds := 0.58
var reach_load := 0.0
var mass_load := 0.0
var budget_effects: Dictionary = {}


static func derive(
	physical: WeaponPhysicalProfile,
	_base_attack_speed: float,
	drawback: String,
) -> CombatDerived:
	var derived := CombatDerived.new()
	var reach_t := clampf(
		(physical.effective_reach - WeaponPhysicalProfile.MIN_EFFECTIVE_REACH)
		/ (WeaponPhysicalProfile.MAX_EFFECTIVE_REACH - WeaponPhysicalProfile.MIN_EFFECTIVE_REACH),
		0.0,
		1.0,
	)
	derived.base_cycle_seconds = snappedf(_cycle_anchor_for_reach(physical.effective_reach), 0.001)
	derived.reach_load = snappedf(derived.base_cycle_seconds - 0.95, 0.001)
	var mass_multiplier := float(MASS_CYCLE_MULTIPLIERS.get(physical.mass_profile, 1.0))
	derived.mass_load = snappedf(mass_multiplier - 1.0, 0.001)
	var drawback_multiplier: float = {
		"slow_recovery": 1.10,
		"self_stagger": 1.16,
		"cooldown_lock": 1.25,
	}.get(drawback, 1.0)
	derived.handling_multiplier = snappedf(mass_multiplier * drawback_multiplier, 0.001)
	var requested_cycle := clampf(
		derived.base_cycle_seconds * derived.handling_multiplier,
		MIN_CYCLE_SECONDS,
		MAX_CYCLE_SECONDS,
	)
	# attack_speed remains the single public executable timing value. Rounding it
	# first and deriving the final cycle back from it keeps HUD, animation, hit,
	# recovery, cooldown, and input acceptance on exactly one authority.
	derived.attack_speed = snappedf(clampf(1.0 / requested_cycle, 0.2, 3.0), 0.01)
	derived.cycle_seconds = snappedf(1.0 / derived.attack_speed, 0.001)

	var startup_fraction := clampf(
		0.18 + reach_t * 0.06 + float({"light": -0.015, "heavy": 0.025}.get(physical.mass_profile, 0.0)),
		0.15,
		0.31,
	)
	var active_fraction := clampf(
		0.18 + reach_t * 0.03 + float({"light": -0.01, "heavy": 0.015}.get(physical.mass_profile, 0.0)),
		0.15,
		0.235,
	)
	derived.startup_seconds = snappedf(derived.cycle_seconds * startup_fraction, 0.001)
	derived.active_seconds = snappedf(derived.cycle_seconds * active_fraction, 0.001)
	derived.hit_delay_seconds = snappedf(
		derived.startup_seconds + derived.active_seconds * ACTIVE_HIT_FRACTION,
		0.001,
	)
	derived.recovery_seconds = snappedf(
		maxf(derived.cycle_seconds - derived.startup_seconds - derived.active_seconds, 0.001),
		0.001,
	)
	return derived


func record_budget_effects(
	original_range: float,
	original_speed: float,
	final_range: float,
	final_speed: float,
) -> void:
	var original_range_cost := original_range / 45.0
	var original_speed_cost := original_speed * 10.0
	var final_range_cost := final_range / 45.0
	var final_speed_cost := final_speed * 10.0
	budget_effects = {
		"range_before": snappedf(original_range_cost, 0.01),
		"range_after": snappedf(final_range_cost, 0.01),
		"speed_before": snappedf(original_speed_cost, 0.01),
		"speed_after": snappedf(final_speed_cost, 0.01),
		"combined_delta": snappedf(
			(final_range_cost + final_speed_cost) - (original_range_cost + original_speed_cost),
			0.01,
		),
	}


func cap_attack_speed(final_attack_speed: float) -> void:
	var safe_speed := snappedf(clampf(final_attack_speed, 0.2, attack_speed), 0.01)
	if is_equal_approx(safe_speed, attack_speed):
		return
	var time_scale := attack_speed / safe_speed
	attack_speed = safe_speed
	cycle_seconds = snappedf(cycle_seconds * time_scale, 0.001)
	startup_seconds = snappedf(startup_seconds * time_scale, 0.001)
	active_seconds = snappedf(active_seconds * time_scale, 0.001)
	hit_delay_seconds = snappedf(hit_delay_seconds * time_scale, 0.001)
	recovery_seconds = snappedf(recovery_seconds * time_scale, 0.001)


func to_dict() -> Dictionary:
	return {
		"attack_speed": attack_speed,
		"handling_multiplier": handling_multiplier,
		"base_cycle_seconds": base_cycle_seconds,
		"cycle_seconds": cycle_seconds,
		"startup_seconds": startup_seconds,
		"active_seconds": active_seconds,
		"hit_delay_seconds": hit_delay_seconds,
		"recovery_seconds": recovery_seconds,
		"reach_load": reach_load,
		"mass_load": mass_load,
		"budget_effects": budget_effects.duplicate(true),
		"contact_model": {
			"mode": "uniform_grip_to_tip",
			"regions": [],
			"sweet_spots_enabled": false,
			"status": "TO VALIDATE (Weapon Physics B2)",
		},
		"authority": "CombatDerived",
		"curve_model": "bounded_piecewise_smoothstep",
		"safety_floor_seconds": MIN_CYCLE_SECONDS,
		"curve_status": "TO VALIDATE",
	}


static func _cycle_anchor_for_reach(reach: float) -> float:
	var bounded_reach := clampf(
		reach,
		float(REACH_CYCLE_ANCHORS[0].x),
		float(REACH_CYCLE_ANCHORS[REACH_CYCLE_ANCHORS.size() - 1].x),
	)
	for index in REACH_CYCLE_ANCHORS.size() - 1:
		var start: Vector2 = REACH_CYCLE_ANCHORS[index]
		var finish: Vector2 = REACH_CYCLE_ANCHORS[index + 1]
		if bounded_reach <= finish.x:
			var linear_t := inverse_lerp(start.x, finish.x, bounded_reach)
			var smooth_t := linear_t * linear_t * (3.0 - 2.0 * linear_t)
			return lerpf(start.y, finish.y, smooth_t)
	return float(REACH_CYCLE_ANCHORS[REACH_CYCLE_ANCHORS.size() - 1].y)
