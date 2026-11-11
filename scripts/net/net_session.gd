extends Node
class_name NetSession

# Online play inside Playground (see docs/multiplayer.md).
# Every machine owns its own snake: it moves with zero input delay and streams its
# state plus the trail segments it laid. Other snakes are shown with dead reckoning
# (last state + steering input, extrapolated by the latency) and their trails are
# rebuilt from the owner's exact segments. The host only decides game flow:
# spawns, deaths, scores, round end and match end.

const SEND_INTERVAL = 1.0 / 30.0
## Each trail segment rides along in this many state packets, so lost packets need no resend.
const SEGMENT_REDUNDANCY = 10
## A snake we stop hearing from is not extrapolated further than this (seconds).
const MAX_EXTRAPOLATION = 0.5
## Corrections bigger than this (teleports) snap instead of sliding.
const SNAP_DISTANCE = 120.0
const CORRECTION_SPEED = 10.0
const BRIDGE_WIDTH = TrailSegment.WIDTH
# Water twin status in twin_state packets
const TWIN_ALIVE = 0
const TWIN_DEAD = 1 # Crashed: it stays where it died, with its trail
const TWIN_ABSORBED = 2 # The water snake took its place: its head goes, its trail stays

class RemoteSnake:
	var player # The Player node, or the TwinHead node for a remote twin
	var state_position
	var state_rotation
	var direction = 0
	var speed
	var angular_speed
	var sent_at = 0.0 # SteamNet.net_time() when the owner was in this state
	var last_sequence = -1
	var known_segments = {}
	# Visual error left from the last correction, faded out over a few frames
	var position_offset = Vector2.ZERO
	var rotation_offset = 0.0
	var dead = false
	var gap = false
	# Visual-only line from the newest received segment to the predicted head, so
	# the trail doesn't look like it has a hole while segments are in flight
	var bridge
	var newest_segment_index = -1
	var newest_segment_position
	var serial = 0 # Twins only: which twin of that water snake this is

var playground
var players = {}       # player_id (element slot) -> Player
var remote_snakes = {} # player_id -> RemoteSnake
var round_id = 0
var sequences = {} # player_id -> last sequence sent, for each snake this machine runs
var send_timer = 0.0
var local_segments = {} # player_id -> [PackedFloat32Array [index, x, y, rotation]] per segment of our own trails
# Water twins (a water snake can have several at once).
# Ours: serial -> {"player_id", "twin", "serial", "sequence", "segments", "last", "final_sends"};
# other machines': "player_id:serial" -> RemoteSnake
var local_twins = {}
var remote_twins = {}
var twin_serial = 0

func setup(owner_playground):
	playground = owner_playground
	SteamNet.peer_left.connect(_on_peer_left)
	if multiplayer.is_server():
		SteamNet.all_peers_ready.connect(host_start_round, CONNECT_ONE_SHOT)
	SteamNet.report_scene_ready()

func is_local(player_id):
	return SteamNet.is_local_slot(player_id)

# Which Player{N} actions steer this snake here (0 = none, an AI or another machine's snake)
func input_id_for(player_id):
	return SteamNet.roster.get(player_id, {}).get("keys", 0) if is_local(player_id) else 0

func register_player(player):
	var player_id = player.playerId
	players[player_id] = player
	if is_local(player_id):
		local_segments[player_id] = []
		sequences[player_id] = 0
		player.body_laid.connect(_on_local_body_laid.bind(player_id))
		player.power_used.connect(_on_local_power_used.bind(player_id))
		player.twin_spawned.connect(_on_local_twin_spawned.bind(player_id))
		player.phoenix_changed.connect(_on_local_phoenix.bind(player_id))
		return
	remote_snakes[player_id] = _new_remote_snake(player, Color(Global.playerColors[player_id]))

func _new_remote_snake(node, color):
	var snake = RemoteSnake.new()
	snake.player = node
	snake.state_position = node.global_position
	snake.state_rotation = node.rotation
	# Still until its owner reports it moving (the first round waits for a countdown)
	snake.speed = 0.0
	snake.angular_speed = node.angular_speed
	snake.sent_at = SteamNet.net_time()
	snake.bridge = Line2D.new()
	snake.bridge.top_level = true
	snake.bridge.width = BRIDGE_WIDTH
	snake.bridge.default_color = color
	snake.bridge.begin_cap_mode = Line2D.LINE_CAP_ROUND
	snake.bridge.end_cap_mode = Line2D.LINE_CAP_ROUND
	node.add_child(snake.bridge)
	return snake

