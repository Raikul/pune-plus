extends Node

# Autoload "Campaign": the roguelike campaign (Play > Roguelike). Its state lives in a save
# (one of SLOTS JSON files in user://), written after every step:
#   seats       the players, in order: {"element": id, "upgrades": [upgrade ids]}. Fixed for
#               the whole save (how many players and which elements).
#   map         the act (CampaignMap.generate): steps of scenarios to pick from, then the boss
#   step        the step being played (0..), path: the scenario picked at each step
#   lives       the team's lives; losing a scenario costs one and it's played again
#   pending_upgrades  a scenario was won and the upgrade picks haven't been made yet
# While a scenario is played (`playing`), Global's match rules come from here (teams: the
# players against the AI, no upgrades between rounds, the scenario's arena and shrooms) and
# the Playground adds CampaignRules (objective, rounds, boss).
#
# Online (a campaign lobby, `online`): the host runs the campaign and keeps the save; the
# other machines get a copy of it (net_open) and follow the host: the scenario it starts
# (net_begin, with the roster: the players' slots plus the AI rivals, all run by the host),
# its end, the upgrade picks (each machine picks for its own players). The seats are the
# lobby's players; a saved campaign needs the same elements in the lobby to continue.

const SLOTS = 3
## Where the saves go (%d: the slot)
var save_path = "user://campaign_%d.json"
const START_LIVES = 3
const VERSION = 1
const SCREEN = "res://scenes/campaign/campaign.tscn"

## A scenario is being played (the Playground follows the campaign's rules)
var playing = false
var slot = -1
var data = {}
## The scenario being played, from the map
var scenario = {}
## Element in play -> seat index, for the players (the rest are AI rivals)
var humans = {}
## The rivals' elements this scenario
var enemies = []
## How the last scenario went ("won", "lost"; "" none): the campaign screen shows it
var last_result = ""
## The match settings a scenario changes, put back afterwards (restore_match_globals)
var saved_globals = {}
## Random upgrades for this scenario (swapped players, rivals): element -> [ids]. Rolled
## once by whoever starts the scenario, so every machine plays with the same ones.
var scenario_upgrades = {}
## An online campaign (see the top), and the lobby's roster (players only)
var online = false
var lobby_roster = {}

# --- Saves ---

func slot_path(index) -> String:
	return save_path % index

func has_save(index) -> bool:
	return FileAccess.file_exists(slot_path(index))

# The save in a slot ({} if empty or unreadable), with its numbers as ints again (JSON
# reads every number back as a float)
func read_slot(index) -> Dictionary:
	if not has_save(index):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(slot_path(index)))
	if not parsed is Dictionary or int(parsed.get("version", 0)) != VERSION:
		return {}
	return _fix_numbers(parsed)

func _fix_numbers(value):
	if value is Dictionary:
		for key in value:
			value[key] = _fix_numbers(value[key])
	elif value is Array:
		for i in value.size():
			value[i] = _fix_numbers(value[i])
	elif value is float and is_equal_approx(value, roundf(value)):
		return int(value)
	return value

func delete_slot(index) -> void:
	if has_save(index):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(slot_path(index)))

func save() -> void:
	if slot < 0 or data.is_empty():
		return
	var file = FileAccess.open(slot_path(slot), FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))

# A new campaign in this slot. elements: the players' elements, in seat order.
func new_run(index, elements: Array) -> void:
	slot = index
	var rng_seed = randi()
	data = {
		"version": VERSION,
		"seats": elements.map(func(e): return {"element": int(e), "upgrades": []}),
		"lives": START_LIVES,
		"step": 0,
		"path": [],
		"seed": rng_seed,
		"map": CampaignMap.generate(rng_seed, elements.size()),
		"pending_upgrades": false,
		"complete": false,
	}
	last_result = ""
	save()

func load_run(index) -> bool:
	var loaded = read_slot(index)
	if loaded.is_empty():
		return false
	slot = index
	data = loaded
	last_result = ""
	return true

func seat_elements() -> Array:
	return data.get("seats", []).map(func(seat): return int(seat.element))

# --- Playing a scenario ---

# Starts the scenario picked at the current step (choice: its index in the step)
func begin_scenario(choice: int) -> void:
	var options = data.map[data.step]
	choice = clampi(choice, 0, options.size() - 1)
	_pick(choice)
	_cast_elements()
	_roll_scenario_upgrades()
	print("[Campaign] step %d: %s (%s), players %s, rivals %s, upgrades %s / %s" % [int(data.step) + 1, scenario.get("id", "?"), scenario.get("objective", "?"), humans.keys(), enemies, data.seats.map(func(seat): return seat.upgrades), scenario_upgrades])
	if online:
		if multiplayer.is_server():
			net_begin.rpc(choice, humans, enemies, scenario_upgrades, _match_roster())
		return
	_apply_match_globals()
	playing = true
	last_result = ""
	get_tree().change_scene_to_file("res://scenes/Playground.tscn")

func _pick(choice: int) -> void:
	scenario = data.map[data.step][choice]
	if data.path.size() <= data.step:
		data.path.append(choice)
	else:
		data.path[data.step] = choice
	save()

