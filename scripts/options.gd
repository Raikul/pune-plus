extends Control

# Options screen (main menu and pause menu). Built in code with the same look as the
# patch notes window. Every value lives in Global and is saved to user://settings.cfg.
# Rows are browsed with up/down; left/right (or clicking) changes the value. Texts are
# translation keys (translations/strings.csv); changing the language rebuilds the screen.

signal back

const ODIN_FONT = preload("res://assets/jorge-resources/Game Selection/Odin Rounded - Bold.otf")
const HIGHLIGHT = Color(0.91, 0.61, 0.17)
const TEXT_COLOR = Color(0.86, 0.86, 0.86)
const DIM_COLOR = Color(0.6, 0.6, 0.6)
const PANEL_COLOR = Color(0.13, 0.13, 0.13, 0.97)
const ROW_WIDTH = 1000

const WINDOW_MODES = ["OPT_FULLSCREEN", "OPT_WINDOWED", "OPT_BORDERLESS_WINDOW", "OPT_BORDERLESS_FULLSCREEN"]
const GAP_SIZES = ["OPT_GAP_SMALL", "OPT_GAP_MEDIUM", "OPT_GAP_LARGE"]
const TABS = ["OPT_TAB_VIDEO", "OPT_TAB_AUDIO", "OPT_TAB_GAMEPLAY", "OPT_TAB_CONTROLS", "OPT_TAB_ACCESSIBILITY"]

var tab_buttons = []
var pages = []
var current_tab = 0
var resolution_row
var volume_sliders = {} # bus -> HSlider, so other menus' changes can be shown (refresh_volumes)

func _ready():
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	_show_tab(0)
	visibility_changed.connect(func():
		if visible:
			focus_first())

func focus_first():
	tab_buttons[current_tab].grab_focus.call_deferred()

func _unhandled_input(event):
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close()

func _close():
	Global.save_settings()
	back.emit()

#region Layout

var built_locale = ""

func _notification(what):
	if what == NOTIFICATION_TRANSLATION_CHANGED and not pages.is_empty():
		_rebuild.call_deferred()

# A new language: every text again, on the same tab, with the language row in focus
func _rebuild():
	if TranslationServer.get_locale() == built_locale:
		return
	var had_focus = get_viewport().gui_get_focus_owner() != null and is_ancestor_of(get_viewport().gui_get_focus_owner())
	for child in get_children():
		remove_child(child)
		child.queue_free()
	tab_buttons.clear()
	pages.clear()
	volume_sliders.clear()
	resolution_row = null
	_build()
	_show_tab(current_tab)
	var rows = pages[current_tab].get_children().filter(func(row): return row.has_meta("control"))
	if had_focus and not rows.is_empty():
		rows[0].get_meta("control").grab_focus.call_deferred()

func _build():
	built_locale = TranslationServer.get_locale()
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
	column.add_theme_constant_override("separation", 24)
	panel.add_child(column)

	var title = Label.new()
	title.text = tr("OPT_TITLE")
	title.add_theme_font_size_override("font_size", 56)
	column.add_child(title)

	var tabs = HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 12)
	column.add_child(tabs)
	for i in TABS.size():
		var button = Button.new()
		button.text = tr(TABS[i])
		button.custom_minimum_size = Vector2(180, 54)
		button.focus_entered.connect(_show_tab.bind(i))
		button.pressed.connect(_show_tab.bind(i))
		tabs.add_child(button)
		tab_buttons.append(button)

	var line = ColorRect.new()
	line.color = Color(1, 1, 1, 0.1)
	line.custom_minimum_size = Vector2(ROW_WIDTH, 2)
	column.add_child(line)

	var page_holder = Control.new()
	page_holder.custom_minimum_size = Vector2(ROW_WIDTH, 440)
	column.add_child(page_holder)
	for builder in [_video_page, _audio_page, _gameplay_page, _controls_page, _accessibility_page]:
		var page = VBoxContainer.new()
		page.add_theme_constant_override("separation", 10)
		page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		page_holder.add_child(page)
		builder.call(page)
		pages.append(page)

	var back_button = Button.new()
	back_button.text = tr("UI_BACK")
	back_button.custom_minimum_size = Vector2(220, 60)
	back_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	back_button.pressed.connect(_close)
	column.add_child(back_button)

func _show_tab(index):
	current_tab = index
	for i in pages.size():
		pages[i].visible = i == index
		tab_buttons[i].add_theme_color_override("font_color", HIGHLIGHT if i == index else TEXT_COLOR)
	_link_focus()

# Up from the first row goes to the tabs, down from the last row to Back
func _link_focus():
	var rows = pages[current_tab].get_children().filter(func(row): return row.has_meta("control"))
	for button in tab_buttons:
		button.focus_neighbor_bottom = button.get_path_to(rows[0].get_meta("control")) if not rows.is_empty() else NodePath()

