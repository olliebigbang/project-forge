class_name WeaponInterpreter
extends Node

signal interpretation_started(request_id: String)
signal interpretation_completed(result: Dictionary)
signal interpretation_cancelled(request_id: String)

const ENDPOINT_PATH := "/api/compile-weapon"
const REQUEST_TIMEOUT_SECONDS := 10.0
const UNKNOWN_COST := "UNKNOWN"

var in_flight := false
var request_count := 0
var attempts := 0
var active_request_id := ""
var last_result: Dictionary = {}
var test_scenario := "success"
var test_options: Dictionary = {}
var test_mode_enabled := false
var force_local := false
var late_response_ignored := 0

var _http_request: HTTPRequest
var _compiler := WeaponCompiler.new()
var _crypto := Crypto.new()
var _session_id := ""
var _request_revision := 0
var _active_payload: Dictionary = {}
var _active_test_options: Dictionary = {}
var _started_msec := 0


func _ready() -> void:
	_session_id = _random_token(16)


func start_interpretation(
	description: String,
	drawing_summary: Dictionary,
	locale: String = "und",
	scenario: String = "",
) -> String:
	if in_flight:
		return ""
	request_count += 1
	attempts = 1
	_request_revision += 1
	_started_msec = Time.get_ticks_msec()
	active_request_id = "m1b1-%s" % _random_token(16)
	_active_payload = {
		"description": description,
		"drawing_summary": _normalize_drawing_summary(drawing_summary),
		"locale": locale.left(16),
		"request_id": active_request_id,
		"supported_attack_patterns": Array(WeaponSpec.ATTACK_PATTERNS),
		"supported_elements": Array(WeaponSpec.ELEMENTS),
		"supported_abilities": Array(WeaponSpec.SPECIAL_ABILITIES),
		"maximum_power_score": PowerBudget.MAX_POWER,
	}
	var selected_scenario := scenario if not scenario.is_empty() else test_scenario
	_active_test_options = test_options.duplicate(true)
	if selected_scenario != "success":
		_active_payload.test_scenario = selected_scenario
	in_flight = true
	interpretation_started.emit(active_request_id)

	if force_local or test_mode_enabled or not OS.has_feature("web") or selected_scenario != "success":
		call_deferred("_complete_local", _request_revision, selected_scenario)
		return active_request_id

	var endpoint := _resolve_endpoint()
	if endpoint.is_empty():
		call_deferred("_complete_with_fallback", _request_revision, "backend_unavailable")
		return active_request_id
	var request_revision := _request_revision
	var request_id := active_request_id
	var request_node := HTTPRequest.new()
	request_node.name = "WeaponInterpreterHttp_%d" % request_revision
	request_node.timeout = REQUEST_TIMEOUT_SECONDS
	add_child(request_node)
	_http_request = request_node
	request_node.request_completed.connect(
		_on_http_request_completed.bind(request_revision, request_id, request_node),
		CONNECT_ONE_SHOT,
	)
	var headers := PackedStringArray([
		"Content-Type: application/json",
		"Accept: application/json",
		"X-Forge-Session: %s" % _session_id,
	])
	var error := request_node.request(
		endpoint,
		headers,
		HTTPClient.METHOD_POST,
		JSON.stringify(_active_payload),
	)
	if error != OK:
		_release_http_request(request_node)
		call_deferred("_complete_with_fallback", _request_revision, "network_unavailable")
	return active_request_id


func cancel() -> bool:
	if not in_flight:
		return false
	var cancelled_request := active_request_id
	# The active revision is invalidated before either the local timer or HTTP
	# callback can publish. Count that discarded work immediately for QA/audit.
	late_response_ignored += 1
	_request_revision += 1
	in_flight = false
	active_request_id = ""
	_active_payload = {}
	_active_test_options = {}
	if _http_request != null:
		var request_node := _http_request
		_http_request = null
		request_node.cancel_request()
		request_node.queue_free()
	interpretation_cancelled.emit(cancelled_request)
	return true


