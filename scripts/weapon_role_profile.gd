class_name WeaponRoleProfile
extends RefCounted

# B1.5 is an internal deterministic view over an already validated WeaponSpec
# and the accepted B0/B1 melee chain. It does not add public Schema fields or
# change PowerBudget prices. All candidate values remain TO VALIDATE.
const ROLE_IDS: PackedStringArray = [
	"short_melee",
	"standard_melee",
	"long_melee",
	"straight_ranged",
	"thrown_blast",
	"boomerang",
	"piercing",
]
const COMPATIBILITY_ROLE_IDS: PackedStringArray = ["direct_blast"]
const DRAWBACK_CYCLE_MULTIPLIERS := {
	"slow_recovery": 1.25,
	"self_stagger": 1.30,
	"cooldown_lock": 1.45,
}
const ROLE_PHASE_SHARES := {
	"short_melee": Vector2(0.22, 0.22),
	"standard_melee": Vector2(0.25, 0.21),
	"long_melee": Vector2(0.29, 0.20),
	"straight_ranged": Vector2(0.18, 0.12),
	"thrown_blast": Vector2(0.30, 0.10),
	"boomerang": Vector2(0.25, 0.16),
	"piercing": Vector2(0.28, 0.10),
}
const BLAST_DAMAGE_DELAY_SECONDS := 0.10
const DEFAULT_PROJECTILE_HIT_RADIUS := 11.0
const NARROW_PROJECTILE_HIT_RADIUS := 7.0
const THROWN_PROJECTILE_HIT_RADIUS := 22.0

var role_id: String = "standard_melee"
var advantages: Array[String] = []
var deterministic_costs: Array[String] = []
var cycle_seconds: float = 1.0
var startup_seconds: float = 0.25
var active_seconds: float = 0.21
var commit_delay_seconds: float = 0.25
var recovery_seconds: float = 0.54
var effective_reach: float = 132.0
var projectile_travel_seconds: float = 0.0
var nominal_projectile_travel_seconds: float = 0.0
var projectile_travel_model: String = "none"
var projectile_hit_radius: float = DEFAULT_PROJECTILE_HIT_RADIUS
var blast_damage_delay_seconds: float = 0.0
var single_target_dps: float = 0.0
var return_window_dps: float = 0.0
var body_hit_limit: int = 1
var per_target_hit_limit: int = 1
var per_phase_per_target_limit: int = 1
var return_hit_opportunity: bool = false
var shield_rule: String = "blocked_to_20_percent"
var moving_target_risk: String = "medium"
var power_score: int = 0
var power_components: Dictionary = {}
var audit_reasons: Array[String] = []


static func derive(
	spec: WeaponSpec,
	geometry: DrawingGeometryProfile = null,
) -> WeaponRoleProfile:
	var profile := WeaponRoleProfile.new()
	if spec == null:
		profile.audit_reasons.append("role B1.5: no validated WeaponSpec; default profile is non-executable")
		return profile
	profile.role_id = _role_for(spec, geometry)
	profile.effective_reach = spec.attack_range
	profile.power_score = spec.power_score
	profile.power_components = PowerBudget.calculate(spec.to_dict()).duplicate(true)
	profile._derive_timing(spec, geometry)
	profile._derive_delivery(spec)
	profile._derive_role_contract(spec)
	profile.single_target_dps = snappedf(float(spec.damage) / maxf(profile.cycle_seconds, 0.001), 0.01)
	profile.return_window_dps = profile.single_target_dps * 2.0 if profile.return_hit_opportunity else 0.0
	profile.audit_reasons.append(
		"role B1.5: %s; advantage=%s; cost=%s; cycle %.3f; commit %.3f; single-target DPS %.2f; public PowerBudget %d unchanged"
		% [
			profile.role_id,
			profile.advantages[0] if not profile.advantages.is_empty() else "none",
			profile.deterministic_costs[0] if not profile.deterministic_costs.is_empty() else "none",
			profile.cycle_seconds,
			profile.commit_delay_seconds,
			profile.single_target_dps,
			profile.power_score,
		]
	)
	return profile


