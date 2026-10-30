extends Control

# Patch notes window opened from the version button in the main menu. Every
# release is listed newest first; the bar on the left jumps to any version and
# highlights the one being read. Closes with the Close button or ui_cancel.

signal closed

const ODIN_FONT = preload("res://assets/jorge-resources/Game Selection/Odin Rounded - Bold.otf")
const HIGHLIGHT = Color(0.91, 0.61, 0.17)
const TEXT_COLOR = Color(0.86, 0.86, 0.86)
const DIM_COLOR = Color(0.6, 0.6, 0.6)

var notes_scroll
var notes_list
var version_buttons = [] # Same order as PatchNotes.RELEASES
var release_blocks = []
var close_button

func _ready():
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_layout()
	notes_scroll.get_v_scroll_bar().value_changed.connect(func(_value): _highlight_visible_release())
	_highlight(0)
	version_buttons[0].grab_focus.call_deferred()

func _unhandled_input(event):
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()

func close():
	closed.emit()
	queue_free()

func jump_to(index):
	notes_scroll.scroll_vertical = int(release_blocks[index].position.y)
	_highlight(index)

# The release whose block is at the top of the view
func _highlight_visible_release():
	var top = notes_scroll.scroll_vertical + 40
	var index = 0
	for i in release_blocks.size():
		if release_blocks[i].position.y <= top:
			index = i
	_highlight(index)

func _highlight(index):
	for i in version_buttons.size():
		version_buttons[i].modulate = HIGHLIGHT if i == index else Color.WHITE

#region Layout

func _build_layout():
	var ui_theme = Theme.new()
	ui_theme.default_font = ODIN_FONT
	ui_theme.default_font_size = 26
	ui_theme.set_stylebox("normal", "Button", _box_style(Color(0.2, 0.2, 0.2)))
	ui_theme.set_stylebox("hover", "Button", _box_style(Color(0.28, 0.28, 0.28)))
	ui_theme.set_stylebox("pressed", "Button", _box_style(Color(0.32, 0.32, 0.32)))
	ui_theme.set_stylebox("focus", "Button", _box_style(Color(0, 0, 0, 0), HIGHLIGHT))
	ui_theme.set_color("font_hover_color", "Button", HIGHLIGHT)
	theme = ui_theme

	var dim = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.75)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 180)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 70)
	add_child(margin)

	var panel = PanelContainer.new()
	var panel_style = _box_style(Color(0.1, 0.1, 0.1))
	panel_style.set_content_margin_all(30)
	panel.add_theme_stylebox_override("panel", panel_style)
	margin.add_child(panel)

	var layout = VBoxContainer.new()
	layout.add_theme_constant_override("separation", 20)
	panel.add_child(layout)

	var header = HBoxContainer.new()
	layout.add_child(header)
	var title = _label("PATCH NOTES", 56, Color.WHITE)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	close_button = _button("Close", close)
	close_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(close_button)

	var columns = HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 30)
	layout.add_child(columns)

	# Left bar: one button per version
	var sidebar_scroll = ScrollContainer.new()
	sidebar_scroll.custom_minimum_size.x = 330
	sidebar_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	columns.add_child(sidebar_scroll)
	var sidebar = VBoxContainer.new()
	sidebar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sidebar.add_theme_constant_override("separation", 10)
	sidebar_scroll.add_child(sidebar)

	notes_scroll = ScrollContainer.new()
	notes_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	notes_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	columns.add_child(notes_scroll)
	notes_list = VBoxContainer.new()
	notes_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	notes_list.add_theme_constant_override("separation", 50)
	notes_scroll.add_child(notes_list)

	for i in PatchNotes.RELEASES.size():
		var release = PatchNotes.RELEASES[i]
		var button = _button("v%s\n%s" % [release.version, PatchNotes.format_date(release.date)], jump_to.bind(i))
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		sidebar.add_child(button)
		version_buttons.append(button)
		var block = _release_block(release, i == 0)
		notes_list.add_child(block)
		release_blocks.append(block)
	# Room to scroll the oldest release up to the top too
	var spacer = Control.new()
	spacer.custom_minimum_size.y = 500
	notes_list.add_child(spacer)

func _release_block(release, latest):
	var block = VBoxContainer.new()
	block.add_theme_constant_override("separation", 10)
	var heading = "v%s  -  %s" % [release.version, release.name]
	block.add_child(_label(heading, 44, HIGHLIGHT if latest else Color.WHITE))
	var subtitle = PatchNotes.format_date(release.date)
	if latest:
		subtitle += "   -   current version"
	block.add_child(_label(subtitle, 22, DIM_COLOR))
	if release.has("note"):
		block.add_child(_label(release.note, 22, DIM_COLOR))
	for section in release.sections:
		var section_title = _label(section[0], 30, Color.WHITE)
		block.add_child(section_title)
		var items = RichTextLabel.new()
		items.bbcode_enabled = true
		items.fit_content = true
		items.scroll_active = false
		items.selection_enabled = false
		items.mouse_filter = Control.MOUSE_FILTER_IGNORE
		items.add_theme_font_override("normal_font", ODIN_FONT)
		items.add_theme_font_size_override("normal_font_size", 24)
		items.add_theme_color_override("default_color", TEXT_COLOR)
		items.add_theme_constant_override("line_separation", 6)
		var text = "[ul]"
		for item in section[1]:
			text += item.replace("[", "[lb]") + "\n"
		items.text = text.trim_suffix("\n") + "[/ul]"
		block.add_child(items)
	return block

func _box_style(color, border = Color.TRANSPARENT):
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(14)
	style.set_content_margin_all(12)
	if border.a > 0:
		style.border_color = border
		style.set_border_width_all(4)
	return style

func _button(text, callback):
	var button = Button.new()
	button.text = text
	button.pressed.connect(callback)
	return button

func _label(text, font_size, color):
	var label = Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

#endregion
