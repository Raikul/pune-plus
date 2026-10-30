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
const BRIDGE_WIDTH = 8.0
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
# Water twins. Ours: player_id -> {"twin", "serial", "sequence", "segments", "last", "final_sends"};
# other machines': player_id -> RemoteSnake
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
		return
	remote_snakes[player_id] = _new_remote_snake(player, Color(Global.playerColors[player_id]))

func _new_remote_snake(node, color):
	var snake = RemoteSnake.new()
	snake.player = node
	snake.state_position = node.global_position
	snake.state_rotation = node.rotation
	snake.speed = node.speed
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
	send_timer += delta
	if send_timer < SEND_INTERVAL:
		return
	send_timer = 0.0
	for player_id in local_segments:
		var local = players.get(player_id)
		if local != null and is_instance_valid(local) and local.is_processing():
			_send_state(local)
	for player_id in local_twins.keys():
		_send_twin_state(player_id)

# final: the snake died here, so it must not be extrapolated any further
func _send_state(local, final = false):
	var player_id = local.playerId
	sequences[player_id] += 1
	var recent = PackedFloat32Array()
	for segment in local_segments[player_id].slice(-SEGMENT_REDUNDANCY):
		recent.append_array(segment)
	snake_state.rpc(round_id, player_id, sequences[player_id], SteamNet.net_time(), local.global_position,
		local.rotation, local.steer_direction, 0.0 if final else local.speed, local.gap, recent)

func _on_local_body_laid(body_position, body_rotation, player_id):
	var segments = local_segments[player_id]
	segments.append(PackedFloat32Array([segments.size(), body_position.x, body_position.y, body_rotation]))

func _on_local_twin_spawned(twin, player_id):
	twin_serial += 1
	var entry = {"twin": twin, "serial": twin_serial, "sequence": 0, "segments": [], "last": null, "final_sends": 0}
	local_twins[player_id] = entry
	twin.body_laid.connect(_on_local_twin_body_laid.bind(entry))

func _on_local_twin_body_laid(body_position, body_rotation, entry):
	entry.segments.append(PackedFloat32Array([entry.segments.size(), body_position.x, body_position.y, body_rotation]))

func _send_twin_state(player_id):
	var entry = local_twins[player_id]
	var twin = entry.twin
	if not is_instance_valid(twin):
		local_twins.erase(player_id) # Round cleared
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
			local_twins.erase(player_id)

func _on_local_power_used(player_id):
	power_event.rpc(round_id, player_id)

# Our snake died on our screen: send its last trail and let the host decide what that means
func report_death(player_id):
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
	var sender = multiplayer.get_remote_sender_id()
	await _fake_latency()
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
	var sender = multiplayer.get_remote_sender_id()
	await _fake_latency()
	if state_round != round_id or SteamNet.peer_for_slot(player_id) != sender:
		return
	var player = players.get(player_id)
	if player == null or not is_instance_valid(player):
		return
	var snake = remote_twins.get(player_id)
	if snake != null and snake.serial > serial:
		return # A late packet from an older twin
	if snake == null or snake.serial < serial:
		# A new twin: the previous one (if any) keeps its trail where it stopped
		if snake != null:
			_stop_twin(player_id)
		var twin = player.spawn_remote_twin()
		twin.global_position = state_position
		twin.rotation = state_rotation
		snake = _new_remote_snake(twin, Color.AQUA)
		snake.serial = serial
		remote_twins[player_id] = snake
	if not is_instance_valid(snake.player):
		return
	_apply_state(snake, state_sequence, sent_at, state_position, state_rotation, direction, speed, gap, segments)
	if status != TWIN_ALIVE:
		_stop_twin(player_id)
	if status == TWIN_ABSORBED and not snake.player.absorbed:
		snake.player.absorb()

# Freeze a remote twin where its owner last reported it
func _stop_twin(player_id):
	var snake = remote_twins.get(player_id)
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
func power_event(event_round, player_id):
	var sender = multiplayer.get_remote_sender_id()
	await _fake_latency()
	if event_round != round_id or SteamNet.peer_for_slot(player_id) != sender:
		return
	var player = players.get(player_id)
	if player == null or not is_instance_valid(player) or not player.is_in_group("alivePlayers"):
		return
	# The water twin arrives through twin_state instead
	if player_id != 4:
		player.use_power()
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
	for player_id in remote_twins:
		_stop_twin(player_id)

#endregion

#region Host authority: rounds, deaths and scores

func host_start_round():
	var spawns = {}
	for slot in SteamNet.roster:
		spawns[slot] = playground.roll_spawn(slot)
	start_round.rpc(round_id + 1, spawns)

@rpc("authority", "call_local", "reliable")
func start_round(new_round_id, spawns):
	await _fake_latency()
	round_id = new_round_id
	players.clear()
	remote_snakes.clear()
	local_segments.clear()
	sequences.clear()
	local_twins.clear()
	remote_twins.clear()
	playground.clear_round()
	playground.call_deferred("setupPlayers", spawns)

@rpc("any_peer", "call_remote", "reliable")
func death_report(report_round, player_id):
	var sender = multiplayer.get_remote_sender_id()
	await _fake_latency()
	if multiplayer.is_server() and report_round == round_id and SteamNet.peer_for_slot(player_id) == sender:
		_host_player_died(player_id)

func _host_player_died(player_id):
	var player = players.get(player_id)
	if player == null or not is_instance_valid(player) or not player.is_in_group("alivePlayers"):
		return
	_stop_snake(player_id)
	player_died.rpc(round_id, player_id)
	playground.playerDead(player) # Scores the survivors and may end the round or the match
	sync_scores.rpc(_scores())

@rpc("authority", "call_remote", "reliable")
func player_died(event_round, player_id):
	await _fake_latency()
	var player = players.get(player_id)
	if event_round != round_id or player == null or not is_instance_valid(player):
		return
	_stop_snake(player_id)
	playground.mark_player_dead(player)

func host_round_over():
	_stop_all_snakes()
	round_over.rpc(round_id, _scores())

@rpc("authority", "call_remote", "reliable")
func round_over(event_round, scores):
	await _fake_latency()
	if event_round != round_id:
		return
	_stop_all_snakes()
	_apply_scores(scores)
	await get_tree().process_frame # Let the HUD show the final scores before it stops
	playground.restart()

func host_game_over(winner_id):
	_stop_all_snakes()
	game_over.rpc(winner_id, _scores())

@rpc("authority", "call_remote", "reliable")
func game_over(winner_id, scores):
	await _fake_latency()
	_stop_all_snakes()
	_apply_scores(scores)
	await get_tree().process_frame
	playground.finishGame(winner_id)

@rpc("authority", "call_remote", "reliable")
func sync_scores(scores):
	await _fake_latency()
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

#endregion


# Debug: simulate network delay on everything we receive (SteamNet.fake_latency)
func _fake_latency():
	await SteamNet.fake_delay()
