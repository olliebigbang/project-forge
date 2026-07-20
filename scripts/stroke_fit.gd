class_name StrokeFit
extends RefCounted

const DEFAULT_PADDING := 0.10
const MIN_PADDING := 0.08
const MAX_PADDING := 0.12


static func duplicate_strokes(source: Array[PackedVector2Array]) -> Array[PackedVector2Array]:
	var output: Array[PackedVector2Array] = []
	for stroke in source:
		output.append(stroke.duplicate())
	return output


static func actual_bounds(source: Array[PackedVector2Array]) -> Rect2:
	var minimum := Vector2(INF, INF)
	var maximum := Vector2(-INF, -INF)
	var count := 0
	for stroke in source:
		for point in stroke:
			minimum = minimum.min(point)
			maximum = maximum.max(point)
			count += 1
	if count == 0:
		return Rect2()
	return Rect2(minimum, maximum - minimum)


static func has_points(source: Array[PackedVector2Array]) -> bool:
	for stroke in source:
		if not stroke.is_empty():
			return true
	return false


static func fit_transform(
	source: Array[PackedVector2Array],
	target: Rect2,
	padding_fraction: float = DEFAULT_PADDING,
	alignment: Vector2 = Vector2(0.5, 0.5),
) -> Dictionary:
	var bounds := actual_bounds(source)
	if not has_points(source) or target.size.x <= 0.0 or target.size.y <= 0.0:
		return {"valid": false, "scale": 1.0, "offset": target.get_center(), "source_bounds": bounds, "inner_rect": target}
	var padding := clampf(padding_fraction, MIN_PADDING, MAX_PADDING)
	var inset := target.size * padding
	var inner := Rect2(target.position + inset, target.size - inset * 2.0)
	var safe_source_size := Vector2(maxf(bounds.size.x, 0.001), maxf(bounds.size.y, 0.001))
	var uniform_scale := minf(inner.size.x / safe_source_size.x, inner.size.y / safe_source_size.y)
	var fitted_size := bounds.size * uniform_scale
	var aligned_position := inner.position + (inner.size - fitted_size) * alignment.clamp(Vector2.ZERO, Vector2.ONE)
	var offset := aligned_position - bounds.position * uniform_scale
	return {
		"valid": true,
		"scale": uniform_scale,
		"offset": offset,
		"source_bounds": bounds,
		"inner_rect": inner,
		"fitted_rect": Rect2(aligned_position, fitted_size),
		"padding_fraction": padding,
	}


static func map_strokes(
	source: Array[PackedVector2Array],
	target: Rect2,
	padding_fraction: float = DEFAULT_PADDING,
	alignment: Vector2 = Vector2(0.5, 0.5),
) -> Array[PackedVector2Array]:
	var transform := fit_transform(source, target, padding_fraction, alignment)
	if not bool(transform.valid):
		return []
	var output: Array[PackedVector2Array] = []
	var uniform_scale := float(transform.scale)
	var offset: Vector2 = transform.offset
	for stroke in source:
		var mapped := PackedVector2Array()
		for point in stroke:
			mapped.append(point * uniform_scale + offset)
		output.append(mapped)
	return output


static func normalize_preserving_aspect(source: Array[PackedVector2Array]) -> Array[PackedVector2Array]:
	var bounds := actual_bounds(source)
	if not has_points(source):
		return []
	var divisor := maxf(maxf(bounds.size.x, bounds.size.y), 0.001)
	var output: Array[PackedVector2Array] = []
	for stroke in source:
		var normalized := PackedVector2Array()
		for point in stroke:
			normalized.append((point - bounds.position) / divisor)
		output.append(normalized)
	return output


static func aspect_ratio(source: Array[PackedVector2Array]) -> float:
	var bounds := actual_bounds(source)
	return bounds.size.x / maxf(bounds.size.y, 0.001) if has_points(source) else 1.0