#region Owner side: stream our snake

func _physics_process(delta):
	if not _online():
		return
	send_timer += delta
	if send_timer < SEND_INTERVAL:
		return
	send_timer = 0.0
	for player_id in local_segments:
		var local = players.get(player_id)
		if local != null and is_instance_valid(local) and local.is_processing():
			_send_state(local)
	for serial in local_twins.keys():
		_send_twin_state(serial)

# final: the snake died here, so it must not be extrapolated any further
func _send_state(local, final = false):
	var player_id = local.playerId
	sequences[player_id] += 1
	var recent = PackedFloat32Array()
	for segment in local_segments[player_id].slice(-SEGMENT_REDUNDANCY):
		recent.append_array(segment)
	snake_state.rpc(round_id, player_id, sequences[player_id], SteamNet.net_time(), local.global_position,
		local.rotation, local.steer_direction, 0.0 if final or local.reviving else local.speed, local.gap, recent)

func _on_local_body_laid(body_position, body_rotation, player_id):
	var segments = local_segments[player_id]
	segments.append(PackedFloat32Array([segments.size(), body_position.x, body_position.y, body_rotation]))

func _on_local_twin_spawned(twin, player_id):
	twin_serial += 1
	var entry = {"player_id": player_id, "twin": twin, "serial": twin_serial, "sequence": 0, "segments": [], "last": null, "final_sends": 0}
	local_twins[twin_serial] = entry
	twin.body_laid.connect(_on_local_twin_body_laid.bind(entry))

func _on_local_twin_body_laid(body_position, body_rotation, entry):
	entry.segments.append(PackedFloat32Array([entry.segments.size(), body_position.x, body_position.y, body_rotation]))

func _send_twin_state(serial):
	var entry = local_twins[serial]
	var player_id = entry.player_id
	var twin = entry.twin
	if not is_instance_valid(twin):
		local_twins.erase(serial) # Round cleared
		return
	var status = TWIN_ALIVE
	if twin.absorbed:
		status = TWIN_ABSORBED
	elif not twin.alive:
		status = TWIN_DEAD
	elif not twin.is_processing():
		return # Round over: frozen, and every machine stops it on its own
	if entry.last == null or status == TWIN_ALIVE:
		entry.last = [twin.global_position, twin.rotation, twin.steer_direction, twin.speed, twin.gap]
	entry.sequence += 1
	var recent = PackedFloat32Array()
	for segment in entry.segments.slice(-SEGMENT_REDUNDANCY):
		recent.append_array(segment)
	var last = entry.last
	twin_state.rpc(round_id, player_id, entry.serial, entry.sequence, SteamNet.net_time(), last[0], last[1],
		last[2], last[3] if status == TWIN_ALIVE else 0.0, last[4], recent, status)
	# Packets are unreliable, so the final one is repeated a few times before we forget this twin
	if status != TWIN_ALIVE:
		entry.final_sends += 1
		if entry.final_sends >= SEGMENT_REDUNDANCY:
			local_twins.erase(serial)

func _on_local_power_used(recast, player_id):
	if not _online():
		return
	power_event.rpc(round_id, player_id, recast)

# Phoenix: our fire snake turned to ash (frozen and hidden everywhere) or rose again
func _on_local_phoenix(rising, player_id):
	if not _online():
		return
	var player = players.get(player_id)
	if not rising:
		_send_state(player, true)
	phoenix_event.rpc(round_id, player_id, rising, player.global_position, player.rotation)

@rpc("any_peer", "call_remote", "reliable")
func phoenix_event(event_round, player_id, rising, point, heading):
	if not _online():
		return
	var sender = multiplayer.get_remote_sender_id()
	if not await _arrived():
		return
	if event_round != round_id or SteamNet.peer_for_slot(player_id) != sender:
		return
	var player = players.get(player_id)
	var snake = remote_snakes.get(player_id)
	if player == null or not is_instance_valid(player) or snake == null or not player.main_power is FirePower:
		return
	if rising:
		# Predict it again from where it rose
		snake.dead = false
		snake.state_position = point
		snake.state_rotation = heading
		snake.direction = 0
		snake.speed = player.speed
		snake.sent_at = SteamNet.net_time()
		snake.position_offset = Vector2.ZERO
		snake.rotation_offset = 0.0
		snake.newest_segment_position = null
	else:
		_stop_snake(player_id)
	player.main_power.remote_phoenix(rising, point, heading)

