extends Control

# The roguelike campaign's screen (scenes/campaign/campaign.tscn), between the menu and the
# scenarios. Built in code; one view at a time:
# - slots: the SLOTS saves (continue, start a new campaign, delete)
# - new run: pick the players' elements (one per player, in seat order)
# - map: the act's steps; pick one of the current step's scenarios to play it
# - after a scenario (Campaign.last_result): the upgrade picks after a win, a lost life,
#   the end of the campaign (all lives lost, or the boss beaten)
# Keys: the menu's ui_* actions and the mouse, and the first player's own keys (Left/Right
# move between the buttons, Punchi presses one; _input).

const ODIN_FONT = preload("res://assets/jorge-resources/Game Selection/Odin Rounded - Bold.otf")
const BACKGROUND = preload("res://assets/jorge-resources/Starting Screen/starting-screen-background.png")
const UPGRADE_SCREEN = preload("res://scenes/upgrade_selection.tscn")
const MAX_PLAYERS = 3
const ELEMENT_NAMES = {1: "ELEMENT_FIRE", 2: "ELEMENT_EARTH", 3: "ELEMENT_AIR", 4: "ELEMENT_WATER", 5: "ELEMENT_VOID"}

var view: Control
var picked = [] # New run: the elements picked, in seat order
var new_slot = 0
var details: Label
var message = ""
var upgrade_layer: CanvasLayer

func _ready():
	get_tree().paused = false
	var ui_theme = Theme.new()
	ui_theme.default_font = ODIN_FONT
	ui_theme.default_font_size = 30
	theme = ui_theme
	var background = TextureRect.new()
	background.texture = BACKGROUND
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.modulate = Color(0.35, 0.35, 0.4)
	add_child(background)
	# Back from a scenario (or an online campaign the host opened)
	if (Campaign.slot >= 0 or Campaign.online) and not Campaign.data.is_empty():
		_after_scenario()
	else:
		show_slots()

# The first player's keys (before a campaign is picked, any player's; online, this
# machine's): Left/Right go to the previous/next button, Punchi (Up) presses it. Not while
# the upgrade picks are up (every player picks there with their own keys).
func _input(event):
	if is_instance_valid(upgrade_layer) or not event.is_pressed() or event.is_echo():
		return
	for element in _nav_elements():
		var move = 0
		if event.is_action_pressed("Player%dLeft" % element):
			move = -1
		elif event.is_action_pressed("Player%dRight" % element):
			move = 1
		elif event.is_action_pressed("Player%dUp" % element):
			get_viewport().set_input_as_handled()
			var button = get_viewport().gui_get_focus_owner()
			if button is BaseButton and not button.disabled and button.is_visible_in_tree():
				button.pressed.emit()
			return
		else:
			continue
		get_viewport().set_input_as_handled()
		var focused = get_viewport().gui_get_focus_owner()
		if focused == null or not is_instance_valid(view) or not view.is_ancestor_of(focused):
			_focus_first(view)
			return
		var next = focused.find_next_valid_focus() if move > 0 else focused.find_prev_valid_focus()
		if next != null:
			next.grab_focus()
		return

func _nav_elements() -> Array:
	if Campaign.online:
		return SteamNet.local_slots().map(func(slot): return int(SteamNet.roster[slot].get("keys", slot)))
	if Campaign.data.is_empty() or Campaign.slot < 0:
		return [1, 2, 3, 4, 5]
	return [int(Campaign.data.seats[0].element)]

# Which keys move around this screen
func _keys_hint(parent):
	var elements = _nav_elements()
	if elements.size() != 1:
		return
	var keys = _keys_text(elements[0]).split(" / ")
	if keys.size() == 3:
		_label(parent, tr("CAMPAIGN_KEYS_HINT") % [keys[0], keys[1], keys[2]], 20, Color(0.65, 0.65, 0.65))

func _unhandled_input(event):
	if event.is_action_pressed("ui_cancel") and view != null and view.has_meta("back"):
		get_viewport().set_input_as_handled()
		view.get_meta("back").call()

# --- Building blocks ---

func _new_view(back: Callable = Callable()) -> VBoxContainer:
	if is_instance_valid(view):
		view.queue_free()
	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	view = center
	if back.is_valid():
		view.set_meta("back", back)
	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.07, 0.09, 0.92)
	style.set_corner_radius_all(18)
	style.set_content_margin_all(36)
	style.border_color = Color(1, 0.6, 0.15, 0.6)
	style.set_border_width_all(2)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)
	return box

