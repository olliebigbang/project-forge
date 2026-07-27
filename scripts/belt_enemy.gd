class_name BeltEnemy
extends CharacterBody2D

const ARENA_SIDE_MARGIN: float = 30.0
const ARENA_HEAD_MARGIN: float = 66.0
const ARENA_FOOT_MARGIN: float = 36.0

## Stable enemy phase stream for HUD, assist logic, and QA.
signal phase_changed(enemy: BeltEnemy, phase: String, duration: float)
## Emitted after non-zero damage is applied.
signal damage_report(enemy: BeltEnemy, amount: int, note: String)
## Emitted once when health reaches zero.
signal defeated(enemy: BeltEnemy)
## Emitted when a committed strike damages the player.
signal strike_landed(enemy: BeltEnemy, amount: int)

enum Phase {
	INACTIVE,
	APPROACH,
	TELEGRAPH,
	STRIKE,
	RECOVER,
	DEFEATED,
}

const BODY_RADIUS: float = 27.0
const BASE_APPROACH_SPEED: float = 88.0
const ATTACK_DISTANCE: float = 78.0
const STRIKE_LEASH: float = 110.0
const TELEGRAPH_SECONDS: float = 0.62
const STRIKE_SECONDS: float = 0.20
const RECOVERY_SECONDS: float = 0.82
const STRIKE_DAMAGE: int = 20

var enemy_id: String = "enemy"
var enemy_kind: String = "moving"
var maximum_health: int = 120
var health: int = 120
var arena_bounds: Rect2 = Rect2(70.0, 238.0, 1140.0, 380.0)
var phase: Phase = Phase.INACTIVE
var facing: Vector2 = Vector2.LEFT

var _target: BeltPlayer
var _simulation_enabled: bool = false
var _phase_remaining: float = 0.0
var _strike_applied: bool = false
var _flash_remaining: float = 0.0
var _slow_remaining: float = 0.0
var _stagger_remaining: float = 0.0
var _status_epoch: int = 0
var _spawn_position: Vector2 = Vector2.ZERO
var _formation_offset: Vector2 = Vector2.ZERO


func configure(
	id: String,
	kind: String,
	max_health_value: int,
	spawn_position: Vector2,
	formation_offset: Vector2 = Vector2.ZERO,
) -> void:
	enemy_id = id
	enemy_kind = kind
	maximum_health = maxi(max_health_value, 1)
	health = maximum_health
	_spawn_position = spawn_position
	_formation_offset = formation_offset
	global_position = spawn_position


func _ready() -> void:
	collision_layer = 8
	collision_mask = 1
	add_to_group("belt_enemy")
	var collision_shape: CollisionShape2D = CollisionShape2D.new()
	var body_shape: CapsuleShape2D = CapsuleShape2D.new()
	body_shape.radius = 22.0 if enemy_kind == "group" else 26.0
	body_shape.height = 68.0 if enemy_kind == "group" else 78.0
	collision_shape.shape = body_shape
	collision_shape.position = Vector2(0.0, -27.0)
	add_child(collision_shape)
	queue_redraw()


func _physics_process(delta: float) -> void:
	_flash_remaining = maxf(_flash_remaining - delta, 0.0)
	_slow_remaining = maxf(_slow_remaining - delta, 0.0)
	_stagger_remaining = maxf(_stagger_remaining - delta, 0.0)
	if not _simulation_enabled or phase == Phase.DEFEATED or not is_instance_valid(_target):
		velocity = Vector2.ZERO
		queue_redraw()
		return
	if _target.is_dead():
		velocity = Vector2.ZERO
		queue_redraw()
		return
	match phase:
		Phase.APPROACH:
			_process_approach()
		Phase.TELEGRAPH:
			velocity = Vector2.ZERO
			_tick_phase(delta, Phase.STRIKE, STRIKE_SECONDS)
		Phase.STRIKE:
			velocity = Vector2.ZERO
			if not _strike_applied:
				_apply_strike()
			_tick_phase(delta, Phase.RECOVER, RECOVERY_SECONDS)
		Phase.RECOVER:
			velocity = Vector2.ZERO
			_tick_phase(delta, Phase.APPROACH)
		_:
			velocity = Vector2.ZERO
	queue_redraw()


func set_target(target: BeltPlayer) -> void:
	_target = target


func set_simulation_enabled(enabled: bool) -> void:
	_simulation_enabled = enabled and health > 0
	if not _simulation_enabled:
		velocity = Vector2.ZERO
		if phase != Phase.DEFEATED:
			_set_phase(Phase.INACTIVE)
	elif phase == Phase.INACTIVE:
		_set_phase(Phase.APPROACH)


