extends Control

const NAVY := Color("#091424")
const PANEL := Color("#12233b")
const PANEL_LIGHT := Color("#1a3150")
const TEXT := Color("#edf4ff")
const MUTED := Color("#9bb0cf")
const CYAN := Color("#65d9ff")
const ORANGE := Color("#ffb65c")

var service := MockAIService.new()
var world: Node2D
var player: ForgePlayer
var dummy: TrainingDummy
var drawing_canvas: DrawingCanvas
var description_input: LineEdit
var forge_overlay: Control
var forge_status: Label
var stats_label: Label
var combat_status: Label
var dummy_health_label: Label
var reforge_button: Button
var attack_button: Button
var current_spec: WeaponSpec
var current_strokes: Array[PackedVector2Array] = []


func _ready() -> void:
	set_process_unhandled_input(true)
	_build_world()
	_build_hud()
	_build_forge_overlay()
	resized.connect(_layout_world)
	_layout_world()
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), NAVY, true)
	var horizon := size.y * 0.70
	draw_rect(Rect2(0, horizon, size.x, size.y - horizon), Color("#14243b"), true)
	draw_line(Vector2(0, horizon), Vector2(size.x, horizon), Color("#355174"), 3.0)
	for x in range(0, int(size.x) + 1, 96):
		draw_line(Vector2(x, horizon), Vector2(x - 55, size.y), Color("#1e3552"), 2.0)
	draw_string(ThemeDB.fallback_font, Vector2(size.x * 0.5 - 175, horizon - 30), "M0 COMBAT PROVING GROUND", HORIZONTAL_ALIGNMENT_CENTER, 350, 18, Color("#395a7f"))


func _build_world() -> void:
	world = Node2D.new()
	world.name = "World"
	add_child(world)
	player = ForgePlayer.new()
	player.name = "TestPilot"
	player.attack_requested.connect(_on_player_attack)
	world.add_child(player)
	dummy = TrainingDummy.new()
	dummy.name = "TrainingDummy"
	dummy.health_changed.connect(_on_dummy_health_changed)
	dummy.defeated.connect(_on_dummy_defeated)
	world.add_child(dummy)


func _build_hud() -> void:
	var top_panel := PanelContainer.new()
	top_panel.name = "WeaponReadout"
	top_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	top_panel.position = Vector2(24, 20)
	top_panel.size = Vector2(510, 176)
	top_panel.add_theme_stylebox_override("panel", _panel_style(PANEL, CYAN, 2))
	add_child(top_panel)
	var top_margin := MarginContainer.new()
	top_margin.add_theme_constant_override("margin_left", 18)
	top_margin.add_theme_constant_override("margin_right", 18)
	top_margin.add_theme_constant_override("margin_top", 14)
	top_margin.add_theme_constant_override("margin_bottom", 14)
	top_panel.add_child(top_margin)
	stats_label = Label.new()
	stats_label.text = "NO WEAPON FORGED\nDraw an idea to begin the M0 probe."
	stats_label.add_theme_color_override("font_color", TEXT)
	stats_label.add_theme_font_size_override("font_size", 18)
	stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	top_margin.add_child(stats_label)

	reforge_button = _button("REFORGE", ORANGE, 18)
	reforge_button.name = "ReforgeButton"
	reforge_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	reforge_button.position = Vector2(size.x - 190, 24)
	reforge_button.size = Vector2(166, 82)
	reforge_button.pressed.connect(_open_reforge)
	reforge_button.disabled = true
	add_child(reforge_button)

	combat_status = Label.new()
	combat_status.text = "Forge a weapon, then move into range and attack."
	combat_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	combat_status.add_theme_color_override("font_color", MUTED)
	combat_status.add_theme_font_size_override("font_size", 16)
	combat_status.anchor_right = 1.0
	combat_status.offset_left = 0.0
	combat_status.offset_top = 210.0
	combat_status.offset_right = 0.0
	combat_status.offset_bottom = 244.0
	add_child(combat_status)

	dummy_health_label = Label.new()
	dummy_health_label.text = "DUMMY 160 / 160"
	dummy_health_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dummy_health_label.add_theme_color_override("font_color", Color("#78eea6"))
	dummy_health_label.add_theme_font_size_override("font_size", 16)
	dummy_health_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	dummy_health_label.position = Vector2(size.x - 264, 118)
	dummy_health_label.size = Vector2(240, 30)
	add_child(dummy_health_label)

	var movement := HBoxContainer.new()
	movement.name = "TouchMovement"
	movement.add_theme_constant_override("separation", 12)
	movement.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	movement.position = Vector2(24, size.y - 108)
	movement.size = Vector2(276, 84)
	add_child(movement)
	var left_button := _button("LEFT", CYAN, 18)
	left_button.name = "MoveLeftButton"
	left_button.custom_minimum_size = Vector2(132, 84)
	left_button.button_down.connect(func(): player.set_touch_axis(-1.0))
	left_button.button_up.connect(func(): player.set_touch_axis(0.0))
	movement.add_child(left_button)
	var right_button := _button("RIGHT", CYAN, 18)
	right_button.name = "MoveRightButton"
	right_button.custom_minimum_size = Vector2(132, 84)
	right_button.button_down.connect(func(): player.set_touch_axis(1.0))
	right_button.button_up.connect(func(): player.set_touch_axis(0.0))
	movement.add_child(right_button)

	attack_button = _button("ATTACK", ORANGE, 21)
	attack_button.name = "AttackButton"
	attack_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	attack_button.position = Vector2(size.x - 202, size.y - 114)
	attack_button.size = Vector2(178, 90)
	attack_button.pressed.connect(player.attack)
	attack_button.disabled = true
	add_child(attack_button)


