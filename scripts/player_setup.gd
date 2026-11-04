extends Control
var player1Active = false
var player2Active = false
var player3Active = false
var player4Active = false

var P1Box
var P2Box
var P3Box
var P4Box

signal back
signal go
signal multigo
#@onready var multiscene = load("res://scenes/multiplayer_playground.tscn")

func _ready():
	P1Box = $"PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/1"
	P2Box = $"PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/2"
	P3Box = $"PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/3"
	P4Box = $"PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/4"
	P1Box.set_ai_status(Global.AI_Enabled[1])
	P2Box.set_ai_status(Global.AI_Enabled[2])
	P3Box.set_ai_status(Global.AI_Enabled[3])
	P4Box.set_ai_status(Global.AI_Enabled[4])	
	_polish_cards()
	_build_match_options()
	_build_name_boxes()
	# Borders start hidden (nobody selected yet)
	for id in [1, 2, 3, 4]:
		activatePlayer(get("player%dActive" % id), [P1Box, P2Box, P3Box, P4Box][id - 1], Global.playerColors[id])

# Look tweaks on the four player cards (individual_player_setup.tscn)
const SETUP_ACCENT = Color(1, 0.6, 0.15)
func _polish_cards():
	for id in [1, 2, 3, 4]:
		var box = [P1Box, P2Box, P3Box, P4Box][id - 1]
		var element_color = Color(Global.playerColors[id])
		# Element name: centered in its header, which gets a thin line in the element color
		var header = box.get_node("PanelContainer2/PanelContainer/MarginContainer2/PanelContainer")
		var name_label = header.get_node("Label")
		name_label.text = name_label.text.strip_edges()
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
		name_label.add_theme_constant_override("line_spacing", 0)
		header.custom_minimum_size.y = 76
		var header_style = StyleBoxFlat.new()
		header_style.bg_color = Color(0.2, 0.2, 0.2)
		header_style.set_corner_radius_all(15)
		header_style.border_color = element_color
		header_style.border_width_bottom = 4
		header.add_theme_stylebox_override("panel", header_style)
		# PUNCHI key: no black plate behind the key name, like Left and Right
		var punchi_plate = box.get_node("InputList/Up/MarginContainer/PanelContainer")
		punchi_plate.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		punchi_plate.self_modulate = Color.WHITE
		# What the power does, in two words, under the symbol
		var tagline = Label.new()
		tagline.text = Global.POWER_TAGLINES[id]
		tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tagline.add_theme_font_size_override("font_size", 28)
		tagline.add_theme_color_override("font_color", element_color.lightened(0.3))
		box.get_node("PanelContainer2/PanelContainer").add_child(tagline)
		var bottom_space = Control.new()
		bottom_space.custom_minimum_size.y = 10
		box.get_node("PanelContainer2/PanelContainer").add_child(bottom_space)

# Rounded dark pill buttons with an orange outline when focused
func _pill_button(text_size, min_width):
	var button = Button.new()
	button.custom_minimum_size = Vector2(min_width, 72)
	button.add_theme_font_size_override("font_size", text_size)
	var styles = {"normal": Color(0.2, 0.2, 0.2), "hover": Color(0.27, 0.27, 0.27), "pressed": Color(0.32, 0.32, 0.32)}
	for state in styles:
		var style = StyleBoxFlat.new()
		style.bg_color = styles[state]
		style.set_corner_radius_all(16)
		style.content_margin_left = 30
		style.content_margin_right = 30
		button.add_theme_stylebox_override(state, style)
	var focus = StyleBoxFlat.new()
	focus.draw_center = false
	focus.border_color = SETUP_ACCENT
	focus.set_border_width_all(3)
	focus.set_corner_radius_all(16)
	button.add_theme_stylebox_override("focus", focus)
	button.add_theme_color_override("font_color", Color(0.92, 0.92, 0.92))
	button.add_theme_color_override("font_hover_color", SETUP_ACCENT)
	button.add_theme_color_override("font_focus_color", SETUP_ACCENT)
	button.add_theme_color_override("font_pressed_color", SETUP_ACCENT)
	return button
	

