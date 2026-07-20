class_name ProjectForgeMain
extends Control

const NAVY := Color("#091424")
const PANEL := Color("#12233b")
const PANEL_LIGHT := Color("#1a3150")
const TEXT := Color("#edf4ff")
const MUTED := Color("#9bb0cf")
const CYAN := Color("#65d9ff")
const ORANGE := Color("#ffb65c")
var service := MockAIService.new()
var interpreter: WeaponInterpreter
var world: Node2D
var player: ForgePlayer
var targets: Array[TrainingDummy] = []
var drawing_canvas: DrawingCanvas
var description_input: LineEdit
var clear_description_button: Button
var pattern_selector: AttackPatternSelector
var forge_overlay: Control
var forge_panel: PanelContainer
var forge_margin: MarginContainer
var forge_layout: VBoxContainer
var forge_title_row: HBoxContainer
var forge_title: Label
var back_button: Button
var description_row: HBoxContainer
var description_label: Label
var forge_action_row: HBoxContainer
var reset_button: Button
var load_idea_button: Button
var generate_button: Button
var cancel_button: Button
var review_panel: PanelContainer
var review_layout: VBoxContainer
var review_summary: Label
var review_details: Label
var review_visual_host: Control
var review_weapon_visual: WeaponVisual
var review_action_row: HBoxContainer
var confirm_button: Button
var modify_button: Button
var try_again_button: Button
var feedback_button: Button
var orientation_prompt: RotationPrompt
var forge_status: Label
var stats_label: Label
var budget_label: Label
var combat_status: Label
var target_health_label: Label
var reforge_button: Button
var attack_button: Button
var current_spec: WeaponSpec
var current_strokes: Array[PackedVector2Array] = []
var loaded_idea_pattern := ""
var pending_result: Dictionary = {}
var pending_spec: WeaponSpec
var last_request_snapshot: Dictionary = {}
var developer_mode := false
var modify_mode := false
var review_mode := false
var interpretation_error_mode := false
var request_strokes: Array[PackedVector2Array] = []
var web_mobile_bridge := WebMobileBridge.new()
var _description_draft := ""
var _last_web_description_revision := -1
var _web_description_composing := false
var _snapshot_in_progress := false
var _request_drawing_summary: Dictionary = {}
var _web_sync_elapsed := 0.0
var _last_stable_landscape_css_size := Vector2.ZERO
var _status_revision := 0
var _qa_attack_count := 0
var _qa_last_attack_pattern := ""
var _qa_projectile_origin := Vector2.ZERO
var _qa_area_impact_position := Vector2.ZERO
var _qa_has_projectile_origin := false
var _qa_has_area_impact := false
var _qa_feedback_count := 0
var _last_try_again_msec := -10000
var _review_ui_ready := false
var _combat_ui_ready := false
var _loading_ui_ready := false
var _developer_ui_ready := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	developer_mode = _detect_developer_mode()
	interpreter = WeaponInterpreter.new()
	interpreter.name = "WeaponInterpreter"
	interpreter.interpretation_started.connect(_on_interpretation_started)
	interpreter.interpretation_completed.connect(_on_interpretation_completed)
	interpreter.interpretation_cancelled.connect(_on_interpretation_cancelled)
	add_child(interpreter)
	_build_world()
	_build_hud()
	_build_forge_overlay()
	_build_orientation_prompt()
	web_mobile_bridge.description_event.connect(_on_web_description_event)
	web_mobile_bridge.viewport_changed.connect(_on_web_viewport_changed)
	web_mobile_bridge.qa_command.connect(_on_qa_command)
	web_mobile_bridge.initialize()
	set_process(web_mobile_bridge.is_available())
	resized.connect(_on_viewport_resized)
	_on_viewport_resized()
	queue_redraw()
	call_deferred("_update_qa_bridge")


func _process(delta: float) -> void:
	if not web_mobile_bridge.is_available():
		return
	_web_sync_elapsed += delta
	if _web_sync_elapsed >= 0.12:
		_web_sync_elapsed = 0.0
		_sync_web_description_overlay()
		_update_qa_bridge()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), NAVY, true)
	var horizon := size.y * 0.69
	draw_rect(Rect2(0, horizon, size.x, size.y - horizon), Color("#14243b"), true)
	draw_line(Vector2(0, horizon), Vector2(size.x, horizon), Color("#355174"), 3.0)
	for x in range(0, int(size.x) + 1, 96):
		draw_line(Vector2(x, horizon), Vector2(x - 55, size.y), Color("#1e3552"), 2.0)
	draw_string(ThemeDB.fallback_font, Vector2(size.x * 0.5 - 190, horizon - 20), "M1B1 VALIDATED COMBAT LAB", HORIZONTAL_ALIGNMENT_CENTER, 380, 17, Color("#44698f"))


func _build_world() -> void:
	world = Node2D.new()
	world.name = "World"
	add_child(world)
	player = ForgePlayer.new()
	player.name = "TestPilot"
	player.attack_requested.connect(_on_player_attack)
	world.add_child(player)
	_add_target("stationary", "STANDARD", 180)
	_add_target("moving", "MOVER", 135)
	_add_target("shield", "SHIELD", 210)
	for index in 3: _add_target("group", "GROUP %d" % (index + 1), 90)


func _add_target(kind: String, label_text: String, maximum: int) -> void:
	var target := TrainingDummy.new()
	target.name = label_text.replace(" ", "")
	target.configure(kind, label_text, maximum)
	target.damage_report.connect(_on_target_damage)
	target.health_changed.connect(func(_current: int, _maximum: int): _refresh_target_health())
	target.defeated.connect(func():
		if forge_overlay == null or not forge_overlay.visible:
			combat_status.text = "%s defeated; automatic reset armed." % label_text
	)
	world.add_child(target)
	targets.append(target)


func _build_hud() -> void:
	var top_panel := PanelContainer.new()
	top_panel.name = "WeaponReadout"
	top_panel.position = Vector2(18, 16)
	top_panel.size = Vector2(500, 184)
	top_panel.add_theme_stylebox_override("panel", _panel_style(PANEL, CYAN, 2))
	top_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top_panel)
	var top_margin := MarginContainer.new()
	top_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]: top_margin.add_theme_constant_override(side, 12)
	top_panel.add_child(top_margin)
	stats_label = Label.new()
	stats_label.text = "NO WEAPON FORGED\nDraw and describe an idea for the M1B1 interpreter."
	stats_label.add_theme_color_override("font_color", TEXT)
	stats_label.add_theme_font_size_override("font_size", 15)
	stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stats_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_margin.add_child(stats_label)

	var budget_panel := PanelContainer.new()
	budget_panel.name = "BudgetReadout"
	budget_panel.position = Vector2(534, 16)
	budget_panel.size = Vector2(450, 184)
	budget_panel.add_theme_stylebox_override("panel", _panel_style(PANEL, Color("#b392ff"), 2))
	budget_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(budget_panel)
	var budget_margin := MarginContainer.new()
	budget_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]: budget_margin.add_theme_constant_override(side, 12)
	budget_panel.add_child(budget_margin)
	budget_label = Label.new()
	budget_label.text = "POWER BUDGET  —  WAITING\nExplicit component costs and repair reasons appear here."
	budget_label.add_theme_color_override("font_color", TEXT)
	budget_label.add_theme_font_size_override("font_size", 14)
	budget_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	budget_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	budget_margin.add_child(budget_label)

	reforge_button = _button("REFORGE", ORANGE, 17)
	reforge_button.name = "ReforgeButton"
	reforge_button.position = Vector2(size.x - 174, 20)
	reforge_button.size = Vector2(156, 74)
	reforge_button.pressed.connect(_open_reforge)
	reforge_button.disabled = true
	add_child(reforge_button)

	combat_status = Label.new()
	combat_status.text = "Forge a weapon, then test it against four target behaviors."
	combat_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	combat_status.add_theme_color_override("font_color", MUTED)
	combat_status.add_theme_font_size_override("font_size", 15)
	combat_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	combat_status.anchor_right = 1.0
	combat_status.offset_top = 208.0
	combat_status.offset_bottom = 236.0
	add_child(combat_status)

	target_health_label = Label.new()
	target_health_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	target_health_label.add_theme_color_override("font_color", Color("#78eea6"))
	target_health_label.add_theme_font_size_override("font_size", 13)
	target_health_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	target_health_label.anchor_right = 1.0
	target_health_label.offset_top = 238.0
	target_health_label.offset_bottom = 266.0
	add_child(target_health_label)
	_refresh_target_health()

	var movement := HBoxContainer.new()
	movement.name = "TouchMovement"
	movement.add_theme_constant_override("separation", 10)
	movement.position = Vector2(18, size.y - 96)
	movement.size = Vector2(252, 76)
	movement.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(movement)
	var left_button := _button("LEFT", CYAN, 17)
	left_button.name = "MoveLeftButton"
	left_button.custom_minimum_size = Vector2(121, 76)
	left_button.button_down.connect(func(): player.set_touch_axis(-1.0))
	left_button.button_up.connect(func(): player.set_touch_axis(0.0))
	movement.add_child(left_button)
	var right_button := _button("RIGHT", CYAN, 17)
	right_button.name = "MoveRightButton"
	right_button.custom_minimum_size = Vector2(121, 76)
	right_button.button_down.connect(func(): player.set_touch_axis(1.0))
	right_button.button_up.connect(func(): player.set_touch_axis(0.0))
	movement.add_child(right_button)

	attack_button = _button("ATTACK", ORANGE, 20)
	attack_button.name = "AttackButton"
	attack_button.position = Vector2(size.x - 180, size.y - 102)
	attack_button.size = Vector2(162, 82)
	attack_button.pressed.connect(player.attack)
	attack_button.disabled = true
	add_child(attack_button)


