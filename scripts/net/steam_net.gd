extends Node

# Autoload "SteamNet": Steam lobbies, the multiplayer peer and the roster of who
# plays which element. GodotSteam is only reached through Engine.get_singleton /
# ClassDB, so the project still runs in a plain Godot editor without Steam.
# See docs/multiplayer.md.

signal status_changed(text)
signal roster_changed
signal lobby_list_received(lobbies)
signal all_peers_ready
signal peer_left(peer_id, slot)
signal session_ended(reason)

const APP_ID = 480 # Spacewar test app until Pune has its own Steam app id
const MAX_PLAYERS = 4
const LOBBY_GAME_KEY = "game"
const LOBBY_GAME_VALUE = "pune_plus"
const LAN_PORT = 7531
const LOBBY_TYPE_FRIENDS_ONLY = 1
const LOBBY_TYPE_PUBLIC = 2
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
var is_lan = false
# peer_id -> {"name": String, "slot": int}, kept the same on every peer by the host
var roster = {}
var ready_peers = {}
## Debug: extra delay applied to every received game packet (seconds).
var fake_latency = 0.0
# Shared clock: the host's time. Clients learn their offset NTP-style.
var clock_offset = 0.0
var clock_samples = [] # [round_trip, offset], the lowest round trip is the most accurate
var clock_timer = 0.0

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
	clock_pong.rpc_id(sender, client_time, _local_time())

@rpc("authority", "call_remote", "unreliable")
func clock_pong(client_time, host_time):
	await fake_delay()
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

func local_slot():
	return roster.get(multiplayer.get_unique_id(), {}).get("slot", 0)

func peer_for_slot(slot):
	for peer_id in roster:
		if roster[peer_id].slot == slot:
			return peer_id
	return 0

#region Hosting and joining

func host_lobby(public = false):
	if not steam_ready:
		_set_status(steam_status)
		return
	leave()
	_set_status("Creating lobby...")
	steam.createLobby(LOBBY_TYPE_PUBLIC if public else LOBBY_TYPE_FRIENDS_ONLY, MAX_PLAYERS)

func _on_lobby_created(result, new_lobby_id):
	if result != STEAM_RESULT_OK:
		_set_status("Could not create lobby (" + str(result) + ")")
		return
	lobby_id = new_lobby_id
	steam.setLobbyData(lobby_id, LOBBY_GAME_KEY, LOBBY_GAME_VALUE)
	steam.setLobbyData(lobby_id, "name", persona_name + "'s Pune")
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
	_set_status("Searching lobbies...")
	steam.addRequestLobbyListStringFilter(LOBBY_GAME_KEY, LOBBY_GAME_VALUE, LOBBY_COMPARISON_EQUAL)
	steam.addRequestLobbyListDistanceFilter(LOBBY_DISTANCE_WORLDWIDE)
	steam.requestLobbyList()

func _on_lobby_match_list(lobbies):
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
	is_lan = false
	clock_offset = 0.0
	clock_samples.clear()
	clock_timer = 0.0
	roster.clear()
	ready_peers.clear()
	Global.isMultiplayerActive = false
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
	roster = {1: {"name": _local_name(), "slot": 1}}
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
	var used = roster.values().map(func(entry): return entry.slot)
	for slot in range(1, MAX_PLAYERS + 1):
		if not used.has(slot):
			roster[peer_id] = {"name": player_name, "slot": slot}
			break
	if not roster.has(peer_id):
		multiplayer.multiplayer_peer.disconnect_peer(peer_id) # Lobby full
		return
	sync_roster.rpc(roster)
	roster_changed.emit()

@rpc("authority", "call_remote", "reliable")
func sync_roster(new_roster):
	roster = new_roster
	roster_changed.emit()

func _on_peer_disconnected(peer_id):
	if not roster.has(peer_id):
		return
	var slot = roster[peer_id].slot
	roster.erase(peer_id)
	ready_peers.erase(peer_id)
	if multiplayer.is_server():
		sync_roster.rpc(roster)
	roster_changed.emit()
	peer_left.emit(peer_id, slot)

#endregion

#region Match start

func start_match():
	if not is_host() or roster.size() < 2:
		return
	if steam_ready and lobby_id != 0:
		steam.setLobbyJoinable(lobby_id, false)
	begin_match.rpc(roster)

@rpc("authority", "call_local", "reliable")
func begin_match(final_roster):
	roster = final_roster
	ready_peers.clear()
	var used_slots = roster.values().map(func(entry): return entry.slot)
	for slot in range(1, MAX_PLAYERS + 1):
		Global.set("player" + str(slot) + "Active", used_slots.has(slot))
		Global.AI_Enabled[slot] = false
	Global.reset_score()
	Global.isMultiplayerActive = true
	# Not synced online yet, see docs/multiplayer.md
	Global.shrooms = false
	Global.upgrades = false
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
	if roster.keys().all(func(id): return ready_peers.has(id)):
		all_peers_ready.emit()

#endregion

func _set_status(text):
	print("[SteamNet] " + text)
	status_changed.emit(text)