func _roll_scenario_upgrades() -> void:
	scenario_upgrades = {}
	Global.reset_all_player_stats()
	for element in enemies:
		_roll_into(element, int(scenario.get("enemy_upgrades", 0)))
	if is_swapped():
		for element in humans:
			_roll_into(element, 1 + int(scenario.get("step", 0) / 2))

func _roll_into(element, count) -> void:
	var ids = []
	for i in count:
		var options = UpgradeCatalog.roll_options(element, 1)
		if options.is_empty() or str(options[0].id) == "skip":
			break
		var buff = UpgradeCatalog.make_buff(options[0].id)
		if buff == null:
			break
		Global.player_stats[element].add_buff(buff)
		ids.append(str(options[0].id))
	scenario_upgrades[element] = ids

# Who plays what: the players their own element (or, in a swap scenario, another one),
# the rivals some of the elements left
func _cast_elements() -> void:
	humans = {}
	var taken = []
	var seats = data.seats
	for i in seats.size():
		var element = int(seats[i].element)
		if scenario.get("swap", false):
			var others = [1, 2, 3, 4, 5].filter(func(e): return e != element and not e in taken and not e in seat_elements())
			if others.is_empty():
				others = [1, 2, 3, 4, 5].filter(func(e): return e != element and not e in taken)
			element = others.pick_random()
		humans[element] = i
		taken.append(element)
	# Rivals: the classic four first (Void only if they run out), at most MAX_SNAKES in all
	var left = [1, 2, 3, 4].filter(func(e): return not e in taken)
	left.shuffle()
	if not 5 in taken:
		left.append(5)
	var count = mini(int(scenario.get("enemies", 1)), Global.MAX_SNAKES - taken.size())
	enemies = left.slice(0, max(count, 0))

func is_human(element) -> bool:
	return humans.has(element)

func human_elements() -> Array:
	return humans.keys()

# The keys that steer this snake: its player's own element keys (they stay the same in a
# swap scenario); 0 for the AI
func input_for(element) -> int:
	if not humans.has(element):
		return 0
	return int(data.seats[humans[element]].element)

# The upgrades this snake keeps from the campaign (none for a swapped element: it gets
# random ones instead, CampaignRules)
func upgrades_for(element) -> Array:
	if not humans.has(element) or scenario.get("swap", false):
		return scenario_upgrades.get(element, [])
	return data.seats[humans[element]].upgrades

func is_swapped() -> bool:
	return scenario.get("swap", false)

# Match settings for the scenario. Only the per-match values (who plays, who's AI); the
# saved settings (teams, shrooms, levels...) are answered by Global from here instead.
func _apply_match_globals() -> void:
	if saved_globals.is_empty():
		for id in [1, 2, 3, 4, 5]:
			saved_globals["player%dActive" % id] = Global.get("player%dActive" % id)
		saved_globals["AI_Enabled"] = Global.AI_Enabled.duplicate()
	var in_play = human_elements() + enemies
	for id in [1, 2, 3, 4, 5]:
		Global.set("player%dActive" % id, id in in_play)
		Global.AI_Enabled[id] = id in enemies
	Global.reset_score()

# Back to the menu: the hotseat setup finds its players as they were
func restore_match_globals() -> void:
	playing = false
	if saved_globals.is_empty():
		return
	for id in [1, 2, 3, 4, 5]:
		Global.set("player%dActive" % id, saved_globals["player%dActive" % id])
	Global.AI_Enabled = saved_globals["AI_Enabled"]
	saved_globals = {}

# Global's rules while playing
func teams() -> bool:
	return not enemies.is_empty()

func team_of(element) -> int:
	return 0 if humans.has(element) else 1

func level_path() -> String:
	return scenario.get("level", "")

# Score shrooms only where they count: the scenarios won by eating them (older saves
# have them on other scenarios too)
func shrooms() -> bool:
	return scenario.get("objective", "") == "shrooms"

# The scenario is over (CampaignRules): to the campaign screen, which shows how it went
func finish_scenario(won: bool) -> void:
	playing = false
	if online:
		# Back to the lobby's players (the rivals were only for the scenario)
		SteamNet.roster = lobby_roster.duplicate(true)
		SteamNet.ready_peers.clear()
	last_result = "won" if won else "lost"
	if won:
		if scenario.get("kind", "") == "boss":
			data.complete = true
		else:
			data.step += 1
			data.pending_upgrades = true
	else:
		data.lives -= 1
	save()
	get_tree().change_scene_to_file(SCREEN)

# Upgrade picks made after a won scenario (seat index -> upgrade id)
func add_upgrade(seat_index: int, upgrade_id) -> void:
	if str(upgrade_id) == "skip":
		return
	data.seats[seat_index].upgrades.append(str(upgrade_id))

func upgrades_done() -> void:
	data.pending_upgrades = false
	upgrade_options = {}
	upgrade_picks = {}
	save()
	push_data()

func is_over() -> bool:
	return data.get("lives", 0) <= 0 or data.get("complete", false)