func _build_forge_overlay() -> void:
	forge_overlay = ColorRect.new()
	forge_overlay.name = "ForgeOverlay"
	forge_overlay.color = Color(0.02, 0.04, 0.075, 1.0)
	forge_overlay.z_index = 100
	forge_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# The forge background is visual only. Interactive children receive their own
	# bounded events; no invisible full-screen Control is allowed to capture touch.
	forge_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(forge_overlay)
	forge_panel = PanelContainer.new()
	forge_panel.name = "ForgePanel"
	forge_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 24)
	forge_panel.add_theme_stylebox_override("panel", _panel_style(PANEL, CYAN, 3))
	forge_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	forge_overlay.add_child(forge_panel)
	forge_margin = MarginContainer.new()
	forge_margin.mouse_filter = Control.MOUSE_FILTER_PASS
	forge_panel.add_child(forge_margin)
	forge_layout = VBoxContainer.new()
	forge_layout.name = "ForgeLayout"
	forge_layout.mouse_filter = Control.MOUSE_FILTER_PASS
	forge_margin.add_child(forge_layout)

	forge_title_row = HBoxContainer.new()
	forge_title_row.mouse_filter = Control.MOUSE_FILTER_PASS
	forge_layout.add_child(forge_title_row)
	forge_title = Label.new()
	forge_title.text = "PROJECT FORGE  /  M1B1 TEXT INTERPRETER"
	forge_title.add_theme_color_override("font_color", TEXT)
	forge_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	forge_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	forge_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	forge_title_row.add_child(forge_title)
	back_button = _button("BACK", MUTED, 15)
	back_button.name = "BackButton"
	back_button.pressed.connect(_close_reforge)
	forge_title_row.add_child(back_button)

	review_panel = PanelContainer.new()
	review_panel.name = "InterpretationReview"
	review_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	review_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	review_panel.add_theme_stylebox_override("panel", _panel_style(Color("#0d1c30"), Color("#b392ff"), 2))
	forge_layout.add_child(review_panel)
	var review_margin := MarginContainer.new()
	review_margin.mouse_filter = Control.MOUSE_FILTER_PASS
	_set_margin(review_margin, 12, 12, 10, 10)
	review_panel.add_child(review_margin)
	review_layout = VBoxContainer.new()
	review_layout.mouse_filter = Control.MOUSE_FILTER_PASS
	review_layout.add_theme_constant_override("separation", 6)
	review_margin.add_child(review_layout)
	review_summary = Label.new()
	review_summary.name = "InterpretationSummary"
	review_summary.add_theme_color_override("font_color", Color("#b9eaff"))
	review_summary.add_theme_font_size_override("font_size", 18)
	review_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	review_summary.mouse_filter = Control.MOUSE_FILTER_IGNORE
	review_layout.add_child(review_summary)
	review_visual_host = Control.new()
	review_visual_host.name = "WeaponStrokePreview"
	review_visual_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	review_visual_host.clip_contents = true
	review_visual_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	review_visual_host.resized.connect(_layout_review_weapon_visual)
	review_layout.add_child(review_visual_host)
	review_weapon_visual = WeaponVisual.new()
	review_weapon_visual.name = "FittedWeaponVisual"
	review_weapon_visual.scale = Vector2.ONE
	review_visual_host.add_child(review_weapon_visual)
	review_details = Label.new()
	review_details.name = "InterpretationDetails"
	review_details.size_flags_vertical = Control.SIZE_EXPAND_FILL
	review_details.add_theme_color_override("font_color", TEXT)
	review_details.add_theme_font_size_override("font_size", 17)
	review_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	review_details.mouse_filter = Control.MOUSE_FILTER_IGNORE
	review_layout.add_child(review_details)
	review_action_row = HBoxContainer.new()
	review_action_row.name = "InterpretationActions"
	review_action_row.mouse_filter = Control.MOUSE_FILTER_PASS
	review_action_row.add_theme_constant_override("separation", 8)
	review_layout.add_child(review_action_row)
	confirm_button = _button("CONFIRM", Color("#78eea6"), 17)
	confirm_button.name = "ConfirmInterpretationButton"
	confirm_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	confirm_button.pressed.connect(_confirm_interpretation)
	review_action_row.add_child(confirm_button)
	modify_button = _button("MODIFY INTERPRETATION", CYAN, 16)
	modify_button.name = "ModifyInterpretationButton"
	modify_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	modify_button.pressed.connect(_modify_interpretation)
	review_action_row.add_child(modify_button)
	try_again_button = _button("TRY AGAIN", ORANGE, 17)
	try_again_button.name = "TryAgainButton"
	try_again_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	try_again_button.pressed.connect(_try_again)
	review_action_row.add_child(try_again_button)
	feedback_button = _button("NOT SUITABLE", Color("#ff8f8f"), 15)
	feedback_button.name = "InterpretationFeedbackButton"
	feedback_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	feedback_button.pressed.connect(_flag_result)
	review_action_row.add_child(feedback_button)
	review_panel.hide()

	drawing_canvas = DrawingCanvas.new()
	drawing_canvas.name = "DrawingCanvas"
	drawing_canvas.custom_minimum_size = Vector2(0, 120)
	drawing_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	forge_layout.add_child(drawing_canvas)

	description_row = HBoxContainer.new()
	description_row.mouse_filter = Control.MOUSE_FILTER_PASS
	description_row.add_theme_constant_override("separation", 8)
	forge_layout.add_child(description_row)
	description_label = Label.new()
	description_label.text = "DESCRIPTION"
	description_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	description_label.add_theme_color_override("font_color", CYAN)
	description_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	description_row.add_child(description_label)
	description_input = LineEdit.new()
	description_input.name = "DescriptionInput"
	description_input.placeholder_text = "e.g. a returning fire boomerang"
	description_input.clear_button_enabled = false
	description_input.editable = true
	description_input.focus_mode = Control.FOCUS_ALL
	description_input.virtual_keyboard_enabled = true
	description_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	description_input.mouse_filter = Control.MOUSE_FILTER_STOP
	description_input.gui_input.connect(_on_description_gui_input)
	description_input.text_changed.connect(_on_native_description_changed)
	description_row.add_child(description_input)
	clear_description_button = _button("×", CYAN, 24)
	clear_description_button.name = "ClearDescriptionButton"
	clear_description_button.tooltip_text = "Clear description"
	clear_description_button.pressed.connect(_clear_description)
	description_row.add_child(clear_description_button)

	pattern_selector = AttackPatternSelector.new()
	pattern_selector.name = "AttackPatternSelector"
	pattern_selector.pattern_selected.connect(_on_pattern_selected)
	forge_layout.add_child(pattern_selector)
	pattern_selector.visible = developer_mode

	forge_action_row = HBoxContainer.new()
	forge_action_row.mouse_filter = Control.MOUSE_FILTER_PASS
	forge_action_row.add_theme_constant_override("separation", 8)
	forge_layout.add_child(forge_action_row)
	reset_button = _button("RESET", MUTED, 18)
	reset_button.name = "ResetButton"
	reset_button.pressed.connect(_reset_forge)
	forge_action_row.add_child(reset_button)
	load_idea_button = _button("LOAD IDEA", Color("#b392ff"), 18)
	load_idea_button.name = "LoadIdeaButton"
	load_idea_button.pressed.connect(_load_selected_idea)
	forge_action_row.add_child(load_idea_button)
	load_idea_button.visible = developer_mode
	forge_status = Label.new()
	forge_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	forge_status.text = "Describe your idea. AI output is validated before combat."
	forge_status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	forge_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	forge_status.add_theme_color_override("font_color", MUTED)
	forge_status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	forge_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	forge_action_row.add_child(forge_status)
	generate_button = _button("FORGE", ORANGE, 20)
	generate_button.name = "GenerateWeaponButton"
	generate_button.pressed.connect(_generate_weapon)
	forge_action_row.add_child(generate_button)
	cancel_button = _button("CANCEL", Color("#ff8f8f"), 18)
	cancel_button.name = "CancelInterpretationButton"
	cancel_button.pressed.connect(_cancel_interpretation)
	cancel_button.hide()
	forge_action_row.add_child(cancel_button)
	_apply_forge_layout()