func _video_page(page):
	_selector(page, tr("OPT_WINDOW_MODE"), WINDOW_MODES.map(tr), func(): return Global.window_mode, func(i):
		Global.window_mode = i
		Global.apply_window_mode()
		_update_resolution_row())
	var sizes = Global.RESOLUTIONS.map(func(size): return "%d x %d" % [size.x, size.y])
	resolution_row = _selector(page, tr("OPT_WINDOW_SIZE"), sizes, func(): return Global.resolution, func(i):
		Global.resolution = i
		Global.apply_window_size())
	_update_resolution_row()
	_toggle(page, tr("OPT_VSYNC"), func(): return Global.vsync, func(on):
		Global.vsync = on
		Global.apply_video_settings())
	var fps_names = Global.MAX_FPS_OPTIONS.map(func(fps): return tr("OPT_NO_LIMIT") if fps == 0 else str(fps))
	_selector(page, tr("OPT_MAX_FPS"), fps_names, func(): return max(Global.MAX_FPS_OPTIONS.find(Global.max_fps), 0), func(i):
		Global.max_fps = Global.MAX_FPS_OPTIONS[i]
		Global.apply_video_settings())
	_toggle(page, tr("OPT_SHOW_FPS"), func(): return Global.show_fps, func(on):
		Global.show_fps = on
		Global.apply_video_settings())

func _update_resolution_row():
	if resolution_row:
		resolution_row.modulate.a = 1.0 if Global.is_windowed() else 0.4
		resolution_row.get_meta("control").tooltip_text = "" if Global.is_windowed() else tr("OPT_ONLY_WINDOWED")

func _audio_page(page):
	for bus in ["Master", "Music", "Effects"]:
		_slider(page, tr("OPT_VOLUME_" + bus.to_upper()), bus)

func _gameplay_page(page):
	# Each language by its own name
	var languages = Global.LANGUAGES.map(func(entry): return entry[1])
	_selector(page, tr("OPT_LANGUAGE"), languages,
		func(): return max(Global.LANGUAGES.map(func(entry): return entry[0]).find(Global.language), 0),
		func(i):
			Global.language = Global.LANGUAGES[i][0]
			# Every screen follows (NOTIFICATION_TRANSLATION_CHANGED); this one is rebuilt
			Global.apply_language())
	_selector(page, tr("OPT_GAP_SIZE"), GAP_SIZES.map(tr), func(): return Global.gapSize, func(i): Global.gapSize = i)
	var times = Global.UPGRADE_TIME_OPTIONS.map(Global.upgrade_time_text)
	_selector(page, tr("OPT_UPGRADE_TIME"), times,
		func(): return max(Global.UPGRADE_TIME_OPTIONS.find(Global.upgrade_time), 0),
		func(i): Global.upgrade_time = Global.UPGRADE_TIME_OPTIONS[i])
	_toggle(page, tr("OPT_WISDOM"), func(): return Global.show_quotes, func(on): Global.show_quotes = on)

func _accessibility_page(page):
	_toggle(page, tr("OPT_NAMEPLATES"), func(): return Global.nameplates, func(on): Global.nameplates = on)
	_toggle(page, tr("OPT_DIRECTION_ARROW"), func(): return Global.direction_arrow, func(on): Global.direction_arrow = on)
	_toggle(page, tr("OPT_SNAKE_EYES"), func(): return Global.snake_eyes, func(on): Global.snake_eyes = on)
	_toggle(page, tr("OPT_COLORBLIND"), func(): return Global.colorblind, func(on):
		Global.colorblind = on
		# A match keeps its colors; the next one starts with the new ones (Playground)
		if not Global.in_match():
			Global.apply_colors())
	var note = Label.new()
	note.text = tr("OPT_NEXT_ROUND_NOTE")
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size.x = ROW_WIDTH
	note.add_theme_color_override("font_color", DIM_COLOR)
	note.add_theme_font_size_override("font_size", 24)
	page.add_child(note)

func _controls_page(page):
	var note = Label.new()
	note.text = tr("OPT_KEYS_NOTE")
	note.add_theme_color_override("font_color", DIM_COLOR)
	note.add_theme_font_size_override("font_size", 24)
	page.add_child(note)
	var reset = Button.new()
	reset.text = tr("OPT_RESET_KEYS")
	reset.custom_minimum_size = Vector2(0, 60)
	reset.pressed.connect(func():
		InputMap.load_from_project_settings()
		reset.text = tr("OPT_KEYS_RESET_DONE"))
	_row(page, tr("OPT_KEYS"), reset)
	reset.size_flags_horizontal = Control.SIZE_EXPAND_FILL

#endregion

