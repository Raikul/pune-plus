extends Node2D

var scored = false
var timers = []
var topLimit
var bottomLimit
var gameEnded = false
var air_earth_texture :Texture= preload("res://assets/jorge-resources/Game Selection/Air-Earth symbol.png")
var fire_water_texure :Texture= preload("res://assets/jorge-resources/Game Selection/Fire-Water symbol.png")
var players_to_reset = []
var player_scene
var RNG :RandomNumberGenerator
var time_flowing = false
var upgrade_selection_scene = preload("res://scenes/upgrade_selection.tscn")
# Online play only: syncs snakes and lets the host drive rounds
var net_session
# 2v2: teams share their score and earn one point per enemy snake that dies (Global.team_of)
var teams_mode = false

@onready var animation_player = $AnimationPlayer
@onready var spawn_locations = [[0,0],[300,300],[300,900],[1400,900],[1400,300]]

# Before the HUD and everything else get ready: the match's colors (a colorblind mode
# switched on in the pause menu waits for the next match)
func _enter_tree():
	Global.apply_colors()

func _ready():
	# Every match starts without upgrades; they build up round after round
	Global.reset_all_player_stats()
	# The AIs get this match's names (online the host names them in the roster)
	if not Global.isMultiplayerActive:
		Global.roll_ai_names()
	Global.reset_match_stats()
	RNG = RandomNumberGenerator.new()
	player_scene = preload("res://scenes/player.tscn")
	groupColliders()
	$Events.set_space(topLimit,bottomLimit)
	setup_music()
	var active_ids = [1, 2, 3, 4].filter(func(id): return Global.get("player" + str(id) + "Active"))
	# Teams only make sense with players on both sides
	var active_teams = {}
	for id in active_ids:
		active_teams[Global.team_of(id)] = true
	teams_mode = Global.teams_enabled() and active_teams.size() >= 2
	if Global.points_to_win_setting() > 0:
		Global.scoreToReach = Global.points_to_win_setting()
	elif teams_mode:
		Global.scoreToReach = 10
	else:
		Global.scoreToReach = max((active_ids.size() - 1) * 10, 10)
	$HUD.setup_teams(teams_mode)
	add_child(CursorFade.new())
	if teams_mode:
		var takeover = AiTakeover.new()
		takeover.name = "AiTakeover"
		takeover.playground = self
		add_child(takeover)
	#debug
#	Global.scoreToReach = 1
	# The play of the game, shown after the win screen (scripts/replay/)
	replay_recorder = ReplayRecorder.new()
	replay_recorder.name = "ReplayRecorder"
	replay_recorder.playground = self
	add_child(replay_recorder)
	$HUD/Centerfold/HBoxContainer/ScoreToReach.set_text(str(Global.scoreToReach))
	$HUD.set_target(Global.scoreToReach)
	_load_level()
	# After the rules above: the first countdown shows them
	if Global.isMultiplayerActive:
		net_session = NetSession.new()
		net_session.name = "NetSession"
		add_child(net_session)
		net_session.setup(self) # The host spawns the first round once every peer has loaded
	else:
		setupPlayers()
	
func _process(delta):
	_count_dead_time(delta)
	_pop_scores()
	#pause_menu_input()
	#exit_menu_input()
	#if Input.is_key_pressed(KEY_ESCAPE):
		#get_tree().change_scene_to_file("res://scenes/menu.tscn")
	set_cooldowns_ui()
	#		get_tree().change_scene_to_file("res://scenes/menu.tscn")

func pause_menu_input() -> void:
	if Input.is_action_just_pressed("Pause"):
		if get_tree().paused:
			$PauseButton.hide()
			get_tree().paused = false
		elif not get_tree().paused:
			$PauseButton.show()
			get_tree().paused = true
			
			
func exit_menu_input() -> void:
	if Input.is_action_just_pressed("ui_cancel"):
		if get_tree().paused:
			$ExitButton.hide()
			get_tree().paused = false
		elif not get_tree().paused:
			$ExitButton.show()
			get_tree().paused = true


# "+1" over a snake whenever its score goes up (online too: it watches the synced scores)
var shown_scores = {}
func _pop_scores():
	for id in [1, 2, 3, 4]:
		var score = Global.get("player%dScore" % id)
		var before = shown_scores.get(id, score)
		shown_scores[id] = score
		if score > before:
			var snake = get_node_or_null("Player%d" % id)
			if snake and is_instance_valid(snake):
				PowerFx.score(self, snake.global_position, Color(Global.playerColors[id]), "+%d" % (score - before))

