class_name CombatEnemy
extends TrainingDummy

## Stable state transition/event stream for UI and QA.
signal combat_event(kind: String, detail: Dictionary)
## Emitted only when the committed strike deals player damage.
signal strike_landed(amount: int)

enum AttackState {
	INACTIVE,
	APPROACH,
	TELEGRAPH,
	STRIKE,
	RECOVER,
	DEFEATED,
}

const APPROACH_SPEED := 96.0
const ATTACK_DISTANCE := 82.0
const LEASH_DISTANCE := 118.0
const TELEGRAPH_SECONDS := 0.62
const STRIKE_SECONDS := 0.22
const RECOVERY_SECONDS := 0.78
const STRIKE_DAMAGE := 20

var attack_state: AttackState = AttackState.INACTIVE
var _player: ForgePlayer
var _state_time_remaining: float = 0.0
var _simulation_enabled: bool = false
var _strike_applied: bool = false
var _facing: float = -1.0
var _event_sequence: int = 0


func configure_combat_enemy(maximum_health: int = 140) -> void:
	configure("combat_enemy", "INKBEAST", maximum_health)


func set_target(player_target: ForgePlayer) -> void:
	_player = player_target


func _ready() -> void:
	super._ready()
	collision_layer = 10
	collision_mask = 1
	_diagnostic_labels_visible = false
	set_physics_process(true)


func set_simulation_enabled(enabled: bool) -> void:
	_simulation_enabled = enabled and health > 0
	if not _simulation_enabled:
		velocity = Vector2.ZERO
		if attack_state != AttackState.DEFEATED:
			_set_state(AttackState.INACTIVE)
	elif attack_state == AttackState.INACTIVE:
		_set_state(AttackState.APPROACH)


func set_presentation_active(active: bool, show_diagnostics: bool) -> void:
	super.set_presentation_active(active, show_diagnostics)
	collision_layer = 10 if active else 0
	collision_mask = 1 if active else 0
	if not active:
		set_simulation_enabled(false)


func reset_combat(arena_position: Vector2) -> void:
	reset_target()
	set_arena_position(arena_position)
	_strike_applied = false
	_facing = -1.0
	_set_state(AttackState.INACTIVE)
	queue_redraw()


func _physics_process(delta: float) -> void:
	_flash = maxf(_flash - delta, 0.0)
	_slow_timer = maxf(_slow_timer - delta, 0.0)
	_stagger_timer = maxf(_stagger_timer - delta, 0.0)
	if not _simulation_enabled or attack_state == AttackState.DEFEATED or not is_instance_valid(_player):
		velocity = Vector2.ZERO
		queue_redraw()
		return
	if _player.is_dead:
		velocity = Vector2.ZERO
		queue_redraw()
		return
	var horizontal_gap: float = absf(_player.global_position.x - global_position.x)
	match attack_state:
		AttackState.APPROACH:
			if horizontal_gap <= ATTACK_DISTANCE:
				_begin_telegraph()
			else:
				_facing = signf(_player.global_position.x - global_position.x)
				velocity = Vector2(_facing * APPROACH_SPEED, 0.0)
				move_and_slide()
		AttackState.TELEGRAPH:
			velocity = Vector2.ZERO
			_state_time_remaining = maxf(_state_time_remaining - delta, 0.0)
			if _state_time_remaining <= 0.0:
				_begin_strike()
		AttackState.STRIKE:
			velocity = Vector2.ZERO
			if not _strike_applied:
				_apply_strike()
			_state_time_remaining = maxf(_state_time_remaining - delta, 0.0)
			if _state_time_remaining <= 0.0:
				_set_state(AttackState.RECOVER, RECOVERY_SECONDS)
		AttackState.RECOVER:
			velocity = Vector2.ZERO
			_state_time_remaining = maxf(_state_time_remaining - delta, 0.0)
			if _state_time_remaining <= 0.0:
				_set_state(AttackState.APPROACH)
		_:
			velocity = Vector2.ZERO
	queue_redraw()


func _begin_telegraph() -> void:
	_facing = signf(_player.global_position.x - global_position.x)
	if is_zero_approx(_facing):
		_facing = -1.0
	_set_state(AttackState.TELEGRAPH, TELEGRAPH_SECONDS)


func _begin_strike() -> void:
	_strike_applied = false
	_set_state(AttackState.STRIKE, STRIKE_SECONDS)


