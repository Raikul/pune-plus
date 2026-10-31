extends Node

# Autoload "SteamNet": Steam lobbies, the multiplayer peer and the roster of who
# plays which element. GodotSteam is only reached through Engine.get_singleton /
# ClassDB, so the project still runs in a plain Godot editor without Steam.
# See docs/multiplayer.md.

signal status_changed(text)
signal roster_changed
signal lobby_list_received(lobbies)
signal all_peers_ready
signal peer_left(peer_id, slots)
signal session_ended(reason)
## The host changed the match options (upgrades, teams, points to win)
signal match_options_changed

const APP_ID = 480 # Spacewar test app until Pune has its own Steam app id
const MAX_PLAYERS = 4
const LOBBY_GAME_KEY = "game"
const LOBBY_GAME_VALUE = "pune_plus"
const LAN_PORT = 7531
const LOBBY_TYPE_PUBLIC = 2
# Invisible lobbies don't show in friends lists but searches still find them: private
# lobbies use it so they can be joined by code (the public list filters them out)
const LOBBY_TYPE_INVISIBLE = 3
const LOBBY_CODE_KEY = "code"
const LOBBY_PRIVATE_KEY = "private"
const LOBBY_CODE_LENGTH = 6
const LOBBY_CODE_CHARS = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789" # No 0/O or 1/I
const LOBBY_COMPARISON_EQUAL = 0
const LOBBY_DISTANCE_WORLDWIDE = 3
const STEAM_RESULT_OK = 1
const CHAT_ROOM_ENTER_SUCCESS = 1
const CLOCK_SYNC_INTERVAL = 1.0
const CLOCK_SAMPLES = 8

var steam = null
var steam_ready = false
var steam_status = "Steam not available"
var persona_name = "Player"
var lobby_id = 0
# The lobby's join code ("" when not in a Steam lobby)
var lobby_code = ""
# Private lobbies aren't listed; hosting uses this, and the host can change it later
var lobby_private = false
# Code being searched for by join_by_code ("" for a normal lobby list)
var searching_code = ""
var is_lan = false
# slot (element 1-4) -> {"peer": peer id that runs the snake, "name": String,
# "ai": bool, "keys": which Player{N} input actions steer it on its machine (0 = AI)}.
# The host owns it and keeps it the same on every peer. A machine can run several
# snakes: extra local players on the same keyboard, or AI snakes.
var roster = {}
var ready_peers = {}
## Debug: extra delay applied to every received game packet (seconds).
var fake_latency = 0.0
# Shared clock: the host's time. Clients learn their offset NTP-style.
var clock_offset = 0.0
var clock_samples = [] # [round_trip, offset], the lowest round trip is the most accurate
var clock_timer = 0.0
# The host's match options (Global.match_options()), shown in every lobby
var match_options = {}
# Offline AI toggles, put back after an online match changed them
var offline_ai = null

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	_init_steam()
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(func(): _end_session("Could not connect"))
	multiplayer.server_disconnected.connect(func(): _end_session("The host left"))
	_check_launch_invite()

func _process(delta):
	if not is_online() or multiplayer.is_server():
		return
	if multiplayer.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return
	clock_timer -= delta
	if clock_timer <= 0:
		# Quick burst right after connecting, so the clock is accurate before the match starts
		clock_timer = CLOCK_SYNC_INTERVAL if clock_samples.size() >= CLOCK_SAMPLES else 0.1
		clock_ping.rpc_id(1, _local_time())

# Time all peers agree on (the host's clock), in seconds
func net_time():
	return _local_time() + clock_offset

func _local_time():
	return Time.get_ticks_usec() / 1000000.0

@rpc("any_peer", "call_remote", "unreliable")
func clock_ping(client_time):
	var sender = multiplayer.get_remote_sender_id()
	await fake_delay()
	if is_online():
		clock_pong.rpc_id(sender, client_time, _local_time())

@rpc("authority", "call_remote", "unreliable")
func clock_pong(client_time, host_time):
	await fake_delay()
	if not is_online():
		return
	var round_trip = _local_time() - client_time
	clock_samples.append([round_trip, host_time + round_trip / 2.0 - _local_time()])
	if clock_samples.size() > CLOCK_SAMPLES:
		clock_samples.pop_front()
	var best = clock_samples[0]
	for sample in clock_samples:
		if sample[0] < best[0]:
			best = sample
	clock_offset = best[1]

