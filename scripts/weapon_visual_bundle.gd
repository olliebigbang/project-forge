class_name WeaponVisualBundle
extends RefCounted


static func from_spec(spec: WeaponSpec) -> Dictionary:
	var result := {
		"held_visual": "player_strokes",
		"projectile_visual": "none",
		"impact_visual": "explosion" if spec.area_effect == "explosion" else "none",
		"projectile_kind": "none",
		"projectile_source": "none",
		"projectile_pivot": "geometry_center",
		"projectile_rotation_mode": "none",
		"hide_held_during_attack": false,
	}

	# Form + delivery semantics take priority over the coarse attack module.
	# An area blast describes the landing effect; it never erases a grenade's
	# visible thrown delivery.
	if spec.weapon_form == "grenade" and spec.delivery == "thrown" and spec.trajectory == "arc":
		result.projectile_visual = "player_strokes"
		result.projectile_kind = "grenade"
		result.projectile_source = "player_strokes"
		result.projectile_pivot = "stroke_bounds_center"
		result.projectile_rotation_mode = "tumble"
		result.hide_held_during_attack = true
		return result

	if spec.weapon_form == "boomerang" or (spec.delivery == "thrown" and spec.trajectory == "returning"):
		result.projectile_visual = "player_strokes"
		result.projectile_kind = "boomerang"
		result.projectile_source = "player_strokes"
		result.projectile_pivot = "stroke_bounds_center"
		result.projectile_rotation_mode = "return_spin"
		result.hide_held_during_attack = true
		return result

	if spec.delivery == "held" or spec.attack_pattern == "melee_slash":
		return result

	if spec.weapon_form == "bow":
		result.projectile_visual = "arrow"
		result.projectile_kind = "arrow"
		result.projectile_source = "procedural"
		result.projectile_rotation_mode = "face_velocity"
		return result

	if spec.weapon_form == "spear" or spec.attack_pattern == "piercing" or spec.impact == "piercing":
		result.projectile_visual = "spear"
		result.projectile_kind = "spear"
		result.projectile_source = "procedural"
		result.projectile_rotation_mode = "face_velocity"
		return result

	if spec.delivery == "projectile" or spec.delivery == "thrown":
		var kind := "bullet" if spec.element == "normal" else "energy"
		result.projectile_visual = kind
		result.projectile_kind = kind
		result.projectile_source = "procedural"
		result.projectile_rotation_mode = "face_velocity"
	return result