func _label(parent, text, size = 30, color = Color.WHITE) -> Label:
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(label)
	return label

func _button(parent, text, callback: Callable, size = 32) -> Button:
	var button = Button.new()
	button.text = text
	button.add_theme_font_size_override("font_size", size)
	button.pressed.connect(callback)
	button.focus_mode = Control.FOCUS_ALL
	parent.add_child(button)
	return button

func _focus_first(parent):
	for child in parent.find_children("*", "Button", true, false):
		if not child.disabled:
			child.grab_focus.call_deferred()
			return

func _element_text(element) -> String:
	return tr(ELEMENT_NAMES.get(int(element), "ELEMENT_FIRE"))

func _team_text(elements) -> String:
	return ", ".join(elements.map(func(e): return _element_text(e)))

# --- Slots ---

func show_slots():
	Campaign.slot = -1
	var box = _new_view(_to_menu)
	_label(box, tr("CAMPAIGN_TITLE"), 64, Color(1, 0.75, 0.3))
	_label(box, tr("CAMPAIGN_ACT_SUBTITLE"), 24, Color(0.75, 0.75, 0.75))
	for index in Campaign.SLOTS:
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		box.add_child(row)
		var save = Campaign.read_slot(index)
		var summary = Label.new()
		summary.custom_minimum_size.x = 640
		summary.add_theme_font_size_override("font_size", 28)
		if save.is_empty():
			summary.text = tr("CAMPAIGN_SLOT_EMPTY") % (index + 1)
			row.add_child(summary)
			_button(row, tr("CAMPAIGN_NEW"), _start_new.bind(index))
		else:
			var elements = save.seats.map(func(seat): return seat.element)
			summary.text = tr("CAMPAIGN_SLOT_SUMMARY") % [index + 1, _team_text(elements), int(save.step) + 1, CampaignMap.STEPS + 1, int(save.lives)]
			row.add_child(summary)
			_button(row, tr("CAMPAIGN_CONTINUE"), _continue.bind(index))
			var delete = _button(row, tr("CAMPAIGN_DELETE"), func(): pass)
			delete.pressed.connect(_confirm_delete.bind(delete, index))
	if message != "":
		_label(box, message, 24, Color(1, 0.8, 0.5))
		message = ""
	_button(box, tr("UI_BACK"), _to_menu)
	_focus_first(box)

func _confirm_delete(button: Button, index):
	if button.has_meta("armed"):
		Campaign.delete_slot(index)
		show_slots()
		return
	button.set_meta("armed", true)
	button.text = tr("CAMPAIGN_DELETE_SURE")

func _continue(index):
	if Campaign.load_run(index):
		_after_scenario()

func _to_menu():
	if Campaign.online:
		# The host takes everyone back to the lobby (saved); another machine just leaves
		if multiplayer.is_server():
			Campaign.host_to_lobby()
		else:
			Campaign.end_online()
			SteamNet.leave()
			get_tree().change_scene_to_file("res://scenes/menu.tscn")
		return
	Campaign.slot = -1
	get_tree().change_scene_to_file("res://scenes/menu.tscn")

# Online, another machine: the host makes the choices
func _waiting() -> bool:
	return Campaign.online and not multiplayer.is_server()

# --- New campaign: who plays ---

func _start_new(index):
	new_slot = index
	picked = []
	_show_new_run()

func _show_new_run():
	var box = _new_view(show_slots)
	_label(box, tr("CAMPAIGN_PICK_TITLE"), 52, Color(1, 0.75, 0.3))
	_label(box, tr("CAMPAIGN_PICK_HELP") % MAX_PLAYERS, 24, Color(0.75, 0.75, 0.75))
	var row = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	box.add_child(row)
	for element in [1, 2, 3, 4, 5]:
		var button = _button(row, _element_text(element), _toggle_element.bind(element), 30)
		button.custom_minimum_size = Vector2(170, 70)
		var color = Color(Global.playerColors[element])
		if element in picked:
			button.modulate = color.lightened(0.3)
			button.text = "%d. %s" % [picked.find(element) + 1, _element_text(element)]
		else:
			button.modulate = Color(1, 1, 1, 0.75)
	var seats = Label.new()
	seats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	seats.add_theme_font_size_override("font_size", 24)
	var lines = []
	for i in picked.size():
		lines.append(tr("CAMPAIGN_SEAT_LINE") % [i + 1, _element_text(picked[i]), _keys_text(picked[i])])
	seats.text = "\n".join(lines) if not lines.is_empty() else tr("CAMPAIGN_PICK_NONE")
	box.add_child(seats)
	var start = _button(box, tr("CAMPAIGN_START"), _create_run)
	start.disabled = picked.is_empty()
	_button(box, tr("UI_BACK"), show_slots)
	_focus_first(row)