func reset_enemy() -> void:
	_status_epoch += 1
	health = maximum_health
	global_position = _spawn_position
	velocity = Vector2.ZERO
	facing = Vector2.LEFT
	_strike_applied = false
	_flash_remaining = 0.0
	_slow_remaining = 0.0
	_stagger_remaining = 0.0
	_set_phase(Phase.INACTIVE)
	queue_redraw()


func clear_transient_status() -> void:
	_status_epoch += 1
	_slow_remaining = 0.0
	_stagger_remaining = 0.0


## Provider-free QA helper; gameplay damage continues to use take_damage().
func qa_set_health(value: int) -> void:
	health = clampi(value, 0, maximum_health)
	if health == 0:
		_simulation_enabled = false
		_set_phase(Phase.DEFEATED)
	elif phase == Phase.DEFEATED:
		_set_phase(Phase.APPROACH if _simulation_enabled else Phase.INACTIVE)
	queue_redraw()


func take_damage(
	amount: int,
	status_effect: String = "none",
	attack_pattern: String = "melee_slash",
	hit_direction: Vector2 = Vector2.RIGHT,
) -> int:
	if phase == Phase.DEFEATED or amount <= 0:
		return 0
	var actual: int = maxi(amount, 1)
	var note: String = status_effect.to_upper()
	var frontal_hit: bool = (
		enemy_kind == "shield"
		and hit_direction.length_squared() > 0.001
		and hit_direction.normalized().dot(-facing) > 0.45
	)
	var bypasses_shield: bool = attack_pattern in ["piercing", "area_blast"]
	if attack_pattern == "boomerang" and hit_direction.normalized().dot(-facing) <= 0.45:
		bypasses_shield = true
	if frontal_hit and not bypasses_shield:
		actual = maxi(1, ceili(float(actual) * 0.2))
		note = "SHIELD BLOCK"
	match status_effect:
		"freeze":
			_slow_remaining = 1.4
			note = _append_note(note, "SLOWED")
		"shock":
			_stagger_remaining = 0.55
			note = _append_note(note, "STAGGER")
		"knockback":
			var knock_direction: Vector2 = hit_direction.normalized()
			global_position += knock_direction * 18.0
			_clamp_to_arena()
		"burn":
			_apply_burn(_status_epoch)
	health = maxi(health - actual, 0)
	_flash_remaining = 0.16
	damage_report.emit(self, actual, note)
	if health == 0:
		_simulation_enabled = false
		velocity = Vector2.ZERO
		_set_phase(Phase.DEFEATED)
		defeated.emit(self)
	queue_redraw()
	return actual


func is_defeated() -> bool:
	return phase == Phase.DEFEATED or health <= 0


func phase_name() -> String:
	return Phase.keys()[phase].to_lower()


func hit_radius() -> float:
	return 22.0 if enemy_kind == "group" else BODY_RADIUS


func qa_state() -> Dictionary:
	return {
		"id": enemy_id,
		"kind": enemy_kind,
		"health": health,
		"max_health": maximum_health,
		"phase": phase_name(),
		"phase_remaining": _phase_remaining,
		"simulation_enabled": _simulation_enabled,
		"position": {"x": global_position.x, "y": global_position.y},
		"velocity": {"x": velocity.x, "y": velocity.y},
		"facing": {"x": facing.x, "y": facing.y},
		"slow_remaining": _slow_remaining,
		"stagger_remaining": _stagger_remaining,
	}


func _process_approach() -> void:
	if _stagger_remaining > 0.0:
		velocity = Vector2.ZERO
		return
	var desired_position: Vector2 = _target.global_position + _formation_offset
	var offset: Vector2 = desired_position - global_position
	var distance: float = offset.length()
	if distance <= ATTACK_DISTANCE:
		facing = global_position.direction_to(_target.global_position)
		if facing.length_squared() <= 0.001:
			facing = Vector2.LEFT
		_set_phase(Phase.TELEGRAPH, TELEGRAPH_SECONDS)
		return
	var speed_scale: float = 0.35 if _slow_remaining > 0.0 else 1.0
	var kind_scale: float = 1.12 if enemy_kind == "moving" else (0.82 if enemy_kind == "shield" else 0.96)
	var move_direction: Vector2 = offset.normalized()
	facing = global_position.direction_to(_target.global_position)
	velocity = move_direction * BASE_APPROACH_SPEED * kind_scale * speed_scale
	move_and_slide()
	_clamp_to_arena()


