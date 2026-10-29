extends Control

# Online lobby screen: host or find a Steam lobby, invite friends, see who plays
# which element and start the match. Debug builds also get a LAN mode and a fake
# latency setting to test the netcode with two game windows on one machine.

const ODIN_FONT = preload("res://assets/jorge-resources/Game Selection/Odin Rounded - Bold.otf")
const ELEMENT_NAMES = ["", "FIRE", "EARTH", "AIR", "WATER"]
const FAKE_LATENCIES = [0.0, 0.1, 0.2]

var status_label
var slot_labels = {}
var lobby_list
var start_button
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
	for slot in slot_labels:
		var peer_id = SteamNet.peer_for_slot(slot)
		var label = slot_labels[slot]
		if peer_id != 0:
			var you = "  (you)" if peer_id == multiplayer.get_unique_id() else ""
			label.text = SteamNet.roster[peer_id].name + you
			label.modulate = Color.WHITE
		else:
			label.text = "Open"
			label.modulate = Color(1, 1, 1, 0.4)
	start_button.disabled = not SteamNet.is_host() or SteamNet.roster.size() < 2
	invite_button.disabled = SteamNet.lobby_id == 0

func _show_lobbies(lobbies):
	for child in lobby_list.get_children():
		child.queue_free()
	if lobbies.is_empty():
		lobby_list.add_child(_label("No lobbies found", 24, Color(0.6, 0.6, 0.6)))
	for lobby in lobbies:
		var button = _button("%s  (%d/4)" % [lobby.name, lobby.members], func(): SteamNet.join_lobby(lobby.id))
		lobby_list.add_child(button)

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
	start_button = _button("Start match", SteamNet.start_match)
	actions.add_child(start_button)
	actions.add_child(_button("Back", _on_back_pressed))
	if OS.is_debug_build():
		actions.add_child(_label("Debug", 22, Color(0.5, 0.5, 0.5)))
		actions.add_child(_button("LAN host", SteamNet.host_lan))
		actions.add_child(_button("LAN join (this PC)", func(): SteamNet.join_lan()))
		latency_button = _button("Fake latency: 0 ms", _cycle_fake_latency)
		actions.add_child(latency_button)

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
		slot_labels[slot] = _label("Open", 30, Color.WHITE)
		row.add_child(slot_labels[slot])
		players_box.add_child(panel)

	var lobbies_box = VBoxContainer.new()
	lobbies_box.custom_minimum_size.x = 520
	lobbies_box.add_theme_constant_override("separation", 14)
	columns.add_child(lobbies_box)
	lobbies_box.add_child(_label("Lobbies", 34, Color.WHITE))
	lobby_list = VBoxContainer.new()
	lobby_list.add_theme_constant_override("separation", 10)
	lobbies_box.add_child(lobby_list)

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
