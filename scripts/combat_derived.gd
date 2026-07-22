class_name CombatDerived
extends RefCounted

# B1 controlled handling curve. The caps prevent the short/light to long/heavy
# matrix from degenerating into a raw three-times inverse-reach speed rule.
const MIN_HANDLING_MULTIPLIER := 0.70
const MAX_HANDLING_MULTIPLIER := 1.58
const ACTIVE_HIT_FRACTION := 0.62

var attack_speed := 1.0
var handling_multiplier := 1.0
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
	base_attack_speed: float,
	drawback: String,
) -> CombatDerived:
	var derived := CombatDerived.new()
	var reach_t := clampf(
		(physical.effective_reach - WeaponPhysicalProfile.MIN_EFFECTIVE_REACH)
		/ (WeaponPhysicalProfile.MAX_EFFECTIVE_REACH - WeaponPhysicalProfile.MIN_EFFECTIVE_REACH),
		0.0,
		1.0,
	)
	derived.reach_load = snappedf(lerpf(-0.18, 0.28, reach_t), 0.001)
	derived.mass_load = float({"light": -0.14, "balanced": 0.0, "heavy": 0.22}.get(physical.mass_profile, 0.0))
	derived.handling_multiplier = snappedf(clampf(
		0.86 + 0.46 * reach_t + derived.mass_load + 0.05 * reach_t * derived.mass_load,
		MIN_HANDLING_MULTIPLIER,
		MAX_HANDLING_MULTIPLIER,
	), 0.001)
	var requested_speed := base_attack_speed / derived.handling_multiplier
	derived.attack_speed = snappedf(clampf(requested_speed, 0.2, _drawback_speed_cap(drawback)), 0.01)
	var drawback_multiplier: float = {
		"slow_recovery": 1.25,
		"self_stagger": 1.30,
		"cooldown_lock": 1.45,
	}.get(drawback, 1.0)
	derived.cycle_seconds = snappedf(drawback_multiplier / maxf(derived.attack_speed, 0.2), 0.001)

	var startup_fraction := clampf(
		0.20 + reach_t * 0.07 + float({"light": -0.025, "heavy": 0.045}.get(physical.mass_profile, 0.0)),
		0.16,
		0.34,
	)
	var active_fraction := clampf(
		0.16 + reach_t * 0.035 + float({"light": -0.015, "heavy": 0.02}.get(physical.mass_profile, 0.0)),
		0.13,
		0.23,
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
		"curve_status": "TO VALIDATE",
	}


static func _drawback_speed_cap(drawback: String) -> float:
	return float({
		"slow_recovery": 1.2,
		"self_stagger": 1.0,
		"cooldown_lock": 0.85,
	}.get(drawback, 3.0))