func _apply_forge_layout() -> void:
	if forge_panel == null:
		return
	var browser_metrics := web_mobile_bridge.metrics()
	var css_size := Vector2(
		float(browser_metrics.get("width", size.x)),
		float(browser_metrics.get("height", size.y)),
	)
	var input_focused := bool(browser_metrics.get("inputFocused", false))
	if css_size.x > css_size.y and not input_focused and css_size.y >= 250.0:
		_last_stable_landscape_css_size = css_size
	var layout_css_size := css_size
	if input_focused and css_size.y < 250.0 and _last_stable_landscape_css_size != Vector2.ZERO:
		# iOS shrinks visualViewport while the software keyboard is visible. Keep
		# the last stable landscape geometry so the Godot canvas does not adopt a
		# permanent keyboard-sized layout; the next viewport event restores it.
		layout_css_size = _last_stable_landscape_css_size
	var compact := MobileLayoutPolicy.should_use_compact(layout_css_size)
	if compact:
		_apply_compact_forge_layout(layout_css_size, browser_metrics)
	else:
		_apply_regular_forge_layout()
	call_deferred("_sync_web_description_overlay")


func _apply_compact_forge_layout(css_size: Vector2, browser_metrics: Dictionary) -> void:
	var metrics := MobileLayoutPolicy.compact_metrics(size, css_size)
	var scale := css_size.x / maxf(size.x, 1.0)
	var logical_per_css := 1.0 / maxf(scale, 0.01)
	var outer_css := float(metrics.outer_margin) / logical_per_css
	var left := (outer_css + float(browser_metrics.get("safeLeft", 0.0))) * logical_per_css
	var right := (outer_css + float(browser_metrics.get("safeRight", 0.0))) * logical_per_css
	var top := (outer_css + float(browser_metrics.get("safeTop", 0.0))) * logical_per_css
	var bottom := (outer_css + float(browser_metrics.get("safeBottom", 0.0))) * logical_per_css
	forge_panel.offset_left = left
	forge_panel.offset_top = top
	forge_panel.offset_right = -right
	forge_panel.offset_bottom = -bottom
	_set_margin(forge_margin, int(metrics.inner_margin), int(metrics.inner_margin), int(metrics.inner_margin), int(metrics.inner_margin))
	forge_layout.add_theme_constant_override("separation", int(metrics.separation))
	forge_title_row.custom_minimum_size.y = float(metrics.title_height)
	forge_title.text = "PROJECT FORGE / M1B1"
	forge_title.add_theme_font_size_override("font_size", int(metrics.title_font))
	back_button.custom_minimum_size = Vector2(float(metrics.back_width), float(metrics.touch_height))
	back_button.add_theme_font_size_override("font_size", int(metrics.body_font))
	drawing_canvas.custom_minimum_size.y = float(metrics.canvas_height)
	description_row.custom_minimum_size.y = float(metrics.touch_height)
	description_row.add_theme_constant_override("separation", maxi(2, int(metrics.separation * 2.0)))
	description_label.custom_minimum_size = Vector2(float(metrics.description_label_width), float(metrics.touch_height))
	description_label.add_theme_font_size_override("font_size", int(metrics.status_font))
	description_input.custom_minimum_size.y = float(metrics.touch_height)
	description_input.add_theme_font_size_override("font_size", int(metrics.input_font))
	clear_description_button.custom_minimum_size = Vector2(float(metrics.touch_height), float(metrics.touch_height))
	clear_description_button.add_theme_font_size_override("font_size", int(metrics.input_font) + 5)
	pattern_selector.set_compact(true, float(metrics.touch_height), int(metrics.body_font))
	review_action_row.custom_minimum_size.y = float(metrics.touch_height)
	review_action_row.add_theme_constant_override("separation", maxi(2, int(metrics.separation * 2.0)))
	review_summary.add_theme_font_size_override("font_size", int(metrics.body_font))
	review_visual_host.custom_minimum_size.y = 104.0
	review_details.add_theme_font_size_override("font_size", int(metrics.status_font) + 2)
	for button in [confirm_button, modify_button, try_again_button, feedback_button]:
		button.custom_minimum_size.y = float(metrics.touch_height)
		button.add_theme_font_size_override("font_size", int(metrics.status_font) + 1)
	forge_action_row.custom_minimum_size.y = float(metrics.touch_height)
	forge_action_row.add_theme_constant_override("separation", maxi(2, int(metrics.separation * 2.0)))
	reset_button.custom_minimum_size = Vector2(float(metrics.reset_width), float(metrics.touch_height))
	load_idea_button.custom_minimum_size = Vector2(float(metrics.load_width), float(metrics.touch_height))
	generate_button.custom_minimum_size = Vector2(float(metrics.compile_width), float(metrics.touch_height))
	cancel_button.custom_minimum_size = Vector2(float(metrics.reset_width), float(metrics.touch_height))
	for button in [reset_button, load_idea_button, generate_button, cancel_button]:
		button.add_theme_font_size_override("font_size", int(metrics.body_font))
	forge_status.add_theme_font_size_override("font_size", int(metrics.status_font))


func _apply_regular_forge_layout() -> void:
	forge_panel.offset_left = 18.0
	forge_panel.offset_top = 18.0
	forge_panel.offset_right = -18.0
	forge_panel.offset_bottom = -18.0
	_set_margin(forge_margin, 14, 14, 8, 8)
	forge_layout.add_theme_constant_override("separation", 6)
	forge_title_row.custom_minimum_size.y = 64.0
	forge_title.text = "PROJECT FORGE  /  M1B1 TEXT INTERPRETER"
	forge_title.add_theme_font_size_override("font_size", 22)
	back_button.custom_minimum_size = Vector2(96, 64)
	back_button.add_theme_font_size_override("font_size", 15)
	drawing_canvas.custom_minimum_size.y = 220.0
	description_row.custom_minimum_size.y = 64.0
	description_row.add_theme_constant_override("separation", 8)
	description_label.custom_minimum_size = Vector2(130, 64)
	description_label.add_theme_font_size_override("font_size", 17)
	description_input.custom_minimum_size.y = 64.0
	description_input.add_theme_font_size_override("font_size", 20)
	clear_description_button.custom_minimum_size = Vector2(64, 64)
	clear_description_button.add_theme_font_size_override("font_size", 24)
	pattern_selector.set_compact(false, 72.0, 18)
	review_action_row.custom_minimum_size.y = 64.0
	review_action_row.add_theme_constant_override("separation", 8)
	review_summary.add_theme_font_size_override("font_size", 18)
	review_visual_host.custom_minimum_size.y = 118.0
	review_details.add_theme_font_size_override("font_size", 17)
	for button in [confirm_button, modify_button, try_again_button, feedback_button]:
		button.custom_minimum_size.y = 64.0
		button.add_theme_font_size_override("font_size", 15)
	forge_action_row.custom_minimum_size.y = 64.0
	forge_action_row.add_theme_constant_override("separation", 8)
	reset_button.custom_minimum_size = Vector2(112, 64)
	load_idea_button.custom_minimum_size = Vector2(146, 64)
	generate_button.custom_minimum_size = Vector2(210, 64)
	cancel_button.custom_minimum_size = Vector2(112, 64)
	for button in [reset_button, load_idea_button, generate_button, cancel_button]:
		button.add_theme_font_size_override("font_size", 17)
	forge_status.add_theme_font_size_override("font_size", 14)