func set_test_scenario(value: String, options: Dictionary = {}) -> void:
	var allowed := [
		"success", "delayed_success", "timeout", "network_error", "rate_limit",
		"invalid_json", "missing_fields", "unsupported_ability", "backend_unavailable",
	]
	test_scenario = value if value in allowed else "success"
	test_options = options.duplicate(true)
	test_mode_enabled = true


func _complete_local(revision: int, scenario: String) -> void:
	var default_delay_ms := 900 if scenario == "delayed_success" else 80
	var delay_ms := clampi(int(_active_test_options.get("delay_ms", default_delay_ms)), 20, 3000)
	if scenario == "delayed_success":
		delay_ms = maxi(delay_ms, 2500)
	var delay := float(delay_ms) / 1000.0
	await get_tree().create_timer(delay).timeout
	if revision != _request_revision or not in_flight:
		late_response_ignored += 1
		return
	var fallback_by_scenario := {
		"timeout": "provider_timeout",
		"network_error": "network_unavailable",
		"rate_limit": "provider_rate_limited",
		"invalid_json": "invalid_provider_response",
		"missing_fields": "invalid_provider_response",
		"backend_unavailable": "backend_unavailable",
	}
	if scenario in fallback_by_scenario:
		attempts = 2 if scenario in ["timeout", "network_error", "rate_limit", "backend_unavailable"] else 1
		_complete_with_fallback(revision, fallback_by_scenario[scenario])
		return
	if scenario == "unsupported_ability":
		var repaired := _compiler.compile_raw({
			"name": "Unsafe Provider Result",
			"weapon_class": "admin",
			"attack_pattern": "teleport_strike",
			"element": "plasma",
			"damage": 999999,
			"attack_speed": 999.0,
			"range": 99999.0,
			"special_ability": "orbital_laser",
			"status_effect": "permanent_stun",
			"drawback": "none",
			"visual_material": "script",
			"power_score": 999,
			"projectile_speed": 9999.0,
			"area_radius": 9999.0,
			"pierce_count": 999,
			"return_speed": 9999.0,
		})
		var repaired_result := _result_from_spec(
			repaired,
			"Unsupported provider fields were repaired to a safe executable weapon.",
			0.1,
			"provider_output_repaired",
			{"provider": "deterministic_client_test", "model": "fault-injection", "attempts": 1},
			UNKNOWN_COST,
		)
		repaired_result.corrections.append("client: unsupported provider output repaired")
		_finish(revision, repaired_result)
		return

	var spec := _compiler.compile(
		str(_active_payload.description),
		_active_payload.drawing_summary,
		"",
		true,
	)
	var result := _result_from_spec(
		spec,
		_interpretation_summary(spec),
		0.72,
		str(_compiler.last_record.get("fallback_reason", "")),
		{"provider": "deterministic_client", "model": "m1b1-local-fallback", "attempts": 1},
		UNKNOWN_COST,
	)
	result.corrections.assign(spec.corrections)
	_finish(revision, result)


func _on_http_request_completed(
	result_code: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray,
	revision: int,
	expected_request_id: String,
	request_node: HTTPRequest,
) -> void:
	_release_http_request(request_node)
	if (
		revision != _request_revision
		or expected_request_id != active_request_id
		or not in_flight
	):
		late_response_ignored += 1
		return
	if result_code != HTTPRequest.RESULT_SUCCESS:
		var reason := "provider_timeout" if result_code == HTTPRequest.RESULT_TIMEOUT else "network_unavailable"
		_complete_with_fallback(revision, reason)
		return
	if response_code < 200 or response_code >= 300:
		var reason := "provider_rate_limited" if response_code == 429 else "backend_unavailable"
		_complete_with_fallback(revision, reason)
		return
	var decoded: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not decoded is Dictionary:
		_complete_with_fallback(revision, "invalid_provider_response")
		return
	var validated := _validate_server_result(decoded, expected_request_id)
	if not bool(validated.get("ok", false)):
		_complete_with_fallback(revision, str(validated.get("reason", "invalid_provider_response")))
		return
	_finish(revision, validated.result)