# Our snake died on our screen: send its last trail and let the host decide what that means
func report_death(player_id):
	if not _online():
		return
	var player = players.get(player_id)
	if player and is_instance_valid(player):
		_send_state(player, true)
	if multiplayer.is_server():
		_host_player_died(player_id)
	else:
		death_report.rpc_id(1, round_id, player_id)

#endregion

#region Remote side: dead reckoning

@rpc("any_peer", "call_remote", "unreliable_ordered", 1)
func snake_state(state_round, player_id, state_sequence, sent_at, state_position, state_rotation, direction, speed, gap, segments):
	if not _online():
		return
	var sender = multiplayer.get_remote_sender_id()
	if not await _arrived():
		return
	if state_round != round_id or SteamNet.peer_for_slot(player_id) != sender:
		return
	var snake = remote_snakes.get(player_id)
	if snake == null or not is_instance_valid(snake.player):
		return
	_apply_state(snake, state_sequence, sent_at, state_position, state_rotation, direction, speed, gap, segments)

# Lays the owner's new segments and moves the prediction to the newest state
func _apply_state(snake, state_sequence, sent_at, state_position, state_rotation, direction, speed, gap, segments):
	for i in range(0, segments.size(), 4):
		var index = int(segments[i])
		if not snake.known_segments.has(index):
			snake.known_segments[index] = true
			snake.player.create_body_at(Vector2(segments[i + 1], segments[i + 2]), segments[i + 3])
			if index > snake.newest_segment_index:
				snake.newest_segment_index = index
				snake.newest_segment_position = Vector2(segments[i + 1], segments[i + 2])
	if state_sequence <= snake.last_sequence or snake.dead:
		return
	snake.last_sequence = state_sequence
	snake.gap = gap
	var shown_position = snake.player.global_position
	var shown_rotation = snake.player.rotation
	snake.state_position = state_position
	snake.state_rotation = state_rotation
	snake.direction = direction
	snake.speed = speed
	snake.sent_at = sent_at
	# Keep showing the snake where it was and slide to the new prediction from there
	var predicted = _predict(snake)
	snake.position_offset = shown_position - predicted[0]
	snake.rotation_offset = angle_difference(predicted[1], shown_rotation)
	if snake.position_offset.length() > SNAP_DISTANCE:
		snake.position_offset = Vector2.ZERO
		snake.rotation_offset = 0.0

func _process(delta):
	var fade = exp(-CORRECTION_SPEED * delta)
	for snake in remote_snakes.values() + remote_twins.values():
		if snake.dead or not is_instance_valid(snake.player):
			continue
		snake.position_offset *= fade
		snake.rotation_offset *= fade
		var predicted = _predict(snake)
		snake.player.global_position = predicted[0] + snake.position_offset
		snake.player.rotation = predicted[1] + snake.rotation_offset
		if snake.gap or snake.newest_segment_position == null \
		or snake.newest_segment_position.distance_to(snake.player.global_position) > SNAP_DISTANCE:
			# No bridge across a jump (teleport, water snake taking its twin's place)
			snake.bridge.clear_points()
		else:
			snake.bridge.points = PackedVector2Array([snake.newest_segment_position, snake.player.global_position])

# Where the snake is now if it kept its last steering: [position, rotation].
# Snakes move on exact circle arcs (constant speed and turn rate), so this is closed form.
func _predict(snake):
	# Time since the owner was in this state: covers network, relay and frame delays alike
	var elapsed = clamp(SteamNet.net_time() - snake.sent_at, 0.0, MAX_EXTRAPOLATION)
	var turn_rate = snake.angular_speed * snake.direction
	var start_rotation = snake.state_rotation
	if is_zero_approx(turn_rate):
		return [snake.state_position + Vector2.UP.rotated(start_rotation) * snake.speed * elapsed, start_rotation]
	var end_rotation = start_rotation + turn_rate * elapsed
	var arc = Vector2(cos(start_rotation) - cos(end_rotation), sin(start_rotation) - sin(end_rotation))
	return [snake.state_position + arc * snake.speed / turn_rate, end_rotation]