func _set_margin(container: MarginContainer, left: int, right: int, top: int, bottom: int) -> void:
	container.add_theme_constant_override("margin_left", left)
	container.add_theme_constant_override("margin_right", right)
	container.add_theme_constant_override("margin_top", top)
	container.add_theme_constant_override("margin_bottom", bottom)


func _on_description_gui_input(event: InputEvent) -> void:
	var pressed: bool = false
	if event is InputEventScreenTouch:
		pressed = event.pressed
	elif event is InputEventMouseButton:
		pressed = event.button_index == MOUSE_BUTTON_LEFT and event.pressed
	if pressed:
		description_input.grab_focus()
		if web_mobile_bridge.is_available():
			web_mobile_bridge.focus()


func _on_native_description_changed(value: String) -> void:
	_description_draft = value.left(512)
	if web_mobile_bridge.is_available() and web_mobile_bridge.value() != value:
		web_mobile_bridge.set_value(value)


func _on_web_description_event(kind: String, value: String, revision: int, composing: bool) -> void:
	_web_description_composing = composing
	if revision >= _last_web_description_revision:
		_last_web_description_revision = revision
		_description_draft = value.left(512)
	if description_input.text != value:
		description_input.text = _description_draft
	match kind:
		"clear": _show_forge_toast("Description cleared", CYAN)
		"blur":
			description_input.release_focus()
			call_deferred("_apply_forge_layout")
		"focus": _show_forge_toast("Description ready for editing", Color("#b9eaff"), 1.0)


func _set_description(value: String) -> void:
	_description_draft = value.left(512)
	description_input.text = _description_draft
	if web_mobile_bridge.is_available():
		web_mobile_bridge.set_value(_description_draft)


func _freeze_description_for_request() -> Dictionary:
	if not web_mobile_bridge.is_available():
		_description_draft = description_input.text.left(512)
		return {"ok": true, "value": _description_draft, "revision": _last_web_description_revision}
	web_mobile_bridge.commit_for_request()
	await get_tree().process_frame
	var deadline := Time.get_ticks_msec() + 350
	var snapshot := web_mobile_bridge.description_snapshot()
	while bool(snapshot.get("composing", false)) and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
		snapshot = web_mobile_bridge.description_snapshot()
	if bool(snapshot.get("composing", false)):
		return {"ok": false, "reason": "description_composition_incomplete"}
	var revision := int(snapshot.get("revision", -1))
	var dom_value := str(snapshot.get("value", "")).left(512)
	if revision > _last_web_description_revision:
		_last_web_description_revision = revision
		_description_draft = dom_value
	elif dom_value != _description_draft:
		# Ignore an unversioned stale DOM mutation; explicit deletion always emits
		# input/clear and advances the revision.
		web_mobile_bridge.set_value(_description_draft)
	description_input.text = _description_draft
	return {
		"ok": bool(snapshot.get("connected", false)),
		"value": _description_draft,
		"revision": _last_web_description_revision,
	}


func _clear_description() -> void:
	_set_description("")
	description_input.grab_focus()
	if web_mobile_bridge.is_available():
		web_mobile_bridge.focus()
	_show_forge_toast("Description cleared", CYAN)


func _reset_forge() -> void:
	drawing_canvas.clear_drawing()
	_set_description("")
	loaded_idea_pattern = ""
	pending_result = {}
	pending_spec = null
	request_strokes.clear()
	last_request_snapshot = {}
	interpretation_error_mode = false
	feedback_button.disabled = false
	description_input.release_focus()
	if web_mobile_bridge.is_available():
		web_mobile_bridge.blur()
	_show_forge_form(false)
	_show_forge_toast("Canvas and description cleared", Color("#78eea6"), 1.8)


func _show_forge_toast(message: String, color: Color = MUTED, duration: float = 1.6) -> void:
	_status_revision += 1
	var revision := _status_revision
	forge_status.text = message
	forge_status.add_theme_color_override("font_color", color)
	if duration <= 0.0:
		return
	await get_tree().create_timer(duration).timeout
	if revision == _status_revision and forge_status.text == message:
		forge_status.text = ""
		forge_status.add_theme_color_override("font_color", MUTED)


func _sync_web_description_overlay() -> void:
	if not web_mobile_bridge.is_available() or description_input == null:
		return
	var visible := (
		forge_overlay.visible
		and description_row.visible
		and not interpreter.in_flight
		and (orientation_prompt == null or not orientation_prompt.visible)
	)
	var input_rect := description_input.get_global_rect()
	if clear_description_button != null:
		input_rect = input_rect.merge(clear_description_button.get_global_rect())
	web_mobile_bridge.update_layout(input_rect, size, visible)


func _on_web_viewport_changed() -> void:
	call_deferred("_refresh_web_viewport")


func _refresh_web_viewport() -> void:
	await get_tree().process_frame
	_apply_forge_layout()
	_sync_web_description_overlay()


func _generate_weapon() -> void:
	if _snapshot_in_progress:
		_show_forge_toast("Input snapshot is already being prepared.", Color("#ffca78"), 1.4)
		return
	_snapshot_in_progress = true
	var description_snapshot: Dictionary = await _freeze_description_for_request()
	if not bool(description_snapshot.get("ok", false)):
		_snapshot_in_progress = false
		_show_forge_toast("Description could not be committed. Please tap FORGE again.", Color("#ff8f8f"), 2.2)
		return
	if drawing_canvas.is_empty():
		_snapshot_in_progress = false
		_show_forge_toast("Draw at least one stroke first.", Color("#ff8f8f"), 2.0)
		return
	if modify_mode:
		_snapshot_in_progress = false
		_apply_manual_correction()
		return
	request_strokes = drawing_canvas.get_strokes_snapshot()
	_request_drawing_summary = drawing_canvas.drawing_summary().duplicate(true)
	var request_id := interpreter.start_interpretation(
		str(description_snapshot.get("value", "")),
		_request_drawing_summary,
		_detect_locale(str(description_snapshot.get("value", ""))),
	)
	_snapshot_in_progress = false
	if request_id.is_empty():
		_show_forge_toast("A weapon request is already running.", Color("#ffca78"), 1.8)


func _on_interpretation_started(request_id: String) -> void:
	var outgoing := interpreter.active_payload_snapshot()
	var outgoing_drawing: Dictionary = outgoing.get("drawing_summary", _request_drawing_summary)
	last_request_snapshot = {
		"request_id": request_id,
		"description": str(outgoing.get("description", _description_draft)),
		"description_revision": _last_web_description_revision,
		"drawing_summary": outgoing_drawing.duplicate(true),
		"stroke_count": request_strokes.size(),
	}
	interpretation_error_mode = false
	review_mode = false
	_review_ui_ready = false
	_loading_ui_ready = false
	review_panel.hide()
	_set_forge_interactable(false)
	generate_button.text = "FORGING…"
	generate_button.show()
	cancel_button.show()
	forge_status.text = _request_snapshot_line("AI REQUEST")
	forge_status.add_theme_color_override("font_color", Color("#b9eaff"))
	_apply_forge_layout()
	_sync_web_description_overlay()
	call_deferred("_mark_loading_ui_ready")


func _on_interpretation_completed(result: Dictionary) -> void:
	_loading_ui_ready = false
	pending_result = result.duplicate(true)
	if not _is_confirmable_result(pending_result):
		pending_spec = null
		_show_interpretation_error()
		return
	var raw_spec: Variant = pending_result.get("weapon_spec")
	if not raw_spec is Dictionary:
		pending_result = {}
		_show_forge_toast("Interpreter response was invalid.", Color("#ff8f8f"), 2.0)
		_show_forge_form(false)
		return
	pending_spec = WeaponSpec.from_dict(raw_spec)
	pending_spec.corrections.clear()
	for correction: Variant in pending_result.get("corrections", []):
		pending_spec.corrections.append(str(correction))
	pending_spec.budget_breakdown = PowerBudget.calculate(pending_spec.to_dict())
	if developer_mode:
		_apply_developer_pattern_override()
	_show_interpretation_review()