# --- Online ---

# Machines that decide: offline this one, online the host
func is_authority() -> bool:
	return not online or multiplayer.is_server()

# The lobby's players (no AI: the rivals come with each scenario), by element
func lobby_players() -> Array:
	var slots = SteamNet.roster.keys().filter(func(s): return not SteamNet.roster[s].ai)
	slots.sort()
	return slots

# Host, in the lobby: why this slot can't start an online campaign ("" if it can)
func online_problem(index) -> String:
	if SteamNet.roster.values().any(func(entry): return entry.ai):
		return "CAMPAIGN_ONLINE_NO_AI"
	var players = lobby_players()
	if players.is_empty() or players.size() > 3:
		return "CAMPAIGN_ONLINE_PLAYERS"
	var save = read_slot(index)
	if not save.is_empty():
		var needed = save.seats.map(func(seat): return int(seat.element))
		needed.sort()
		if needed != players:
			return "CAMPAIGN_ONLINE_SEATS"
	return ""

# Host: the online campaign of this slot (a new one with the lobby's players if empty)
func host_online(index) -> void:
	if online_problem(index) != "":
		return
	if has_save(index):
		load_run(index)
	else:
		new_run(index, lobby_players())
	if SteamNet.steam_ready and SteamNet.lobby_id != 0:
		SteamNet.steam.setLobbyJoinable(SteamNet.lobby_id, false)
	net_open.rpc(data, SteamNet.roster)

# Everyone: to the campaign screen with the host's campaign
@rpc("authority", "call_local", "reliable")
func net_open(new_data, roster_copy):
	if not multiplayer.is_server():
		data = _fix_numbers(new_data)
		slot = -1
	online = true
	lobby_roster = roster_copy.duplicate(true)
	last_result = ""
	playing = false
	Global.isMultiplayerActive = true
	get_tree().paused = false
	get_tree().change_scene_to_file(SCREEN)

# Host: a fresh copy of the campaign for everyone
func push_data() -> void:
	if online and multiplayer.is_server():
		net_data.rpc(data)

@rpc("authority", "call_remote", "reliable")
func net_data(new_data):
	data = _fix_numbers(new_data)

# The scenario's roster: each player's lobby entry on the element they play, and the AI
# rivals (run by the host)
func _match_roster() -> Dictionary:
	var roster = {}
	for element in humans:
		var own = int(data.seats[humans[element]].element)
		roster[element] = lobby_roster.get(own, {"peer": 1, "name": "?", "ai": false, "keys": 0}).duplicate()
	for element in enemies:
		roster[element] = {"peer": 1, "name": Global.random_ai_name(element), "ai": true, "keys": 0}
	return roster

# Everyone: play the scenario the host started
@rpc("authority", "call_local", "reliable")
func net_begin(choice, new_humans, new_enemies, upgrades, roster):
	if not multiplayer.is_server():
		_pick(choice)
		humans = new_humans
		enemies = new_enemies
		scenario_upgrades = upgrades
	SteamNet.roster = roster
	SteamNet.ready_peers.clear()
	if SteamNet.offline_ai == null:
		SteamNet.offline_ai = Global.AI_Enabled.duplicate()
	for id in [1, 2, 3, 4, 5]:
		Global.set("player%dActive" % id, roster.has(id))
		Global.AI_Enabled[id] = roster.has(id) and roster[id].ai
	Global.reset_score()
	Global.isMultiplayerActive = true
	playing = true
	last_result = ""
	get_tree().change_scene_to_file("res://scenes/Playground.tscn")

# Upgrade picks: each machine picks for its own players and tells the others
signal net_upgrade_options(preset)
signal net_upgrade_picked(element, upgrade_id)

## The host's upgrade options and the other machines' picks, kept until the campaign
## screen shows them (they can arrive before it's ready)
var upgrade_options = {}
var upgrade_picks = {}

func share_upgrade_options(options) -> void:
	net_upgrades.rpc(options)

@rpc("authority", "call_local", "reliable")
func net_upgrades(options):
	upgrade_options = options
	net_upgrade_options.emit(options)

func share_upgrade_pick(element, upgrade_id) -> void:
	net_pick.rpc(element, str(upgrade_id))

@rpc("any_peer", "call_remote", "reliable")
func net_pick(element, upgrade_id):
	if SteamNet.peer_for_slot(element) != multiplayer.get_remote_sender_id():
		return
	upgrade_picks[element] = upgrade_id
	net_upgrade_picked.emit(element, upgrade_id)

# The host leaves the campaign (saved): everyone back to the lobby
func host_to_lobby() -> void:
	if online and multiplayer.is_server():
		net_to_lobby.rpc()

@rpc("authority", "call_local", "reliable")
func net_to_lobby():
	SteamNet.roster = lobby_roster.duplicate(true)
	end_online()
	SteamNet.return_to_lobby()

# Out of the online campaign (back in the lobby, or the session ended)
func end_online() -> void:
	online = false
	playing = false
	lobby_roster = {}
	if not multiplayer.is_server():
		data = {}
