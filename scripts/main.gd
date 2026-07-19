extends Control

const NAVY := Color("#091424")
const PANEL := Color("#12233b")
const PANEL_LIGHT := Color("#1a3150")
const TEXT := Color("#edf4ff")
const MUTED := Color("#9bb0cf")
const CYAN := Color("#65d9ff")
const ORANGE := Color("#ffb65c")
const IDEA_TEXT := [
	"a solid normal blade for close combat",
	"a fast ice projectile launcher",
	"a returning fire boomerang",
	"an electric area blast for a crowd",
	"a piercing normal lance that breaks shields",
]

var service := MockAIService.new()
var world: Node2D
var player: ForgePlayer
var targets: Array[TrainingDummy] = []
var drawing_canvas: DrawingCanvas
var description_input: LineEdit
var idea_selector: OptionButton
var forge_overlay: Control
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
	set_process_unhandled_input(true)
	_build_world()
	_build_hud()
	_build_forge_overlay()
	resized.connect(_layout_world)
	_layout_world()
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
	target.defeated.connect(func(): combat_status.text = "%s defeated; automatic reset armed." % label_text)
	world.add_child(target)
	targets.append(target)


func _build_hud() -> void:
	var top_panel := PanelContainer.new()
	top_panel.name = "WeaponReadout"
	top_panel.position = Vector2(18, 16)
	top_panel.size = Vector2(500, 184)
	top_panel.add_theme_stylebox_override("panel", _panel_style(PANEL, CYAN, 2))
	add_child(top_panel)
	var top_margin := MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]: top_margin.add_theme_constant_override(side, 12)
	top_panel.add_child(top_margin)
	stats_label = Label.new()
	stats_label.text = "NO WEAPON FORGED\nDraw an idea to start the M1A compiler."
	stats_label.add_theme_color_override("font_color", TEXT)
	stats_label.add_theme_font_size_override("font_size", 15)
	stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	top_margin.add_child(stats_label)

	var budget_panel := PanelContainer.new()
	budget_panel.name = "BudgetReadout"
	budget_panel.position = Vector2(534, 16)
	budget_panel.size = Vector2(450, 184)
	budget_panel.add_theme_stylebox_override("panel", _panel_style(PANEL, Color("#b392ff"), 2))
	add_child(budget_panel)
	var budget_margin := MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]: budget_margin.add_theme_constant_override(side, 12)
	budget_panel.add_child(budget_margin)
	budget_label = Label.new()
	budget_label.text = "POWER BUDGET  —  WAITING\nExplicit component costs and repair reasons appear here."
	budget_label.add_theme_color_override("font_color", TEXT)
	budget_label.add_theme_font_size_override("font_size", 14)
	budget_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
	combat_status.anchor_right = 1.0
	combat_status.offset_top = 208.0
	combat_status.offset_bottom = 236.0
	add_child(combat_status)

	target_health_label = Label.new()
	target_health_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	target_health_label.add_theme_color_override("font_color", Color("#78eea6"))
	target_health_label.add_theme_font_size_override("font_size", 13)
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
	forge_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(forge_overlay)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 28)
	panel.add_theme_stylebox_override("panel", _panel_style(PANEL, CYAN, 3))
	forge_overlay.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]: margin.add_theme_constant_override(side, 16)
	panel.add_child(margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 8)
	margin.add_child(layout)

	var title_row := HBoxContainer.new()
	layout.add_child(title_row)
	var title := Label.new()
	title.text = "PROJECT FORGE  /  M1A WEAPON COMPILER"
	title.add_theme_color_override("font_color", TEXT)
	title.add_theme_font_size_override("font_size", 25)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title)
	var close_button := _button("BACK", MUTED, 15)
	close_button.name = "BackButton"
	close_button.custom_minimum_size = Vector2(100, 60)
	close_button.pressed.connect(func(): if current_spec: forge_overlay.hide())
	title_row.add_child(close_button)

	var guide := Label.new()
	guide.text = "Draw with mouse/touch. Describe one weapon. The local compiler validates, budgets and repairs every field."
	guide.add_theme_color_override("font_color", MUTED)
	guide.add_theme_font_size_override("font_size", 15)
	layout.add_child(guide)
	drawing_canvas = DrawingCanvas.new()
	drawing_canvas.name = "DrawingCanvas"
	drawing_canvas.custom_minimum_size = Vector2(0, 235)
	drawing_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(drawing_canvas)

	var input_row := HBoxContainer.new()
	input_row.add_theme_constant_override("separation", 10)
	layout.add_child(input_row)
	var prompt_label := Label.new()
	prompt_label.text = "DESCRIPTION"
	prompt_label.custom_minimum_size = Vector2(125, 66)
	prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	prompt_label.add_theme_color_override("font_color", CYAN)
	prompt_label.add_theme_font_size_override("font_size", 15)
	input_row.add_child(prompt_label)
	description_input = LineEdit.new()
	description_input.name = "DescriptionInput"
	description_input.placeholder_text = "e.g. a returning fire boomerang"
	description_input.clear_button_enabled = true
	description_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	description_input.custom_minimum_size.y = 66
	description_input.add_theme_font_size_override("font_size", 17)
	input_row.add_child(description_input)

	var action_row := HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 8)
	layout.add_child(action_row)
	var clear_button := _button("CLEAR", MUTED, 14)
	clear_button.name = "ClearDrawingButton"
	clear_button.custom_minimum_size = Vector2(105, 70)
	clear_button.pressed.connect(drawing_canvas.clear_drawing)
	action_row.add_child(clear_button)
	idea_selector = OptionButton.new()
	idea_selector.name = "IdeaSelector"
	idea_selector.custom_minimum_size = Vector2(230, 70)
	idea_selector.add_theme_font_size_override("font_size", 15)
	for label_text in ["MELEE SLASH", "STRAIGHT PROJECTILE", "BOOMERANG", "AREA BLAST", "PIERCING"]: idea_selector.add_item(label_text)
	idea_selector.item_selected.connect(func(index: int): description_input.text = IDEA_TEXT[index])
	action_row.add_child(idea_selector)
	var load_button := _button("LOAD IDEA", Color("#b392ff"), 14)
	load_button.name = "LoadIdeaButton"
	load_button.custom_minimum_size = Vector2(125, 70)
	load_button.pressed.connect(func(): description_input.text = IDEA_TEXT[idea_selector.selected])
	action_row.add_child(load_button)
	forge_status = Label.new()
	forge_status.text = "Offline deterministic mock — no API key."
	forge_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	forge_status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	forge_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	forge_status.add_theme_color_override("font_color", MUTED)
	forge_status.add_theme_font_size_override("font_size", 13)
	action_row.add_child(forge_status)
	var generate_button := _button("COMPILE WEAPON", ORANGE, 17)
	generate_button.name = "GenerateWeaponButton"
	generate_button.custom_minimum_size = Vector2(190, 70)
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
	attack_button.disabled = false


func _open_reforge() -> void:
	attack_button.disabled = true
	drawing_canvas.clear_drawing()
	description_input.clear()
	forge_status.text = "Draw again; a valid replacement is committed only after compile."
	forge_status.add_theme_color_override("font_color", MUTED)
	forge_overlay.show()
	description_input.grab_focus()


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
	combat_status.text = "Area blast expanding to %.0f px." % spec.area_radius


func _launch_projectile(spec: WeaponSpec, origin: Vector2, direction: Vector2, strokes: Array[PackedVector2Array]) -> void:
	var projectile := ForgeProjectile.new()
	projectile.configure(spec, strokes, direction, player)
	projectile.global_position = origin
	projectile.hit_target.connect(func(label_text: String, amount: int): combat_status.text = "%s hit %s for %d." % [spec.attack_label(), label_text, amount])
	world.add_child(projectile)
	combat_status.text = {"straight_projectile": "Straight projectile launched; stops on first target.", "boomerang": "Boomerang outbound; it can strike again on return.", "piercing": "Piercing lance launched; shield bypass active."}.get(spec.attack_pattern, "Attack launched.")


func _on_target_damage(label_text: String, amount: int, note: String) -> void:
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