# Debug: simulate network delay on a received message (fake_latency)
func fake_delay():
	if fake_latency > 0:
		await get_tree().create_timer(fake_latency).timeout

func _init_steam():
	if not Engine.has_singleton("Steam") or not ClassDB.class_exists("SteamMultiplayerPeer"):
		steam_status = "This build has no Steam support (use the GodotSteam editor)"
		return
	steam = Engine.get_singleton("Steam")
	var result = steam.steamInitEx(APP_ID, true)
	if result.status != 0:
		steam_status = "Steam failed to start: " + str(result.verbal)
		return
	steam_ready = true
	persona_name = steam.getPersonaName()
	steam_status = "Steam ready - " + persona_name
	steam.lobby_created.connect(_on_lobby_created)
	steam.lobby_joined.connect(_on_lobby_joined)
	steam.lobby_match_list.connect(_on_lobby_match_list)
	steam.join_requested.connect(func(lobby, _friend): join_lobby(lobby))

# A friend's invite can also start the game with "+connect_lobby <id>"
func _check_launch_invite():
	var args = OS.get_cmdline_args()
	var index = args.find("+connect_lobby")
	if steam_ready and index != -1 and index + 1 < args.size():
		join_lobby.call_deferred(int(args[index + 1]))

func is_online():
	return multiplayer.has_multiplayer_peer() and not multiplayer.multiplayer_peer is OfflineMultiplayerPeer

func is_host():
	return is_online() and multiplayer.is_server()

func peer_for_slot(slot):
	return roster.get(slot, {}).get("peer", 0)

func is_local_slot(slot):
	return peer_for_slot(slot) == multiplayer.get_unique_id()

func local_slots():
	return roster.keys().filter(is_local_slot)

func slots_of_peer(peer_id):
	return roster.keys().filter(func(slot): return roster[slot].peer == peer_id)

# Every machine taking part in the match
func roster_peers():
	var peers = []
	for entry in roster.values():
		if not peers.has(entry.peer):
			peers.append(entry.peer)
	return peers

#region Hosting and joining

func host_lobby():
	if not steam_ready:
		_set_status(steam_status)
		return
	var make_private = lobby_private
	leave()
	lobby_private = make_private
	_set_status("Creating lobby...")
	steam.createLobby(_lobby_type(), MAX_PLAYERS)

func _lobby_type():
	return LOBBY_TYPE_INVISIBLE if lobby_private else LOBBY_TYPE_PUBLIC

# Before hosting it picks the type of the next lobby; the host can also change it live
func set_lobby_private(make_private):
	lobby_private = make_private
	if steam_ready and lobby_id != 0 and is_host():
		steam.setLobbyType(lobby_id, _lobby_type())
		steam.setLobbyData(lobby_id, LOBBY_PRIVATE_KEY, "1" if lobby_private else "0")
	roster_changed.emit()

func _new_lobby_code():
	var code = ""
	for i in LOBBY_CODE_LENGTH:
		code += LOBBY_CODE_CHARS[randi() % LOBBY_CODE_CHARS.length()]
	return code

func join_by_code(code):
	code = code.strip_edges().to_upper()
	if code.length() != LOBBY_CODE_LENGTH:
		_set_status("Lobby codes have %d letters and numbers" % LOBBY_CODE_LENGTH)
		return
	if not steam_ready:
		_set_status(steam_status)
		return
	searching_code = code
	_set_status("Looking for lobby " + code + "...")
	steam.addRequestLobbyListStringFilter(LOBBY_GAME_KEY, LOBBY_GAME_VALUE, LOBBY_COMPARISON_EQUAL)
	steam.addRequestLobbyListStringFilter(LOBBY_CODE_KEY, code, LOBBY_COMPARISON_EQUAL)
	steam.addRequestLobbyListDistanceFilter(LOBBY_DISTANCE_WORLDWIDE)
	steam.requestLobbyList()