func _on_interpretation_cancelled(_request_id: String) -> void:
	_loading_ui_ready = false
	_show_forge_form(false)
	_show_forge_toast("Interpretation cancelled — drawing and text preserved.", Color("#ffca78"), 1.8)
	_update_qa_bridge()


func _cancel_interpretation() -> void:
	if not interpreter.cancel():
		_show_forge_form(false)


func _show_interpretation_review() -> void:
	if pending_spec == null:
		return
	review_mode = true
	interpretation_error_mode = false
	_review_ui_ready = false
	modify_mode = false
	drawing_canvas.hide()
	description_row.hide()
	pattern_selector.hide()
	forge_action_row.hide()
	review_panel.show()
	review_visual_host.show()
	confirm_button.show()
	modify_button.show()
	modify_button.text = "MODIFY INTERPRETATION"
	try_again_button.show()
	feedback_button.show()
	feedback_button.disabled = false
	_update_review_copy()
	back_button.disabled = false
	_apply_forge_layout()
	_sync_web_description_overlay()
	# Containers finalize button rectangles over deferred layout passes. Do not
	# expose a terminal QA phase until the visible controls have stable bounds.
	call_deferred("_mark_review_ui_ready")


func _show_interpretation_error() -> void:
	review_mode = true
	interpretation_error_mode = true
	modify_mode = false
	_review_ui_ready = false
	drawing_canvas.hide()
	description_row.hide()
	pattern_selector.hide()
	forge_action_row.hide()
	review_panel.show()
	review_visual_host.hide()
	confirm_button.hide()
	modify_button.show()
	modify_button.text = "EDIT INPUT"
	try_again_button.show()
	feedback_button.hide()
	var reason := str(pending_result.get("fallback_reason", "invalid_provider_response"))
	var metadata: Dictionary = pending_result.get("provider_metadata", {})
	review_summary.text = "INTERPRETATION ERROR: %s\nNo weapon was generated or equipped." % reason.replace("_", " ").to_upper()
	review_summary.add_theme_color_override("font_color", Color("#ff9c9c"))
	review_details.text = (
		"%s\n"
		+ "PROVIDER  %s / %s    ATTEMPTS %d    CONFIDENCE 0%%\n"
		+ "Your drawing and description are preserved. Choose EDIT INPUT or TRY AGAIN."
	) % [
		_request_snapshot_line("INPUT SNAPSHOT"),
		str(metadata.get("provider", "none")),
		str(metadata.get("model", "none")),
		int(metadata.get("attempts", 0)),
	]
	back_button.disabled = false
	_apply_forge_layout()
	_sync_web_description_overlay()
	call_deferred("_mark_review_ui_ready")


func _is_confirmable_result(result: Dictionary) -> bool:
	var metadata: Dictionary = result.get("provider_metadata", {})
	return (
		bool(result.get("success", false))
		and bool(result.get("provider_invoked", false))
		and str(result.get("fallback_reason", "")).is_empty()
		and result.get("weapon_spec") is Dictionary
		and bool(result.get("runtime_valid", false))
		and str(metadata.get("provider", "none")) not in ["", "none", "unknown"]
		and int(metadata.get("attempts", 0)) >= 1
		and float(result.get("confidence", 0.0)) > 0.0
	)


func _request_snapshot_line(prefix: String) -> String:
	var request_id := str(last_request_snapshot.get("request_id", "pending"))
	var description := str(last_request_snapshot.get("description", ""))
	var drawing: Dictionary = last_request_snapshot.get("drawing_summary", {})
	var bounded_description := description.left(72)
	if description.length() > 72:
		bounded_description += "…"
	return "%s %s  •  \"%s\"  •  %d stroke(s) / %d point(s)" % [
		prefix,
		request_id,
		bounded_description,
		int(drawing.get("stroke_count", last_request_snapshot.get("stroke_count", 0))),
		int(drawing.get("point_count", 0)),
	]


func _update_review_copy() -> void:
	if pending_spec == null:
		return
	review_weapon_visual.configure(request_strokes, pending_spec)
	_layout_review_weapon_visual()
	review_summary.add_theme_color_override("font_color", Color("#b9eaff"))
	var fallback_reason := str(pending_result.get("fallback_reason", ""))
	var summary := str(pending_result.get("interpretation_summary", "Weapon interpretation ready."))
	if not fallback_reason.is_empty():
		summary = "SAFE FALLBACK (%s)\n%s" % [fallback_reason.replace("_", " ").to_upper(), summary]
	review_summary.text = summary
	var metadata: Dictionary = pending_result.get("provider_metadata", {})
	var cost: Variant = pending_result.get("estimated_cost", "UNKNOWN")
	var cost_text := str(cost) if not cost is Dictionary else "%s %.6f" % [str(cost.get("currency", "USD")), float(cost.get("amount", 0.0))]
	review_details.text = (
		"%s    POWER %d/100\n"
		+ "FORM  %s    DELIVERY  %s / %s\n"
		+ "ATTACK  %s    IMPACT  %s / %s    ELEMENT  %s\n"
		+ "DAMAGE  %d    SPEED  %.2f    RANGE  %.0f\n"
		+ "ABILITY  %s    STATUS  %s\n"
		+ "WEAKNESS  %s\n"
		+ "CONFIDENCE  %d%%    REPAIRS  %d\n"
		+ "PROVIDER  %s / %s    %d ms    COST %s"
	) % [
		pending_spec.display_name,
		pending_spec.power_score,
		pending_spec.weapon_form.to_upper(),
		pending_spec.delivery.to_upper(),
		pending_spec.trajectory.to_upper(),
		pending_spec.attack_label().to_upper(),
		pending_spec.impact.replace("_", " ").to_upper(),
		pending_spec.area_effect.to_upper(),
		pending_spec.element.to_upper(),
		pending_spec.damage,
		pending_spec.attack_speed,
		pending_spec.attack_range,
		pending_spec.special_ability.replace("_", " ").to_upper(),
		pending_spec.status_effect.replace("_", " ").to_upper(),
		pending_spec.weakness_label().to_upper(),
		roundi(clampf(float(pending_result.get("confidence", 0.0)), 0.0, 1.0) * 100.0),
		pending_spec.corrections.size(),
		str(metadata.get("provider", "unknown")),
		str(metadata.get("model", "unknown")),
		int(pending_result.get("latency_ms", 0)),
		cost_text,
	]


func _layout_review_weapon_visual() -> void:
	if review_visual_host == null or review_weapon_visual == null:
		return
	review_weapon_visual.position = Vector2(
		maxf((review_visual_host.size.x - WeaponVisual.DEFAULT_TARGET_RECT.size.x) * 0.5, 0.0),
		review_visual_host.size.y * 0.5,
	)


func _show_forge_form(correction: bool) -> void:
	review_mode = false
	interpretation_error_mode = false
	_review_ui_ready = false
	_loading_ui_ready = false
	modify_mode = correction
	review_panel.hide()
	drawing_canvas.show()
	description_row.show()
	forge_action_row.show()
	pattern_selector.visible = developer_mode or correction
	load_idea_button.visible = developer_mode and not correction
	generate_button.text = "REVIEW CORRECTION" if correction else "FORGE"
	generate_button.show()
	cancel_button.hide()
	_set_forge_interactable(true)
	_apply_forge_layout()
	_sync_web_description_overlay()
	_update_qa_bridge()


func _set_forge_interactable(enabled: bool) -> void:
	description_input.editable = enabled
	clear_description_button.disabled = not enabled
	reset_button.disabled = not enabled
	load_idea_button.disabled = not enabled
	generate_button.disabled = not enabled
	back_button.disabled = not enabled
	drawing_canvas.mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE
	for button: Button in pattern_selector.buttons():
		button.disabled = not enabled


func _modify_interpretation() -> void:
	if interpretation_error_mode:
		_show_forge_form(false)
		_show_forge_toast("Input restored from the failed request.", Color("#b9eaff"), 1.6)
		return
	if pending_spec == null:
		return
	var current_index := AttackPatternSelector.PATTERNS.find(pending_spec.attack_pattern)
	pattern_selector.select_pattern(maxi(current_index, 0), false)
	review_mode = true
	_review_ui_ready = false
	modify_mode = true
	drawing_canvas.hide()
	description_row.hide()
	forge_action_row.hide()
	review_panel.show()
	pattern_selector.show()
	for button: Button in pattern_selector.buttons():
		button.disabled = false
	feedback_button.disabled = false
	review_summary.text = "MODIFY INTERPRETATION — choose one attack pattern. Validation updates immediately."
	_apply_forge_layout()
	_sync_web_description_overlay()
	call_deferred("_mark_review_ui_ready")