func _build_forge_overlay() -> void:
	forge_overlay = ColorRect.new()
	forge_overlay.name = "ForgeOverlay"
	forge_overlay.color = Color(0.02, 0.04, 0.075, 1.0)
	forge_overlay.z_index = 100
	forge_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	forge_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(forge_overlay)

	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 36)
	panel.add_theme_stylebox_override("panel", _panel_style(PANEL, CYAN, 3))
	forge_overlay.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 20)
	panel.add_child(margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 10)
	margin.add_child(layout)

	var title_row := HBoxContainer.new()
	layout.add_child(title_row)
	var title := Label.new()
	title.text = "PROJECT FORGE  /  M0 WEAPON LAB"
	title.add_theme_color_override("font_color", TEXT)
	title.add_theme_font_size_override("font_size", 28)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title)
	var close_button := _button("BACK", MUTED, 16)
	close_button.name = "BackButton"
	close_button.custom_minimum_size = Vector2(110, 78)
	close_button.pressed.connect(func(): if current_spec: forge_overlay.hide())
	title_row.add_child(close_button)

	var guide := Label.new()
	guide.text = "1  Draw with mouse or touch     2  Add one sentence     3  Generate a bounded mock WeaponSpec"
	guide.add_theme_color_override("font_color", MUTED)
	guide.add_theme_font_size_override("font_size", 16)
	layout.add_child(guide)

	drawing_canvas = DrawingCanvas.new()
	drawing_canvas.name = "DrawingCanvas"
	drawing_canvas.custom_minimum_size = Vector2(0, 290)
	drawing_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(drawing_canvas)

	var input_row := HBoxContainer.new()
	input_row.add_theme_constant_override("separation", 10)
	layout.add_child(input_row)
	var prompt_label := Label.new()
	prompt_label.text = "DESCRIPTION"
	prompt_label.custom_minimum_size = Vector2(135, 82)
	prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	prompt_label.add_theme_color_override("font_color", CYAN)
	prompt_label.add_theme_font_size_override("font_size", 16)
	input_row.add_child(prompt_label)
	description_input = LineEdit.new()
	description_input.name = "DescriptionInput"
	description_input.placeholder_text = "e.g. a heavy fire blade for close combat"
	description_input.clear_button_enabled = true
	description_input.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_DEFAULT
	description_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	description_input.custom_minimum_size.y = 82
	description_input.add_theme_font_size_override("font_size", 18)
	input_row.add_child(description_input)

	var action_row := HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 10)
	layout.add_child(action_row)
	var clear_button := _button("CLEAR DRAWING", MUTED, 16)
	clear_button.name = "ClearDrawingButton"
	clear_button.custom_minimum_size = Vector2(176, 84)
	clear_button.pressed.connect(drawing_canvas.clear_drawing)
	action_row.add_child(clear_button)
	var melee_example := _button("MELEE IDEA", Color("#ff845e"), 16)
	melee_example.name = "MeleeIdeaButton"
	melee_example.custom_minimum_size = Vector2(154, 84)
	melee_example.pressed.connect(func(): description_input.text = "a heavy fire blade for close combat")
	action_row.add_child(melee_example)
	var projectile_example := _button("PROJECTILE IDEA", Color("#73dcff"), 16)
	projectile_example.name = "ProjectileIdeaButton"
	projectile_example.custom_minimum_size = Vector2(184, 84)
	projectile_example.pressed.connect(func(): description_input.text = "a fast ice projectile launcher")
	action_row.add_child(projectile_example)
	forge_status = Label.new()
	forge_status.text = "Local mock only — no network request or API key."
	forge_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	forge_status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	forge_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	forge_status.add_theme_color_override("font_color", MUTED)
	forge_status.add_theme_font_size_override("font_size", 14)
	action_row.add_child(forge_status)
	var generate_button := _button("GENERATE WEAPON", ORANGE, 18)
	generate_button.name = "GenerateWeaponButton"
	generate_button.custom_minimum_size = Vector2(210, 84)
	generate_button.pressed.connect(_generate_weapon)
	action_row.add_child(generate_button)


