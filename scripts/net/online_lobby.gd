extends Control

# Online lobby screen: host or find a Steam lobby, invite friends, see who plays
# which element and start the match. Each machine can add more snakes: another
# person on the same keyboard or an AI, and everyone can see and rebind the keys of
# the snakes they steer. Debug builds also get a LAN mode and a fake latency
# setting to test the netcode with two game windows on one machine.

const ODIN_FONT = preload("res://assets/jorge-resources/Game Selection/Odin Rounded - Bold.otf")
# Translation keys (shown with tr())
const ELEMENT_NAMES = ["", "ELEMENT_FIRE_UPPER", "ELEMENT_EARTH_UPPER", "ELEMENT_AIR_UPPER", "ELEMENT_WATER_UPPER", "ELEMENT_VOID_UPPER"]
const FAKE_LATENCIES = [0.0, 0.1, 0.2]
const KEY_ACTIONS = ["Left", "Right", "Up"]
const KEY_NAMES = {"Left": "KEY_LEFT", "Right": "KEY_RIGHT", "Up": "KEY_PUNCHI"}
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
var mode_button
var points_button
var upgrade_time_button
var spawns_button
var random_teams_button
var countdown_button
var arena_button
var settings_toggle
var settings_box
var invite_button
var latency_button
var privacy_button
var code_label
var copy_code_button
var code_input

func _ready():
	# Steam only runs on this screen and in online matches (SteamNet.stop_steam)
	SteamNet.start_steam()
	_build_layout()
	SteamNet.status_changed.connect(_on_status_changed)
	SteamNet.roster_changed.connect(_refresh_roster)
	SteamNet.match_options_changed.connect(_refresh_roster)
	SteamNet.lobby_list_received.connect(_show_lobbies)
	status_label.text = SteamNet.steam_status
	_refresh_roster()
	SteamNet.take_pending_invite()

func _exit_tree():
	SteamNet.status_changed.disconnect(_on_status_changed)
	SteamNet.roster_changed.disconnect(_refresh_roster)
	SteamNet.match_options_changed.disconnect(_refresh_roster)
	SteamNet.lobby_list_received.disconnect(_show_lobbies)

