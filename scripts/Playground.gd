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
const UPGRADE_TIME_LIMIT = 10.0
# Online play only: syncs snakes and lets the host drive rounds
var net_session
# 2v2: teams share their score and earn one point per enemy snake that dies (Global.team_of)
var teams_mode = false

@onready var animation_player = $AnimationPlayer
@onready var spawn_locations = [[0,0],[300,300],[300,900],[1400,900],[1400,300]]

func _ready():
	# Every match starts without upgrades; they build up round after round
	Global.reset_all_player_stats()
	RNG = RandomNumberGenerator.new()
	player_scene = preload("res://scenes/player.tscn")
	groupColliders()
	if Global.isMultiplayerActive:
		# Pickups aren't synced online yet (docs/multiplayer.md)
		for child in get_children():
			if child is Shroom:
				child.queue_free()
		net_session = NetSession.new()
		net_session.name = "NetSession"
		add_child(net_session)
		net_session.setup(self) # The host spawns the first round once every peer has loaded
	else:
		setupPlayers()
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
	#debug
#	Global.scoreToReach = 1
	$HUD/Centerfold/HBoxContainer/ScoreToReach.set_text(str(Global.scoreToReach))
	
func _process(_delta):
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
	

# spawns: optional {player_id: [x, y, rotation]} decided by the host when playing online
func setupPlayers(spawns = {}):
	for player_id in [1, 2, 3, 4]:
		if spawns.has(player_id):
			spawn_player(player_id, spawns[player_id])
		elif spawns.is_empty() and Global.get("player" + str(player_id) + "Active"):
			spawn_player(player_id, roll_spawn(player_id))
	for player in get_tree().get_nodes_in_group("activePlayers"):
		for child in player.get_children():
			if child is Timer:
				timers.append(child)
		player.show()
	get_tree().get_first_node_in_group("HUD").set_process(true)
	refresh_upgrade_badges()
	time_flowing = true
		
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
	$HUD.set_player_dead(player.playerId) # <--- AGREGAR ESTA LÍNEA
	if player.is_in_group("alivePlayers") :
		player.remove_from_group("alivePlayers")
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
	player.set_process(false)
	$HUD.set_player_dead(player.playerId)
	player.remove_from_group("alivePlayers")

func finishGame(playerId):
	if gameEnded:
		return
	if net_session and multiplayer.is_server():
		net_session.host_game_over(playerId)
	stopTime()
	gameEnded = true
	if teams_mode:
		$Lesson.improvise(Global.TEAM_NAMES[Global.team_of(playerId)] + " Wins")
	else:
		$Lesson.improvise("Player "+str(playerId)+" Wins")
	$Lesson.show()
	$Victory.play()
	
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
	if alive_players.size() == 1 or (teams_mode and alive_players.size() > 0):
		var id = alive_players[0].playerId
		animation_player.play("player_"+str(id)+"_win")
	
	# Online clients wait for the host's next round instead (NetSession.start_round)
	if net_session and not multiplayer.is_server():
		return
	await(get_tree().create_timer(delay).timeout)
	clear_round()
#	await(get_tree().create_timer(2.0).timeout)
	if Global.upgrades_enabled():
		if net_session:
			await net_session.host_run_upgrades(UPGRADE_TIME_LIMIT)
		else:
			await run_upgrade_selection()
	if net_session:
		net_session.host_start_round()
	else:
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
	var screen = open_upgrade_screen(UPGRADE_TIME_LIMIT)
	await screen.finished

# The open upgrade screen, if any (online picks from other machines are passed to it)
var upgrade_screen = null

# preset: online options and row owners (see UpgradeSelection.start); closes itself when done
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