func _on_lobby_created(result, new_lobby_id):
	if result != STEAM_RESULT_OK:
		_set_status("Could not create lobby (" + str(result) + ")")
		return
	lobby_id = new_lobby_id
	steam.setLobbyData(lobby_id, LOBBY_GAME_KEY, LOBBY_GAME_VALUE)
	steam.setLobbyData(lobby_id, "name", persona_name + "'s Pune")
	lobby_code = _new_lobby_code()
	steam.setLobbyData(lobby_id, LOBBY_CODE_KEY, lobby_code)
	steam.setLobbyData(lobby_id, LOBBY_PRIVATE_KEY, "1" if lobby_private else "0")
	var peer = _new_steam_peer()
	var error = peer.host_with_lobby(lobby_id)
	if error != OK:
		_set_status("Could not host (" + str(error) + ")")
		return
	multiplayer.multiplayer_peer = peer
	_start_roster()
	_set_status("Lobby ready - invite your friends")

func join_lobby(id):
	if not steam_ready:
		_set_status(steam_status)
		return
	leave()
	_set_status("Joining lobby...")
	steam.joinLobby(id)

func _on_lobby_joined(joined_lobby, _permissions, _locked, response):
	if response != CHAT_ROOM_ENTER_SUCCESS:
		_set_status("Could not join lobby (" + str(response) + ")")
		return
	lobby_id = joined_lobby
	lobby_code = steam.getLobbyData(lobby_id, LOBBY_CODE_KEY)
	lobby_private = steam.getLobbyData(lobby_id, LOBBY_PRIVATE_KEY) == "1"
	# The owner already hosts through _on_lobby_created
	if steam.getLobbyOwner(lobby_id) == steam.getSteamID():
		return
	var peer = _new_steam_peer()
	var error = peer.connect_to_lobby(lobby_id)
	if error != OK:
		_set_status("Could not connect to lobby (" + str(error) + ")")
		return
	multiplayer.multiplayer_peer = peer
	_set_status("Connecting to host...")

func _new_steam_peer():
	var peer = ClassDB.instantiate("SteamMultiplayerPeer")
	# Send every packet right away instead of batching: latency matters more than bandwidth
	peer.no_delay = true
	peer.no_nagle = true
	return peer

func find_lobbies():
	if not steam_ready:
		_set_status(steam_status)
		return
	searching_code = ""
	_set_status("Searching lobbies...")
	steam.addRequestLobbyListStringFilter(LOBBY_GAME_KEY, LOBBY_GAME_VALUE, LOBBY_COMPARISON_EQUAL)
	steam.addRequestLobbyListStringFilter(LOBBY_PRIVATE_KEY, "0", LOBBY_COMPARISON_EQUAL)
	steam.addRequestLobbyListDistanceFilter(LOBBY_DISTANCE_WORLDWIDE)
	steam.requestLobbyList()

func _on_lobby_match_list(lobbies):
	if searching_code != "":
		var code = searching_code
		searching_code = ""
		if lobbies.is_empty():
			_set_status("No lobby with code " + code)
		else:
			join_lobby(lobbies[0])
		return
	var found = []
	for id in lobbies:
		found.append({
			"id": id,
			"name": steam.getLobbyData(id, "name"),
			"members": steam.getNumLobbyMembers(id),
		})
	_set_status("Found " + str(found.size()) + " lobbies")
	lobby_list_received.emit(found)

func invite_friends():
	if steam_ready and lobby_id != 0:
		steam.activateGameOverlayInviteDialog(lobby_id)

# Debug transport: plain ENet on this machine, to test the netcode with two game windows
func host_lan():
	leave()
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(LAN_PORT, MAX_PLAYERS - 1)
	if error != OK:
		_set_status("LAN host failed (" + str(error) + ")")
		return
	multiplayer.multiplayer_peer = peer
	is_lan = true
	_start_roster()
	_set_status("LAN host on port " + str(LAN_PORT))

func join_lan(address = "127.0.0.1"):
	leave()
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_client(address, LAN_PORT)
	if error != OK:
		_set_status("LAN join failed (" + str(error) + ")")
		return
	multiplayer.multiplayer_peer = peer
	is_lan = true
	_set_status("Connecting to " + address + "...")