# End-screen stats: seconds each snake spends dead (or as a Phoenix ember) while the
# round goes on, and its longest life in one round. Online each machine counts its own
# snakes.
var life_time = {} # player_id -> seconds alive this round
func _count_dead_time(delta):
	if not time_flowing:
		return
	for player in get_tree().get_nodes_in_group("activePlayers"):
		if net_session and not net_session.is_local(player.playerId):
			continue
		if not player.is_in_group("alivePlayers") or player.reviving:
			Global.add_stat(player.playerId, "dead_time", delta)
		else:
			life_time[player.playerId] = life_time.get(player.playerId, 0.0) + delta
			Global.max_stat(player.playerId, "best_life", life_time[player.playerId])

func set_cooldowns_ui():
	if is_instance_valid(get_tree()):
		for player in get_tree().get_nodes_in_group("activePlayers"):
			var cooldown_timer = player.get_node("CooldownTimer")
			$HUD.set_cooldown(player.playerId, cooldown_timer.time_left, cooldown_timer.wait_time)


func setup_music():
	$MusicPlayer.play(Global.musicProgress)
	$MusicPlayer.connect("finished",$MusicPlayer.play)
	
	
func reset_match():
	gameEnded = false
	Global.reset_score()

func groupColliders():
#	var topCollider = $Colliders/LimitTop/Collider
	var topRect =  $Colliders/LimitTop/ColorRect
	
#	topCollider.shape.get_rect() as Rect2
	topLimit = topRect.get_position().y + topRect.get_size().y 
	
#	var bottomCollider = $Colliders/Control/LimitBottom/Collider
	var bottomRect = $Colliders/Control/LimitBottom/ColorRect
#	bottomCollider.shape.get_rect()  as Rect2
	bottomLimit = bottomRect.global_position.y
	$Colliders/Control/LimitBottom.add_to_group("limits")
	$Colliders/LimitTop.add_to_group("limits")
	$Colliders/LimitLeft.add_to_group("limits")
	$Colliders/LimitRight.add_to_group("limits")
	_draw_arena_border()

# One thin line on the inner edge of the four wall colliders (where a head dies), instead
# of the old mismatched color strips
const BORDER_COLOR = Color(0.62, 0.36, 1.0, 0.9) # Purple
const BORDER_WIDTH = 2.0
func _draw_arena_border():
	var edges = {}
	for wall in ["LimitTop", "LimitLeft", "LimitRight", "Control/LimitBottom"]:
		var collider = get_node("Colliders/" + wall + "/Collider")
		get_node("Colliders/" + wall + "/ColorRect").hide()
		var rect = collider.global_transform * collider.shape.get_rect()
		edges[wall] = rect
	var half = BORDER_WIDTH / 2
	# The scoreboard bar (a CanvasLayer, always on top) reaches a little past the top wall:
	# the line goes just under it so it shows like the other three
	var top = edges["LimitTop"].end.y
	var hud_bar = get_node_or_null("HUD/PanelContainer")
	if hud_bar:
		top = max(top, hud_bar.get_global_rect().end.y)
	top += half
	var bottom = edges["Control/LimitBottom"].position.y - half
	var left = max(edges["LimitLeft"].end.x, 0.0) + half
	var right = min(edges["LimitRight"].position.x, get_viewport_rect().size.x) - half
	var border = Line2D.new()
	border.name = "ArenaBorder"
	border.width = BORDER_WIDTH
	border.default_color = BORDER_COLOR
	border.closed = true
	border.joint_mode = Line2D.LINE_JOINT_SHARP
	border.points = PackedVector2Array([Vector2(left, top), Vector2(right, top), Vector2(right, bottom), Vector2(left, bottom)])
	border.z_index = 2
	$Colliders.add_child(border)