func recalculate_all_labels():
	_on_redefine_keys_recalculate_labels(1)
	_on_redefine_keys_recalculate_labels(2)
	_on_redefine_keys_recalculate_labels(3)
	_on_redefine_keys_recalculate_labels(4)
	
	P1Box.get_node("VBoxContainer/Select").grab_focus.call_deferred()
	
func _on_p_1on_pressed():
	player1Active = not player1Active
	activatePlayer(player1Active, P1Box, Global.playerColors[1])
#	activatePlayer(player1Active, P1Box,Color("1ab2ff"))
	
func _on_p_2on_pressed():
	player2Active = not player2Active
	activatePlayer(player2Active, P2Box, Global.playerColors[2])
#	activatePlayer(player2Active, P2Box, Color("aecd53"))

func _on_p_3on_pressed():
	player3Active = not player3Active
	activatePlayer(player3Active, P3Box, Global.playerColors[3])
#	activatePlayer(player3Active, P3Box, Color("e8a547"))

func _on_p_4on_pressed():
	player4Active = not player4Active
	activatePlayer(player4Active, P4Box, Global.playerColors[4])
#	activatePlayer(player4Active, P4Box, Color("13c9ee"))

func activatePlayer(active, playerBox, color):
#	var labelNode = playerBox.get_node("PanelContainer").get_node("Label")
	# Selected: the card takes a light tint of the element color (a full tint made its
	# text hard to read) and a glowing border in that color
	var card = playerBox.get_node("PanelContainer2")
	var style = card.get_theme_stylebox("panel").duplicate()
	if style is StyleBoxFlat:
		# Same width on every card (invisible when not selected), so the columns stay aligned
		style.border_color = Color(Color(color), 1.0 if active else 0.0)
		style.set_border_width_all(4)
		style.shadow_color = Color(Color(color), 0.35 if active else 0.0)
		style.shadow_size = 14 if active else 0
		card.add_theme_stylebox_override("panel", style)
	if active:
		playerBox.modulate = Color.WHITE.lerp(Color(color), 0.45)
#		playerBox.get_node("TextureRect").modulate = color
		playerBox.get_node("VBoxContainer/Select").text = "Deselect"
	else :
		playerBox.modulate = Color.WHITE
#		playerBox.get_node("TextureRect").modulate = Color.WHITE
		playerBox.get_node("VBoxContainer/Select").text = "Select"
	
func _on_color_picker_color_changed(color):
	P4Box.get_node("Label").modulate = color
	P4Box.get_node("TextureRect").modulate = color

func _on_back_pressed():
	back.emit()

func _on_go_pressed():
	# Teams need players on both sides
	if Global.teams:
		var actives = {1: player1Active, 2: player2Active, 3: player3Active, 4: player4Active}
		var sides = {}
		for id in actives:
			if actives[id]:
				sides[Global.team_of(id)] = true
		if sides.size() < 2:
			options_warning.text = "Teams need at least one player on each team"
			return
	options_warning.text = ""
	Global.player1Active = player1Active
	Global.player2Active = player2Active
	Global.player3Active = player3Active
	Global.player4Active = player4Active
	Global.player1Score = 0
	Global.player2Score = 0
	Global.player3Score = 0
	Global.player4Score = 0
	go.emit()

@rpc("any_peer","call_local")
func StartGame():
#	var scene = multiscene.instantiate()
#	get_tree().root.add_child(scene)
#	scene.connect("restartNotice", reboot.bind(scene))
	self.hide()
	
func reboot(_scene):
	StartGame.rpc()
#	var newScene = multiscene.instantiate()
#	scene.queue_free()
#	get_tree().root.add_child(newScene)
#	self.hide()


#region multi
func _on_multi_go():
#	Global.isMultiplayerActive = true
#	Global.player1Active = player1Active
#	Global.player2Active = player2Active
	
	StartGame.rpc()
#	get_tree().change_scene_to_file("res://scenes/multiplayer_playground.tscn")
#	get_tree().change_scene_to_file(multiscene)
	pass # Replace with function body.

func _on_multiplayer_test_hosted():
	_on_p_1on_pressed()
	pass # Replace with function body.

func _on_multiplayer_test_joined():
	_on_p_2on_pressed()
	pass # Replace with function body.
#endregion