func leave():
	if is_online():
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	if steam_ready and lobby_id != 0:
		steam.leaveLobby(lobby_id)
	lobby_id = 0
	lobby_code = ""
	lobby_private = false
	is_lan = false
	clock_offset = 0.0
	clock_samples.clear()
	clock_timer = 0.0
	roster.clear()
	ready_peers.clear()
	Global.isMultiplayerActive = false
	if offline_ai != null:
		Global.AI_Enabled = offline_ai
		offline_ai = null
	roster_changed.emit()

func _end_session(reason):
	var was_playing = Global.isMultiplayerActive
	leave()
	_set_status(reason)
	session_ended.emit(reason)
	if was_playing:
		get_tree().paused = false
		get_tree().change_scene_to_file("res://scenes/net/online_lobby.tscn")

#endregion

#region Roster: who plays which element

func _start_roster():
	roster = {}
	_add_slot(1, _local_name(), false)
	roster_changed.emit()

func _local_name():
	return persona_name if steam_ready and not is_lan else "Player " + str(multiplayer.get_unique_id() % 1000)

func _on_connected_to_server():
	_set_status("Connected")
	introduce.rpc_id(1, _local_name())

func _on_peer_connected(_peer_id):
	pass # Peers announce themselves with introduce()

# Client -> host: my display name. The host gives the new peer the lowest free slot.
@rpc("any_peer", "call_remote", "reliable")
func introduce(player_name):
	if not multiplayer.is_server():
		return
	var peer_id = multiplayer.get_remote_sender_id()
	if _add_slot(peer_id, player_name, false) == 0:
		multiplayer.multiplayer_peer.disconnect_peer(peer_id) # Lobby full
		return
	_roster_updated()

# Host: give peer_id the requested element, or the lowest free one (slot 0).
# Returns the slot, or 0 when it's taken or the lobby is full.
func _add_slot(peer_id, player_name, ai, slot = 0):
	if slot == 0:
		slot = _lowest_free(roster.keys())
	if slot < 1 or slot > MAX_PLAYERS or roster.has(slot):
		return 0
	var keys = 0
	if not ai:
		# Each person on the same machine steers with their own Player{N} key set
		var used_keys = slots_of_peer(peer_id).map(func(s): return roster[s].keys)
		keys = _lowest_free(used_keys)
	roster[slot] = {"peer": peer_id, "name": player_name, "ai": ai, "keys": keys}
	return slot

func _lowest_free(used):
	for number in range(1, MAX_PLAYERS + 1):
		if not used.has(number):
			return number
	return 0

# Another snake run by this machine: a second person on this keyboard, or an AI.
# slot picks its element; 0 takes the lowest free one.
func add_local_player(ai = false, slot = 0):
	if not is_online():
		return
	if multiplayer.is_server():
		_host_add_extra(1, ai, slot)
	else:
		request_extra_slot.rpc_id(1, ai, slot)

@rpc("any_peer", "call_remote", "reliable")
func request_extra_slot(ai, slot):
	if multiplayer.is_server() and not Global.isMultiplayerActive:
		_host_add_extra(multiplayer.get_remote_sender_id(), ai, slot)

func _host_add_extra(peer_id, ai, slot = 0):
	var owner_slots = slots_of_peer(peer_id)
	if owner_slots.is_empty():
		return
	var owner_name = roster[owner_slots[0]].name
	var player_name = "AI (" + owner_name + ")" if ai else owner_name + " #" + str(owner_slots.size() + 1)
	if _add_slot(peer_id, player_name, ai, slot) != 0:
		_roster_updated()

# Move one of this machine's snakes to a free element
func move_slot(from_slot, to_slot):
	if not is_online():
		return
	if multiplayer.is_server():
		_host_move_slot(1, from_slot, to_slot)
	else:
		request_move_slot.rpc_id(1, from_slot, to_slot)

@rpc("any_peer", "call_remote", "reliable")
func request_move_slot(from_slot, to_slot):
	if multiplayer.is_server() and not Global.isMultiplayerActive:
		_host_move_slot(multiplayer.get_remote_sender_id(), from_slot, to_slot)

