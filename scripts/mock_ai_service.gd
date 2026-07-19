class_name MockAIService
extends WeaponCompiler

# Compatibility boundary retained for M0 callers. M1A behavior lives in WeaponCompiler.
var last_metadata: Dictionary = {}


func generate(description: String, drawing_summary: Dictionary) -> WeaponSpec:
	var spec := compile(description, drawing_summary)
	last_metadata = last_record.duplicate(true)
	last_metadata.attack_pattern = spec.attack_pattern
	return spec