func _on_redefine_1_pressed():
	$RedefineKeys.show()
	$RedefineKeys.redefinePlayer(1)

func _on_redefine_2_pressed():
	$RedefineKeys.show()
	$RedefineKeys.redefinePlayer(2)

func _on_redefine_3_pressed():
	$RedefineKeys.show()
	$RedefineKeys.redefinePlayer(3)

func _on_redefine_4_pressed():
	$RedefineKeys.show()
	$RedefineKeys.redefinePlayer(4)

func _on_redefine_keys_recalculate_labels(playerId):
	setKeys(playerId, "Left")
	setKeys(playerId, "Right")
	setKeys(playerId, "Up")
	
func setKeys(playerId, control):
	var playerBoxes = $PanelContainer/MarginContainer/VBoxContainer/HBoxContainer as HBoxContainer
	var inputList = playerBoxes.get_node(str(playerId)).get_node("InputList")
	var text = ""
	var label
	
	for i in InputMap.action_get_events("Player"+str(playerId)+control):
		if text != "":
			text += " / "
		text += Global.input_event_name(i)
		
		
	if control == "Up":
		label =  inputList.get_node(control).get_node("MarginContainer/PanelContainer").get_node(control)
	else: label = inputList.get_node(control).get_node(control)
	
	var string_size = label.get_theme_font("font") \
	.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.get_theme_font_size("font_size"))
#	print(string_size)
	label.set_text(text)
	string_size = label.get_theme_font("font") \
	.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.get_theme_font_size("font_size"))
#	print(string_size)
	if string_size.x > 300:
		var ls = LabelSettings.new()
		ls.set_font_size(44)
		label.set_label_settings(ls)
		label.set_text(label.text.substr(0,20))
	#if label.text .size() > 300:
		#label.text.substr(300)

func _on_enable_ai_toggled(button_pressed, player_id):
	#Connected through Scene - TODO: Connect through code
	Global.AI_Enabled[player_id] = button_pressed
	if button_pressed: enable_player(player_id)
	pass # Replace with function body.

func enable_player(player_id:int) -> void:
	match player_id:
		1:
			if !player1Active : _on_p_1on_pressed()
		2:
			if !player2Active : _on_p_2on_pressed()
		3:
			if !player3Active : _on_p_3on_pressed()
		4:
			if !player4Active : _on_p_4on_pressed()


#region Match options (saved in Global's settings): a panel in the top left corner with
# the mode and points always in view, and the rest folding out under "Match settings"

var mode_button: Button
var points_button: Button
var spawns_button: Button
var countdown_button: Button
var arena_button: Button
var upgrades_button: Button
var shrooms_button: Button
var upgrade_time_button: Button
var settings_toggle: Button
var settings_box: VBoxContainer
var options_warning: Label
var team_buttons = {}

func _build_match_options():
	var row = $PanelContainer/MarginContainer/VBoxContainer/HBoxContainer2
	var options_box = row.get_parent()
	var panel = VBoxContainer.new()
	# Pinned to the screen's corner, whatever the cards' layout
	panel.top_level = true
	panel.position = Vector2(28, 44)
	panel.add_theme_constant_override("separation", 10)
	add_child(panel)
	var title = Label.new()
	title.text = "MATCH"
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	panel.add_child(title)
	mode_button = _match_button(panel, _toggle_teams)
	points_button = _match_button(panel, _cycle_points)
	settings_toggle = _match_button(panel, func():
		settings_box.visible = not settings_box.visible
		_refresh_match_options())
	settings_box = VBoxContainer.new()
	settings_box.add_theme_constant_override("separation", 10)
	settings_box.hide()
	panel.add_child(settings_box)
	arena_button = _match_button(settings_box, _open_arena_rotation)
	upgrades_button = _match_button(settings_box, func():
		Global.upgrades = not Global.upgrades
		_options_changed())
	upgrade_time_button = _match_button(settings_box, func():
		var times = Global.UPGRADE_TIME_OPTIONS
		Global.upgrade_time = times[(max(times.find(Global.upgrade_time), 0) + 1) % times.size()]
		_options_changed())
	shrooms_button = _match_button(settings_box, func():
		Global.shrooms = not Global.shrooms
		_options_changed())
	spawns_button = _match_button(settings_box, _toggle_random_spawns)
	countdown_button = _match_button(settings_box, func():
		Global.round_countdown = not Global.round_countdown
		_options_changed())
	# The warning goes under the cards, so it doesn't push them off center
	options_warning = Label.new()
	options_warning.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	options_warning.add_theme_font_size_override("font_size", 28)
	options_warning.add_theme_color_override("font_color", Color(1, 0.4, 0.3))
	options_box.add_child(options_warning)
	options_box.move_child(options_warning, row.get_index() + 1)
	for id in [1, 2, 3, 4]:
		var box = $PanelContainer/MarginContainer/VBoxContainer/HBoxContainer.get_node(str(id))
		var team_button = _pill_button(28, 0)
		team_button.custom_minimum_size.y = 56
		team_button.pressed.connect(_toggle_team.bind(id))
		box.add_child(team_button)
		team_buttons[id] = team_button
	_refresh_match_options()