# A person who chose a name before gets it back when they join with those keys (asked
# once per slot and name, so a refused rename doesn't loop)
var asked_names = {}
func _restore_name(slot, entry):
	var saved = str(Global.online_names.get(entry.keys, "")).strip_edges()
	var key = "%d:%s" % [slot, saved]
	if saved == "" or saved == entry.name or asked_names.has(key):
		return
	asked_names[key] = true
	SteamNet.rename_slot(slot, saved)

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
		row.name_edit.visible = false
		if entry == null:
			row.name.text = tr("LOBBY_OPEN")
			row.name.modulate = Color(1, 1, 1, 0.4)
			row.keys.text = ""
			continue
		row.name.modulate = Color.WHITE
		var local = entry.peer == me
		row.name.text = entry.name + ("  " + tr("LOBBY_YOU") if local and not entry.ai else "")
		# Your own people: a name box instead (and the name they used last time comes back)
		if local and not entry.ai:
			row.name.visible = false
			row.name_edit.visible = true
			if not row.name_edit.has_focus():
				row.name_edit.text = entry.name
			_restore_name(slot, entry)
		if entry.ai:
			row.keys.text = tr("LOBBY_AI_HERE") if local else tr("LOBBY_AI_THERE")
		elif local:
			row.keys.text = _keys_text(entry.keys)
			row.keys_button.visible = true
		else:
			row.keys.text = tr("LOBBY_PLAYS_THERE")
		row.keys.modulate = Color(0.7, 0.7, 0.7)
		row.remove_button.visible = SteamNet.can_remove_slot(slot, me)
	if rebind_keys != 0:
		_show_rebind_prompt()
	var full = SteamNet.roster.size() >= SteamNet.MAX_PLAYERS
	add_player_button.disabled = not SteamNet.is_online() or full
	add_ai_button.disabled = not SteamNet.is_online() or full
	start_button.disabled = not SteamNet.is_host() or SteamNet.roster.size() < 2
	# The host's toggle decides the match (Global.online_upgrades)
	# Match options: the host's (Global) on the host, the synced copy everywhere else
	var options = Global.match_options() if SteamNet.is_host() or not SteamNet.is_online() else SteamNet.match_options
	var host = SteamNet.is_host()
	var in_steam_lobby = SteamNet.lobby_code != ""
	code_label.text = (tr("LOBBY_CODE_LABEL") % SteamNet.lobby_code) if in_steam_lobby else ""
	copy_code_button.visible = in_steam_lobby
	privacy_button.text = tr("LOBBY_PRIVACY") % (tr("LOBBY_PRIVATE") if SteamNet.lobby_private else tr("LOBBY_PUBLIC"))
	# Before hosting it picks the new lobby's type; in a lobby only the host changes it
	privacy_button.disabled = SteamNet.is_lan or (SteamNet.is_online() and not host)
	upgrades_button.disabled = not host
	upgrades_button.text = tr("MATCH_UPGRADES") % Global.on_off(options.get("upgrades", false))
	mode_button.disabled = not host
	mode_button.text = tr("MATCH_MODE") % (tr("MATCH_TEAMS") if options.get("teams", false) else tr("MATCH_FFA"))
	points_button.disabled = not host
	points_button.text = tr("MATCH_POINTS") % Global.points_to_win_text(options.get("points_to_win", 0))
	# Seconds each snake has to pick its upgrade (only matters with upgrades on)
	upgrade_time_button.disabled = not host or not options.get("upgrades", false)
	upgrade_time_button.text = tr("MATCH_UPGRADE_TIME") % Global.upgrade_time_text(int(options.get("upgrade_time", Global.online_upgrade_time)))
	random_teams_button.disabled = not host or not options.get("teams", false)
	random_teams_button.text = tr("MATCH_RANDOM_TEAMS") % Global.on_off(options.get("random_teams", false))
	spawns_button.disabled = not host
	spawns_button.text = tr("MATCH_SPAWNS") % (tr("MATCH_SPAWNS_RANDOM") if options.get("random_spawns", false) else tr("MATCH_SPAWNS_FIXED"))
	countdown_button.disabled = not host
	countdown_button.text = tr("MATCH_COUNTDOWN") % Global.on_off(options.get("round_countdown", true))
	arena_button.disabled = not host
	arena_button.text = tr("MATCH_ARENAS") % Global.level_rotation_text(options.get("levels", [options.get("level", "")]))
	var player_team = options.get("player_team", Global.player_team)
	for slot in slot_rows:
		var team_button = slot_rows[slot].team_button
		var team = player_team.get(slot, 0)
		team_button.visible = options.get("teams", false) and not options.get("random_teams", false)
		team_button.disabled = not host
		team_button.text = Global.team_name(team)
		team_button.add_theme_color_override("font_color", Global.TEAM_COLORS[team])
		team_button.add_theme_color_override("font_disabled_color", Global.TEAM_COLORS[team].darkened(0.2))
	invite_button.disabled = SteamNet.lobby_id == 0

func _keys_text(keys):
	var parts = []
	for action in KEY_ACTIONS:
		parts.append(tr(KEY_NAMES[action]) + ": " + Global.action_key_name("Player" + str(keys) + action))
	return "   ".join(parts)


#region Open slot menu

const MENU_ADD_PLAYER = 100
const MENU_ADD_AI = 101