@rpc("any_peer", "call_remote", "unreliable_ordered", 1)
func twin_state(state_round, player_id, serial, state_sequence, sent_at, state_position, state_rotation, direction, speed, gap, segments, status):
	if not _online():
		return
	var sender = multiplayer.get_remote_sender_id()
	if not await _arrived():
		return
	if state_round != round_id or SteamNet.peer_for_slot(player_id) != sender:
		return
	var player = players.get(player_id)
	if player == null or not is_instance_valid(player):
		return
	var key = str(player_id) + ":" + str(serial)
	var snake = remote_twins.get(key)
	if snake == null:
		# A new twin. Older twins of the same snake keep going: each has its own packets.
		var twin = player.spawn_remote_twin()
		twin.global_position = state_position
		twin.rotation = state_rotation
		snake = _new_remote_snake(twin, twin.ghost_color())
		snake.serial = serial
		remote_twins[key] = snake
	if not is_instance_valid(snake.player):
		return
	_apply_state(snake, state_sequence, sent_at, state_position, state_rotation, direction, speed, gap, segments)
	if status != TWIN_ALIVE:
		_stop_twin(key)
	if status == TWIN_ABSORBED and not snake.player.absorbed:
		snake.player.absorb()

# Freeze a remote twin where its owner last reported it
func _stop_twin(key):
	var snake = remote_twins.get(key)
	if snake == null or snake.dead:
		return
	snake.dead = true
	if is_instance_valid(snake.player):
		snake.player.global_position = snake.state_position
		snake.player.rotation = snake.state_rotation
		snake.player.alive = false
		snake.player.remove_from_group("twinHeads")
		snake.bridge.clear_points()

@rpc("any_peer", "call_remote", "reliable")
func power_event(event_round, player_id, recast = false):
	if not _online():
		return
	var sender = multiplayer.get_remote_sender_id()
	if not await _arrived():
		return
	if event_round != round_id or SteamNet.peer_for_slot(player_id) != sender:
		return
	var player = players.get(player_id)
	if player == null or not is_instance_valid(player) or not player.is_in_group("alivePlayers"):
		return
	# The water twin arrives through twin_state instead
	if player_id != 4:
		player.use_power()
	# Air's second jump is free: it must not restart the cooldown
	if not recast:
		player.powerCooldown()

# Freeze a remote snake where its owner last reported it (its death spot)
func _stop_snake(player_id):
	var snake = remote_snakes.get(player_id)
	if snake == null or snake.dead:
		return
	snake.dead = true
	if is_instance_valid(snake.player):
		snake.player.global_position = snake.state_position
		snake.player.rotation = snake.state_rotation
		snake.bridge.clear_points()

# Round or match over: nobody moves anymore, so stop predicting
func _stop_all_snakes():
	for player_id in remote_snakes:
		_stop_snake(player_id)
	for key in remote_twins:
		_stop_twin(key)

#endregion

#region Host authority: rounds, deaths and scores

# --- Upgrade screen between rounds ---
# The host rolls every snake's options and opens the screen everywhere. Each machine
# picks for its own snakes and sends the pick to the others, and every machine applies
# every pick, so all copies of a snake have the same upgrades. Snakes whose player left
# get their highlighted card from the host once time (plus a grace period) is up.

const UPGRADE_GRACE = 3.0
var pending_picks = {} # Picks that arrived before this machine opened its screen

func host_run_upgrades(time_limit):
	if not _online():
		return
	var options = {}
	for slot in SteamNet.roster:
		options[slot] = UpgradeCatalog.roll_options(slot, 3).map(func(upgrade): return String(upgrade.id))
	open_upgrades.rpc(round_id, options, time_limit)
	while _online() and playground.upgrade_screen == null:
		await get_tree().process_frame
	var screen = playground.upgrade_screen
	if screen == null:
		return
	get_tree().create_timer(time_limit + UPGRADE_GRACE, false).timeout.connect(_host_force_picks.bind(screen))
	await screen.finished

func _host_force_picks(screen):
	if not _online() or not is_instance_valid(screen) or screen.finishing:
		return
	for missing in screen.unpicked():
		upgrade_pick.rpc(round_id, missing[0], missing[1])
		screen.remote_pick(missing[0], missing[1])

