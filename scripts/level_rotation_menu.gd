extends Control
class_name LevelRotationMenu

# Match settings > Arena rotation: every arena as a card (a small map of its walls and its
# name) that's in the rotation or not; click (or Enter) to switch it. Every round of the
# match plays a random arena of the rotation (Global.pick_level). At least one stays in:
# unchecking the last one isn't possible. Used by player setup and the online lobby; it
# covers the whole window (top_level, so a scaled parent doesn't shrink it).

signal changed(rotation)
signal closed

const ODIN = preload("res://assets/jorge-resources/Game Selection/Odin Rounded - Bold.otf")
const ACCENT = Color(0.91, 0.61, 0.17)
const WALL_FILL = Color(0.62, 0.36, 1.0, 0.85)
const COLUMNS = 4
const CARD_SIZE = Vector2(300, 220)

var picked = [] # The rotation being edited
var cards = {} # path -> Button
var count_label: Label

static func open(parent: Node, current: Array) -> LevelRotationMenu:
	var menu = LevelRotationMenu.new()
	menu.picked = current.duplicate()
	parent.add_child(menu)
	return menu

func _ready():
	top_level = true
	position = Vector2.ZERO
	size = get_viewport_rect().size
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.75)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.13)
	style.set_corner_radius_all(22)
	style.set_content_margin_all(32)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	var page = VBoxContainer.new()
	page.add_theme_constant_override("separation", 18)
	panel.add_child(page)

	page.add_child(_label("ARENA ROTATION", 44, Color.WHITE))
	page.add_child(_label("Every round plays a random arena from the ones checked.", 24, Color(0.7, 0.7, 0.7)))

	var scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(COLUMNS * (CARD_SIZE.x + 14), min(3, ceili((Global.level_paths().size() + 1) / float(COLUMNS))) * (CARD_SIZE.y + 14))
	page.add_child(scroll)
	var grid = GridContainer.new()
	grid.columns = COLUMNS
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	scroll.add_child(grid)
	var first = null
	for path in [""] + Global.level_paths():
		var card = _card(path)
		grid.add_child(card)
		cards[path] = card
		if first == null:
			first = card

	var footer = HBoxContainer.new()
	footer.add_theme_constant_override("separation", 14)
	page.add_child(footer)
	count_label = _label("", 26, ACCENT)
	count_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(count_label)
	footer.add_child(_button("ALL", _select_all))
	footer.add_child(_button("CLASSIC ONLY", func(): _set_rotation([""])))
	var done = _button("DONE", _close)
	footer.add_child(done)
	_refresh()
	first.grab_focus.call_deferred()

func _card(path) -> Button:
	var card = Button.new()
	card.custom_minimum_size = CARD_SIZE
	card.focus_mode = Control.FOCUS_ALL
	card.pressed.connect(_toggle.bind(path))
	var box = VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 12
	box.offset_right = -12
	box.offset_top = 12
	box.offset_bottom = -10
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 8)
	card.add_child(box)
	var preview = LevelPreview.new()
	preview.path = path
	preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(preview)
	var name_row = HBoxContainer.new()
	name_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(name_row)
	var check = _label("", 26, ACCENT)
	check.name = "Check"
	check.custom_minimum_size.x = 34
	name_row.add_child(check)
	var title = _label(Global.level_name(path), 26, Color.WHITE)
	title.name = "Title"
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_child(title)
	return card

func _toggle(path):
	var next = picked.duplicate()
	if next.has(path):
		if next.size() == 1:
			return # One arena always stays in
		next.erase(path)
	else:
		next.append(path)
	_set_rotation(next)

func _select_all():
	_set_rotation([""] + Global.level_paths())

func _set_rotation(next):
	# In the order they're listed
	picked = ([""] + Global.level_paths()).filter(func(path): return next.has(path))
	_refresh()
	changed.emit(picked.duplicate())

func _refresh():
	for path in cards:
		var card = cards[path]
		var on = picked.has(path)
		for state in ["normal", "hover", "pressed", "focus"]:
			var style = StyleBoxFlat.new()
			style.set_corner_radius_all(16)
			style.bg_color = Color(0.2, 0.2, 0.22) if on else Color(0.14, 0.14, 0.15)
			if state == "hover":
				style.bg_color = style.bg_color.lightened(0.08)
			style.border_color = ACCENT if on else Color(1, 1, 1, 0.12)
			style.set_border_width_all(3 if on else 2)
			if state == "focus":
				style.draw_center = false
				style.border_color = Color.WHITE
				style.set_border_width_all(4)
			card.add_theme_stylebox_override(state, style)
		card.modulate = Color.WHITE if on else Color(1, 1, 1, 0.55)
		var check = card.find_child("Check", true, false)
		check.text = "✓" if on else ""
	count_label.text = "In rotation: " + Global.level_rotation_text(picked)

func _button(text, callback) -> Button:
	var button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(150, 56)
	button.add_theme_font_override("font", ODIN)
	button.add_theme_font_size_override("font_size", 24)
	for state in ["normal", "hover", "pressed"]:
		var style = StyleBoxFlat.new()
		style.bg_color = {"normal": Color(0.2, 0.2, 0.2), "hover": Color(0.27, 0.27, 0.27), "pressed": Color(0.32, 0.32, 0.32)}[state]
		style.set_corner_radius_all(14)
		style.content_margin_left = 20
		style.content_margin_right = 20
		button.add_theme_stylebox_override(state, style)
	var focus = StyleBoxFlat.new()
	focus.draw_center = false
	focus.border_color = ACCENT
	focus.set_border_width_all(3)
	focus.set_corner_radius_all(14)
	button.add_theme_stylebox_override("focus", focus)
	button.add_theme_color_override("font_hover_color", ACCENT)
	button.add_theme_color_override("font_focus_color", ACCENT)
	button.pressed.connect(callback)
	return button

func _label(text, font_size, color) -> Label:
	var label = Label.new()
	label.text = text
	label.add_theme_font_override("font", ODIN)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _unhandled_input(event):
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close()

func _close():
	closed.emit()
	queue_free()

# A small map of a level: the play area and its walls (where they start, for moving ones)
class LevelPreview extends Control:
	var path = ""
	var walls = []

	func _ready():
		if path == "" or not ResourceLoader.exists(path):
			return
		var level = load(path).instantiate()
		for wall in level.find_children("*", "LevelWall", true, false):
			# Walls can sit inside other nodes (Windmill's blades)
			var xf = Transform2D.IDENTITY
			var node = wall
			while node != level:
				xf = node.get_transform() * xf
				node = node.get_parent()
			walls.append(xf * wall.polygon)
		level.free()

	func _draw():
		var arena = Level.ARENA
		var fit = min(size.x / arena.size.x, size.y / arena.size.y)
		var area = arena.size * fit
		var origin = (size - area) / 2
		draw_rect(Rect2(origin, area), Color(0.07, 0.07, 0.08))
		draw_rect(Rect2(origin, area), Color(0.62, 0.36, 1.0, 0.7), false, 2.0)
		for polygon in walls:
			var points = PackedVector2Array()
			for point in polygon:
				points.append(origin + (point - arena.position) * fit)
			if points.size() >= 3:
				draw_colored_polygon(points, LevelRotationMenu.WALL_FILL)