# The keys a player steers with: their element's (Player{N}Left/Right/Up)
func _keys_text(element) -> String:
	var parts = []
	for action in ["Left", "Right", "Up"]:
		var events = InputMap.action_get_events("Player%d%s" % [element, action])
		parts.append(Global.input_event_name(events[0]) if not events.is_empty() else "?")
	return " / ".join(parts)

func _toggle_element(element):
	if element in picked:
		picked.erase(element)
	elif picked.size() < MAX_PLAYERS:
		picked.append(element)
	_show_new_run()
	# Keep the focus on the element's button
	for button in view.find_children("*", "Button", true, false):
		if button.text.ends_with(_element_text(element)):
			button.grab_focus.call_deferred()

func _create_run():
	Campaign.new_run(new_slot, picked)
	show_map()

# --- After a scenario ---

func _after_scenario():
	var data = Campaign.data
	if data.get("complete", false):
		_show_end(true)
	elif int(data.get("lives", 0)) <= 0:
		_show_end(false)
	elif data.get("pending_upgrades", false):
		_show_upgrades()
	else:
		if Campaign.last_result == "lost":
			message = tr("CAMPAIGN_LIFE_LOST") % int(data.lives)
		show_map()

func _show_end(won: bool):
	var slot = Campaign.slot
	var box = _new_view()
	_label(box, tr("CAMPAIGN_VICTORY") if won else tr("CAMPAIGN_GAME_OVER"), 72, Color(1, 0.8, 0.3) if won else Color(1, 0.4, 0.35))
	_label(box, tr("CAMPAIGN_VICTORY_TEXT") if won else tr("CAMPAIGN_GAME_OVER_TEXT"), 28)
	if slot >= 0:
		Campaign.delete_slot(slot)
	if Campaign.online:
		# Back to the lobby (the host takes everyone)
		if _waiting():
			_label(box, tr("CAMPAIGN_WAIT_HOST"), 24, Color(0.7, 0.7, 0.7))
		else:
			_button(box, tr("CAMPAIGN_TO_LOBBY"), _to_menu)
		_focus_first(box)
		return
	Campaign.data = {}
	Campaign.slot = -1
	_button(box, tr("CAMPAIGN_TO_SLOTS"), show_slots)
	_focus_first(box)

# Every player picks one of three upgrades of their element (the between-rounds screen);
# after a hard scenario or a special one the cards come out rarer
func _show_upgrades():
	if is_instance_valid(view):
		view.queue_free()
	Global.reset_all_player_stats()
	var seats = Campaign.data.seats
	var options = {}
	var better = Campaign.scenario.get("kind", "normal") in ["hard", "special"]
	for i in seats.size():
		var element = int(seats[i].element)
		for upgrade_id in seats[i].upgrades:
			var buff = UpgradeCatalog.make_buff(StringName(upgrade_id))
			if buff != null:
				Global.player_stats[element].add_buff(buff)
		options[element] = _roll(element, better)
	if not Campaign.online:
		_open_upgrade_screen(options)
		return
	# Online the host rolls the cards for everyone
	if multiplayer.is_server():
		Campaign.share_upgrade_options(options)
	if not Campaign.upgrade_options.is_empty():
		_open_upgrade_screen(Campaign.upgrade_options)
	else:
		var box = _new_view()
		_label(box, tr("CAMPAIGN_WAIT_HOST"), 30)
		Campaign.net_upgrade_options.connect(_open_upgrade_screen, CONNECT_ONE_SHOT)

