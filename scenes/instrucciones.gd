extends Control

# How to play (main menu and pause menu). Built in code with the look of Options and the
# power gallery: the controls, a card per element (its symbol in the element's color, its
# power and what it does), how points are earned, and a way to the power gallery.
# Rebuilt every time it opens, so it follows the language and the colorblind mode.

signal closed

const ODIN = preload("res://assets/jorge-resources/Game Selection/Odin Rounded - Bold.otf")
const HIGHLIGHT = Color(0.91, 0.61, 0.17)
const TEXT_COLOR = Color(0.86, 0.86, 0.86)
const DIM_COLOR = Color(0.62, 0.62, 0.62)
const PANEL_COLOR = Color(0.13, 0.13, 0.13, 0.97)
const SYMBOLS_PATH = "res://assets/jorge-resources/Game Selection/"
const SYMBOLS = ["", "Fire-Water symbol.png", "Air-Earth symbol rot.png", "Air-Earth symbol.png", "Fire-Water symbol rot.png"]
const DESCRIPTIONS = ["", "GALLERY_BASE_FIRE", "GALLERY_BASE_EARTH", "GALLERY_BASE_AIR", "GALLERY_BASE_WATER", "GALLERY_BASE_VOID"]
const CARD_SIZE = Vector2(280, 380)

var close_button: Button

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visibility_changed.connect(func():
		if visible:
			_build()
			close_button.grab_focus.call_deferred())
	if visible:
		_build()

func _unhandled_input(event):
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close()

func _close():
	hide()
	closed.emit()

func _build():
	for child in get_children():
		remove_child(child)
		child.queue_free()
	theme = _make_theme()

	var dim = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.75)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel = PanelContainer.new()
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = PANEL_COLOR
	panel_style.set_corner_radius_all(18)
	panel_style.set_content_margin_all(40)
	panel_style.border_color = Color(1, 1, 1, 0.08)
	panel_style.set_border_width_all(2)
	panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(panel)
	var column = VBoxContainer.new()
	column.add_theme_constant_override("separation", 22)
	panel.add_child(column)

	column.add_child(_label(tr("INSTR_TITLE"), 56, Color.WHITE))
	var controls = _label(tr("INSTR_CONTROLS"), 26, TEXT_COLOR)
	controls.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	controls.custom_minimum_size.x = 5 * CARD_SIZE.x + 4 * 20
	column.add_child(controls)

	var cards = HBoxContainer.new()
	cards.add_theme_constant_override("separation", 20)
	column.add_child(cards)
	for id in [1, 2, 3, 4, 5]:
		cards.add_child(_element_card(id))

	var line = ColorRect.new()
	line.color = Color(1, 1, 1, 0.1)
	line.custom_minimum_size.y = 2
	column.add_child(line)
	column.add_child(_label(tr("INSTR_SCORING_TITLE"), 30, HIGHLIGHT))
	var scoring = _label(tr("INSTR_SCORING"), 24, TEXT_COLOR)
	scoring.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	scoring.custom_minimum_size.x = controls.custom_minimum_size.x
	column.add_child(scoring)

	var buttons = HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	buttons.add_theme_constant_override("separation", 14)
	column.add_child(buttons)
	var gallery = _button(tr("INSTR_GALLERY_BUTTON"))
	gallery.pressed.connect(func(): add_child(PowerGallery.new()))
	buttons.add_child(gallery)
	close_button = _button(tr("UI_CLOSE"))
	close_button.pressed.connect(_close)
	buttons.add_child(close_button)

# One element: its symbol, name and power, in its color (Global.playerColors follows the
# colorblind mode), and what the power does
func _element_card(id) -> Control:
	var color = Color(Global.playerColors[id])
	var card = PanelContainer.new()
	card.custom_minimum_size = CARD_SIZE
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.18, 0.18, 0.19)
	style.set_corner_radius_all(16)
	style.set_content_margin_all(20)
	style.border_color = color
	style.border_width_bottom = 5
	card.add_theme_stylebox_override("panel", style)
	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	card.add_child(box)
	var symbol = TextureRect.new()
	symbol.texture = Global.element_symbol(id)
	symbol.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	symbol.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	symbol.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	symbol.custom_minimum_size = Vector2(0, 100)
	symbol.modulate = color
	box.add_child(symbol)
	box.add_child(_label(tr(Global.ELEMENT_KEYS[id] + "_UPPER"), 34, color))
	if id == Global.VOID_ID:
		box.add_child(_label(tr("SETUP_EXPERIMENTAL"), 16, Color(1, 0.75, 0.3)))
	box.add_child(_label(tr(Global.POWER_TAGLINES[id]), 22, color.lightened(0.35)))
	var description = _label(tr(DESCRIPTIONS[id]), 20, DIM_COLOR)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.custom_minimum_size.x = CARD_SIZE.x - 40
	box.add_child(description)
	return card

func _label(text, font_size, color) -> Label:
	var label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

func _button(text) -> Button:
	var button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(240, 60)
	return button

# Same as Options
func _make_theme():
	var ui_theme = Theme.new()
	ui_theme.default_font = ODIN
	ui_theme.default_font_size = 28
	ui_theme.set_stylebox("normal", "Button", _box(Color(0.2, 0.2, 0.2)))
	ui_theme.set_stylebox("hover", "Button", _box(Color(0.27, 0.27, 0.27)))
	ui_theme.set_stylebox("pressed", "Button", _box(Color(0.31, 0.31, 0.31)))
	ui_theme.set_stylebox("focus", "Button", _box(Color(0, 0, 0, 0), HIGHLIGHT))
	ui_theme.set_color("font_color", "Button", TEXT_COLOR)
	ui_theme.set_color("font_hover_color", "Button", HIGHLIGHT)
	ui_theme.set_color("font_focus_color", "Button", HIGHLIGHT)
	ui_theme.set_color("font_pressed_color", "Button", HIGHLIGHT)
	return ui_theme

func _box(color, border = Color(0, 0, 0, 0)):
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(10)
	style.content_margin_left = 18
	style.content_margin_right = 18
	if border.a > 0:
		style.border_color = border
		style.set_border_width_all(3)
	return style
