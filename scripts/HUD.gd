extends CanvasLayer


var label1: Label
var label2: Label
var label3: Label
var label4: Label
var player1cooldown: TextureProgressBar
var player2cooldown: TextureProgressBar
var player3cooldown: TextureProgressBar
var player4cooldown: TextureProgressBar

# Diccionario para saber quién murio
var dead_players = {1: false, 2: false, 3: false, 4: false}
# Red cross drawn over a dead snake's symbol, per player
var dead_marks = {}
const DEAD_SYMBOL_ALPHA = 0.3
const DEAD_CROSS_COLOR = Color(0.9, 0.1, 0.1)
# Team letter before the symbol (2v2) and the snake's upgrades after the score
var team_tags = {}
var upgrade_badges = {}
const ODIN_FONT = preload("res://assets/jorge-resources/Game Selection/Odin Rounded - Bold.otf")

func _ready():
	label1 = $PanelContainer/MarginContainer/HBoxContainer/PanelContainer/HBoxContainer/Player1ScoreLabel
	label2 = $PanelContainer/MarginContainer/HBoxContainer/PanelContainer2/HBoxContainer/Player2ScoreLabel
	label3 = $PanelContainer/MarginContainer/HBoxContainer/PanelContainer3/HBoxContainer/Player3ScoreLabel
	label4 = $PanelContainer/MarginContainer/HBoxContainer/PanelContainer4/HBoxContainer/Player4ScoreLabel
	player1cooldown  = $PanelContainer/MarginContainer/HBoxContainer/PanelContainer/HBoxContainer/Player1Cooldown
	player2cooldown = $PanelContainer/MarginContainer/HBoxContainer/PanelContainer2/HBoxContainer/Player2Cooldown
	player3cooldown = $PanelContainer/MarginContainer/HBoxContainer/PanelContainer3/HBoxContainer/Player3Cooldown
	player4cooldown = $PanelContainer/MarginContainer/HBoxContainer/PanelContainer4/HBoxContainer/Player4Cooldown
	

	_restyle()

	for id in [1, 2, 3, 4]:
		dead_marks[id] = _make_dead_mark(_cooldown_bar(id))
		var row = _cooldown_bar(id).get_parent()
		var tag = Label.new()
		tag.add_theme_font_override("font", ODIN_FONT)
		tag.add_theme_font_size_override("font_size", 34)
		tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		tag.hide()
		row.add_child(tag)
		row.move_child(tag, 0)
		team_tags[id] = tag
		var badges = UpgradeBadges.new()
		badges.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(badges)
		upgrade_badges[id] = badges

	add_to_group("HUD")

# Dark bar with one rounded card per snake, the score in its element's color
const BAR_COLOR = Color(0.07, 0.07, 0.08, 0.94)
const CARD_COLOR = Color(0.13, 0.13, 0.15)
var target_label: Label

func _restyle():
	$PanelContainer/ColorRect.color = BAR_COLOR
	var accent = ColorRect.new()
	accent.color = Color(1, 1, 1, 0.07)
	accent.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	accent.offset_top = -2
	accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$PanelContainer/ColorRect.add_child(accent)
	var margin = $PanelContainer/MarginContainer
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 22)
	for id in [1, 2, 3, 4]:
		var label = [null, label1, label2, label3, label4][id]
		var color = Color(Global.playerColors[id])
		label.self_modulate = Color.WHITE
		label.add_theme_font_override("font", ODIN_FONT)
		label.add_theme_font_size_override("font_size", 56)
		label.add_theme_color_override("font_color", color.lightened(0.15))
		label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
		label.add_theme_constant_override("outline_size", 6)
		label.custom_minimum_size.x = 64
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		var row = label.get_parent()
		row.add_theme_constant_override("separation", 16)
		var card = row.get_parent()
		card.self_modulate = Color.WHITE
		var style = StyleBoxFlat.new()
		style.bg_color = CARD_COLOR
		style.set_corner_radius_all(16)
		style.content_margin_left = 18
		style.content_margin_right = 22
		style.content_margin_top = 8
		style.content_margin_bottom = 8
		style.border_color = color
		style.border_width_bottom = 4
		card.add_theme_stylebox_override("panel", style)
		_cooldown_bar(id).custom_minimum_size = Vector2(64, 64)
	# "FIRST TO 10" under the middle of the bar
	target_label = Label.new()
	target_label.add_theme_font_override("font", ODIN_FONT)
	target_label.add_theme_font_size_override("font_size", 18)
	target_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	target_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	target_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	target_label.offset_left = -150
	target_label.offset_right = 150
	target_label.offset_top = -24
	target_label.offset_bottom = -2
	target_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$PanelContainer/ColorRect.add_child(target_label)

func set_target(points):
	target_label.text = "FIRST TO %d" % points

# total: the cooldown's full length (upgrades can shorten it), so the bar starts full
func set_cooldown(player_id, time_left, total = 0.0):
	var cooldown
	match player_id:
		1:
			cooldown = player1cooldown
		2:
			cooldown = player2cooldown
		3:
			cooldown = player3cooldown
		4:
			cooldown = player4cooldown
	if total > 0:
		cooldown.max_value = total
	cooldown.value = time_left

# 2v2: shows which team each snake is on ("A" / "B")
func setup_teams(enabled):
	for id in team_tags:
		var team = Global.team_of(id)
		team_tags[id].visible = enabled
		team_tags[id].text = Global.TEAM_NAMES[team].right(1)
		team_tags[id].add_theme_color_override("font_color", Global.TEAM_COLORS[team])

# can_see(player_id) -> bool: false shows only how many upgrades a rival has
func refresh_upgrades(can_see: Callable):
	for id in upgrade_badges:
		if Global.get("player%dActive" % id):
			upgrade_badges[id].refresh(id, not can_see.call(id))
		else:
			upgrade_badges[id].refresh(id, true)

func set_player_dead(player_id: int):
	dead_players[player_id] = true

func reset_labels():
	label1.self_modulate = Color.WHITE
	label2.self_modulate = Color.WHITE
	label3.self_modulate = Color.WHITE
	label4.self_modulate = Color.WHITE
	# Reiniciar el estado de muerte para la siguiente ronda
	for id in dead_players:
		dead_players[id] = false

func _cooldown_bar(player_id):
	return [null, player1cooldown, player2cooldown, player3cooldown, player4cooldown][player_id]

func _make_dead_mark(bar):
	var mark = Control.new()
	mark.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mark.top_level = false
	mark.hide()
	mark.draw.connect(func():
		var inset = mark.size * 0.12
		var a = inset
		var b = mark.size - inset
		for line in [[a, b], [Vector2(b.x, a.y), Vector2(a.x, b.y)]]:
			mark.draw_line(line[0], line[1], Color.BLACK, 14.0, true)
			mark.draw_line(line[0], line[1], DEAD_CROSS_COLOR, 8.0, true))
	bar.add_child(mark)
	return mark

# A dead snake's symbol is dimmed and crossed out until the next round
func _show_dead(player_id, dead):
	var bar = _cooldown_bar(player_id)
	bar.self_modulate.a = DEAD_SYMBOL_ALPHA if dead else 1.0 # self_modulate: the cross stays bright
	dead_marks[player_id].visible = dead

func _process(_delta):
	refresh()

# Scores and dead marks. Also called once when time stops (round or match over), since
# _process is off from then on and the last point would never be shown
func refresh():
	for id in [1, 2, 3, 4]:
		if Global.get("player%dActive" % id):
			[null, label1, label2, label3, label4][id].text = str(Global.get("player%dScore" % id))
			_show_dead(id, dead_players[id])
