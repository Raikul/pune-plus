extends Control

# Online lobby screen: host or find a Steam lobby, invite friends, see who plays
# which element and start the match. Each machine can add more snakes: another
# person on the same keyboard or an AI, and everyone can see and rebind the keys of
# the snakes they steer. Debug builds also get a LAN mode and a fake latency
# setting to test the netcode with two game windows on one machine.

const ODIN_FONT = preload("res://assets/jorge-resources/Game Selection/Odin Rounded - Bold.otf")
const ELEMENT_NAMES = ["", "FIRE", "EARTH", "AIR", "WATER"]
const FAKE_LATENCIES = [0.0, 0.1, 0.2]
const KEY_ACTIONS = ["Left", "Right", "Up"]
const KEY_NAMES = {"Left": "Left", "Right": "Right", "Up": "Punchy"}
const HIGHLIGHT = Color(0.91, 0.61, 0.17)

var status_label
var slot_rows = {} # slot -> {"name", "open_button", "keys", "keys_button", "remove_button"}
var add_player_button
var add_ai_button
# Key set being rebound (Player{N}), 0 when not rebinding
var rebind_keys = 0
var rebind_step = 0
var lobby_list
var start_button
var upgrades_button
var invite_button
var latency_button

func _ready():
	_build_layout()
	SteamNet.status_changed.connect(_on_status_changed)
	SteamNet.roster_changed.connect(_refresh_roster)
	SteamNet.lobby_list_received.connect(_show_lobbies)
	status_label.text = SteamNet.steam_status
	_refresh_roster()

func _exit_tree():
	SteamNet.status_changed.disconnect(_on_status_changed)
	SteamNet.roster_changed.disconnect(_refresh_roster)
	SteamNet.lobby_list_received.disconnect(_show_lobbies)

func _on_status_changed(text):
	status_label.text = text

func _refresh_roster():
	var me = multiplayer.get_unique_id()
	for slot in slot_rows:
		var row = slot_rows[slot]
		var entry = SteamNet.roster.get(slot)
		row.keys_button.visible = false
		row.remove_button.visible = false
		# An open slot is a menu to move one of your snakes there or add one
		row.open_button.visible = entry == null and SteamNet.is_online()
		row.name.visible = not row.open_button.visible
		if entry == null:
			row.name.text = "Open"
			row.name.modulate = Color(1, 1, 1, 0.4)
			row.keys.text = ""
			continue
		row.name.modulate = Color.WHITE
		var local = entry.peer == me
		row.name.text = entry.name + ("  (you)" if local and not entry.ai else "")
		if entry.ai:
			row.keys.text = "AI, runs on " + ("this machine" if local else "its owner's machine")
		elif local:
			row.keys.text = _keys_text(entry.keys)
			row.keys_button.visible = true
		else:
			row.keys.text = "Plays on their machine"
		row.keys.modulate = Color(0.7, 0.7, 0.7)
		row.remove_button.visible = SteamNet.can_remove_slot(slot, me)
	if rebind_keys != 0:
		_show_rebind_prompt()
	var full = SteamNet.roster.size() >= SteamNet.MAX_PLAYERS
	add_player_button.disabled = not SteamNet.is_online() or full
	add_ai_button.disabled = not SteamNet.is_online() or full
	start_button.disabled = not SteamNet.is_host() or SteamNet.roster.size() < 2
	# The host's toggle decides the match (Global.online_upgrades)
	upgrades_button.disabled = not SteamNet.is_host()
	upgrades_button.text = "Upgrades: " + ("ON" if Global.upgrades else "OFF")
	invite_button.disabled = SteamNet.lobby_id == 0

func _keys_text(keys):
	var parts = []
	for action in KEY_ACTIONS:
		parts.append(KEY_NAMES[action] + ": " + _key_name("Player" + str(keys) + action))
	return "   ".join(parts)

func _key_name(action):
	var events = InputMap.action_get_events(action)
	if events.is_empty():
		return "?"
	var event = events[0]
	if event is InputEventKey:
		var code = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		return OS.get_keycode_string(code)
	return event.as_text()

#region Open slot menu

const MENU_ADD_PLAYER = 100
const MENU_ADD_AI = 101