func _generate_weapon() -> void:
	if drawing_canvas.is_empty():
		forge_status.text = "Draw at least one stroke first."
		forge_status.add_theme_color_override("font_color", Color("#ff8f8f"))
		return
	current_strokes = drawing_canvas.get_normalized_strokes()
	current_spec = service.generate(description_input.text, drawing_canvas.drawing_summary())
	player.equip(current_spec, current_strokes)
	stats_label.text = (
		"%s\nDAMAGE  %d     POWER  %d / 100\nATTACK  %s\nEFFECT  %s\nWEAKNESS  %s"
		% [current_spec.display_name, current_spec.damage, current_spec.power_score,
		current_spec.attack_label(), current_spec.effect_label(), current_spec.weakness_label()]
	)
	forge_status.add_theme_color_override("font_color", MUTED)
	forge_status.text = "Generated by local mock in %d ms." % service.last_metadata.get("elapsed_ms", 0)
	combat_status.text = "Weapon ready. Move with A/D or touch; attack with SPACE or ATTACK."
	reforge_button.disabled = false
	attack_button.disabled = false
	forge_overlay.hide()


func _open_reforge() -> void:
	drawing_canvas.clear_drawing()
	description_input.clear()
	forge_status.text = "Draw a new idea; generation replaces the active weapon."
	forge_status.add_theme_color_override("font_color", MUTED)
	forge_overlay.show()
	description_input.grab_focus()


func _on_player_attack(spec: WeaponSpec, origin: Vector2, direction: Vector2, strokes: Array[PackedVector2Array]) -> void:
	if spec.attack_pattern == "melee_slash":
		var horizontal_distance := (dummy.global_position.x - player.global_position.x) * direction.x
		if horizontal_distance >= 0.0 and horizontal_distance <= spec.attack_range + 34.0:
			dummy.take_damage(spec.damage, spec.status_effect)
			combat_status.text = "Melee hit for %d. Weakness: %s." % [spec.damage, spec.weakness_label()]
		else:
			combat_status.text = "Melee missed — move closer to the dummy."
	else:
		var projectile := ForgeProjectile.new()
		projectile.configure(spec, strokes, direction)
		projectile.global_position = origin
		projectile.hit_target.connect(func(): combat_status.text = "Projectile hit for %d (%s)." % [spec.damage, spec.effect_label()])
		world.add_child(projectile)
		combat_status.text = "Projectile launched."


func _on_dummy_health_changed(current: int, maximum: int) -> void:
	dummy_health_label.text = "DUMMY %d / %d" % [current, maximum]


func _on_dummy_defeated() -> void:
	combat_status.text = "Probe complete: dummy defeated. It will reset for another test."


func _layout_world() -> void:
	if not is_instance_valid(player):
		return
	var ground_y := size.y * 0.70 - 56.0
	player.global_position = Vector2(clampf(player.global_position.x, 80.0, size.x - 80.0), ground_y)
	if player.global_position.x <= 85.0 or player.global_position.x >= size.x - 85.0:
		player.global_position.x = size.x * 0.28
	dummy.global_position = Vector2(size.x * 0.74, ground_y - 12.0)
	player.movement_bounds = Vector2(80.0, size.x - 80.0)
	if reforge_button:
		reforge_button.position = Vector2(size.x - 190, 24)
		dummy_health_label.position = Vector2(size.x - 264, 118)
		attack_button.position = Vector2(size.x - 202, size.y - 114)
		var movement := get_node("TouchMovement") as Control
		movement.position = Vector2(24, size.y - 108)
	queue_redraw()


func _button(label_text: String, accent: Color, font_size: int) -> Button:
	var button := Button.new()
	button.text = label_text
	button.focus_mode = Control.FOCUS_NONE
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
