class_name WebMobileBridge
extends RefCounted

signal description_event(kind: String, value: String, revision: int, composing: bool)
signal viewport_changed
signal qa_command(command: String, payload: Dictionary)

var _description_callback: Variant
var _viewport_callback: Variant
var _qa_callback: Variant
var _initialized := false


func initialize() -> void:
	if not OS.has_feature("web") or _initialized:
		return
	_description_callback = JavaScriptBridge.create_callback(_on_description_event)
	_viewport_callback = JavaScriptBridge.create_callback(_on_viewport_event)
	_qa_callback = JavaScriptBridge.create_callback(_on_qa_event)
	var browser_window: JavaScriptObject = JavaScriptBridge.get_interface("window")
	browser_window.__forgeGodotDescriptionCallback = _description_callback
	browser_window.__forgeGodotViewportCallback = _viewport_callback
	browser_window.__forgeGodotQaCallback = _qa_callback
	JavaScriptBridge.eval("window.__forgeInstallMobileInput && window.__forgeInstallMobileInput();", true)
	_initialized = true


func is_available() -> bool:
	return OS.has_feature("web") and _initialized


func metrics() -> Dictionary:
	if not is_available():
		return {}
	var encoded: Variant = JavaScriptBridge.eval(
		"window.__forgeMobileInput ? JSON.stringify(window.__forgeMobileInput.metrics()) : '{}'",
		true,
	)
	var parsed: Variant = JSON.parse_string(str(encoded))
	return parsed if parsed is Dictionary else {}


func set_value(value: String) -> void:
	if not is_available():
		return
	JavaScriptBridge.eval(
		"window.__forgeMobileInput && window.__forgeMobileInput.setValue(%s);" % JSON.stringify(value),
		true,
	)


func value() -> String:
	if not is_available():
		return ""
	return str(JavaScriptBridge.eval(
		"window.__forgeMobileInput ? window.__forgeMobileInput.value() : ''",
		true,
	))


func description_snapshot() -> Dictionary:
	if not is_available():
		return {"value": "", "revision": -1, "composing": false, "connected": false}
	var encoded: Variant = JavaScriptBridge.eval(
		"window.__forgeMobileInput ? JSON.stringify(window.__forgeMobileInput.snapshot()) : '{}'",
		true,
	)
	var parsed: Variant = JSON.parse_string(str(encoded))
	return parsed if parsed is Dictionary else {"value": "", "revision": -1, "composing": false, "connected": false}


func commit_for_request() -> void:
	if is_available():
		JavaScriptBridge.eval("window.__forgeMobileInput && window.__forgeMobileInput.commitForRequest();", true)


func focus() -> void:
	if is_available():
		JavaScriptBridge.eval("window.__forgeMobileInput && window.__forgeMobileInput.focus();", true)


func blur() -> void:
	if is_available():
		JavaScriptBridge.eval("window.__forgeMobileInput && window.__forgeMobileInput.blur();", true)


func update_layout(input_rect: Rect2, logical_size: Vector2, visible: bool) -> void:
	if not is_available():
		return
	var payload := {
		"x": input_rect.position.x,
		"y": input_rect.position.y,
		"width": input_rect.size.x,
		"height": input_rect.size.y,
		"logicalWidth": logical_size.x,
		"logicalHeight": logical_size.y,
		"visible": visible,
	}
	JavaScriptBridge.eval(
		"window.__forgeMobileInput && window.__forgeMobileInput.updateLayout(%s);" % JSON.stringify(payload),
		true,
	)


func update_qa_state(state: Dictionary, controls: Dictionary, logical_size: Vector2) -> void:
	if not is_available():
		return
	var payload := {
		"state": state,
		"controls": controls,
		"logicalWidth": logical_size.x,
		"logicalHeight": logical_size.y,
	}
	JavaScriptBridge.eval(
		"window.__forgeM1B1Test && window.__forgeM1B1Test._update(%s);" % JSON.stringify(payload),
		true,
	)


func _on_description_event(arguments: Array) -> void:
	if arguments.is_empty():
		return
	var kind := str(arguments[0])
	var input_value := str(arguments[1]) if arguments.size() > 1 else ""
	var revision := int(arguments[2]) if arguments.size() > 2 else -1
	var composing := bool(arguments[3]) if arguments.size() > 3 else false
	description_event.emit(kind, input_value, revision, composing)


func _on_viewport_event(_arguments: Array) -> void:
	viewport_changed.emit()


func _on_qa_event(arguments: Array) -> void:
	if arguments.is_empty():
		return
	var command := str(arguments[0])
	var payload: Dictionary = {}
	if arguments.size() > 1:
		var parsed: Variant = JSON.parse_string(str(arguments[1]))
		if parsed is Dictionary:
			payload = parsed
	qa_command.emit(command, payload)