func _validate_server_result(server_result: Dictionary, expected_request_id: String = "") -> Dictionary:
	var expected := expected_request_id if not expected_request_id.is_empty() else active_request_id
	if expected.is_empty() or expected != active_request_id:
		return {"ok": false, "reason": "stale_response"}
	if str(server_result.get("request_id", "")) != expected:
		return {"ok": false, "reason": "stale_response"}
	var raw_spec: Variant = server_result.get("weapon_spec")
	if not raw_spec is Dictionary:
		return {"ok": false, "reason": "invalid_provider_response"}
	var balanced := PowerBudget.balance(raw_spec)
	var spec := WeaponSpec.from_dict(balanced.values)
	spec.corrections.assign(balanced.corrections)
	spec.budget_breakdown = balanced.after.duplicate(true)
	var calculated := PowerBudget.calculate(spec.to_dict())
	var valid := (
		spec.is_valid()
		and bool(balanced.within_budget)
		and float(calculated.total) <= PowerBudget.MAX_POWER
		and spec.power_score == int(ceil(float(calculated.total)))
	)
	if not valid:
		return {"ok": false, "reason": "post_validation_failed"}

	var response := server_result.duplicate(true)
	response.weapon_spec = spec.to_dict()
	var corrections: Array[String] = []
	for correction: Variant in server_result.get("corrections", []):
		corrections.append(str(correction).left(240))
	for correction: String in balanced.corrections:
		corrections.append("client: %s" % correction)
	response.corrections = corrections
	response.power_budget = calculated
	response.schema_valid = true
	response.allow_list_valid = true
	response.power_valid = true
	response.runtime_valid = true
	response.interpretation_summary = str(response.get("interpretation_summary", _interpretation_summary(spec))).left(240)
	response.confidence = clampf(float(response.get("confidence", 0.0)), 0.0, 1.0)
	response.fallback_reason = str(response.get("fallback_reason", "")).left(64)
	response.estimated_cost = _sanitize_cost(response.get("estimated_cost", UNKNOWN_COST))
	response.provider_metadata = _sanitize_provider_metadata(response.get("provider_metadata", {}))
	response.latency_ms = maxi(int(response.get("latency_ms", Time.get_ticks_msec() - _started_msec)), 0)
	return {"ok": true, "result": response}


func _complete_with_fallback(revision: int, reason: String) -> void:
	if revision != _request_revision or not in_flight:
		return
	var balanced := PowerBudget.balance(WeaponSpec.fallback().to_dict())
	var spec := WeaponSpec.from_dict(balanced.values)
	spec.corrections.assign(balanced.corrections)
	spec.budget_breakdown = balanced.after.duplicate(true)
	var result := _result_from_spec(
		spec,
		"A safe practice weapon was substituted because the interpreter was unavailable.",
		0.0,
		reason,
		{"provider": "none", "model": "none", "attempts": attempts},
		UNKNOWN_COST,
	)
	result.corrections.push_front("fallback: %s" % reason)
	_finish(revision, result)


func _result_from_spec(
	spec: WeaponSpec,
	summary: String,
	confidence: float,
	fallback_reason: String,
	provider_metadata: Dictionary,
	estimated_cost: Variant,
) -> Dictionary:
	var calculated := PowerBudget.calculate(spec.to_dict())
	return {
		"request_id": active_request_id,
		"weapon_spec": spec.to_dict(),
		"interpretation_summary": summary.left(240),
		"confidence": clampf(confidence, 0.0, 1.0),
		"corrections": spec.corrections.duplicate(),
		"fallback_reason": fallback_reason,
		"provider_metadata": _sanitize_provider_metadata(provider_metadata),
		"latency": {
			"total_ms": maxi(Time.get_ticks_msec() - _started_msec, 0),
			"provider_ms": 0,
			"attempts": attempts,
		},
		"latency_ms": maxi(Time.get_ticks_msec() - _started_msec, 0),
		"estimated_cost": _sanitize_cost(estimated_cost),
		"power_budget": calculated,
		"schema_valid": spec.is_valid(),
		"allow_list_valid": spec.is_valid(),
		"power_valid": float(calculated.total) <= PowerBudget.MAX_POWER,
		"runtime_valid": (
			spec.is_valid()
			and float(calculated.total) <= PowerBudget.MAX_POWER
			and spec.power_score == int(ceil(float(calculated.total)))
		),
	}


