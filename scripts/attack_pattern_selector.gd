class_name AttackPatternSelector
extends GridContainer

signal pattern_selected(index: int, pattern: String)

const PATTERNS: PackedStringArray = [
	"melee_slash", "straight_projectile", "boomerang", "area_blast", "piercing",
]
const LABELS: PackedStringArray = [
	"MELEE SLASH", "STRAIGHT PROJECTILE", "BOOMERANG", "AREA BLAST", "PIERCING",
]
const IDEAS: PackedStringArray = [
	"a solid normal blade for close combat",
	"a fast ice projectile launcher",
	"a returning fire boomerang",
	"an electric area blast for a crowd",
	"a piercing normal lance that breaks shields",
]

var selected_index := 0
var _button_group := ButtonGroup.new()
var _buttons: Array[Button] = []


func _ready() -> void:
	columns = 3
	# Safari's visible viewport can fall to ~734x343 after browser chrome. A
	# 102px logical target remains >=48px there and about 55px at 844x390.
	custom_minimum_size.y = 212.0
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_PASS
	add_theme_constant_override("h_separation", 8)
	add_theme_constant_override("v_separation", 8)
	_button_group.allow_unpress = false
	_build_buttons()
	select_pattern(0, false)


func _build_buttons() -> void:
	if not _buttons.is_empty():
		return
	for index in PATTERNS.size():
		var button := Button.new()
		button.name = "Pattern%s" % LABELS[index].to_pascal_case().replace(" ", "")
		button.toggle_mode = true
		button.action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
		button.button_group = _button_group
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_filter = Control.MOUSE_FILTER_STOP
		button.custom_minimum_size = Vector2(0, 102)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 20)
		button.pressed.connect(_on_button_pressed.bind(index))
		_buttons.append(button)
		add_child(button)


func select_pattern(index: int, emit_change: bool = true) -> void:
	selected_index = clampi(index, 0, PATTERNS.size() - 1)
	for button_index in _buttons.size():
		_buttons[button_index].set_pressed_no_signal(button_index == selected_index)
		_apply_button_state(_buttons[button_index], button_index == selected_index, LABELS[button_index])
	if emit_change:
		pattern_selected.emit(selected_index, PATTERNS[selected_index])


func selected_pattern() -> String:
	return PATTERNS[selected_index]


func selected_idea() -> String:
	return IDEAS[selected_index]


func buttons() -> Array[Button]:
	return _buttons.duplicate()


func _on_button_pressed(index: int) -> void:
	select_pattern(index)


func _apply_button_state(button: Button, is_selected: bool, label_text: String) -> void:
	var background := Color("#65d9ff") if is_selected else Color("#1a3150")
	var border := Color("#edf4ff") if is_selected else Color("#5578a4")
	var foreground := Color("#091424") if is_selected else Color("#edf4ff")
	var style := _style(background, border, 4 if is_selected else 2)
	button.text = ("[X]  " if is_selected else "[ ]  ") + label_text
	button.add_theme_color_override("font_color", foreground)
	button.add_theme_color_override("font_pressed_color", foreground)
	button.add_theme_color_override("font_hover_color", foreground)
	button.add_theme_color_override("font_hover_pressed_color", foreground)
	button.add_theme_color_override("font_focus_color", foreground)
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("pressed", style)
	button.add_theme_stylebox_override("hover", style)
	button.add_theme_stylebox_override("hover_pressed", style)
	button.add_theme_stylebox_override("focus", style)
	button.queue_redraw()


func _style(background: Color, border: Color, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(8)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style