@rpc("authority", "call_local", "reliable")
func open_upgrades(event_round, options, time_limit):
	if not await _arrived():
		return
	if event_round != round_id:
		return
	if not multiplayer.is_server():
		playground.clear_round()
	var preset = {}
	for slot in options:
		preset[slot] = {
			"options": options[slot],
			"ai": SteamNet.roster.get(slot, {}).get("ai", false),
			"input_id": input_id_for(slot),
			"remote": not is_local(slot),
			"hidden": not playground.can_see_upgrades(slot),
		}
	var screen = playground.open_upgrade_screen(time_limit, preset)
	for slot in pending_picks:
		screen.remote_pick(slot, pending_picks[slot])
	pending_picks.clear()

func send_upgrade_pick(slot, upgrade_id):
	if _online():
		upgrade_pick.rpc(round_id, slot, String(upgrade_id))

@rpc("any_peer", "call_remote", "reliable")
func upgrade_pick(event_round, slot, upgrade_id):
	if not _online():
		return
	var sender = multiplayer.get_remote_sender_id()
	if not await _arrived():
		return
	# The snake's own machine, or the host picking for a player who left
	if event_round != round_id or (SteamNet.peer_for_slot(slot) != sender and sender != 1):
		return
	var screen = playground.upgrade_screen
	if screen == null or not is_instance_valid(screen):
		pending_picks[slot] = upgrade_id
		return
	screen.remote_pick(slot, upgrade_id)

func host_start_round():
	if not _online():
		return
	# This round's arena first: the spawns keep clear of its walls
	var level_path = Global.pick_level(playground.level_path if round_id > 0 else null)
	playground.use_level(level_path)
	var spawns = playground.roll_spawns(SteamNet.roster.keys())
	start_round.rpc(round_id + 1, spawns, level_path)

@rpc("authority", "call_local", "reliable")
func start_round(new_round_id, spawns, level_path = ""):
	if not await _arrived():
		return
	playground.use_level(level_path)
	round_id = new_round_id
	players.clear()
	remote_snakes.clear()
	local_segments.clear()
	sequences.clear()
	local_twins.clear()
	remote_twins.clear()
	pending_picks.clear()
	playground.clear_round()
	playground.call_deferred("setupPlayers", spawns)

@rpc("any_peer", "call_remote", "reliable")
func death_report(report_round, player_id):
	if not _online():
		return
	var sender = multiplayer.get_remote_sender_id()
	if not await _arrived():
		return
	if multiplayer.is_server() and report_round == round_id and SteamNet.peer_for_slot(player_id) == sender:
		_host_player_died(player_id)

func _host_player_died(player_id):
	if not _online():
		return
	var player = players.get(player_id)
	if player == null or not is_instance_valid(player) or not player.is_in_group("alivePlayers"):
		return
	_stop_snake(player_id)
	player_died.rpc(round_id, player_id)
	playground.playerDead(player) # Scores the survivors and may end the round or the match
	sync_scores.rpc(_scores())

@rpc("authority", "call_remote", "reliable")
func player_died(event_round, player_id):
	if not await _arrived():
		return
	var player = players.get(player_id)
	if event_round != round_id or player == null or not is_instance_valid(player):
		return
	_stop_snake(player_id)
	playground.mark_player_dead(player)

func host_round_over():
	if not _online():
		return
	_stop_all_snakes()
	round_over.rpc(round_id, _scores())

@rpc("authority", "call_remote", "reliable")
func round_over(event_round, scores):
	if not await _arrived():
		return
	if event_round != round_id:
		return
	_stop_all_snakes()
	_apply_scores(scores)
	await get_tree().process_frame # Let the HUD show the final scores before it stops
	if not _online():
		return
	playground.restart()

func host_game_over(winner_id):
	if not _online():
		return
	_stop_all_snakes()
	game_over.rpc(winner_id, _scores())

@rpc("authority", "call_remote", "reliable")
func game_over(winner_id, scores):
	if not await _arrived():
		return
	_stop_all_snakes()
	_apply_scores(scores)
	await get_tree().process_frame
	if not _online():
		return
	playground.finishGame(winner_id)

@rpc("authority", "call_remote", "reliable")
func sync_scores(scores):
	if not await _arrived():
		return
	_apply_scores(scores)