func _match_button(parent, callback):
	var button = _pill_button(28, 400)
	button.custom_minimum_size.y = 58
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _options_changed():
	Global.save_settings()
	_refresh_match_options()

# The arenas the match picks from, one at random every round
func _open_arena_rotation():
	var menu = LevelRotationMenu.open(self, Global.level_rotation)
	menu.changed.connect(func(rotation):
		Global.level_rotation = rotation
		_options_changed())
	menu.closed.connect(arena_button.grab_focus)

func _toggle_teams():
	Global.teams = not Global.teams
	Global.save_settings()
	_refresh_match_options()

func _cycle_points():
	var options = Global.POINTS_TO_WIN_OPTIONS
	Global.points_to_win = options[(options.find(Global.points_to_win) + 1) % options.size()]
	Global.save_settings()
	_refresh_match_options()

func _toggle_random_spawns():
	Global.random_spawns = not Global.random_spawns
	Global.save_settings()
	_refresh_match_options()

func _toggle_team(id):
	Global.player_team[id] = 1 - Global.team_of(id)
	Global.save_settings()
	_refresh_match_options()

func _refresh_match_options():
	mode_button.text = "Mode: " + ("2v2 Teams" if Global.teams else "Free for all")
	points_button.text = "Points to win: " + Global.points_to_win_text(Global.points_to_win)
	spawns_button.text = "Spawns: " + ("Random" if Global.random_spawns else "Fixed")
	settings_toggle.text = "Match settings  " + ("-" if settings_box.visible else "+")
	arena_button.text = "Arena rotation: " + Global.level_rotation_text(Global.level_rotation)
	upgrades_button.text = "Upgrades: " + ("On" if Global.upgrades else "Off")
	upgrade_time_button.text = "Upgrade pick time: " + Global.upgrade_time_text(Global.upgrade_time)
	upgrade_time_button.disabled = not Global.upgrades
	shrooms_button.text = "Shrooms: " + ("On" if Global.shrooms else "Off")
	countdown_button.text = "Countdown: " + ("On" if Global.round_countdown else "Off")
	options_warning.text = ""
	for id in team_buttons:
		var team = Global.team_of(id)
		team_buttons[id].visible = Global.teams
		team_buttons[id].text = Global.TEAM_NAMES[team]
		team_buttons[id].add_theme_color_override("font_color", Global.TEAM_COLORS[team])
		team_buttons[id].add_theme_color_override("font_hover_color", Global.TEAM_COLORS[team].lightened(0.3))
		team_buttons[id].add_theme_color_override("font_focus_color", Global.TEAM_COLORS[team])

#endregion

#region Player names: a box on each card, dragged onto another card to swap elements

# The person moves with their name: keys, AI, selection and team go along, and whoever
# was on the other element takes this one
var name_edits = {}

