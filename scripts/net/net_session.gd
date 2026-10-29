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

class RemoteSnake:
	var player
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

var playground
var players = {}       # player_id (element slot) -> Player
var remote_snakes = {} # player_id -> RemoteSnake
var round_id = 0
var sequence = 0
var send_timer = 0.0
var local_segments = [] # PackedFloat32Array [index, x, y, rotation] per segment of our own trail

func setup(owner_playground):
	playground = owner_playground
	SteamNet.peer_left.connect(_on_peer_left)
	if multiplayer.is_server():
		SteamNet.all_peers_ready.connect(host_start_round, CONNECT_ONE_SHOT)
	SteamNet.report_scene_ready()

func is_local(player_id):
	return SteamNet.local_slot() == player_id

func register_player(player):
	var player_id = player.playerId
	players[player_id] = player
	if is_local(player_id):
		player.body_laid.connect(_on_local_body_laid)
		player.power_used.connect(_on_local_power_used.bind(player_id))
		return
	var snake = RemoteSnake.new()
	snake.player = player
	snake.state_position = player.global_position
	snake.state_rotation = player.rotation
	snake.speed = player.speed
	snake.angular_speed = player.angular_speed
	snake.sent_at = SteamNet.net_time()
	snake.bridge = Line2D.new()
	snake.bridge.top_level = true
	snake.bridge.width = BRIDGE_WIDTH
	snake.bridge.default_color = Color(Global.playerColors[player_id])
	snake.bridge.begin_cap_mode = Line2D.LINE_CAP_ROUND
	snake.bridge.end_cap_mode = Line2D.LINE_CAP_ROUND
	player.add_child(snake.bridge)
	remote_snakes[player_id] = snake

#region Owner side: stream our snake

func _physics_process(delta):
	var local = players.get(SteamNet.local_slot())
	if local == null or not is_instance_valid(local) or not local.is_processing():
		return
	send_timer += delta
	if send_timer >= SEND_INTERVAL:
		send_timer = 0.0
		_send_state(local)

# final: the snake died here, so it must not be extrapolated any further
func _send_state(local, final = false):
	sequence += 1
	var recent = PackedFloat32Array()
	for segment in local_segments.slice(-SEGMENT_REDUNDANCY):
		recent.append_array(segment)
	snake_state.rpc(round_id, local.playerId, sequence, SteamNet.net_time(), local.global_position,
		local.rotation, local.steer_direction, 0.0 if final else local.speed, local.gap, recent)

func _on_local_body_laid(body_position, body_rotation):
	local_segments.append(PackedFloat32Array([local_segments.size(), body_position.x, body_position.y, body_rotation]))

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
	for player_id in remote_snakes:
		var snake = remote_snakes[player_id]
		if snake.dead or not is_instance_valid(snake.player):
			continue
		snake.position_offset *= fade
		snake.rotation_offset *= fade
		var predicted = _predict(snake)
		snake.player.global_position = predicted[0] + snake.position_offset
		snake.player.rotation = predicted[1] + snake.rotation_offset
		if snake.gap or snake.newest_segment_position == null:
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

@rpc("any_peer", "call_remote", "reliable")
func power_event(event_round, player_id):
	var sender = multiplayer.get_remote_sender_id()
	await _fake_latency()
	if event_round != round_id or SteamNet.peer_for_slot(player_id) != sender:
		return
	var player = players.get(player_id)
	if player == null or not is_instance_valid(player) or not player.is_in_group("alivePlayers"):
		return
	# TODO: the water twin reads the keyboard directly and isn't synced yet
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

#endregion

#region Host authority: rounds, deaths and scores

func host_start_round():
	var spawns = {}
	for entry in SteamNet.roster.values():
		spawns[entry.slot] = playground.roll_spawn(entry.slot)
	start_round.rpc(round_id + 1, spawns)

@rpc("authority", "call_local", "reliable")
func start_round(new_round_id, spawns):
	await _fake_latency()
	round_id = new_round_id
	players.clear()
	remote_snakes.clear()
	local_segments.clear()
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

# A player left mid-match: the host counts their snake as dead
func _on_peer_left(_peer_id, slot):
	Global.set("player" + str(slot) + "Active", false)
	if multiplayer.is_server():
		_host_player_died(slot)

#endregion


# Debug: simulate network delay on everything we receive (SteamNet.fake_latency)
func _fake_latency():
	await SteamNet.fake_delay()