func _scores():
	return [Global.player1Score, Global.player2Score, Global.player3Score, Global.player4Score]

func _apply_scores(scores):
	for i in scores.size():
		Global.set("player" + str(i + 1) + "Score", scores[i])

# A player left mid-match: the host counts their snakes as dead
func _on_peer_left(_peer_id, slots):
	for slot in slots:
		Global.set("player" + str(slot) + "Active", false)
		if multiplayer.is_server():
			_host_player_died(slot)
	if multiplayer.is_server():
		_host_check_end_votes()

#endregion

#region End of the match: stats and rematch
# Each machine counted what it decided (Global.match_stats); at game over they all send
# theirs and add up everyone's. On the stats screen each machine's players pick REMATCH or
# QUIT; once every machine confirmed, the host starts a rematch if everybody wants one,
# otherwise everyone goes back to the lobby.

signal stats_received
signal end_choice_received(slot, rematch)
var peer_stats = {}   # peer id -> that machine's Global.match_stats
var end_choices = {}  # slot -> rematch, picks made on other machines
var end_votes = {}    # Host: peer id -> {slot: rematch}, once that machine confirmed

func send_stats():
	if _online():
		stats_shared.rpc(Global.match_stats)

@rpc("any_peer", "call_remote", "reliable")
func stats_shared(stats):
	var sender = multiplayer.get_remote_sender_id()
	if not await _arrived():
		return
	peer_stats[sender] = stats
	stats_received.emit()

func send_end_choice(slot, rematch):
	if _online() and is_local(slot):
		end_choice.rpc(slot, rematch)

@rpc("any_peer", "call_remote", "reliable")
func end_choice(slot, rematch):
	var sender = multiplayer.get_remote_sender_id()
	if not await _arrived():
		return
	if SteamNet.peer_for_slot(slot) != sender:
		return
	end_choices[slot] = rematch
	end_choice_received.emit(slot, rematch)

# This machine's players are done: their final picks go to the host
func confirm_end(choices):
	if not _online():
		return
	if multiplayer.is_server():
		_host_end_confirmed(1, choices)
	else:
		end_confirmed.rpc_id(1, choices)

@rpc("any_peer", "call_remote", "reliable")
func end_confirmed(choices):
	var sender = multiplayer.get_remote_sender_id()
	if not await _arrived():
		return
	if multiplayer.is_server():
		_host_end_confirmed(sender, choices)

func _host_end_confirmed(peer_id, choices):
	end_votes[peer_id] = choices
	_host_check_end_votes()

func _host_check_end_votes():
	if end_votes.is_empty() or not _online():
		return
	var peers = SteamNet.roster_peers()
	if not peers.all(func(peer_id): return end_votes.has(peer_id)):
		return
	var rematch = SteamNet.roster.size() >= 2
	# Machines where every player picked QUIT leave; the others go back to the lobby
	var leaving = []
	for peer_id in peers:
		var votes = end_votes[peer_id].values()
		for wants_more in votes:
			rematch = rematch and wants_more
		if not votes.is_empty() and not votes.any(func(wants_more): return wants_more):
			leaving.append(peer_id)
	end_votes.clear()
	if rematch:
		SteamNet.start_match()
		return
	# The host keeps the lobby for whoever stays; it only leaves if everyone does
	if leaving.size() == peers.size():
		for peer_id in peers:
			if peer_id != 1:
				leave_match.rpc_id(peer_id)
		leave_match()
		return
	for peer_id in peers:
		if peer_id == 1:
			continue
		if peer_id in leaving:
			leave_match.rpc_id(peer_id)
		else:
			back_to_lobby.rpc_id(peer_id)
	back_to_lobby()

# QUIT at the end of a match: out of the session, to the main menu
@rpc("authority", "call_remote", "reliable")
func leave_match():
	SteamNet.leave()
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/menu.tscn")

@rpc("authority", "call_local", "reliable")
func back_to_lobby():
	SteamNet.return_to_lobby()

#endregion


# Still in a running session? False once this node left the tree (scene change)
# or the connection closed, e.g. right after a player or the host left.
func _online():
	return is_inside_tree() and SteamNet.is_online()

# Call (with await) at the start of every received message: applies the debug
# network delay (SteamNet.fake_latency) and says whether it's still safe to handle it.
func _arrived():
	await SteamNet.fake_delay()
	return _online()