func _apply_manual_correction() -> void:
	var corrected := service.compile(
		description_input.text,
		drawing_canvas.drawing_summary(),
		pattern_selector.selected_pattern(),
		true,
	)
	pending_spec = corrected
	pending_result.weapon_spec = corrected.to_dict()
	pending_result.interpretation_summary = "Player-corrected interpretation; schema and PowerBudget were re-applied."
	pending_result.confidence = 1.0
	pending_result.corrections = corrected.corrections.duplicate()
	pending_result.corrections.append("manual correction: attack_pattern set to %s" % corrected.attack_pattern)
	pending_result.fallback_reason = ""
	pending_result.success = true
	pending_result.provider_invoked = true
	pending_result.latency_ms = int(service.last_record.get("elapsed_ms", 0))
	pending_result.estimated_cost = "UNKNOWN"
	pending_result.power_budget = corrected.budget_breakdown.duplicate(true)
	pending_result.schema_valid = corrected.is_valid()
	pending_result.allow_list_valid = corrected.is_valid()
	pending_result.power_valid = corrected.power_score <= PowerBudget.MAX_POWER
	pending_result.runtime_valid = corrected.is_valid() and corrected.power_score <= PowerBudget.MAX_POWER
	if modify_mode:
		_update_review_copy()
		_apply_forge_layout()
		_update_qa_bridge()
	else:
		_show_interpretation_review()


func _apply_developer_pattern_override() -> void:
	var corrected := service.compile(
		description_input.text,
		drawing_canvas.drawing_summary(),
		pattern_selector.selected_pattern(),
		true,
	)
	pending_spec = corrected
	pending_result.weapon_spec = corrected.to_dict()
	var corrections: Array = pending_result.get("corrections", [])
	corrections.append("developer mode: attack_pattern forced to %s" % corrected.attack_pattern)
	pending_result.corrections = corrections


func _try_again() -> void:
	var now := Time.get_ticks_msec()
	if now - _last_try_again_msec < 1500:
		return
	_last_try_again_msec = now
	_show_forge_form(false)
	_generate_weapon()


func _flag_result() -> void:
	_qa_feedback_count += 1
	review_summary.text = "RESULT FLAGGED FOR THIS SESSION ONLY\nNo drawing or description was published or stored."
	feedback_button.disabled = true
	_update_qa_bridge()


func _confirm_interpretation() -> void:
	if pending_spec == null or not _is_confirmable_result(pending_result):
		_show_forge_toast("This result cannot be equipped. Edit the input or retry.", Color("#ff8f8f"), 2.0)
		return
	current_spec = pending_spec
	current_strokes = request_strokes.duplicate(true)
	_commit_weapon()


func _commit_weapon() -> void:
	if current_spec == null or not _is_confirmable_result(pending_result):
		current_spec = null
		_show_interpretation_error()
		return
	player.equip(current_spec, current_strokes)
	player.set_combat_enabled(true)
	description_input.release_focus()
	if web_mobile_bridge.is_available():
		web_mobile_bridge.blur()
	stats_label.text = (
		"%s\nDAMAGE %d   POWER %d/100   SPEED %.2f\nATTACK  %s\nELEMENT  %s   SPECIAL  %s\nWEAKNESS  %s"
		% [current_spec.display_name, current_spec.damage, current_spec.power_score, current_spec.attack_speed,
		current_spec.attack_label(), current_spec.effect_label(), current_spec.special_ability.replace("_", " ").to_upper(), current_spec.weakness_label()]
	)
	var parts := current_spec.budget_breakdown
	budget_label.text = (
		"POWER BUDGET  %d / 100\nDamage %.1f + Speed %.1f + Range %.1f + Pattern %.1f\nElement %.1f + Ability %.1f + Status %.1f + Module %.1f\nTradeoff %.1f   •   Repairs %d"
		% [current_spec.power_score, parts.get("damage", 0), parts.get("attack_speed", 0), parts.get("range", 0),
		parts.get("attack_pattern", 0), parts.get("element", 0), parts.get("special_ability", 0), parts.get("status_effect", 0),
		float(parts.get("projectile_speed", 0)) + float(parts.get("return_speed", 0)) + float(parts.get("area_radius", 0)) + float(parts.get("piercing", 0)),
		parts.get("drawback_credit", 0), current_spec.corrections.size()]
	)
	forge_status.add_theme_color_override("font_color", MUTED)
	forge_status.text = "Valid • %d repair(s) • %d ms • safe audit" % [current_spec.corrections.size(), int(pending_result.get("latency_ms", 0))]
	combat_status.text = "%s ready. Use A/D or touch, then SPACE/ATTACK." % current_spec.attack_label()
	reforge_button.disabled = false
	attack_button.disabled = true
	_combat_ui_ready = false
	pattern_selector.hide()
	forge_overlay.hide()
	_sync_web_description_overlay()
	review_mode = false
	_review_ui_ready = false
	modify_mode = false
	_arm_attack_button()
	_update_qa_bridge()


func _arm_attack_button() -> void:
	# Prevent the pointer release that closes the overlay from falling through to ATTACK.
	await get_tree().process_frame
	await get_tree().process_frame
	if current_spec and not forge_overlay.visible:
		attack_button.disabled = false
		_combat_ui_ready = true
		_update_qa_bridge()


func _close_reforge() -> void:
	if interpreter.in_flight:
		_cancel_interpretation()
		return
	if review_mode and current_spec == null:
		_show_forge_form(false)
		return
	if current_spec == null:
		forge_status.text = "Forge one weapon before returning to combat."
		forge_status.add_theme_color_override("font_color", Color("#ffca78"))
		return
	description_input.release_focus()
	if web_mobile_bridge.is_available():
		web_mobile_bridge.blur()
	_combat_ui_ready = false
	forge_overlay.hide()
	review_mode = false
	modify_mode = false
	_sync_web_description_overlay()
	player.set_combat_enabled(true)
	combat_status.text = "%s ready. Use A/D or touch, then SPACE/ATTACK." % current_spec.attack_label()
	_arm_attack_button()


func _open_reforge() -> void:
	_combat_ui_ready = false
	attack_button.disabled = true
	player.set_combat_enabled(false)
	_clear_transient_combat()
	drawing_canvas.clear_drawing()
	_set_description("")
	loaded_idea_pattern = ""
	pending_result = {}
	pending_spec = null
	request_strokes.clear()
	last_request_snapshot = {}
	interpretation_error_mode = false
	feedback_button.disabled = false
	description_input.release_focus()
	if web_mobile_bridge.is_available():
		web_mobile_bridge.blur()
	var current_index := AttackPatternSelector.PATTERNS.find(current_spec.attack_pattern) if current_spec else 0
	pattern_selector.select_pattern(maxi(current_index, 0), false)
	_show_forge_form(false)
	forge_status.text = "Draw and describe a replacement; the current weapon remains until CONFIRM."
	forge_status.add_theme_color_override("font_color", MUTED)
	forge_overlay.show()
	_apply_forge_layout()
	call_deferred("_sync_web_description_overlay")


func _load_selected_idea() -> void:
	if not developer_mode:
		return
	_set_description(pattern_selector.selected_idea())
	loaded_idea_pattern = pattern_selector.selected_pattern()
	_show_forge_toast("%s idea loaded — edit or compile" % pattern_selector.selected_pattern().replace("_", " ").to_upper(), MUTED)


func _on_pattern_selected(_index: int, pattern: String) -> void:
	if modify_mode and pending_spec != null:
		_apply_manual_correction()
		return
	_show_forge_toast("%s selected" % pattern.replace("_", " ").to_upper(), Color("#b9eaff"), 1.2)


func _clear_transient_combat() -> void:
	_qa_has_projectile_origin = false
	_qa_has_area_impact = false
	for node: Node in get_tree().get_nodes_in_group("forge_transient_attack"):
		if is_instance_valid(node):
			var parent := node.get_parent()
			if parent:
				parent.remove_child(node)
			node.queue_free()
	for target in targets:
		target.clear_transient_status()


