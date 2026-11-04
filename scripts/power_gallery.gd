extends Control
class_name PowerGallery

# Every power in the game on one screen, opened from Instructions: a column per snake
# (plus upgrades any snake can take) and a row per rarity, with each element's base power
# on top. Empty cells show an open slot, and the totals row counts each column (upgrades
# and picks: an upgrade that stacks x3 is three picks), so it's easy to see where an
# element is short of powers.

const ODIN = preload("res://assets/jorge-resources/Game Selection/Odin Rounded - Bold.otf")
const SYMBOLS_PATH = "res://assets/jorge-resources/Game Selection/"
const SYMBOLS = {"fire": "Fire-Water symbol.png", "earth": "Air-Earth symbol rot.png", "air": "Air-Earth symbol.png", "water": "Fire-Water symbol rot.png"}
const COLUMNS = ["generic", "fire", "earth", "air", "water"]
const BASE_POWERS = {
	"fire": "Shoots a fireball that burns through the trails it hits.",
	"earth": "Rock armor: passes through trails for a moment, leaving a path of stone behind.",
	"air": "Jumps to the marker ahead of it.",
	"water": "Splits off a mirrored twin. If the head dies while the twin lives, you take over the twin.",
}
const LABEL_WIDTH = 150
const CELL_WIDTH = 330
const BG = Color(0.07, 0.07, 0.09)

signal closed

func _ready():
	# The whole window, whatever its parent's size
	top_level = true
	position = Vector2.ZERO
	size = get_viewport_rect().size
	mouse_filter = Control.MOUSE_FILTER_STOP
	var background = ColorRect.new()
	background.color = BG
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)
	var page = VBoxContainer.new()
	page.add_theme_constant_override("separation", 12)
	margin.add_child(page)

	var header = HBoxContainer.new()
	page.add_child(header)
	var title = _label("POWER GALLERY", 44, Color.WHITE)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close = Button.new()
	close.text = "CLOSE"
	close.custom_minimum_size = Vector2(160, 48)
	close.add_theme_font_override("font", ODIN)
	close.add_theme_font_size_override("font_size", 22)
	close.pressed.connect(_close)
	header.add_child(close)

	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page.add_child(scroll)
	var grid = GridContainer.new()
	grid.columns = COLUMNS.size() + 1
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	scroll.add_child(grid)
	_fill(grid)
	close.grab_focus.call_deferred()

func _fill(grid):
	# Column heads
	grid.add_child(Control.new())
	for column in COLUMNS:
		grid.add_child(_column_head(column))

	# Each element's base power
	grid.add_child(_row_head("BASE", Color(0.9, 0.9, 0.9), "Always on"))
	for column in COLUMNS:
		if column == "generic":
			grid.add_child(_slot("Every snake: turn with Left/Right, power on Up"))
		else:
			var id = UpgradeCatalog.PLAYER_ELEMENTS.find_key(column)
			grid.add_child(_card(Global.POWER_TAGLINES[id], BASE_POWERS[column], _element_color(column), Color(0.9, 0.9, 0.9), []))

	# Upgrades by rarity
	var counts = {}
	for column in COLUMNS:
		counts[column] = {}
	var total_weight = 0.0
	for rarity in UpgradeCatalog.RARITIES.values():
		total_weight += rarity.weight
	for rarity_id in UpgradeCatalog.RARITIES:
		var rarity = UpgradeCatalog.RARITIES[rarity_id]
		grid.add_child(_row_head(rarity.name.to_upper(), rarity.color, "%d%% of rolls" % roundi(100.0 * rarity.weight / total_weight)))
		for column in COLUMNS:
			var cell = VBoxContainer.new()
			cell.custom_minimum_size = Vector2(CELL_WIDTH, 0)
			cell.add_theme_constant_override("separation", 8)
			for upgrade in UpgradeCatalog.UPGRADES:
				if upgrade.element != column or upgrade.get("rarity", "common") != rarity_id:
					continue
				counts[column][rarity_id] = counts[column].get(rarity_id, 0) + upgrade.get("max_stacks", 1)
				counts[column]["upgrades"] = counts[column].get("upgrades", 0) + 1
				cell.add_child(_upgrade_card(upgrade, rarity.color))
			if cell.get_child_count() == 0:
				cell.add_child(_slot("Open slot"))
			grid.add_child(cell)

	# How many each column has
	grid.add_child(_row_head("TOTAL", Color.WHITE, "Upgrades"))
	for column in COLUMNS:
		grid.add_child(_totals(counts[column]))