func to_dict() -> Dictionary:
	return {
		"role_id": role_id,
		"advantages": advantages.duplicate(),
		"deterministic_costs": deterministic_costs.duplicate(),
		"cycle_seconds": cycle_seconds,
		"startup_seconds": startup_seconds,
		"active_seconds": active_seconds,
		"commit_delay_seconds": commit_delay_seconds,
		"recovery_seconds": recovery_seconds,
		"effective_reach": effective_reach,
		"projectile_travel_seconds": projectile_travel_seconds,
		"nominal_projectile_travel_seconds": nominal_projectile_travel_seconds,
		"projectile_travel_model": projectile_travel_model,
		"projectile_hit_radius": projectile_hit_radius,
		"blast_damage_delay_seconds": blast_damage_delay_seconds,
		"single_target_dps": single_target_dps,
		"return_window_dps": return_window_dps,
		"body_hit_limit": body_hit_limit,
		"per_target_hit_limit": per_target_hit_limit,
		"per_phase_per_target_limit": per_phase_per_target_limit,
		"return_hit_opportunity": return_hit_opportunity,
		"shield_rule": shield_rule,
		"moving_target_risk": moving_target_risk,
		"power_score": power_score,
		"power_components": power_components.duplicate(true),
		"audit_reasons": audit_reasons.duplicate(),
		"authority": "WeaponRoleProfile",
		"role_family_status": "compatibility_existing_path" if role_id in COMPATIBILITY_ROLE_IDS else "authorized_b1_5_role",
		"status": "TO VALIDATE",
	}


func _derive_timing(spec: WeaponSpec, geometry: DrawingGeometryProfile) -> void:
	if geometry != null and geometry.applies_to(spec) and geometry.combat_derived != null:
		var melee_timing: CombatDerived = geometry.combat_derived
		cycle_seconds = melee_timing.cycle_seconds
		startup_seconds = melee_timing.startup_seconds
		active_seconds = melee_timing.active_seconds
		commit_delay_seconds = melee_timing.hit_delay_seconds
		recovery_seconds = melee_timing.recovery_seconds
		return
	var drawback_multiplier := float(DRAWBACK_CYCLE_MULTIPLIERS.get(spec.drawback, 1.0))
	cycle_seconds = snappedf((1.0 / maxf(spec.attack_speed, 0.2)) * drawback_multiplier, 0.001)
	var shares: Vector2 = ROLE_PHASE_SHARES.get(role_id, Vector2(0.25, 0.21))
	startup_seconds = snappedf(cycle_seconds * shares.x, 0.001)
	active_seconds = snappedf(cycle_seconds * shares.y, 0.001)
	commit_delay_seconds = snappedf(
		startup_seconds + active_seconds * CombatDerived.ACTIVE_HIT_FRACTION
		if spec.delivery == "held" and spec.attack_pattern == "melee_slash"
		else startup_seconds,
		0.001,
	)
	recovery_seconds = snappedf(maxf(cycle_seconds - startup_seconds - active_seconds, 0.001), 0.001)


func _derive_delivery(spec: WeaponSpec) -> void:
	match role_id:
		"straight_ranged", "piercing":
			projectile_travel_seconds = snappedf(spec.attack_range / maxf(spec.projectile_speed, 1.0), 0.001)
			projectile_travel_model = "range_over_projectile_speed"
			if role_id == "piercing":
				projectile_hit_radius = NARROW_PROJECTILE_HIT_RADIUS
		"thrown_blast":
			nominal_projectile_travel_seconds = snappedf(
				clampf(spec.attack_range * 0.50, 64.0, 180.0) / maxf(spec.projectile_speed, 1.0),
				0.001,
			)
			projectile_travel_seconds = 0.0
			projectile_travel_model = "runtime_arc_path_samples"
			projectile_hit_radius = THROWN_PROJECTILE_HIT_RADIUS
			blast_damage_delay_seconds = BLAST_DAMAGE_DELAY_SECONDS
		"direct_blast":
			projectile_travel_model = "none"
			blast_damage_delay_seconds = BLAST_DAMAGE_DELAY_SECONDS
		"boomerang":
			var leg_distance := spec.attack_range * 0.52
			projectile_travel_seconds = snappedf(
				leg_distance / maxf(spec.projectile_speed, 1.0)
				+ leg_distance / maxf(spec.return_speed, 1.0),
				0.001,
			)
			projectile_travel_model = "outbound_plus_return"
			projectile_hit_radius = THROWN_PROJECTILE_HIT_RADIUS
		_:
			projectile_travel_model = "none"


