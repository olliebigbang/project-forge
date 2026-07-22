class_name GeometryEvidence
extends RefCounted

# B0 authority layer: immutable evidence copied from the frozen FORGE snapshot.
# This layer describes geometry only. It never assigns combat stats or semantics.

var source_strokes: Array[PackedVector2Array] = []
var source_bounds := Rect2()
var canvas_size := Vector2.ONE
var normalized_length := 0.0
var normalized_cross_axis := 0.0
var ink_aspect := 1.0
var stroke_count := 0
var point_count := 0
var normalized_path_load := 0.0


static func from_snapshot(
	source: Array[PackedVector2Array],
	frozen_canvas_size: Vector2,
) -> GeometryEvidence:
	var evidence := GeometryEvidence.new()
	evidence.canvas_size = Vector2(maxf(frozen_canvas_size.x, 1.0), maxf(frozen_canvas_size.y, 1.0))
	var path_length := 0.0
	for stroke: PackedVector2Array in source:
		var frozen_stroke := stroke.duplicate()
		evidence.source_strokes.append(frozen_stroke)
		evidence.point_count += frozen_stroke.size()
		for index in range(1, frozen_stroke.size()):
			path_length += frozen_stroke[index - 1].distance_to(frozen_stroke[index])
	evidence.stroke_count = evidence.source_strokes.size()
	evidence.source_bounds = StrokeFit.actual_bounds(evidence.source_strokes)
	evidence.normalized_length = clampf(evidence.source_bounds.size.x / evidence.canvas_size.x, 0.0, 1.0)
	evidence.normalized_cross_axis = clampf(evidence.source_bounds.size.y / evidence.canvas_size.y, 0.0, 1.0)
	evidence.ink_aspect = evidence.source_bounds.size.x / maxf(evidence.source_bounds.size.y, 1.0)
	evidence.normalized_path_load = snappedf(clampf(path_length / evidence.canvas_size.x, 0.0, 8.0), 0.001)
	return evidence


func to_dict() -> Dictionary:
	return {
		"source_bounds": _rect_dict(source_bounds),
		"canvas_size": {"x": canvas_size.x, "y": canvas_size.y},
		"normalized_length": normalized_length,
		"normalized_cross_axis": normalized_cross_axis,
		"ink_aspect": ink_aspect,
		"stroke_count": stroke_count,
		"point_count": point_count,
		"normalized_path_load": normalized_path_load,
		"source_strokes_preserved": true,
		"authority": "GeometryEvidence",
	}


func _rect_dict(rect: Rect2) -> Dictionary:
	return {
		"x": rect.position.x,
		"y": rect.position.y,
		"width": rect.size.x,
		"height": rect.size.y,
	}
