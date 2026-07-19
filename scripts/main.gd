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
var targets: Array[TrainingDummy] = []
var drawing_canvas: DrawingCanvas
var description_input: LineEdit
var pattern_selector: AttackPatternSelector
var forge_overlay: Control
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


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_world()
	_build_hud()
	_build_forge_overlay()
	_build_orientation_prompt()
	resized.connect(_on_viewport_resized)
	_on_viewport_resized()
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), NAVY, true)
	var horizon := size.y * 0.69
	draw_rect(Rect2(0, horizon, size.x, size.y - horizon), Color("#14243b"), true)
	draw_line(Vector2(0, horizon), Vector2(size.x, horizon), Color("#355174"), 3.0)
	for x in range(0, int(size.x) + 1, 96):
		draw_line(Vector2(x, horizon), Vector2(x - 55, size.y), Color("#1e3552"), 2.0)
	draw_string(ThemeDB.fallback_font, Vector2(size.x * 0.5 - 190, horizon - 20), "M1A DETERMINISTIC COMBAT LAB", HORIZONTAL_ALIGNMENT_CENTER, 380, 17, Color("#44698f"))


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
	stats_label.text = "NO WEAPON FORGED\nDraw an idea to start the M1A compiler."
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
	var panel := PanelContainer.new()
	panel.name = "ForgePanel"
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 24)
	panel.add_theme_stylebox_override("panel", _panel_style(PANEL, CYAN, 3))
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	forge_overlay.add_child(panel)
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_PASS
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 22)
	panel.add_child(margin)
	var layout := VBoxContainer.new()
	layout.name = "ForgeLayout"
	layout.mouse_filter = Control.MOUSE_FILTER_PASS
	layout.add_theme_constant_override("separation", 6)
	margin.add_child(layout)

	var title_row := HBoxContainer.new()
	title_row.mouse_filter = Control.MOUSE_FILTER_PASS
	layout.add_child(title_row)
	var title := Label.new()
	title.text = "PROJECT FORGE  /  M1A WEAPON COMPILER"
	title.add_theme_color_override("font_color", TEXT)
	title.add_theme_font_size_override("font_size", 25)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_row.add_child(title)
	var close_button := _button("BACK", MUTED, 15)
	close_button.name = "BackButton"
	close_button.custom_minimum_size = Vector2(128, 102)
	close_button.pressed.connect(_close_reforge)
	title_row.add_child(close_button)

	drawing_canvas = DrawingCanvas.new()
	drawing_canvas.name = "DrawingCanvas"
	drawing_canvas.custom_minimum_size = Vector2(0, 120)
	drawing_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(drawing_canvas)

	var input_row := HBoxContainer.new()
	input_row.mouse_filter = Control.MOUSE_FILTER_PASS
	input_row.add_theme_constant_override("separation", 10)
	layout.add_child(input_row)
	var prompt_label := Label.new()
	prompt_label.text = "DESCRIPTION"
	prompt_label.custom_minimum_size = Vector2(142, 90)
	prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	prompt_label.add_theme_color_override("font_color", CYAN)
	prompt_label.add_theme_font_size_override("font_size", 18)
	prompt_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	input_row.add_child(prompt_label)
	description_input = LineEdit.new()
	description_input.name = "DescriptionInput"
	description_input.placeholder_text = "e.g. a returning fire boomerang"
	description_input.clear_button_enabled = true
	description_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	description_input.custom_minimum_size.y = 90
	description_input.mouse_filter = Control.MOUSE_FILTER_STOP
	description_input.add_theme_font_size_override("font_size", 22)
	input_row.add_child(description_input)

	pattern_selector = AttackPatternSelector.new()
	pattern_selector.name = "AttackPatternSelector"
	pattern_selector.pattern_selected.connect(_on_pattern_selected)
	layout.add_child(pattern_selector)

	var action_row := HBoxContainer.new()
	action_row.mouse_filter = Control.MOUSE_FILTER_PASS
	action_row.add_theme_constant_override("separation", 8)
	layout.add_child(action_row)
	var clear_button := _button("CLEAR", MUTED, 18)
	clear_button.name = "ClearDrawingButton"
	clear_button.custom_minimum_size = Vector2(126, 102)
	clear_button.pressed.connect(drawing_canvas.clear_drawing)
	action_row.add_child(clear_button)
	var load_button := _button("LOAD IDEA", Color("#b392ff"), 18)
	load_button.name = "LoadIdeaButton"
	load_button.custom_minimum_size = Vector2(158, 102)
	load_button.pressed.connect(_load_selected_idea)
	action_row.add_child(load_button)
	forge_status = Label.new()
	forge_status.text = "Offline deterministic mock — no API key."
	forge_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	forge_status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	forge_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	forge_status.add_theme_color_override("font_color", MUTED)
	forge_status.add_theme_font_size_override("font_size", 16)
	forge_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	action_row.add_child(forge_status)
	var generate_button := _button("COMPILE WEAPON", ORANGE, 20)
	generate_button.name = "GenerateWeaponButton"
	generate_button.custom_minimum_size = Vector2(226, 102)
	generate_button.pressed.connect(_generate_weapon)
	action_row.add_child(generate_button)