func _tick_phase(delta: float, next_phase: Phase, next_duration: float = 0.0) -> void:
	_phase_remaining = maxf(_phase_remaining - delta, 0.0)
	if _phase_remaining <= 0.0:
		_set_phase(next_phase, next_duration)


func _apply_strike() -> void:
	_strike_applied = true
	var offset: Vector2 = _target.global_position - global_position
	var actual: int = 0
	if offset.length() <= STRIKE_LEASH:
		actual = _target.take_damage(STRIKE_DAMAGE)
	if actual > 0:
		strike_landed.emit(self, actual)


func _set_phase(next_phase: Phase, duration: float = 0.0) -> void:
	if phase == next_phase and is_equal_approx(_phase_remaining, duration):
		return
	phase = next_phase
	_phase_remaining = duration
	if phase == Phase.STRIKE:
		_strike_applied = false
	phase_changed.emit(self, phase_name(), duration)
	queue_redraw()


func _apply_burn(epoch: int) -> void:
	for tick: int in 2:
		await get_tree().create_timer(0.42).timeout
		if not is_instance_valid(self) or epoch != _status_epoch or is_defeated():
			return
		var burn_damage: int = mini(3, health)
		health -= burn_damage
		damage_report.emit(self, burn_damage, "BURN %d/2" % (tick + 1))
		if health == 0:
			_simulation_enabled = false
			velocity = Vector2.ZERO
			_set_phase(Phase.DEFEATED)
			defeated.emit(self)
			return
		queue_redraw()


func _append_note(existing: String, addition: String) -> String:
	return addition if existing.is_empty() or existing == "NONE" else "%s / %s" % [existing, addition]


func _clamp_to_arena() -> void:
	clamp_to_arena()


func clamp_to_arena() -> void:
	global_position = Vector2(
		clampf(
			global_position.x,
			arena_bounds.position.x + ARENA_SIDE_MARGIN,
			arena_bounds.end.x - ARENA_SIDE_MARGIN,
		),
		clampf(
			global_position.y,
			arena_bounds.position.y + ARENA_HEAD_MARGIN,
			arena_bounds.end.y - ARENA_FOOT_MARGIN,
		),
	)


func _draw() -> void:
	var defeated_color: Color = Color("#4a4050")
	var palette: Color = {
		"moving": Color("#71d6bc"),
		"shield": Color("#9a8cff"),
		"group": Color("#ff8fa4"),
	}.get(enemy_kind, Color("#d493a9"))
	var body_color: Color = defeated_color if is_defeated() else (Color("#fff4cf") if _flash_remaining > 0.0 else palette)
	var body_scale: float = 0.82 if enemy_kind == "group" else 1.0
	draw_ellipse(
		Vector2(0.0, 18.0),
		28.0 * body_scale,
		8.0 * body_scale,
		Color("#03070d", 0.34),
	)
	if phase == Phase.TELEGRAPH:
		var pulse: float = 1.0 + 0.08 * sin(Time.get_ticks_msec() * 0.025)
		draw_circle(Vector2(0.0, -24.0), 38.0 * body_scale * pulse, Color("#ffbf69", 0.25))
	draw_circle(Vector2(0.0, -38.0 * body_scale), 25.0 * body_scale, body_color)
	draw_rect(
		Rect2(-22.0 * body_scale, -20.0 * body_scale, 44.0 * body_scale, 54.0 * body_scale),
		body_color,
		true,
	)
	var facing_vector: Vector2 = facing.normalized() if facing.length_squared() > 0.001 else Vector2.LEFT
	var arm_length: float = 48.0 if phase == Phase.STRIKE else 29.0
	draw_line(
		Vector2(facing_vector.x * 12.0, -8.0),
		Vector2(facing_vector.x * arm_length, -8.0 + facing_vector.y * arm_length * 0.45),
		Color("#d493a9"),
		9.0 * body_scale,
		true,
	)
	if enemy_kind == "shield":
		var shield_center: Vector2 = facing_vector * 31.0 + Vector2(0.0, -12.0)
		var shield_angle: float = facing_vector.angle()
		draw_arc(shield_center, 32.0, shield_angle - 1.1, shield_angle + 1.1, 18, Color("#d7d0ff"), 9.0, true)
	draw_rect(Rect2(-35.0, -76.0, 70.0, 7.0), Color("#17243b"), true)
	draw_rect(
		Rect2(-34.0, -75.0, 68.0 * float(health) / float(maximum_health), 5.0),
		Color("#ff879d"),
		true,
	)