func _column_head(column) -> Control:
	var box = HBoxContainer.new()
	box.custom_minimum_size = Vector2(CELL_WIDTH, 56)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 10)
	if SYMBOLS.has(column):
		var symbol = TextureRect.new()
		symbol.texture = load(SYMBOLS_PATH + SYMBOLS[column])
		symbol.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		symbol.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		symbol.custom_minimum_size = Vector2(44, 44)
		symbol.modulate = _element_color(column)
		box.add_child(symbol)
	var name_label = _label("ANY SNAKE" if column == "generic" else column.to_upper(), 30, _element_color(column))
	name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	box.add_child(name_label)
	return box

func _row_head(text, color, note) -> Control:
	var box = VBoxContainer.new()
	box.custom_minimum_size = Vector2(LABEL_WIDTH, 0)
	box.add_theme_constant_override("separation", 0)
	box.add_child(_label(text, 24, color))
	box.add_child(_label(note, 15, Color(0.6, 0.6, 0.6)))
	return box

func _upgrade_card(upgrade, rarity_color) -> Control:
	var notes = []
	if upgrade.get("max_stacks", 1) > 1:
		notes.append("Stacks x%d" % upgrade.max_stacks)
	if upgrade.has("requires"):
		notes.append("Needs " + UpgradeCatalog.get_upgrade(upgrade.requires).get("name", str(upgrade.requires)))
	if not upgrade.get("enabled", true):
		notes.append("OFF (not in the rolls)")
	var card = _card(upgrade.name, upgrade.description, _element_color(upgrade.element), rarity_color, notes, upgrade.icon)
	if not upgrade.get("enabled", true):
		card.modulate.a = 0.45
	return card

func _card(title, description, color, border, notes, icon_kind = "") -> Control:
	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(CELL_WIDTH, 0)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.17, 0.17, 0.19)
	style.border_color = border.darkened(0.2)
	style.set_border_width_all(3)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(10)
	card.add_theme_stylebox_override("panel", style)
	var content = HBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	card.add_child(content)
	if icon_kind != "":
		var icon = UpgradeIcon.new()
		icon.kind = icon_kind
		icon.color = color
		icon.custom_minimum_size = Vector2(96, 96)
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		content.add_child(icon)
	var text_box = VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.add_theme_constant_override("separation", 2)
	content.add_child(text_box)
	text_box.add_child(_label(title, 20, Color.WHITE))
	text_box.add_child(_label(description, 14, Color(0.78, 0.78, 0.78)))
	for note in notes:
		text_box.add_child(_label(note, 13, border.lightened(0.2)))
	return card

func _slot(text) -> Control:
	var slot = PanelContainer.new()
	slot.custom_minimum_size = Vector2(CELL_WIDTH, 60)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0.03)
	style.border_color = Color(1, 1, 1, 0.12)
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(10)
	slot.add_theme_stylebox_override("panel", style)
	var label = _label(text, 15, Color(1, 1, 1, 0.3))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	slot.add_child(label)
	return slot

# Upgrades and picks (stacks included) in a column, and a block per pick in its rarity's color
func _totals(counts) -> Control:
	var box = VBoxContainer.new()
	box.custom_minimum_size = Vector2(CELL_WIDTH, 0)
	var upgrades = counts.get("upgrades", 0)
	var picks = 0
	for rarity_id in UpgradeCatalog.RARITIES:
		picks += counts.get(rarity_id, 0)
	box.add_child(_label("%d upgrade%s, %d pick%s" % [upgrades, "" if upgrades == 1 else "s", picks, "" if picks == 1 else "s"], 22, Color.WHITE))
	var bar = HBoxContainer.new()
	bar.add_theme_constant_override("separation", 3)
	box.add_child(bar)
	for rarity_id in UpgradeCatalog.RARITIES:
		for i in counts.get(rarity_id, 0):
			var block = ColorRect.new()
			block.color = UpgradeCatalog.RARITIES[rarity_id].color
			block.custom_minimum_size = Vector2(18, 14)
			bar.add_child(block)
	return box

func _element_color(element) -> Color:
	var id = UpgradeCatalog.PLAYER_ELEMENTS.find_key(element)
	if id == null:
		return Color(0.75, 0.75, 0.75)
	return Color(Global.playerColors[id])

func _label(text, font_size, color) -> Label:
	var label = Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_override("font", ODIN)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

func _unhandled_input(event):
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close()

func _close():
	closed.emit()
	queue_free()