func _apply_strike() -> void:
	_strike_applied = true
	var horizontal_gap: float = absf(_player.global_position.x - global_position.x)
	var vertical_gap: float = absf(_player.global_position.y - global_position.y)
	var in_range: bool = horizontal_gap <= LEASH_DISTANCE and vertical_gap <= 72.0
	var actual: int = _player.take_damage(STRIKE_DAMAGE) if in_range else 0
	if actual > 0:
		strike_landed.emit(actual)
		_emit_combat_event("strike_hit", {"amount": actual, "player_health": _player.health})
	else:
		_emit_combat_event("strike_miss", {"horizontal_gap": horizontal_gap})


func _apply_damage(amount: int, note: String) -> void:
	if attack_state == AttackState.DEFEATED or amount <= 0:
		return
	health = maxi(health - amount, 0)
	_flash = 0.16
	_status_text = "-%d  %s" % [amount, note]
	health_changed.emit(health, max_health)
	if health == 0:
		_simulation_enabled = false
		velocity = Vector2.ZERO
		_set_state(AttackState.DEFEATED)
		defeated.emit()
	queue_redraw()


func reset_target() -> void:
	super.reset_target()
	_strike_applied = false
	_set_state(AttackState.INACTIVE)


func qa_state() -> Dictionary:
	var state: Dictionary = super.qa_state()
	state.merge({
		"attack_state": state_name(),
		"state_time_remaining": _state_time_remaining,
		"simulation_enabled": _simulation_enabled,
		"strike_applied": _strike_applied,
		"facing": _facing,
		"event_sequence": _event_sequence,
		"attack_distance": ATTACK_DISTANCE,
		"telegraph_seconds": TELEGRAPH_SECONDS,
		"strike_seconds": STRIKE_SECONDS,
		"recovery_seconds": RECOVERY_SECONDS,
		"strike_damage": STRIKE_DAMAGE,
		"collision_layer": collision_layer,
		"collision_mask": collision_mask,
	}, true)
	return state


func state_name() -> String:
	return AttackState.keys()[attack_state].to_lower()


func _set_state(next_state: int, duration: float = 0.0) -> void:
	if attack_state == next_state and is_equal_approx(_state_time_remaining, duration):
		return
	attack_state = next_state
	_state_time_remaining = duration
	_emit_combat_event("enemy_state", {"state": state_name(), "duration": duration})
	queue_redraw()


func _emit_combat_event(kind: String, detail: Dictionary) -> void:
	_event_sequence += 1
	var event_detail: Dictionary = detail.duplicate(true)
	event_detail["sequence"] = _event_sequence
	event_detail["state"] = state_name()
	combat_event.emit(kind, event_detail)


func _draw() -> void:
	var body_color: Color = Color("#f5e8c8") if _flash > 0.0 else Color("#9c5d78")
	if attack_state == AttackState.DEFEATED:
		body_color = Color("#4a4050")
	var pulse: float = 1.0
	if attack_state == AttackState.TELEGRAPH:
		pulse = 1.0 + 0.10 * sin(Time.get_ticks_msec() * 0.025)
	draw_circle(Vector2(0.0, -20.0), 34.0 * pulse, Color("#ffbf69", 0.24) if attack_state == AttackState.TELEGRAPH else Color.TRANSPARENT)
	draw_circle(Vector2(0.0, -20.0), 29.0, body_color)
	draw_circle(Vector2(-12.0 * _facing, -27.0), 4.0, Color("#111827"))
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(-26.0, 4.0),
			Vector2(26.0, 4.0),
			Vector2(20.0, 43.0),
			Vector2(-20.0, 43.0),
		]),
		body_color,
	)
	var arm_reach: float = 50.0 if attack_state == AttackState.STRIKE else 30.0
	draw_line(Vector2(18.0 * _facing, 2.0), Vector2(arm_reach * _facing, -4.0), Color("#d493a9"), 10.0, true)
	draw_rect(Rect2(-42.0, -76.0, 84.0, 8.0), Color("#17243b"), true)
	draw_rect(Rect2(-40.0, -74.0, 80.0 * float(health) / maxf(float(max_health), 1.0), 4.0), Color("#ff879d"), true)
	var state_color: Color = Color("#ffd166") if attack_state == AttackState.TELEGRAPH else Color("#edf4ff")
	draw_string(
		ThemeDB.fallback_font,
		Vector2(-66.0, 68.0),
		state_name().replace("_", " ").to_upper(),
		HORIZONTAL_ALIGNMENT_CENTER,
		132.0,
		12,
		state_color,
	)
