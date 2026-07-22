class_name ForgeSlashEffect
extends Node2D

var color := Color.WHITE
var direction := Vector2.RIGHT
var reach := 92.0
var lifetime := 0.30
var _elapsed := 0.0


func _process(delta: float) -> void:
	_elapsed += delta
	queue_redraw()
	if _elapsed > lifetime: queue_free()


func _draw() -> void:
	var alpha := 1.0 - clampf(_elapsed / maxf(lifetime, 0.001), 0.0, 1.0)
	var facing := 1.0 if direction.x >= 0.0 else -1.0
	var start := -1.15 if facing > 0 else PI + 1.15
	var finish := 0.75 if facing > 0 else PI - 0.75
	draw_arc(Vector2.ZERO, reach, start, finish, 28, Color(color, 0.22 * alpha), 19.0, true)
	draw_arc(Vector2.ZERO, reach, start, finish, 28, Color(color, alpha), 6.0, true)