func _build_name_boxes():
	for id in [1, 2, 3, 4]:
		var box = _card(id)
		var holder = PanelContainer.new()
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.16, 0.16, 0.16)
		style.set_corner_radius_all(14)
		style.content_margin_left = 8
		style.content_margin_right = 12
		style.border_color = Color(Global.playerColors[id])
		style.border_width_bottom = 3
		holder.add_theme_stylebox_override("panel", style)
		holder.tooltip_text = "Drag to swap elements with another player"
		holder.mouse_default_cursor_shape = Control.CURSOR_MOVE
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		holder.add_child(row)
		var grip = Label.new()
		grip.text = "::"
		grip.add_theme_font_size_override("font_size", 30)
		grip.add_theme_color_override("font_color", Color(1, 1, 1, 0.4))
		grip.custom_minimum_size.x = 30
		grip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		grip.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		grip.mouse_filter = Control.MOUSE_FILTER_PASS
		grip.mouse_default_cursor_shape = Control.CURSOR_MOVE
		row.add_child(grip)
		var edit = LineEdit.new()
		edit.max_length = 14
		edit.placeholder_text = "Player %d" % id
		edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
		edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		edit.custom_minimum_size.y = 52
		edit.add_theme_font_size_override("font_size", 30)
		edit.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
		var focus = StyleBoxFlat.new()
		focus.bg_color = Color(1, 1, 1, 0.06)
		focus.set_corner_radius_all(10)
		edit.add_theme_stylebox_override("focus", focus)
		# Only by clicking: browsing the buttons with the keys skips it
		edit.focus_mode = Control.FOCUS_CLICK
		edit.text_changed.connect(func(text): Global.player_names[_slot_of(edit)] = text)
		edit.text_submitted.connect(func(_text): edit.release_focus())
		edit.focus_exited.connect(Global.save_settings)
		row.add_child(edit)
		name_edits[id] = edit
		for control in [holder, edit, box.get_node("PanelContainer2")]:
			control.set_drag_forwarding(_drag_name.bind(id), _can_drop_name, _drop_name.bind(id))
		box.add_child(holder)
		box.move_child(holder, box.get_node("PanelContainer2").get_index() + 1)
	_refresh_names()

func _card(id):
	return $PanelContainer/MarginContainer/VBoxContainer/HBoxContainer.get_node(str(id))

func _slot_of(edit):
	for id in name_edits:
		if name_edits[id] == edit:
			return id
	return 0

func _refresh_names():
	for id in name_edits:
		name_edits[id].text = str(Global.player_names.get(id, ""))

func _drag_name(_at, id):
	var preview = Label.new()
	var name = name_edits[id].text if name_edits[id].text != "" else name_edits[id].placeholder_text
	preview.text = name
	preview.add_theme_font_size_override("font_size", 34)
	preview.add_theme_color_override("font_color", Color(Global.playerColors[id]))
	preview.add_theme_constant_override("outline_size", 8)
	preview.add_theme_color_override("font_outline_color", Color.BLACK)
	set_drag_preview(preview)
	return {"swap_player": id}

func _can_drop_name(_at, data):
	return data is Dictionary and data.has("swap_player")

func _drop_name(_at, data, id):
	swap_players(data.swap_player, id)

func swap_players(a, b):
	if a == b:
		return
	var names = Global.player_names
	var name_a = names.get(a, "")
	names[a] = names.get(b, "")
	names[b] = name_a
	for control in ["Left", "Right", "Up"]:
		var action_a = "Player%d%s" % [a, control]
		var action_b = "Player%d%s" % [b, control]
		var events_a = InputMap.action_get_events(action_a)
		var events_b = InputMap.action_get_events(action_b)
		InputMap.action_erase_events(action_a)
		InputMap.action_erase_events(action_b)
		for event in events_b:
			InputMap.action_add_event(action_a, event)
		for event in events_a:
			InputMap.action_add_event(action_b, event)
	var ai_a = Global.AI_Enabled[a]
	Global.AI_Enabled[a] = Global.AI_Enabled[b]
	Global.AI_Enabled[b] = ai_a
	var team_a = Global.team_of(a)
	Global.player_team[a] = Global.team_of(b)
	Global.player_team[b] = team_a
	var active_a = get("player%dActive" % a)
	set("player%dActive" % a, get("player%dActive" % b))
	set("player%dActive" % b, active_a)
	for id in [a, b]:
		_card(id).set_ai_status(Global.AI_Enabled[id])
		activatePlayer(get("player%dActive" % id), _card(id), Global.playerColors[id])
		_on_redefine_keys_recalculate_labels(id)
	_refresh_names()
	_refresh_match_options()
	Global.save_settings()

#endregion