func _generate_weapon() -> void:
	if drawing_canvas.is_empty():
		forge_status.text = "Draw at least one stroke first."
		forge_status.add_theme_color_override("font_color", Color("#ff8f8f"))
		return
	current_strokes = drawing_canvas.get_normalized_strokes()
	current_spec = service.generate(
		description_input.text,
		drawing_canvas.drawing_summary(),
		pattern_selector.selected_pattern(),
	)
	player.equip(current_spec, current_strokes)
	player.set_combat_enabled(true)
	description_input.release_focus()
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
		float(parts.get("projectile_speed", 0)) + float(parts.get("area_radius", 0)) + float(parts.get("piercing", 0)),
		parts.get("drawback_credit", 0), current_spec.corrections.size()]
	)
	forge_status.add_theme_color_override("font_color", MUTED)
	forge_status.text = "Valid • %d repair(s) • %d ms • JSONL logged" % [current_spec.corrections.size(), service.last_metadata.get("elapsed_ms", 0)]
	combat_status.text = "%s ready. Use A/D or touch, then SPACE/ATTACK." % current_spec.attack_label()
	reforge_button.disabled = false
	attack_button.disabled = true
	forge_overlay.hide()
	_arm_attack_button()


func _arm_attack_button() -> void:
	# Prevent the pointer release that closes the overlay from falling through to ATTACK.
	await get_tree().process_frame
	await get_tree().process_frame
	if current_spec and not forge_overlay.visible:
		attack_button.disabled = false


func _close_reforge() -> void:
	if current_spec == null:
		forge_status.text = "Forge one weapon before returning to combat."
		forge_status.add_theme_color_override("font_color", Color("#ffca78"))
		return
	description_input.release_focus()
	forge_overlay.hide()
	player.set_combat_enabled(true)
	combat_status.text = "%s ready. Use A/D or touch, then SPACE/ATTACK." % current_spec.attack_label()
	_arm_attack_button()


func _open_reforge() -> void:
	attack_button.disabled = true
	player.set_combat_enabled(false)
	_clear_transient_combat()
	drawing_canvas.clear_drawing()
	description_input.clear()
	description_input.release_focus()
	var current_index := AttackPatternSelector.PATTERNS.find(current_spec.attack_pattern) if current_spec else 0
	pattern_selector.select_pattern(maxi(current_index, 0), false)
	forge_status.text = "Draw again; a valid replacement is committed only after compile."
	forge_status.add_theme_color_override("font_color", MUTED)
	forge_overlay.show()


func _load_selected_idea() -> void:
	description_input.text = pattern_selector.selected_idea()
	forge_status.text = "%s example loaded. Edit it or compile directly." % pattern_selector.selected_pattern().replace("_", " ").to_upper()
	forge_status.add_theme_color_override("font_color", MUTED)


func _on_pattern_selected(_index: int, pattern: String) -> void:
	forge_status.text = "%s selected. LOAD IDEA or compile your text with this M1A test override." % pattern.replace("_", " ").to_upper()
	forge_status.add_theme_color_override("font_color", Color("#b9eaff"))


func _clear_transient_combat() -> void:
	for node: Node in get_tree().get_nodes_in_group("forge_transient_attack"):
		if is_instance_valid(node):
			var parent := node.get_parent()
			if parent:
				parent.remove_child(node)
			node.queue_free()
	for target in targets:
		target.clear_transient_status()


func _on_player_attack(spec: WeaponSpec, origin: Vector2, direction: Vector2, strokes: Array[PackedVector2Array]) -> void:
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
	var projectile := ForgeProjectile.new()
	projectile.configure(spec, strokes, direction, player)
	projectile.global_position = origin
	projectile.hit_target.connect(func(label_text: String, amount: int): combat_status.text = "%s hit %s for %d." % [spec.attack_label(), label_text, amount])
	world.add_child(projectile)
	projectile.add_to_group("forge_transient_attack")
	combat_status.text = {"straight_projectile": "Straight projectile launched; stops on first target.", "boomerang": "Boomerang outbound; it can strike again on return.", "piercing": "Piercing lance launched; shield bypass active."}.get(spec.attack_pattern, "Attack launched.")


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
	_update_orientation_prompt()


func _update_orientation_prompt() -> void:
	if orientation_prompt == null:
		return
	var portrait := RotationPrompt.should_show_for(size)
	orientation_prompt.visible = portrait
	if portrait:
		description_input.release_focus()
		player.set_combat_enabled(false)
		player.set_touch_axis(0.0)
		attack_button.disabled = true
	elif forge_overlay.visible:
		player.set_combat_enabled(false)
		attack_button.disabled = true
	elif current_spec:
		player.set_combat_enabled(true)
		attack_button.disabled = false


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
