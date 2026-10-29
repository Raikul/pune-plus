extends Control

# Between-rounds upgrade screen. Every active snake picks one of its own upgrades
# at the same time, browsing with its Left/Right keys and confirming with its
# Punchy (Up) key. For now the picks are only reported through the signals below.

signal upgrade_selected(player_id, upgrade_id)
signal all_upgrades_selected(selections)

const ODIN_FONT = preload("res://assets/jorge-resources/Game Selection/Odin Rounded - Bold.otf")

@export var options_per_player = 3
## Seconds the screen stays up after the last pick before all_upgrades_selected is emitted.
@export var finish_delay = 1.2

var selections = {}
var rows = []
var player_ids = []
var waiting_for_reroll = false
var rows_box
var footer_label
var signal_label

func _ready():
	_build_layout()
	# Running this scene on its own (F6) starts a test round right away
	if get_tree().current_scene == self:
		start()

# player_ids defaults to the snakes marked active in Global (all four when none are)
func start(ids = []):
	if not is_node_ready():
		await ready
	for row in rows:
		row.queue_free()
	rows.clear()
	selections.clear()
	waiting_for_reroll = false
	player_ids = ids if not ids.is_empty() else _active_player_ids()

	for i in player_ids.size():
		var id = player_ids[i]
		var row = UpgradeRow.new()
		rows_box.add_child(row)
		row.setup(id, UpgradeCatalog.roll_options(id, options_per_player), Global.AI_Enabled.get(id, false))
		row.chosen.connect(_on_row_chosen)
		rows.append(row)
		row.modulate.a = 0
		create_tween().tween_property(row, "modulate:a", 1.0, 0.3).set_delay(0.08 * i)

	footer_label.text = "Left / Right to browse   |   Punchy to confirm"
	signal_label.text = ""

func _active_player_ids():
	var ids = []
	for id in [1, 2, 3, 4]:
		if Global.get("player" + str(id) + "Active"):
			ids.append(id)
	if ids.is_empty():
		ids = [1, 2, 3, 4]
	return ids

func _on_row_chosen(player_id, upgrade_id):
	selections[player_id] = upgrade_id
	upgrade_selected.emit(player_id, upgrade_id)
	_report("upgrade_selected(%d, %s)" % [player_id, upgrade_id])
	if selections.size() == rows.size():
		_finish()

func _finish():
	footer_label.text = "All snakes are ready!"
	await get_tree().create_timer(finish_delay).timeout
	if not is_inside_tree():
		return
	all_upgrades_selected.emit(selections.duplicate())
	_report("all_upgrades_selected(%s)" % selections)
	if get_tree().current_scene == self:
		waiting_for_reroll = true
		footer_label.text = "Press any Punchy key to roll new upgrades"

func _unhandled_input(event):
	if not waiting_for_reroll:
		return
	for id in player_ids:
		if event.is_action_pressed("Player" + str(id) + "Up"):
			get_viewport().set_input_as_handled()
			start(player_ids)
			return

func _report(text):
	print("[UpgradeSelection] " + text)
	signal_label.text = "Signal: " + text

func _build_layout():
	var ui_theme = Theme.new()
	ui_theme.default_font = ODIN_FONT
	ui_theme.default_font_size = 24
	theme = ui_theme

	var gradient = Gradient.new()
	gradient.set_color(0, Color(0.17, 0.17, 0.17))
	gradient.set_color(1, Color(0.06, 0.06, 0.06))
	var background_texture = GradientTexture2D.new()
	background_texture.gradient = gradient
	background_texture.fill = GradientTexture2D.FILL_RADIAL
	background_texture.fill_from = Vector2(0.5, 0.45)
	background_texture.fill_to = Vector2(1.1, 1.1)
	var background = TextureRect.new()
	background.texture = background_texture
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_SCALE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_right", 40)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	add_child(margin)

	var layout = VBoxContainer.new()
	layout.add_theme_constant_override("separation", 10)
	margin.add_child(layout)

	layout.add_child(_centered_label("CHOOSE YOUR UPGRADE", 60, Color.WHITE))
	layout.add_child(_centered_label("Each snake picks one of its own upgrades", 24, Color(0.6, 0.6, 0.6)))

	rows_box = VBoxContainer.new()
	rows_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rows_box.alignment = BoxContainer.ALIGNMENT_CENTER
	rows_box.add_theme_constant_override("separation", 16)
	layout.add_child(rows_box)

	footer_label = _centered_label("", 30, Color.WHITE)
	layout.add_child(footer_label)
	signal_label = _centered_label("", 18, Color(0.5, 0.5, 0.5))
	layout.add_child(signal_label)

func _centered_label(text, font_size, font_color):
	var label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", font_color)
	return label