# Rebuilt every time it opens, so it lists this machine's current snakes
func _fill_open_menu(slot):
	var popup = slot_rows[slot].open_button.get_popup()
	popup.clear()
	for own_slot in SteamNet.local_slots():
		var entry = SteamNet.roster[own_slot]
		popup.add_item("Take slot: move " + entry.name + " (" + ELEMENT_NAMES[own_slot] + ")", own_slot)
	var full = SteamNet.roster.size() >= SteamNet.MAX_PLAYERS
	popup.add_item("Add player here (this keyboard)", MENU_ADD_PLAYER)
	popup.set_item_disabled(popup.get_item_index(MENU_ADD_PLAYER), full)
	popup.add_item("Add my AI here", MENU_ADD_AI)
	popup.set_item_disabled(popup.get_item_index(MENU_ADD_AI), full)

func _on_open_menu_chosen(id, slot):
	match id:
		MENU_ADD_PLAYER: SteamNet.add_local_player(false, slot)
		MENU_ADD_AI: SteamNet.add_local_player(true, slot)
		_: SteamNet.move_slot(id, slot)

#endregion

#region Key rebinding (local only, like the offline player setup)

func _start_rebind(slot):
	var entry = SteamNet.roster.get(slot)
	if entry == null or entry.keys == 0:
		return
	rebind_keys = entry.keys
	rebind_step = 0
	_show_rebind_prompt()

func _show_rebind_prompt():
	for slot in slot_rows:
		var entry = SteamNet.roster.get(slot)
		if entry and SteamNet.is_local_slot(slot) and entry.keys == rebind_keys:
			slot_rows[slot].keys.text = "Press the key for " + KEY_NAMES[KEY_ACTIONS[rebind_step]].to_upper() + "..."
			slot_rows[slot].keys.modulate = HIGHLIGHT
			return
	rebind_keys = 0 # That snake is gone

func _input(event):
	if rebind_keys == 0 or not event.is_pressed() or event.is_echo():
		return
	if not (event is InputEventKey or event is InputEventJoypadButton):
		return
	get_viewport().set_input_as_handled()
	var action = "Player" + str(rebind_keys) + KEY_ACTIONS[rebind_step]
	InputMap.action_erase_events(action)
	InputMap.action_add_event(action, event)
	rebind_step += 1
	if rebind_step >= KEY_ACTIONS.size():
		rebind_keys = 0
	_refresh_roster()

#endregion

func _show_lobbies(lobbies):
	for child in lobby_list.get_children():
		child.queue_free()
	if lobbies.is_empty():
		lobby_list.add_child(_label("No lobbies found", 24, Color(0.6, 0.6, 0.6)))
	for lobby in lobbies:
		var button = _button("%s  (%d/4)" % [lobby.name, lobby.members], func(): SteamNet.join_lobby(lobby.id))
		lobby_list.add_child(button)

func _toggle_upgrades():
	Global.upgrades = not Global.upgrades
	Global.save_settings()
	_refresh_roster()

func _on_back_pressed():
	SteamNet.leave()
	get_tree().change_scene_to_file("res://scenes/menu.tscn")

func _cycle_fake_latency():
	var index = (FAKE_LATENCIES.find(SteamNet.fake_latency) + 1) % FAKE_LATENCIES.size()
	SteamNet.fake_latency = FAKE_LATENCIES[index]
	latency_button.text = "Fake latency: %d ms" % int(SteamNet.fake_latency * 1000)

#region Layout