# options: element -> [upgrade ids] (online, the host's)
func _open_upgrade_screen(options):
	if is_instance_valid(view):
		view.queue_free()
	var preset = {}
	for element in options:
		var local = not Campaign.online or SteamNet.is_local_slot(element)
		var keys = SteamNet.roster.get(element, {}).get("keys", element) if Campaign.online else element
		preset[element] = {"options": options[element], "ai": false, "input_id": keys if local else 0, "remote": not local}
	var layer = CanvasLayer.new()
	add_child(layer)
	upgrade_layer = layer
	var screen = UPGRADE_SCREEN.instantiate()
	layer.add_child(screen)
	screen.upgrade_selected.connect(func(element, upgrade_id):
		var index = Campaign.seat_elements().find(element)
		if index >= 0:
			Campaign.add_upgrade(index, upgrade_id)
		if Campaign.online and SteamNet.is_local_slot(element):
			Campaign.share_upgrade_pick(element, upgrade_id))
	screen.finished.connect(func():
		Campaign.upgrades_done()
		layer.queue_free()
		show_map())
	screen.start([], 0.0, preset)
	if Campaign.online:
		var on_pick = func(element, upgrade_id):
			if is_instance_valid(screen):
				screen.remote_pick(element, upgrade_id)
		Campaign.net_upgrade_picked.connect(on_pick)
		screen.tree_exiting.connect(func(): Campaign.net_upgrade_picked.disconnect(on_pick))
		# Picks made before this screen was up
		for element in Campaign.upgrade_picks:
			screen.remote_pick(element, Campaign.upgrade_picks[element])

func _roll(element, better) -> Array:
	var options = UpgradeCatalog.roll_options(element, 3)
	if better:
		# Two rolls, the rarest three of them
		var more = UpgradeCatalog.roll_options(element, 3)
		for option in more:
			if not options.any(func(o): return o.id == option.id):
				options.append(option)
		options.sort_custom(func(a, b): return UpgradeCatalog.rarity_of(a).weight < UpgradeCatalog.rarity_of(b).weight)
		options = options.slice(0, 3)
	return options.map(func(o): return str(o.id))

# --- The act's map ---

func show_map():
	var data = Campaign.data
	var box = _new_view(_to_menu)
	_label(box, tr("CAMPAIGN_ACT_TITLE"), 48, Color(1, 0.75, 0.3))
	var main = HBoxContainer.new()
	main.add_theme_constant_override("separation", 40)
	box.add_child(main)
	# The steps, climbing from the first one (bottom) to the boss (top)
	var steps = VBoxContainer.new()
	steps.add_theme_constant_override("separation", 8)
	main.add_child(steps)
	var first_choice: Button
	for step in range(data.map.size() - 1, -1, -1):
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		steps.add_child(row)
		var number = Label.new()
		number.text = str(step + 1)
		number.custom_minimum_size.x = 44
		number.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		number.add_theme_font_size_override("font_size", 24)
		number.add_theme_color_override("font_color", Color(1, 0.75, 0.3) if step == int(data.step) else Color(0.6, 0.6, 0.6))
		row.add_child(number)
		var options = data.map[step]
		for choice in options.size():
			var scenario = options[choice]
			var button = Button.new()
			button.custom_minimum_size = Vector2(260 * 2 + 10 if options.size() == 1 else 260, 66)
			button.add_theme_font_size_override("font_size", 20)
			button.text = tr("CAMPAIGN_SC_" + str(scenario.id).to_upper()) + _kind_mark(scenario)
			button.focus_mode = Control.FOCUS_ALL
			button.modulate = _kind_color(scenario)
			if step < int(data.step):
				var taken = step < data.path.size() and data.path[step] == choice
				button.disabled = true
				button.modulate = Color(0.6, 1, 0.6) if taken else Color(1, 1, 1, 0.25)
			elif step > int(data.step):
				button.disabled = true
				button.modulate.a = 0.5
			else:
				button.pressed.connect(Campaign.begin_scenario.bind(choice))
				# Online only the host picks (the others see where it goes)
				button.disabled = _waiting()
				if first_choice == null and not button.disabled:
					first_choice = button
			if button.disabled:
				# Out of the keys' way (the mouse still shows what it is)
				button.focus_mode = Control.FOCUS_NONE
			button.focus_entered.connect(_show_details.bind(scenario))
			button.mouse_entered.connect(_show_details.bind(scenario))
			row.add_child(button)
	# Beside it: lives, the players and their upgrades, the scenario under the cursor
	var side = VBoxContainer.new()
	side.custom_minimum_size.x = 720
	side.add_theme_constant_override("separation", 14)
	main.add_child(side)
	var info = [tr("CAMPAIGN_HUD_LIVES") % int(data.lives), tr("CAMPAIGN_STEP") % [int(data.step) + 1, data.map.size()]]
	_label(side, "  ·  ".join(info), 28)
	for seat in data.seats:
		var names = seat.upgrades.map(func(id): return tr(UpgradeCatalog.get_upgrade(StringName(id)).get("name", id)))
		var line = "%s: %s" % [_element_text(seat.element), ", ".join(names) if not names.is_empty() else tr("CAMPAIGN_NO_UPGRADES")]
		var label = _label(side, line, 22, Color(Global.playerColors[int(seat.element)]).lightened(0.35))
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size.x = 720
	if message != "":
		_label(side, message, 26, Color(1, 0.5, 0.4)).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		message = ""
	details = _label(side, "", 24, Color(0.9, 0.9, 0.9))
	details.custom_minimum_size = Vector2(720, 220)
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if _waiting():
		_label(side, tr("CAMPAIGN_WAIT_HOST"), 24, Color(0.7, 0.7, 0.7))
	var quit_text = "CAMPAIGN_SAVE_QUIT" if Campaign.is_authority() else "CAMPAIGN_LEAVE"
	if Campaign.online and multiplayer.is_server():
		quit_text = "CAMPAIGN_TO_LOBBY"
	var quit = _button(side, tr(quit_text), _to_menu)
	_keys_hint(side)
	_show_details(data.map[int(data.step)][0])
	if first_choice:
		first_choice.grab_focus.call_deferred()
	else:
		quit.grab_focus.call_deferred()