# spawns: optional {player_id: [x, y, rotation]} decided by the host when playing online
func setupPlayers(spawns = {}):
	if spawns.is_empty() and not net_session:
		spawns = roll_spawns([1, 2, 3, 4].filter(func(id): return Global.get("player" + str(id) + "Active")))
	for player_id in [1, 2, 3, 4]:
		if spawns.has(player_id):
			spawn_player(player_id, spawns[player_id])
	for player in get_tree().get_nodes_in_group("activePlayers"):
		for child in player.get_children():
			if child is Timer:
				timers.append(child)
		player.show()
	get_tree().get_first_node_in_group("HUD").set_process(true)
	refresh_upgrade_badges()
	round_deaths = 0
	life_time = {}
	# 3 s before the first round, with the match's goal; 2 s before every other round unless
	# the Countdown match setting is off
	var first = not counted_down
	var countdown = 3 if first else (2 if Global.round_countdown_enabled() else 0)
	counted_down = true
	if countdown > 0:
		await _start_countdown(countdown, _countdown_text(first))
		if not is_inside_tree():
			return
	time_flowing = true

var counted_down = false
var round_deaths = 0

# Under the countdown: the match's goal (first round) and, with an arena rotation, the
# arena this round is played on
func _countdown_text(first) -> String:
	var lines = []
	if first:
		lines.append(_quest_text())
	if Global.level_rotation_setting().size() > 1:
		lines.append(tr("COUNTDOWN_ARENA") % Global.level_name(level_path).to_upper())
	return "
".join(lines)

# The match's goal, shown under the first countdown
func _quest_text() -> String:
	var mode = tr("COUNTDOWN_TEAMS") if teams_mode else tr("COUNTDOWN_FFA")
	return tr("COUNTDOWN_QUEST") % [mode, Global.scoreToReach]