func _derive_role_contract(spec: WeaponSpec) -> void:
	match role_id:
		"short_melee":
			advantages.assign(["highest bounded held-melee cadence"])
			deterministic_costs.assign(["shortest grip-to-tip reach; must close distance"])
			moving_target_risk = "high"
		"standard_melee":
			advantages.assign(["balanced held-melee reach and cadence"])
			deterministic_costs.assign(["single closest target and proximity exposure"])
			moving_target_risk = "medium"
		"long_melee":
			advantages.assign(["longest held-melee control reach"])
			deterministic_costs.assign(["slow startup and recovery from B1 handling"])
			moving_target_risk = "low"
		"straight_ranged":
			advantages.assign(["long safe range and fast direct travel"])
			deterministic_costs.assign(["low impact and first body ends the shot"])
			moving_target_risk = "medium"
		"thrown_blast":
			advantages.assign(["all visible bodies inside the blast radius; shield bypass"])
			deterministic_costs.assign(["startup plus arc and blast delay; slow complete cycle"])
			body_hit_limit = -1
			shield_rule = "bypassed_by_area_blast"
			moving_target_risk = "high"
		"direct_blast":
			advantages.assign(["all visible bodies inside the player-centred radius; shield bypass"])
			deterministic_costs.assign(["must commit at close range and pay the complete cooldown cycle"])
			body_hit_limit = -1
			shield_rule = "bypassed_by_area_blast"
			moving_target_risk = "high"
		"boomerang":
			advantages.assign(["outbound and return hit opportunities; return can flank shield"])
			deterministic_costs.assign(["self-staggered cycle and outbound-plus-return travel"])
			body_hit_limit = -1
			per_target_hit_limit = 2
			per_phase_per_target_limit = 1
			return_hit_opportunity = true
			shield_rule = "outbound_blocked_return_bypasses"
			moving_target_risk = "medium"
		"piercing":
			advantages.assign(["shield bypass and deterministic multi-body pierce"])
			deterministic_costs.assign(["narrow projectile hit radius and committed startup"])
			body_hit_limit = spec.pierce_count
			shield_rule = "bypassed_by_piercing"
			moving_target_risk = "high"


static func _role_for(spec: WeaponSpec, geometry: DrawingGeometryProfile) -> String:
	match spec.attack_pattern:
		"straight_projectile":
			return "straight_ranged"
		"area_blast":
			if spec.delivery == "thrown" and spec.trajectory == "arc" and spec.area_effect == "explosion":
				return "thrown_blast"
			return "direct_blast"
		"boomerang":
			return "boomerang"
		"piercing":
			return "piercing"
	if geometry != null and geometry.physical_profile != null:
		var reach_profile: String = geometry.physical_profile.reach_profile
		if reach_profile in ["ultra_short", "short"]:
			return "short_melee"
		if reach_profile in ["long", "extreme_long"]:
			return "long_melee"
		return "standard_melee"
	if spec.attack_range <= WeaponPhysicalProfile.SHORT_MAX_REACH:
		return "short_melee"
	if spec.attack_range >= WeaponPhysicalProfile.STANDARD_MAX_REACH:
		return "long_melee"
	return "standard_melee"