func _on_player_attack(spec: WeaponSpec, origin: Vector2, direction: Vector2, strokes: Array[PackedVector2Array]) -> void:
	_qa_attack_count += 1
	_qa_last_attack_pattern = spec.attack_pattern
	_update_qa_bridge()
	if spec.delivery == "thrown" and spec.trajectory == "arc":
		_launch_projectile(spec, origin, direction, strokes)
		return
	match spec.attack_pattern:
		"melee_slash": _launch_melee(spec, origin, direction)
		"area_blast": _launch_area(spec, player.global_position + Vector2(0, -12), direction)
		"straight_projectile", "boomerang", "piercing": _launch_projectile(spec, origin, direction, strokes)


func _launch_melee(spec: WeaponSpec, origin: Vector2, direction: Vector2) -> void:
	var slash := ForgeSlashEffect.new()
	slash.color = WeaponVisual._color_for_element(spec.element)
	slash.direction = direction
	slash.global_position = origin
	world.add_child(slash)
	slash.add_to_group("forge_transient_attack")
	var candidates: Array[TrainingDummy] = []
	for target in targets:
		var offset := target.global_position - player.global_position
		var forward := offset.dot(direction.normalized())
		# The visible slash and the hand-drawn weapon extend beyond the body origin.
		# Keep the target in the facing half-plane while allowing that full visual reach.
		if forward >= -12.0 and forward <= spec.attack_range + 96.0 and absf(offset.y) < 120.0:
			candidates.append(target)
	if candidates.is_empty():
		combat_status.text = "Melee slash missed — close the distance."
		return
	candidates.sort_custom(func(a: TrainingDummy, b: TrainingDummy): return a.global_position.distance_to(player.global_position) < b.global_position.distance_to(player.global_position))
	var actual := candidates[0].take_damage(spec.damage, spec.status_effect, spec.attack_pattern, direction)
	combat_status.text = "Melee arc hit %s for %d." % [candidates[0].target_label, actual]


func _launch_area(spec: WeaponSpec, origin: Vector2, direction: Vector2) -> void:
	var blast := ForgeAreaBlast.new()
	blast.configure(spec, direction)
	blast.global_position = origin
	blast.hits_complete.connect(func(count: int, total: int): combat_status.text = "Area blast hit %d target(s) for %d total." % [count, total])
	world.add_child(blast)
	blast.add_to_group("forge_transient_attack")
	combat_status.text = "Area blast expanding to %.0f px." % spec.area_radius


func _launch_projectile(spec: WeaponSpec, origin: Vector2, direction: Vector2, strokes: Array[PackedVector2Array]) -> void:
	_qa_projectile_origin = origin
	_qa_has_projectile_origin = true
	_qa_has_area_impact = false
	var projectile := ForgeProjectile.new()
	projectile.configure(spec, strokes, direction, player)
	projectile.global_position = origin
	projectile.hit_target.connect(func(label_text: String, amount: int): combat_status.text = "%s hit %s for %d." % [spec.attack_label(), label_text, amount])
	projectile.area_impact.connect(func(impact_position: Vector2, impact_direction: Vector2):
		_qa_area_impact_position = impact_position
		_qa_has_area_impact = true
		_launch_area(spec, impact_position, impact_direction)
		combat_status.text = "Thrown %s exploded at its landing point." % spec.weapon_form
	)
	world.add_child(projectile)
	projectile.add_to_group("forge_transient_attack")
	combat_status.text = "Grenade thrown on a visible arc; explosion follows at impact." if spec.delivery == "thrown" and spec.trajectory == "arc" else {"straight_projectile": "Straight projectile launched; stops on first target.", "boomerang": "Boomerang outbound; it can strike again on return.", "piercing": "Piercing lance launched; shield bypass active."}.get(spec.attack_pattern, "Attack launched.")


func _on_target_damage(label_text: String, amount: int, note: String) -> void:
	if forge_overlay and forge_overlay.visible:
		_refresh_target_health()
		return
	combat_status.text = "%s took %d — %s." % [label_text, amount, note]
	_refresh_target_health()


func _refresh_target_health() -> void:
	if target_health_label == null: return
	var fragments: PackedStringArray = []
	for target in targets: fragments.append("%s %d/%d" % [target.target_label, target.health, target.max_health])
	target_health_label.text = "   |   ".join(fragments)


func _layout_world() -> void:
	if not is_instance_valid(player): return
	var ground_y := size.y * 0.69 - 52.0
	if player.global_position.x <= 85.0 or player.global_position.x >= size.x - 85.0: player.global_position.x = size.x * 0.25
	player.global_position.y = ground_y
	player.movement_bounds = Vector2(70.0, size.x - 70.0)
	var positions := [Vector2(size.x * 0.50, ground_y - 4), Vector2(size.x * 0.64, ground_y - 4), Vector2(size.x * 0.82, ground_y - 4), Vector2(size.x * 0.53, ground_y - 132), Vector2(size.x * 0.61, ground_y - 132), Vector2(size.x * 0.69, ground_y - 132)]
	for index in mini(targets.size(), positions.size()): targets[index].set_arena_position(positions[index])
	if reforge_button:
		reforge_button.position = Vector2(size.x - 174, 20)
		attack_button.position = Vector2(size.x - 180, size.y - 102)
		var movement := get_node("TouchMovement") as Control
		movement.position = Vector2(18, size.y - 96)
	queue_redraw()


func _build_orientation_prompt() -> void:
	orientation_prompt = RotationPrompt.new()
	orientation_prompt.name = "LandscapeRotationPrompt"
	orientation_prompt.z_index = 500
	orientation_prompt.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(orientation_prompt)


func _on_viewport_resized() -> void:
	_layout_world()
	_apply_forge_layout()
	_update_orientation_prompt()
	call_deferred("_sync_web_description_overlay")


func _update_orientation_prompt() -> void:
	if orientation_prompt == null:
		return
	var portrait := RotationPrompt.should_show_for(size)
	orientation_prompt.visible = portrait
	if portrait:
		description_input.release_focus()
		if web_mobile_bridge.is_available():
			web_mobile_bridge.blur()
		player.set_combat_enabled(false)
		player.set_touch_axis(0.0)
		attack_button.disabled = true
	elif forge_overlay.visible:
		player.set_combat_enabled(false)
		attack_button.disabled = true
	elif current_spec:
		player.set_combat_enabled(true)
		attack_button.disabled = false
	call_deferred("_sync_web_description_overlay")
	call_deferred("_update_qa_bridge")


func _detect_developer_mode() -> bool:
	if not OS.has_feature("web"):
		return OS.get_cmdline_user_args().has("--forge-developer-mode")
	return bool(JavaScriptBridge.eval(
		"new URLSearchParams(window.location.search).get('dev') === '1'",
		true,
	))


func _detect_locale(text: String) -> String:
	for index in text.length():
		var codepoint := text.unicode_at(index)
		if codepoint >= 0x3400 and codepoint <= 0x9FFF:
			return "zh-CN"
	return "en"


func _on_qa_command(command: String, payload: Dictionary) -> void:
	match command:
		"scenario":
			var options: Variant = payload.get("options", {})
			interpreter.set_test_scenario(
				str(payload.get("name", "success")),
				options if options is Dictionary else {},
			)
		"developer_mode":
			developer_mode = bool(payload.get("enabled", false))
			_developer_ui_ready = false
			if not review_mode and not interpreter.in_flight:
				pattern_selector.visible = developer_mode or modify_mode
				load_idea_button.visible = developer_mode and not modify_mode
				_apply_forge_layout()
			if developer_mode:
				call_deferred("_mark_developer_ui_ready")
				return
	_update_qa_bridge()