func _finish(revision: int, result: Dictionary) -> void:
	if revision != _request_revision or not in_flight:
		return
	in_flight = false
	active_request_id = ""
	_active_payload = {}
	_active_test_options = {}
	last_result = result.duplicate(true)
	print("[WeaponInterpreter] ", JSON.stringify({
		"request_id": str(result.get("request_id", "")),
		"provider": str(result.get("provider_metadata", {}).get("provider", "unknown")),
		"attempts": int(result.get("provider_metadata", {}).get("attempts", attempts)),
		"latency_ms": int(result.get("latency_ms", 0)),
		"fallback_reason": str(result.get("fallback_reason", "")),
		"correction_count": result.get("corrections", []).size(),
		"estimated_cost": result.get("estimated_cost", UNKNOWN_COST),
		"runtime_valid": bool(result.get("runtime_valid", false)),
	}))
	interpretation_completed.emit(last_result)


func _resolve_endpoint() -> String:
	var configured := str(ProjectSettings.get_setting("project_forge/interpreter_endpoint", "")).strip_edges()
	if not configured.is_empty():
		return configured.trim_suffix("/") + ENDPOINT_PATH if not configured.ends_with(ENDPOINT_PATH) else configured
	if OS.has_feature("web"):
		var origin: Variant = JavaScriptBridge.eval("window.location.origin", true)
		if origin != null and str(origin).begins_with("http"):
			return str(origin).trim_suffix("/") + ENDPOINT_PATH
	return ""


func _release_http_request(request_node: HTTPRequest) -> void:
	if request_node == _http_request:
		_http_request = null
	if is_instance_valid(request_node) and not request_node.is_queued_for_deletion():
		request_node.queue_free()


func _random_token(byte_count: int) -> String:
	var random_bytes: PackedByteArray = _crypto.generate_random_bytes(byte_count)
	if random_bytes.size() == byte_count:
		return random_bytes.hex_encode()
	var fallback_seed := "%d:%d:%d" % [
		Time.get_unix_time_from_system(),
		Time.get_ticks_usec(),
		randi(),
	]
	return fallback_seed.sha256_text().left(byte_count * 2)


func _normalize_drawing_summary(value: Dictionary) -> Dictionary:
	var aspect := clampf(float(value.get("aspect_ratio", 1.0)), 0.05, 20.0)
	return {
		"stroke_count": clampi(int(value.get("stroke_count", 0)), 0, 256),
		"point_count": clampi(int(value.get("point_count", 0)), 0, 10000),
		"aspect_ratio": aspect,
		"coverage": clampf(float(value.get("coverage", 0.0)), 0.0, 1.0),
		"dominant_direction": "horizontal" if aspect >= 1.5 else ("vertical" if aspect <= 0.67 else "mixed"),
	}


func _sanitize_provider_metadata(value: Variant) -> Dictionary:
	var source: Dictionary = value if value is Dictionary else {}
	return {
		"provider": str(source.get("provider", "unknown")).left(48),
		"model": str(source.get("model", "unknown")).left(80),
		"attempts": clampi(int(source.get("attempts", attempts)), 0, 2),
	}


func _sanitize_cost(value: Variant) -> Variant:
	if value is String:
		return UNKNOWN_COST if str(value).to_upper() != UNKNOWN_COST else UNKNOWN_COST
	if value is Dictionary:
		var amount := float(value.get("amount", -1.0))
		if is_finite(amount) and amount >= 0.0:
			return {"amount": amount, "currency": str(value.get("currency", "USD")).left(8)}
	return UNKNOWN_COST


func _interpretation_summary(spec: WeaponSpec) -> String:
	return "Interpreted as a %s %s with %s and %s." % [
		spec.element,
		spec.attack_pattern.replace("_", " "),
		spec.status_effect.replace("_", " "),
		spec.special_ability.replace("_", " "),
	]