# Rebuilt every time it opens, so it lists this machine's current snakes
func _fill_open_menu(slot):
	var popup = slot_rows[slot].open_button.get_popup()
	popup.clear()
	for own_slot in SteamNet.local_slots():
		var entry = SteamNet.roster[own_slot]
		popup.add_item(tr("LOBBY_TAKE_SLOT") % [entry.name, tr(ELEMENT_NAMES[own_slot])], own_slot)
	var full = SteamNet.roster.size() >= SteamNet.MAX_PLAYERS
	popup.add_item(tr("LOBBY_ADD_PLAYER_HERE"), MENU_ADD_PLAYER)
	popup.set_item_disabled(popup.get_item_index(MENU_ADD_PLAYER), full)
	popup.add_item(tr("LOBBY_ADD_AI_HERE"), MENU_ADD_AI)
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
			slot_rows[slot].keys.text = tr("LOBBY_PRESS_KEY") % tr(KEY_NAMES[KEY_ACTIONS[rebind_step]]).to_upper()
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
		lobby_list.add_child(_label(tr("LOBBY_NONE_FOUND"), 24, Color(0.6, 0.6, 0.6)))
	for lobby in lobbies:
		var button = _button("%s  (%d/4)" % [lobby.name, lobby.members], func(): SteamNet.join_lobby(lobby.id))
		lobby_list.add_child(button)

func _toggle_upgrades():
	Global.upgrades = not Global.upgrades
	_match_options_edited()

func _toggle_teams():
	Global.teams = not Global.teams
	_match_options_edited()

func _cycle_points():
	var choices = Global.POINTS_TO_WIN_OPTIONS
	Global.points_to_win = choices[(choices.find(Global.points_to_win) + 1) % choices.size()]
	_match_options_edited()

func _toggle_random_spawns():
	Global.random_spawns = not Global.random_spawns
	_match_options_edited()

func _toggle_round_countdown():
	Global.round_countdown = not Global.round_countdown
	_match_options_edited()

# The arenas the match picks from, one at random every round (only the host edits them)
func _open_arena_rotation():
	var menu = LevelRotationMenu.open(self, Global.level_rotation)
	menu.changed.connect(func(rotation):
		Global.level_rotation = rotation
		_match_options_edited())
	menu.closed.connect(arena_button.grab_focus)

func _cycle_upgrade_time():
	var choices = Global.ONLINE_UPGRADE_TIME_OPTIONS
	Global.online_upgrade_time = choices[(choices.find(Global.online_upgrade_time) + 1) % choices.size()]
	_match_options_edited()

func _toggle_team(slot):
	Global.player_team[slot] = 1 - Global.team_of(slot)
	_match_options_edited()

# Host only: saved like the offline options and sent to the lobby
func _match_options_edited():
	Global.save_settings()
	SteamNet.push_match_options()
	_refresh_roster()

func _on_back_pressed():
	SteamNet.leave()
	get_tree().change_scene_to_file("res://scenes/menu.tscn")