func _update_qa_bridge() -> void:
	if not web_mobile_bridge.is_available() or forge_overlay == null:
		return
	var screen := "forge"
	var phase := "idle"
	if orientation_prompt and orientation_prompt.visible:
		screen = "portrait"
		phase = "portrait"
	elif not forge_overlay.visible:
		if _combat_ui_ready:
			screen = "combat"
			phase = "combat"
		else:
			screen = "transition"
			phase = "settling"
	elif interpreter.in_flight and not _loading_ui_ready:
		phase = "settling"
	elif interpreter.in_flight:
		phase = "loading"
	elif review_mode and not _review_ui_ready:
		screen = "confirmation"
		phase = "settling"
	elif modify_mode:
		phase = "modify"
		screen = "confirmation"
	elif review_mode:
		screen = "confirmation"
		phase = "error" if interpretation_error_mode else "result"
	var request_id := interpreter.active_request_id
	if request_id.is_empty():
		request_id = str(pending_result.get("request_id", ""))
	var selector_visible := pattern_selector.visible
	if developer_mode and not modify_mode:
		selector_visible = selector_visible and _developer_ui_ready
	var active_projectiles := 0
	var active_area_blasts := 0
	for transient: Node in get_tree().get_nodes_in_group("forge_transient_attack"):
		if transient is ForgeProjectile:
			active_projectiles += 1
		elif transient is ForgeAreaBlast:
			active_area_blasts += 1
	var state := {
		"screen": screen,
		"phase": phase,
		"request_count": interpreter.request_count,
		"attempts": interpreter.attempts,
		"request_attempts": interpreter.attempts,
		"in_flight": interpreter.in_flight,
		"request_id": request_id,
		"description": _description_draft,
		"request_snapshot": last_request_snapshot,
		"description_revision": _last_web_description_revision,
		"description_composing": _web_description_composing,
		"interpretation_error": interpretation_error_mode,
		"drawing_count": drawing_canvas.strokes.size(),
		"selector_visible": selector_visible,
		"selected_pattern": pattern_selector.selected_pattern(),
		"developer_mode": developer_mode,
		"modify_mode": modify_mode,
		"review_mode": review_mode,
		"result": pending_result,
		"spec": pending_spec.to_dict() if pending_spec else {},
		"confirmation_fields": _confirmation_field_evidence(),
		"runtime_valid": bool(pending_result.get("runtime_valid", false)),
		"power_score": pending_spec.power_score if pending_spec else 0,
		"fallback_reason": str(pending_result.get("fallback_reason", "")),
		"message": review_summary.text if review_mode else forge_status.text,
		"late_response_ignored": interpreter.late_response_ignored,
		"http_result_code": interpreter.last_http_result_code,
		"http_response_code": interpreter.last_http_response_code,
		"feedback_count": _qa_feedback_count,
		"attack_count": _qa_attack_count,
		"last_attack_pattern": _qa_last_attack_pattern,
		"combat_message": combat_status.text,
		"active_projectiles": active_projectiles,
		"active_area_blasts": active_area_blasts,
		"projectile_origin": _vector_dictionary(_qa_projectile_origin) if _qa_has_projectile_origin else {},
		"area_impact_position": _vector_dictionary(_qa_area_impact_position) if _qa_has_area_impact else {},
		"area_impact_distance": _qa_projectile_origin.distance_to(_qa_area_impact_position) if _qa_has_projectile_origin and _qa_has_area_impact else 0.0,
		"stroke_geometry": _stroke_fit_evidence(),
		"visual_transforms": _visual_transform_evidence(),
	}
	var pattern_rects: Array[Dictionary] = []
	for button: Button in pattern_selector.buttons():
		pattern_rects.append(_rect_dictionary(button))
	var controls := {
		"canvas": _rect_dictionary(drawing_canvas),
		"forge": _rect_dictionary(generate_button),
		"reset": _rect_dictionary(reset_button),
		"cancel": _rect_dictionary(cancel_button),
		"confirm": _rect_dictionary(confirm_button),
		"modify": _rect_dictionary(modify_button),
		"try_again": _rect_dictionary(try_again_button),
		"feedback": _rect_dictionary(feedback_button),
		"attack": _rect_dictionary(attack_button),
		"reforge": _rect_dictionary(reforge_button),
		"back": _rect_dictionary(back_button),
		"stroke_preview": _rect_dictionary(review_visual_host),
		"pattern_buttons": pattern_rects,
	}
	web_mobile_bridge.update_qa_state(state, controls, size)


func _stroke_fit_evidence() -> Dictionary:
	var source: Array[PackedVector2Array] = request_strokes
	if source.is_empty():
		source = current_strokes
	if source.is_empty():
		return {}
	var transform := StrokeFit.fit_transform(source, WeaponVisual.DEFAULT_TARGET_RECT)
	if not bool(transform.get("valid", false)):
		return {}
	var source_aspect := StrokeFit.aspect_ratio(source)
	var fitted := StrokeFit.map_strokes(source, WeaponVisual.DEFAULT_TARGET_RECT)
	var rendered_aspect := StrokeFit.aspect_ratio(fitted)
	return {
		"source_bounds": _vector_rect_dictionary(transform.source_bounds),
		"fitted_bounds": _vector_rect_dictionary(transform.fitted_rect),
		"source_aspect": source_aspect,
		"rendered_aspect": rendered_aspect,
		"relative_aspect_error": absf(rendered_aspect / maxf(source_aspect, 0.001) - 1.0),
		"scale_x": float(transform.scale),
		"scale_y": float(transform.scale),
		"padding_fraction": float(transform.padding_fraction),
	}


func _vector_rect_dictionary(rect: Rect2) -> Dictionary:
	return {
		"x": rect.position.x,
		"y": rect.position.y,
		"width": rect.size.x,
		"height": rect.size.y,
	}


func _vector_dictionary(value: Vector2) -> Dictionary:
	return {"x": value.x, "y": value.y}


func _visual_transform_evidence() -> Dictionary:
	var projectiles: Array[Dictionary] = []
	for transient: Node in get_tree().get_nodes_in_group("forge_transient_attack"):
		if transient is ForgeProjectile:
			var projectile_visual: Variant = transient.get("_visual")
			if projectile_visual is CanvasItem:
				projectiles.append(_canvas_transform_scale(projectile_visual))
	return {
		"review": _canvas_transform_scale(review_weapon_visual),
		"held": _canvas_transform_scale(player.weapon_visual if is_instance_valid(player) else null),
		"projectiles": projectiles,
	}


func _canvas_transform_scale(item: CanvasItem) -> Dictionary:
	if not is_instance_valid(item):
		return {}
	var item_transform: Transform2D = item.global_transform
	var scale_x: float = item_transform.x.length()
	var scale_y: float = item_transform.y.length()
	return {
		"scale_x": scale_x,
		"scale_y": scale_y,
		"absolute_delta": absf(scale_x - scale_y),
	}


func _mark_review_ui_ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if not review_mode:
		return
	_review_ui_ready = true
	_update_qa_bridge()


func _mark_loading_ui_ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if not interpreter.in_flight:
		return
	_loading_ui_ready = true
	_update_qa_bridge()


func _mark_developer_ui_ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if not developer_mode:
		return
	_developer_ui_ready = true
	_update_qa_bridge()


func _confirmation_field_evidence() -> Dictionary:
	if pending_spec == null or not review_mode:
		return {}
	return {
		"name": pending_spec.display_name,
		"summary": str(pending_result.get("interpretation_summary", "Weapon interpretation ready.")),
		"attack_pattern": pending_spec.attack_pattern,
		"weapon_form": pending_spec.weapon_form,
		"delivery": pending_spec.delivery,
		"trajectory": pending_spec.trajectory,
		"impact": pending_spec.impact,
		"area_effect": pending_spec.area_effect,
		"element": pending_spec.element,
		"damage": pending_spec.damage,
		"attack_speed": pending_spec.attack_speed,
		"range": pending_spec.attack_range,
		"special_ability": pending_spec.special_ability,
		"status_effect": pending_spec.status_effect,
		"weakness": pending_spec.weakness_label(),
		"power_score": pending_spec.power_score,
	}


func _rect_dictionary(control: Control) -> Dictionary:
	if control == null:
		return {"x": 0.0, "y": 0.0, "width": 0.0, "height": 0.0}
	var rect := control.get_global_rect()
	return {
		"x": rect.position.x,
		"y": rect.position.y,
		"width": rect.size.x if control.is_visible_in_tree() else 0.0,
		"height": rect.size.y if control.is_visible_in_tree() else 0.0,
	}


func _button(label_text: String, accent: Color, font_size: int) -> Button:
	var button := Button.new()
	button.text = label_text
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_color_override("font_color", TEXT)
	button.add_theme_color_override("font_hover_color", TEXT)
	button.add_theme_color_override("font_pressed_color", NAVY)
	button.add_theme_stylebox_override("normal", _panel_style(PANEL_LIGHT, accent, 2))
	button.add_theme_stylebox_override("hover", _panel_style(Color("#244366"), accent, 3))
	button.add_theme_stylebox_override("pressed", _panel_style(accent, accent, 2))
	button.add_theme_stylebox_override("disabled", _panel_style(Color("#18263a"), Color("#46566e"), 1))
	return button


func _panel_style(background: Color, border: Color, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(8)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style
