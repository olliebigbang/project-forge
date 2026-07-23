class_name ForgeAreaBlast
extends Node2D

signal hits_complete(count: int, total_damage: int)

var _spec: WeaponSpec
var _role_profile: WeaponRoleProfile
var _direction := Vector2.RIGHT
var _elapsed := 0.0
var _applied := false


func configure(spec: WeaponSpec, direction: Vector2) -> void:
	_spec = spec
	_role_profile = WeaponRoleProfile.derive(spec)
	_direction = direction


func _ready() -> void:
	z_index = 3


func _process(delta: float) -> void:
	_elapsed += delta
	if not _applied and _elapsed >= _role_profile.blast_damage_delay_seconds:
		_applied = true
		_apply_damage()
	queue_redraw()
	if _elapsed >= 0.55: queue_free()


func qa_state() -> Dictionary:
	return {
		"position": {"x": global_position.x, "y": global_position.y},
		"elapsed": _elapsed,
		"damage_applied": _applied,
		"weapon_role": _role_profile.to_dict() if _role_profile != null else {},
		"role_profile": _role_profile.to_dict() if _role_profile != null else {},
	}


func _apply_damage() -> void:
	var count := 0
	var total := 0
	for target: Node in get_tree().get_nodes_in_group("test_targets"):
		if target is Node2D and target.visible and global_position.distance_to(target.global_position) <= _spec.area_radius:
			var actual: int = target.take_damage(_spec.damage, _spec.status_effect, "area_blast", _direction)
			if actual > 0:
				count += 1
				total += actual
	hits_complete.emit(count, total)


func _draw() -> void:
	if _spec == null: return
	var progress := clampf(_elapsed / 0.42, 0.0, 1.0)
	var color := WeaponVisual._color_for_element(_spec.element)
	var radius := lerpf(18.0, _spec.area_radius, progress)
	draw_circle(Vector2.ZERO, radius, Color(color, 0.10 * (1.0 - progress)))
	draw_arc(Vector2.ZERO, radius, 0, TAU, 64, Color(color, 0.9 * (1.0 - progress)), 8.0, true)
	draw_arc(Vector2.ZERO, radius * 0.68, 0, TAU, 48, Color(color, 0.45 * (1.0 - progress)), 4.0, true)