func _cycle_fake_latency():
	var index = (FAKE_LATENCIES.find(SteamNet.fake_latency) + 1) % FAKE_LATENCIES.size()
	SteamNet.fake_latency = FAKE_LATENCIES[index]
	latency_button.text = tr("LOBBY_FAKE_LATENCY") % int(SteamNet.fake_latency * 1000)

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

	var title = _label(tr("LOBBY_TITLE"), 72, Color.WHITE)
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
	actions.add_theme_constant_override("separation", 10)
	columns.add_child(actions)
	var host_button = _button(tr("LOBBY_HOST"), SteamNet.host_lobby)
	actions.add_child(host_button)
	privacy_button = _button(tr("LOBBY_PRIVACY") % tr("LOBBY_PUBLIC"), func(): SteamNet.set_lobby_private(not SteamNet.lobby_private))
	privacy_button.tooltip_text = tr("LOBBY_PRIVATE_TIP")
	actions.add_child(privacy_button)
	invite_button = _button(tr("LOBBY_INVITE"), SteamNet.invite_friends)
	actions.add_child(invite_button)
	add_player_button = _button(tr("LOBBY_ADD_PLAYER"), func(): SteamNet.add_local_player(false))
	actions.add_child(add_player_button)
	add_ai_button = _button(tr("LOBBY_ADD_AI"), func(): SteamNet.add_local_player(true))
	actions.add_child(add_ai_button)
	# Mode and points always show; the rest of the match settings fold out
	mode_button = _button(tr("MATCH_MODE") % tr("MATCH_FFA"), _toggle_teams)
	actions.add_child(mode_button)
	points_button = _button(tr("MATCH_POINTS") % tr("VALUE_AUTO"), _cycle_points)
	actions.add_child(points_button)
	settings_toggle = _button(tr("MATCH_SETTINGS") + "  +", func():
		settings_box.visible = not settings_box.visible
		settings_toggle.text = tr("MATCH_SETTINGS") + "  " + ("-" if settings_box.visible else "+"))
	actions.add_child(settings_toggle)
	settings_box = VBoxContainer.new()
	settings_box.add_theme_constant_override("separation", 10)
	settings_box.hide()
	actions.add_child(settings_box)
	arena_button = _button(tr("MATCH_ARENAS") % tr("LEVEL_CLASSIC"), _open_arena_rotation)
	settings_box.add_child(arena_button)
	upgrades_button = _button(tr("MATCH_UPGRADES") % tr("VALUE_OFF"), _toggle_upgrades)
	settings_box.add_child(upgrades_button)
	upgrade_time_button = _button(tr("MATCH_UPGRADE_TIME") % Global.upgrade_time_text(10), _cycle_upgrade_time)
	settings_box.add_child(upgrade_time_button)
	random_teams_button = _button(tr("MATCH_RANDOM_TEAMS") % tr("VALUE_OFF"), func():
		Global.random_teams = not Global.random_teams
		_match_options_edited())
	settings_box.add_child(random_teams_button)
	spawns_button = _button(tr("MATCH_SPAWNS") % tr("MATCH_SPAWNS_FIXED"), _toggle_random_spawns)
	settings_box.add_child(spawns_button)
	countdown_button = _button(tr("MATCH_COUNTDOWN") % tr("VALUE_ON"), _toggle_round_countdown)
	settings_box.add_child(countdown_button)
	start_button = _button(tr("LOBBY_START"), SteamNet.start_match)
	actions.add_child(start_button)
	actions.add_child(_button(tr("UI_BACK"), _on_back_pressed))
	# Many buttons: a bit smaller than the rest so the column fits on screen
	for button in actions.get_children() + settings_box.get_children():
		if not button is Button:
			continue
		button.add_theme_font_size_override("font_size", 24)
		for state in ["normal", "hover", "pressed", "focus", "disabled"]:
			var style = ui_theme.get_stylebox(state, "Button").duplicate()
			style.content_margin_top = 7
			style.content_margin_bottom = 7
			button.add_theme_stylebox_override(state, style)

	var players_box = VBoxContainer.new()
	players_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	players_box.add_theme_constant_override("separation", 14)
	columns.add_child(players_box)
	var players_header = HBoxContainer.new()
	players_header.add_theme_constant_override("separation", 20)
	players_box.add_child(players_header)
	var players_title = _label(tr("LOBBY_PLAYERS"), 34, Color.WHITE)
	players_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	players_header.add_child(players_title)
	code_label = _label("", 30, HIGHLIGHT)
	code_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	players_header.add_child(code_label)
	copy_code_button = _button(tr("LOBBY_COPY_CODE"), func():
		DisplayServer.clipboard_set(SteamNet.lobby_code)
		status_label.text = tr("LOBBY_CODE_COPIED") % SteamNet.lobby_code)
	players_header.add_child(copy_code_button)
	for slot in range(1, SteamNet.MAX_SLOTS + 1):
		var panel = PanelContainer.new()
		var style = _box_style(Color(0.16, 0.16, 0.16))
		style.border_color = Color(Global.playerColors[slot])
		style.border_width_left = 8
		panel.add_theme_stylebox_override("panel", style)
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 30)
		panel.add_child(row)
		var element_box = VBoxContainer.new()
		element_box.custom_minimum_size.x = 190
		element_box.alignment = BoxContainer.ALIGNMENT_CENTER
		element_box.add_theme_constant_override("separation", 0)
		element_box.add_child(_label(tr(ELEMENT_NAMES[slot]), 34, Color(Global.playerColors[slot])))
		# What its power does, in two words
		element_box.add_child(_label(tr(Global.POWER_TAGLINES[slot]), 20, Color(Global.playerColors[slot]).lightened(0.35)))
		row.add_child(element_box)
		var texts = VBoxContainer.new()
		texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(texts)
		var name_label = _label(tr("LOBBY_OPEN"), 30, Color.WHITE)
		# Long names and key lists shrink or wrap instead of pushing the buttons off screen
		name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		name_label.clip_text = true
		texts.add_child(name_label)
		# This machine's people type the name they go by
		var name_edit = LineEdit.new()
		name_edit.max_length = SteamNet.MAX_NAME_LENGTH
		name_edit.placeholder_text = tr("LOBBY_YOUR_NAME")
		name_edit.add_theme_font_size_override("font_size", 28)
		name_edit.custom_minimum_size = Vector2(320, 0)
		name_edit.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		name_edit.select_all_on_focus = true
		name_edit.text_submitted.connect(func(text):
			SteamNet.rename_slot(slot, text)
			name_edit.release_focus())
		name_edit.focus_exited.connect(func(): SteamNet.rename_slot(slot, name_edit.text))
		name_edit.hide()
		texts.add_child(name_edit)
		var open_button = MenuButton.new()
		open_button.text = tr("LOBBY_OPEN_CHOOSE")
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
		keys_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		texts.add_child(keys_label)
		var keys_button = _button(tr("OPT_KEYS"), _start_rebind.bind(slot))
		keys_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(keys_button)
		var team_button = _button(Global.team_name(0), _toggle_team.bind(slot))
		team_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		team_button.hide()
		row.add_child(team_button)
		var remove_button = _button(tr("LOBBY_REMOVE"), func(): SteamNet.remove_slot(slot))
		remove_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(remove_button)
		slot_rows[slot] = {"name": name_label, "name_edit": name_edit, "open_button": open_button, "keys": keys_label, "keys_button": keys_button, "remove_button": remove_button, "team_button": team_button}
		players_box.add_child(panel)

	var lobbies_box = VBoxContainer.new()
	lobbies_box.custom_minimum_size.x = 440
	lobbies_box.add_theme_constant_override("separation", 14)
	columns.add_child(lobbies_box)
	lobbies_box.add_child(_label(tr("LOBBY_LOBBIES"), 34, Color.WHITE))
	# Join by code: for private lobbies, or when the list is too long to find one
	var code_row = HBoxContainer.new()
	code_row.add_theme_constant_override("separation", 10)
	lobbies_box.add_child(code_row)
	code_input = LineEdit.new()
	code_input.placeholder_text = tr("LOBBY_CODE_PLACEHOLDER")
	code_input.max_length = SteamNet.LOBBY_CODE_LENGTH
	code_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	code_input.add_theme_stylebox_override("normal", _box_style(Color(0.16, 0.16, 0.16)))
	code_input.add_theme_stylebox_override("focus", _box_style(Color(0.16, 0.16, 0.16), HIGHLIGHT))
	code_input.text_changed.connect(func(text):
		var caret = code_input.caret_column
		code_input.text = text.to_upper()
		code_input.caret_column = caret)
	code_input.text_submitted.connect(func(text): SteamNet.join_by_code(text))
	code_row.add_child(code_input)
	code_row.add_child(_button(tr("LOBBY_JOIN"), func(): SteamNet.join_by_code(code_input.text)))
	lobbies_box.add_child(_button(tr("LOBBY_FIND"), SteamNet.find_lobbies))
	lobby_list = VBoxContainer.new()
	lobby_list.add_theme_constant_override("separation", 10)
	lobby_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var lobby_scroll = ScrollContainer.new()
	lobby_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lobby_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	lobby_scroll.add_child(lobby_list)
	lobbies_box.add_child(lobby_scroll)
	if OS.is_debug_build():
		lobbies_box.add_child(_label(tr("LOBBY_DEBUG"), 22, Color(0.5, 0.5, 0.5)))
		lobbies_box.add_child(_button(tr("LOBBY_LAN_HOST"), SteamNet.host_lan))
		lobbies_box.add_child(_button(tr("LOBBY_LAN_JOIN"), func(): SteamNet.join_lan()))
		latency_button = _button(tr("LOBBY_FAKE_LATENCY") % 0, _cycle_fake_latency)
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