# The snakes wait in place through "3, 2, 1, GO!" (from seconds down); quest: a line under it
func _start_countdown(seconds, quest = ""):
	var steps = range(seconds, 0, -1).map(func(n): return str(n)) + [tr("COUNTDOWN_GO")]
	var snakes = get_tree().get_nodes_in_group("activePlayers")
	for snake in snakes:
		snake.set_frozen(true)
	var layer = CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	var label = Label.new()
	label.add_theme_font_override("font", preload("res://assets/jorge-resources/Game Selection/Odin Rounded - Bold.otf"))
	label.add_theme_font_size_override("font_size", 220)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_constant_override("outline_size", 24)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(label)
	if quest != "":
		var line = Label.new()
		line.text = quest
		line.add_theme_font_override("font", preload("res://assets/jorge-resources/Game Selection/Odin Rounded - Bold.otf"))
		line.add_theme_font_size_override("font_size", 46)
		line.add_theme_color_override("font_color", Color(1, 0.85, 0.4))
		line.add_theme_constant_override("outline_size", 14)
		line.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
		line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		# Across the screen, a bit under the middle
		line.anchor_right = 1.0
		line.anchor_top = 0.5
		line.anchor_bottom = 0.5
		line.offset_top = 150
		line.offset_bottom = 150 + 70 * quest.count("
") + 70
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(line)
		# Fades out with the GO!
		line.create_tween().tween_property(line, "modulate:a", 0.0, 0.6).set_delay(seconds + 0.4)
	for step in steps:
		# A ring closing in on each snake, so everyone sees where they start
		if step != steps.back():
			for snake in snakes:
				if is_instance_valid(snake):
					PowerFx.home(self, snake, Color(Global.playerColors[snake.playerId]))
		label.text = step
		label.pivot_offset = get_viewport_rect().size / 2
		label.scale = Vector2(1.4, 1.4)
		label.modulate.a = 1.0
		var tween = label.create_tween().set_parallel()
		tween.tween_property(label, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		var last = step == steps.back()
		tween.tween_property(label, "modulate:a", 0.0 if last else 0.25, 0.6).set_delay(0.4)
		if last:
			# GO: the snakes are off while it fades
			for snake in snakes:
				if is_instance_valid(snake):
					snake.set_frozen(false)
			tween.chain().tween_callback(layer.queue_free)
			return
		# Not process_always, so pausing also holds the countdown
		await get_tree().create_timer(1.0, false).timeout
		if not is_inside_tree():
			return

# This round's arena layout (scripts/levels/level.gd), if any. Every round plays a random
# level of the arena rotation (Global.pick_level); online the host picks and sends it with
# the round (NetSession.start_round).
var level: Level
var level_path = ""

const LEVEL_Z_INDEX = 12
func _load_level():
	# Online the first round's level comes with the round
	if not Global.isMultiplayerActive:
		use_level(Global.pick_level())

# Swaps the arena for this level ("" = the empty classic one), between rounds
func use_level(path):
	if path != "" and not ResourceLoader.exists(path):
		path = "" # A level this build doesn't have
	if path == level_path and (path == "") == (level == null):
		return
	if is_instance_valid(level):
		# Out of the tree right away, so its walls don't count for this round's spawns
		remove_child(level)
		level.queue_free()
	level = null
	level_path = path
	if path == "":
		return
	level = load(path).instantiate()
	add_child(level)
	move_child(level, $Colliders.get_index() + 1)
	# Drawn over the snakes, their trails, Earth's rocks and fireballs (heads and symbols go
	# up to z 11), under the effects and edge markers (20 and up): an obstacle always reads
	# as solid, and Earth burrowing through one (Burrower) disappears under it
	level.z_index = LEVEL_Z_INDEX

## How far from a level's walls a snake can start
const SPAWN_LEVEL_MARGIN = 110.0
## How far ahead of a starting snake must be free of walls (arena border and level walls,
## where moving walls will be by then); otherwise its heading is turned until it is
const SPAWN_CLEAR_AHEAD = 320.0
## Seconds a moving wall is followed to check a start: the countdown and a bit more
const SPAWN_WALL_LOOKAHEAD = 4.5

# Clear of the level's walls now and while moving walls go by during the countdown
func _clear_of_level(point, margin = SPAWN_LEVEL_MARGIN) -> bool:
	if level == null:
		return true
	var seconds = 0.0
	while seconds <= SPAWN_WALL_LOOKAHEAD:
		if not level.is_clear(point, margin, seconds):
			return false
		seconds += 0.75
	return true

# How far a snake starting here with this heading goes before reaching a wall (up to
# SPAWN_CLEAR_AHEAD)
func _clear_ahead(point, heading) -> float:
	var arena = _arena_rect().grow(-30)
	var forward = Vector2.UP.rotated(heading)
	var distance = 40.0
	while distance <= SPAWN_CLEAR_AHEAD:
		var at = point + forward * distance
		if not arena.has_point(at) or not _clear_of_level(at, 30.0):
			return distance
		distance += 40.0
	return SPAWN_CLEAR_AHEAD

# The heading itself if the way ahead is clear, else the closest turn of it that is (or
# the one with the most room)
func _open_heading(point, heading) -> float:
	var best = heading
	var best_room = -1.0
	for turn in [0, 1, -1, 2, -2, 3, -3, 4, -4, 5, -5, 6, -6, 7, -7, 8]:
		var candidate = heading + turn * PI / 8
		var room = _clear_ahead(point, candidate)
		if room >= SPAWN_CLEAR_AHEAD:
			return candidate
		if room > best_room:
			best_room = room
			best = candidate
	return best

## Random starting spots: distance from the walls, from each other, and how far the
## heading can stray from facing the middle of the arena
const SPAWN_WALL_MARGIN = 160.0
const SPAWN_MIN_DISTANCE = 380.0
const SPAWN_HEADING_SPREAD = PI / 4

# {player_id: [x, y, rotation]} for these snakes: fixed corners, or anywhere with Random starts
func roll_spawns(ids):
	var spawns = {}
	var arena = _arena_rect().grow(-SPAWN_WALL_MARGIN)
	var middle = arena.get_center()
	var taken = []
	var to_roll = ids
	if not Global.random_spawns_enabled():
		# Fixed spots: the level's markers, else the usual corners; a corner that lands on a
		# level wall gets a random spot instead
		to_roll = []
		for id in ids:
			var spot = level.spawn_for(id) if level else []
			if spot.is_empty():
				# Around its corner, away from the walls and from the snakes placed so far
				for attempt in 20:
					spot = roll_spawn(id)
					if _clear_of_level(Vector2(spot[0], spot[1])) and _far_from(Vector2(spot[0], spot[1]), taken):
						break
				if not _clear_of_level(Vector2(spot[0], spot[1])):
					to_roll.append(id)
					continue
				spot[2] = _open_heading(Vector2(spot[0], spot[1]), spot[2])
			spawns[id] = spot
			taken.append(Vector2(spot[0], spot[1]))
	for id in to_roll:
		var point = middle
		# The spot farthest from the others, if no try gets far enough (it always should)
		var best_distance = -1.0
		for attempt in 200:
			var candidate = Vector2(randf_range(arena.position.x, arena.end.x), randf_range(arena.position.y, arena.end.y))
			if not _clear_of_level(candidate):
				continue
			var nearest = INF
			for other in taken:
				nearest = min(nearest, candidate.distance_to(other))
			if nearest > best_distance:
				best_distance = nearest
				point = candidate
			if nearest >= SPAWN_MIN_DISTANCE:
				break
		taken.append(point)
		var heading = Vector2.UP.angle_to(middle - point) + randf_range(-SPAWN_HEADING_SPREAD, SPAWN_HEADING_SPREAD)
		spawns[id] = [point.x, point.y, _open_heading(point, heading)]
	return spawns

func _far_from(point, others) -> bool:
	for other in others:
		if point.distance_to(other) < SPAWN_MIN_DISTANCE:
			return false
	return true

# Inside the walls and under the scoreboard (the purple border)
func _arena_rect() -> Rect2:
	var points = $Colliders/ArenaBorder.points
	return Rect2(points[0], points[2] - points[0])

# Random spawn point and heading for a snake: [x, y, rotation]
func roll_spawn(player_id):
	var spawn_x = spawn_locations[player_id][0]
	var spawn_y = spawn_locations[player_id][1]
	var spawn_range = 150
	return [
		spawn_x + randf_range(-spawn_range,spawn_range),
		spawn_y + randf_range(-spawn_range,spawn_range),
		(3/2 * PI) - (player_id * PI/2) - (randf_range(0,PI/2)) + PI/2,
	]

func spawn_player(player_id, spawn):
	var newPlayer = player_scene.instantiate()
	newPlayer.playerId = player_id
	newPlayer.stats = Global.player_stats[player_id]
	newPlayer.global_position = Vector2(spawn[0], spawn[1])
	newPlayer.rotation = spawn[2]
	if net_session:
		newPlayer.net_remote = not net_session.is_local(player_id)
		newPlayer.input_id = net_session.input_id_for(player_id)
	newPlayer.get_node("HeadSprite").modulate = Global.playerColors[player_id]
	newPlayer.get_node("ElementHeadSprite").set_texture(air_earth_texture)
	newPlayer.connect("dead", _on_player_dead.bind(newPlayer))
	newPlayer.connect("score", _on_player_score.bind(player_id))
	newPlayer.name = "Player" + str(player_id)
	add_child(newPlayer)
	newPlayer.add_to_group("activePlayers")
	newPlayer.add_to_group("alivePlayers")
	
	# Límites del mapa
	newPlayer.left_limit_x = $Colliders/LimitLeft/Collider.global_position.x
	newPlayer.right_limit_x = $Colliders/LimitRight/Collider.global_position.x
	newPlayer.top_limit_y = $Colliders/LimitTop/Collider.global_position.y
	newPlayer.bottom_limit_y = $Colliders/Control/LimitBottom/Collider.global_position.y

	if newPlayer.playerId == 4:
		var raycaster = newPlayer.get_node("Raycaster")
		for raycast in raycaster.get_children():
			if raycast.name != "UpPlayer":
				raycast.collision_mask = 0b1
	if net_session:
		net_session.register_player(newPlayer)
		
#	
#	if player_id == 4, set raycast masks to not 3. Por default marquemoslo como 3 true

func _on_player_dead(player):
	if net_session:
		net_session.report_death(player.playerId)
	else:
		playerDead(player)
	
# Online this only runs on the host (NetSession tells the clients)
func playerDead(player):	
	player.powerAvailable = false
	player.update_power_indicator()
	player.hide_teleport_marker()
	$HUD.set_player_dead(player.playerId) # <--- AGREGAR ESTA LÍNEA
	if player.is_in_group("alivePlayers") :
		_death_fx(player)
		player.remove_from_group("alivePlayers")
		# End-screen stats: the first snake out of the round
		if round_deaths == 0:
			Global.add_stat(player.playerId, "first_out")
		round_deaths += 1
		if teams_mode:
			# One point for the other team, if it still has a snake alive
			var enemy_team = 1 - Global.team_of(player.playerId)
			if get_tree().get_nodes_in_group("alivePlayers").any(func(p): return Global.team_of(p.playerId) == enemy_team):
				add_team_point(enemy_team)
		else:
			for alivePlayer in get_tree().get_nodes_in_group("alivePlayers"):
				alivePlayer.emit_signal("score")
	# The match may have ended on the first survivor's point: show everyone's
	$HUD.refresh()
	if round_is_over() and gameEnded == false and time_flowing:
		if net_session:
			net_session.host_round_over()
		restart()

# Free for all: one snake left. Teams: only one team left.
func round_is_over():
	var alive = get_tree().get_nodes_in_group("alivePlayers")
	if not teams_mode:
		return alive.size() <= 1
	var teams_alive = {}
	for p in alive:
		teams_alive[Global.team_of(p.playerId)] = true
	return teams_alive.size() <= 1

# Teams keep the same score on both members, so the scoreboard shows it on each
func add_team_point(team):
	var score = 0
	var members = [1, 2, 3, 4].filter(func(id): return Global.get("player%dActive" % id) and Global.team_of(id) == team)
	for id in members:
		score = max(score, Global.get("player%dScore" % id))
	score += 1
	for id in members:
		Global.set("player%dScore" % id, score)
	if score >= Global.scoreToReach and not members.is_empty():
		finishGame(members[0])

# Online clients: the host says this snake died
func mark_player_dead(player):
	player.powerAvailable = false
	player.update_power_indicator()
	player.hide_teleport_marker()
	player.set_process(false)
	$HUD.set_player_dead(player.playerId)
	if player.is_in_group("alivePlayers"):
		_death_fx(player)
	player.remove_from_group("alivePlayers")

func _death_fx(player):
	PowerFx.burst(self, player.global_position, Color(Global.playerColors[player.playerId]))
	if player.has_method("set_face"):
		player.set_face("dead")

## Seconds the arena stays frozen on the final result before the win screen
const FINAL_RESULT_TIME = 2.0

func finishGame(playerId):
	if gameEnded:
		return
	if net_session and multiplayer.is_server():
		net_session.host_game_over(playerId)
	stopTime()
	gameEnded = true
	if net_session:
		net_session.send_stats()
	# Let the final moment (last crash, last point on the scoreboard) sink in first
	await get_tree().create_timer(FINAL_RESULT_TIME, false).timeout
	if not is_inside_tree():
		return
	# Covers the whole arena, under the scoreboard
	var screen = get_viewport_rect().size
	var arena_top = $Colliders/ArenaBorder.points[0].y - BORDER_WIDTH
	var arena = Rect2(0, arena_top, screen.x, screen.y - arena_top)
	if teams_mode:
		$Lesson.improvise(tr("WIN_NAME") % Global.team_name(Global.team_of(playerId)), arena, playerId)
	else:
		$Lesson.improvise(tr("WIN_NAME") % Global.player_name(playerId), arena, playerId)
	$Lesson.show()
	$Victory.play()
	winners = _winners(playerId)
	_start_celebration()
	$Lesson.closed.connect(_show_replay, CONNECT_ONE_SHOT)

# --- End of the match: victory lap, stats, rematch ---

var winners = []
var celebration: Celebration
var stats_screen: MatchStatsScreen
var replay_recorder: ReplayRecorder

func _active_ids():
	return [1, 2, 3, 4].filter(func(id): return Global.get("player%dActive" % id))

# The winning snake, or the whole winning team
func _winners(player_id):
	if not teams_mode:
		return [player_id]
	return _active_ids().filter(func(id): return Global.team_of(id) == Global.team_of(player_id))

# Who's behind a snake, for the end screens. input_id: the Player{N} keys that steer it on
# this machine (0 = an AI, or a snake of another machine)
func _end_info(player_id):
	var entry = {"name": Global.player_name(player_id), "input_id": player_id, "ai": Global.AI_Enabled[player_id]}
	if net_session:
		var slot = SteamNet.roster.get(player_id, {})
		entry.name = slot.get("name", entry.name)
		entry.ai = slot.get("ai", false)
		entry.input_id = net_session.input_id_for(player_id)
	if entry.ai:
		entry.input_id = 0
	return entry

# The winners take a lap behind the win screen's text (scripts/celebration.gd)
func _start_celebration():
	var backdrop = $Lesson/DopamineContainer/Dopamine
	backdrop.clip_contents = true
	celebration = Celebration.new()
	backdrop.add_child(celebration)
	backdrop.move_child(celebration, 0) # Under the text
	celebration.setup(winners.map(func(id): return {"id": id, "input_id": _end_info(id).input_id}))

func _close_win_screen():
	$Lesson.hide()
	if is_instance_valid(celebration):
		celebration.queue_free()

# The play of the game, looping until someone skips it; then the stats
func _show_replay():
	_close_win_screen()
	var play = replay_recorder.play_of_the_game() if is_instance_valid(replay_recorder) else {}
	if play.is_empty():
		_show_match_stats()
		return
	var layer = CanvasLayer.new()
	layer.layer = 6 # Like the stats screen: above the HUD, below the pause menu
	add_child(layer)
	var replay = ReplayScreen.new()
	layer.add_child(replay)
	replay.setup(play)
	replay.finished.connect(func():
		layer.queue_free()
		_show_match_stats())

func _show_match_stats():
	_close_win_screen()
	var layer = CanvasLayer.new()
	layer.layer = 6 # Above the HUD and upgrade screen, below the pause menu
	add_child(layer)
	stats_screen = MatchStatsScreen.new()
	layer.add_child(stats_screen)
	var ids = _active_ids()
	if teams_mode:
		ids.sort_custom(func(a, b): return Global.team_of(a) < Global.team_of(b))
	var info = {}
	for id in ids:
		info[id] = _end_info(id)
	stats_screen.setup(ids, winners, match_stats_totals(), info)
	stats_screen.confirmed.connect(_on_stats_confirmed)
	if net_session:
		stats_screen.choice_changed.connect(net_session.send_end_choice)
		net_session.end_choice_received.connect(stats_screen.set_choice)
		net_session.stats_received.connect(func(): stats_screen.set_totals(match_stats_totals()))
		# Picks other machines made before this screen opened
		for slot in net_session.end_choices:
			stats_screen.set_choice(slot, net_session.end_choices[slot])

# Every machine's counts added up (offline just this one's)
func match_stats_totals():
	if net_session:
		return Global.sum_stats([Global.match_stats] + net_session.peer_stats.values())
	return Global.match_stats

# Everyone on REMATCH plays again with the same snakes and rules. Otherwise the players
# who wanted a rematch go back to the lobby (player setup) without the ones who quit; if
# nobody did, back to the main menu. Online the host decides once every machine confirmed
# (NetSession).
func _on_stats_confirmed(choices):
	if net_session:
		var mine = {}
		for id in choices:
			if net_session.is_local(id):
				mine[id] = choices[id]
		net_session.confirm_end(mine)
		stats_screen.show_waiting()
		return
	if choices.values().all(func(rematch): return rematch):
		Global.reset_score()
		get_tree().change_scene_to_file("res://scenes/Playground.tscn")
		return
	# AI snakes always vote rematch: only the humans count to keep the lobby going
	var staying = choices.keys().filter(func(id): return choices[id] and not Global.AI_Enabled.get(id, false))
	if not staying.is_empty():
		for id in choices:
			if not choices[id]:
				Global.set("player%dActive" % id, false)
		Global.open_player_setup = true
	get_tree().change_scene_to_file("res://scenes/menu.tscn")
	
func stopTime():
	time_flowing = false
	for item in timers:
		if is_instance_valid(item): item.stop()
	for player in get_tree().get_nodes_in_group("activePlayers"):
		player.set_process(false)
	for twinHead in get_tree().get_nodes_in_group("twinHeads"):
		twinHead.set_process(false)
	var hud = get_tree().get_first_node_in_group("HUD")
	hud.refresh()
	hud.set_process(false)
	pass

func restart(delay = 2):
	stopTime()
	var alive_players = get_tree().get_nodes_in_group("alivePlayers")
	last_round_winner = 0
	if alive_players.size() == 1 or (teams_mode and alive_players.size() > 0):
		var id = alive_players[0].playerId
		last_round_winner = id
		for survivor in alive_players:
			Global.note_highlight(survivor.playerId, "round", 1.0)
			# End-screen stats (online the host counts them)
			if not net_session or multiplayer.is_server():
				Global.add_stat(survivor.playerId, "round_wins")
		animation_player.play("player_"+str(id)+"_win")
	
	# Online clients wait for the host's next round instead (NetSession.start_round)
	if net_session and not multiplayer.is_server():
		return
	await(get_tree().create_timer(delay).timeout)
	clear_round()
#	await(get_tree().create_timer(2.0).timeout)
	if Global.upgrades_enabled():
		if net_session:
			await net_session.host_run_upgrades(Global.online_upgrade_time)
		else:
			await run_upgrade_selection()
	if net_session:
		net_session.host_start_round()
	else:
		use_level(Global.pick_level(level_path))
		call_deferred("setupPlayers")

func clear_round():
	animation_player.stop()
	$HUD.reset_labels()
	if Global.lessons:
		$Lesson.teach("Water")
		$Lesson.show()
	for player in get_tree().get_nodes_in_group("activePlayers"):
		player.remove_from_group("activePlayers")
		player.remove_from_group("alivePlayers")
		player.queue_free()
	for shroom in get_tree().get_nodes_in_group("Shrooms"):
		shroom.queue_free()

# Shows the upgrade screen between rounds and waits until every snake picked or time ran out.
func run_upgrade_selection():
	var screen = open_upgrade_screen(Global.upgrade_time)
	await screen.finished

# The open upgrade screen, if any (online picks from other machines are passed to it)
var upgrade_screen = null

# preset: online options and row owners (see UpgradeSelection.start); closes itself when done
# Snake that survived the last round (0 = nobody): its element picks the upgrade screen's quote
var last_round_winner = 0

func open_upgrade_screen(time_limit, preset = {}):
	var layer = CanvasLayer.new()
	layer.layer = 5 # Above the HUD, below the pause menu
	add_child(layer)
	var screen = upgrade_selection_scene.instantiate()
	layer.add_child(screen)
	screen.upgrade_selected.connect(_on_upgrade_selected)
	screen.finished.connect(func():
		upgrade_screen = null
		layer.queue_free())
	upgrade_screen = screen
	screen.start([], time_limit, preset)
	if Global.show_quotes:
		screen.show_wisdom(last_round_winner)
	return screen

func _on_upgrade_selected(player_id, upgrade_id):
	_apply_upgrade(player_id, upgrade_id)
	# Online: tell the others about the picks made on this machine
	if net_session and net_session.is_local(player_id):
		net_session.send_upgrade_pick(player_id, upgrade_id)

# A snake picked an upgrade: it keeps it (stacking) for the rest of the match
func _apply_upgrade(player_id, upgrade_id):
	var stats = Global.player_stats.get(player_id)
	var buff = UpgradeCatalog.make_buff(upgrade_id)
	if stats != null and buff != null:
		stats.add_buff(buff)
	refresh_upgrade_badges()

func refresh_upgrade_badges():
	$HUD.refresh_upgrades(can_see_upgrades)

# Online, rivals' upgrades stay hidden: you see your own snakes' and your team's
func can_see_upgrades(player_id) -> bool:
	if not net_session:
		return true
	if net_session.is_local(player_id):
		return true
	if teams_mode:
		for slot in SteamNet.local_slots():
			if Global.team_of(slot) == Global.team_of(player_id):
				return true
	return false
#

func _on_player_score(player_id):
	# Shrooms: with teams the point goes to the team
	if teams_mode:
		add_team_point(Global.team_of(player_id))
		return
	match player_id:
		1: _on_player_1_score()
		2: _on_player_2_score()
		3: _on_player_3_score()
		4: _on_player_4_score()
	
func _on_player_1_score():
	Global.player1Score += 1
	if Global.player1Score >= Global.scoreToReach:
		finishGame(1)

func _on_player_2_score():
	Global.player2Score += 1
	if Global.player2Score >= Global.scoreToReach:
		finishGame(2)

func _on_player_3_score():
	Global.player3Score += 1
	if Global.player3Score >= Global.scoreToReach:
		finishGame(3)

func _on_player_4_score():
	Global.player4Score += 1
	if Global.player4Score >= Global.scoreToReach:
		finishGame(4)
	
func _on_pause_button_pressed():
	get_tree().paused = false
	$PauseButton.hide()
	
# Simulate until one snake remains 
func simulate_round():
	var alive = get_tree().get_nodes_in_group("alivePlayers")
	
	
	if round_is_over() or gameEnded:
		return

	while not round_is_over() and not gameEnded:
		var victim = alive.pick_random() # Kills random serpents 
		playerDead(victim)               
		alive = get_tree().get_nodes_in_group("alivePlayers") # Actualiza la lista