func _kind_mark(scenario) -> String:
	match scenario.get("kind", "normal"):
		"hard":
			return "\n" + tr("CAMPAIGN_KIND_HARD")
		"special":
			return "\n" + tr("CAMPAIGN_KIND_SPECIAL")
		"boss":
			return "\n" + tr("CAMPAIGN_KIND_BOSS")
	return ""

func _kind_color(scenario) -> Color:
	match scenario.get("kind", "normal"):
		"hard":
			return Color(1, 0.6, 0.5)
		"special":
			return Color(0.75, 0.65, 1)
		"boss":
			return Color(0.6, 1, 0.7)
	return Color.WHITE

# What a scenario is about, under the map
func _show_details(scenario):
	if details == null:
		return
	var lines = [tr("CAMPAIGN_SC_" + str(scenario.id).to_upper()) + ": " + _goal(scenario)]
	var extras = []
	if int(scenario.get("enemies", 0)) > 0:
		extras.append(tr("CAMPAIGN_DETAIL_RIVALS") % [int(scenario.enemies), int(scenario.get("enemy_upgrades", 0))])
	if scenario.get("level", "") != "":
		extras.append(tr("CAMPAIGN_DETAIL_ARENA") % Global.level_name(scenario.level))
	if scenario.get("objective", "") == "shrooms":
		extras.append(tr("CAMPAIGN_DETAIL_SHROOMS"))
	if scenario.get("power_shrooms", false):
		extras.append(tr("CAMPAIGN_DETAIL_POWER_SHROOMS"))
	if scenario.get("swap", false):
		extras.append(tr("CAMPAIGN_DETAIL_SWAP"))
	if scenario.get("kind", "") == "hard":
		extras.append(tr("CAMPAIGN_DETAIL_HARD"))
	if not extras.is_empty():
		lines.append(" · ".join(extras))
	details.text = "\n".join(lines)

func _goal(scenario) -> String:
	match scenario.objective:
		"rounds":
			return tr("CAMPAIGN_GOAL_ROUNDS") % [scenario.need, scenario.rounds]
		"survive":
			return tr("CAMPAIGN_GOAL_SURVIVE") % [scenario.target, scenario.need, scenario.rounds]
		"shrooms":
			return tr("CAMPAIGN_GOAL_SHROOMS") % [scenario.target, scenario.rounds]
		"kills":
			return tr("CAMPAIGN_GOAL_KILLS") % [scenario.target, scenario.rounds]
		"boss":
			return tr("CAMPAIGN_GOAL_BOSS")
	return ""