func _host_move_slot(peer_id, from_slot, to_slot):
	if peer_for_slot(from_slot) != peer_id or roster.has(to_slot) or to_slot < 1 or to_slot > MAX_PLAYERS:
		return
	roster[to_slot] = roster[from_slot]
	roster.erase(from_slot)
	_roster_updated()

# Owners can drop their extra snakes (never their own first one); the host can drop any AI
func remove_slot(slot):
	if not is_online():
		return
	if multiplayer.is_server():
		_host_remove_slot(1, slot)
	else:
		request_remove_slot.rpc_id(1, slot)

@rpc("any_peer", "call_remote", "reliable")
func request_remove_slot(slot):
	if multiplayer.is_server() and not Global.isMultiplayerActive:
		_host_remove_slot(multiplayer.get_remote_sender_id(), slot)

func can_remove_slot(slot, by_peer):
	if not roster.has(slot):
		return false
	var entry = roster[slot]
	if entry.ai:
		return by_peer == entry.peer or by_peer == 1
	return by_peer == entry.peer and slots_of_peer(by_peer).filter(func(s): return not roster[s].ai).size() > 1

func _host_remove_slot(peer_id, slot):
	if can_remove_slot(slot, peer_id):
		roster.erase(slot)
		_roster_updated()

func _roster_updated():
	sync_roster.rpc(roster)
	roster_changed.emit()
	push_match_options()

# Host: send the current match options to everyone in the lobby
func push_match_options():
	if not is_host():
		return
	match_options = Global.match_options()
	sync_match_options.rpc(match_options)
	match_options_changed.emit()

@rpc("authority", "call_remote", "reliable")
func sync_match_options(options):
	match_options = options
	match_options_changed.emit()

@rpc("authority", "call_remote", "reliable")
func sync_roster(new_roster):
	roster = new_roster
	roster_changed.emit()

func _on_peer_disconnected(peer_id):
	var slots = slots_of_peer(peer_id)
	if slots.is_empty():
		return
	for slot in slots:
		roster.erase(slot)
	ready_peers.erase(peer_id)
	if multiplayer.is_server():
		sync_roster.rpc(roster)
	roster_changed.emit()
	peer_left.emit(peer_id, slots)

#endregion

#region Match start

func start_match():
	if not is_host() or roster.size() < 2:
		return
	if steam_ready and lobby_id != 0:
		steam.setLobbyJoinable(lobby_id, false)
	# The host's own toggles decide the match options
	begin_match.rpc(roster, Global.match_options())

@rpc("authority", "call_local", "reliable")
func begin_match(final_roster, options = {}):
	roster = final_roster
	ready_peers.clear()
	if offline_ai == null:
		offline_ai = Global.AI_Enabled.duplicate()
	for slot in range(1, MAX_PLAYERS + 1):
		Global.set("player" + str(slot) + "Active", roster.has(slot))
		# Only matters on the machine that runs the snake; the others just mirror it
		Global.AI_Enabled[slot] = roster.has(slot) and roster[slot].ai
	Global.reset_score()
	Global.isMultiplayerActive = true
	# Shrooms aren't synced online yet (docs/multiplayer.md); the player's own saved
	# toggles stay untouched, Global.shrooms_enabled() / upgrades_enabled() handle online
	Global.online_upgrades = options.get("upgrades", false)
	Global.online_teams = options.get("teams", false)
	Global.online_player_team = options.get("player_team", {1: 0, 2: 1, 3: 0, 4: 1})
	Global.online_points_to_win = options.get("points_to_win", 0)
	get_tree().change_scene_to_file("res://scenes/Playground.tscn")

# Every peer calls this once its Playground is loaded. The host starts the first round when all are in.
func report_scene_ready():
	if multiplayer.is_server():
		_mark_ready(1)
	else:
		scene_ready.rpc_id(1)

@rpc("any_peer", "call_remote", "reliable")
func scene_ready():
	if multiplayer.is_server():
		_mark_ready(multiplayer.get_remote_sender_id())

func _mark_ready(peer_id):
	ready_peers[peer_id] = true
	if roster_peers().all(func(id): return ready_peers.has(id)):
		all_peers_ready.emit()

#endregion

func _set_status(text):
	print("[SteamNet] " + text)
	status_changed.emit(text)
