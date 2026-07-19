class_name TrainingDummy
extends CharacterBody2D

signal health_changed(current: int, maximum: int)
signal defeated

const MAX_HEALTH := 160

var health := MAX_HEALTH
var _flash := 0.0
var _status_text := "READY"
var _resetting := false


func _ready() -> void:
	collision_layer = 2
	collision_mask = 0
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(72, 112)
	collider.shape = shape
	collider.position = Vector2(0, -8)
	add_child(collider)
	queue_redraw()


func _process(delta: float) -> void:
	if _flash > 0.0:
		_flash = maxf(_flash - delta, 0.0)
		queue_redraw()


func take_damage(amount: int, status_effect: String = "none") -> void:
	if _resetting:
		return
	health = maxi(health - maxi(amount, 1), 0)
	_flash = 0.16
	_status_text = ("-%d  %s" % [amount, status_effect.to_upper()])
	health_changed.emit(health, MAX_HEALTH)
	queue_redraw()
	if health == 0:
		_resetting = true
		_status_text = "DUMMY DOWN"
		defeated.emit()
		_reset_after_delay()


func _reset_after_delay() -> void:
	await get_tree().create_timer(1.15).timeout
	health = MAX_HEALTH
	_resetting = false
	_status_text = "RESET"
	health_changed.emit(health, MAX_HEALTH)
	queue_redraw()


func _draw() -> void:
	var body_color := Color("#ff6b6b") if _flash > 0.0 else Color("#e4a75f")
	draw_line(Vector2(0, 50), Vector2(0, 72), Color("#835a3d"), 12.0, true)
	draw_line(Vector2(-26, 72), Vector2(26, 72), Color("#835a3d"), 10.0, true)
	draw_rect(Rect2(-32, -50, 64, 100), body_color, true)
	draw_rect(Rect2(-25, -42, 50, 86), Color(body_color, 0.35), false, 3.0)
	draw_line(Vector2(-44, -24), Vector2(44, 18), Color("#5a3e2b"), 7.0, true)
	draw_circle(Vector2(0, -72), 27.0, body_color)
	draw_circle(Vector2(-9, -76), 3.0, Color("#39281f"))
	draw_circle(Vector2(9, -76), 3.0, Color("#39281f"))
	draw_rect(Rect2(-48, -116, 96, 10), Color("#17243b"), true)
	draw_rect(Rect2(-46, -114, 92.0 * float(health) / MAX_HEALTH, 6), Color("#60e69a"), true)
	draw_string(ThemeDB.fallback_font, Vector2(-70, -126), "TRAINING DUMMY", HORIZONTAL_ALIGNMENT_CENTER, 140, 14, Color("#f2dfc7"))
	draw_string(ThemeDB.fallback_font, Vector2(-70, 100), _status_text, HORIZONTAL_ALIGNMENT_CENTER, 140, 14, Color("#f2dfc7"))