#region Rows

func _row(page, label_text, control):
	var row = HBoxContainer.new()
	row.custom_minimum_size = Vector2(ROW_WIDTH, 66)
	var label = Label.new()
	label.text = label_text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)
	control.custom_minimum_size.x = 440
	control.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(control)
	row.set_meta("control", control)
	page.add_child(row)
	return row

# "‹  value  ›": left/right or clicking cycles through the values
func _selector(page, label_text, values, getter: Callable, setter: Callable):
	var button = Button.new()
	button.custom_minimum_size.y = 56
	var refresh = func(): button.text = "‹   %s   ›" % values[getter.call()]
	var change = func(step):
		setter.call(posmod(getter.call() + step, values.size()))
		Global.save_settings()
		refresh.call()
	button.pressed.connect(change.bind(1))
	button.gui_input.connect(func(event):
		if event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right"):
			change.call(-1 if event.is_action_pressed("ui_left") else 1)
			button.accept_event())
	refresh.call()
	return _row(page, label_text, button)

func _toggle(page, label_text, getter: Callable, setter: Callable):
	return _selector(page, label_text, [tr("VALUE_OFF"), tr("VALUE_ON")], func(): return 1 if getter.call() else 0,
		func(i): setter.call(i == 1))

# The pause menu has its own volume sliders: show their values here too
func refresh_volumes():
	for bus in volume_sliders:
		volume_sliders[bus].value = Global.volumes[bus]

func _slider(page, label_text, bus):
	var box = HBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	var slider = HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = Global.volumes[bus]
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var percent = Label.new()
	percent.custom_minimum_size.x = 80
	percent.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	percent.text = "%d%%" % round(slider.value * 100)
	slider.value_changed.connect(func(value):
		Global.volumes[bus] = value
		Global.apply_volumes()
		percent.text = "%d%%" % round(value * 100))
	slider.drag_ended.connect(func(_changed): Global.save_settings())
	volume_sliders[bus] = slider
	box.add_child(slider)
	box.add_child(percent)
	var row = _row(page, label_text, box)
	# The slider is what gets focus (left/right move it)
	row.set_meta("control", slider)
	slider.focus_exited.connect(Global.save_settings)
	return row

#endregion

#region Theme

func _make_theme():
	var ui_theme = Theme.new()
	ui_theme.default_font = ODIN_FONT
	ui_theme.default_font_size = 30
	ui_theme.set_color("font_color", "Label", TEXT_COLOR)
	ui_theme.set_stylebox("normal", "Button", _box(Color(0.2, 0.2, 0.2)))
	ui_theme.set_stylebox("hover", "Button", _box(Color(0.27, 0.27, 0.27)))
	ui_theme.set_stylebox("pressed", "Button", _box(Color(0.31, 0.31, 0.31)))
	ui_theme.set_stylebox("focus", "Button", _box(Color(0, 0, 0, 0), HIGHLIGHT))
	ui_theme.set_color("font_color", "Button", TEXT_COLOR)
	ui_theme.set_color("font_hover_color", "Button", HIGHLIGHT)
	ui_theme.set_color("font_focus_color", "Button", HIGHLIGHT)
	ui_theme.set_color("font_pressed_color", "Button", HIGHLIGHT)
	ui_theme.set_font_size("font_size", "Button", 28)
	# Slider: thin rounded track, orange fill, round grabber
	var track = _box(Color(0.25, 0.25, 0.25))
	track.content_margin_top = 4
	track.content_margin_bottom = 4
	var fill = _box(HIGHLIGHT)
	fill.content_margin_top = 4
	fill.content_margin_bottom = 4
	ui_theme.set_stylebox("slider", "HSlider", track)
	ui_theme.set_stylebox("grabber_area", "HSlider", fill)
	ui_theme.set_stylebox("grabber_area_highlight", "HSlider", fill)
	ui_theme.set_icon("grabber", "HSlider", _dot(Color.WHITE))
	ui_theme.set_icon("grabber_highlight", "HSlider", _dot(HIGHLIGHT.lightened(0.4)))
	var focus = _box(Color(0, 0, 0, 0), HIGHLIGHT)
	focus.expand_margin_top = 14
	focus.expand_margin_bottom = 14
	focus.expand_margin_left = 8
	focus.expand_margin_right = 8
	ui_theme.set_stylebox("focus", "HSlider", focus)
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

func _dot(color):
	var image = Image.create(24, 24, false, Image.FORMAT_RGBA8)
	for y in 24:
		for x in 24:
			var d = Vector2(x + 0.5, y + 0.5).distance_to(Vector2(12, 12))
			image.set_pixel(x, y, Color(color, clamp(11.0 - d, 0.0, 1.0)))
	return ImageTexture.create_from_image(image)

#endregion