func _build_layout():
	var ui_theme = Theme.new()
	ui_theme.default_font = ODIN_FONT
	ui_theme.default_font_size = 28
	var normal = _box_style(Color(0.22, 0.22, 0.22))
	ui_theme.set_stylebox("normal", "Button", normal)
	ui_theme.set_stylebox("hover", "Button", _box_style(Color(0.3, 0.3, 0.3)))
	ui_theme.set_stylebox("pressed", "Button", _box_style(Color(0.35, 0.35, 0.35)))
	ui_theme.set_stylebox("focus", "Button", _box_style(Color(0, 0, 0, 0), Color(0.91, 0.61, 0.17)))
	ui_theme.set_stylebox("disabled", "Button", _box_style(Color(0.16, 0.16, 0.16)))
	ui_theme.set_color("font_disabled_color", "Button", Color(0.4, 0.4, 0.4))
	ui_theme.set_color("font_hover_color", "Button", Color(0.91, 0.61, 0.17))
	theme = ui_theme

	var background = ColorRect.new()
	background.color = Color(0.1, 0.1, 0.1)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 60)
	add_child(margin)

	var layout = VBoxContainer.new()
	layout.add_theme_constant_override("separation", 30)
	margin.add_child(layout)

	var title = _label("ONLINE", 72, Color.WHITE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layout.add_child(title)
	status_label = _label("", 26, Color(0.7, 0.7, 0.7))
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layout.add_child(status_label)

	var columns = HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 60)
	layout.add_child(columns)

	var actions = VBoxContainer.new()
	actions.custom_minimum_size.x = 420
	actions.add_theme_constant_override("separation", 14)
	columns.add_child(actions)
	var host_button = _button("Host (friends)", func(): SteamNet.host_lobby(false))
	actions.add_child(host_button)
	actions.add_child(_button("Host (public)", func(): SteamNet.host_lobby(true)))
	actions.add_child(_button("Find lobbies", SteamNet.find_lobbies))
	invite_button = _button("Invite friends", SteamNet.invite_friends)
	actions.add_child(invite_button)
	add_player_button = _button("Add player (this keyboard)", func(): SteamNet.add_local_player(false))
	actions.add_child(add_player_button)
	add_ai_button = _button("Add AI player", func(): SteamNet.add_local_player(true))
	actions.add_child(add_ai_button)
	upgrades_button = _button("Upgrades: OFF", _toggle_upgrades)
	actions.add_child(upgrades_button)
	start_button = _button("Start match", SteamNet.start_match)
	actions.add_child(start_button)
	actions.add_child(_button("Back", _on_back_pressed))

	var players_box = VBoxContainer.new()
	players_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	players_box.add_theme_constant_override("separation", 14)
	columns.add_child(players_box)
	players_box.add_child(_label("Players", 34, Color.WHITE))
	for slot in range(1, 5):
		var panel = PanelContainer.new()
		var style = _box_style(Color(0.16, 0.16, 0.16))
		style.border_color = Color(Global.playerColors[slot])
		style.border_width_left = 8
		panel.add_theme_stylebox_override("panel", style)
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 30)
		panel.add_child(row)
		var element = _label(ELEMENT_NAMES[slot], 34, Color(Global.playerColors[slot]))
		element.custom_minimum_size.x = 170
		row.add_child(element)
		var texts = VBoxContainer.new()
		texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(texts)
		var name_label = _label("Open", 30, Color.WHITE)
		texts.add_child(name_label)
		var open_button = MenuButton.new()
		open_button.text = "Open  -  choose..."
		open_button.flat = false
		open_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		open_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		open_button.focus_mode = Control.FOCUS_ALL
		open_button.about_to_popup.connect(_fill_open_menu.bind(slot))
		open_button.get_popup().id_pressed.connect(_on_open_menu_chosen.bind(slot))
		open_button.get_popup().add_theme_font_size_override("font_size", 26)
		open_button.hide()
		texts.add_child(open_button)
		var keys_label = _label("", 22, Color(0.7, 0.7, 0.7))
		texts.add_child(keys_label)
		var keys_button = _button("Keys", _start_rebind.bind(slot))
		keys_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(keys_button)
		var remove_button = _button("Remove", func(): SteamNet.remove_slot(slot))
		remove_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(remove_button)
		slot_rows[slot] = {"name": name_label, "open_button": open_button, "keys": keys_label, "keys_button": keys_button, "remove_button": remove_button}
		players_box.add_child(panel)

	var lobbies_box = VBoxContainer.new()
	lobbies_box.custom_minimum_size.x = 440
	lobbies_box.add_theme_constant_override("separation", 14)
	columns.add_child(lobbies_box)
	lobbies_box.add_child(_label("Lobbies", 34, Color.WHITE))
	lobby_list = VBoxContainer.new()
	lobby_list.add_theme_constant_override("separation", 10)
	lobby_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lobbies_box.add_child(lobby_list)
	if OS.is_debug_build():
		lobbies_box.add_child(_label("Debug", 22, Color(0.5, 0.5, 0.5)))
		lobbies_box.add_child(_button("LAN host", SteamNet.host_lan))
		lobbies_box.add_child(_button("LAN join (this PC)", func(): SteamNet.join_lan()))
		latency_button = _button("Fake latency: 0 ms", _cycle_fake_latency)
		lobbies_box.add_child(latency_button)

	host_button.grab_focus.call_deferred()

func _box_style(color, border = Color.TRANSPARENT):
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(14)
	style.set_content_margin_all(14)
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
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

#endregion
