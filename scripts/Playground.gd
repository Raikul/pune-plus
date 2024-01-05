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
@onready var spawn_locations = [[0,0],[300,300],[300,900],[1400,900],[1400,300]]

func _ready():
	RNG = RandomNumberGenerator.new()
	player_scene = preload("res://scenes/player.tscn")
	groupColliders()
	setupPlayers()
	$Events.set_space(topLimit,bottomLimit)
	$MusicPlayer.play(Global.musicProgress)
	Global.scoreToReach = (get_tree().get_nodes_in_group("activePlayers").size() - 1) * 10
	Global.scoreToReach = max(Global.scoreToReach, 10)
	#debug
#	Global.scoreToReach = 1
	$HUD/Centerfold/HBoxContainer/ScoreToReach.set_text(str(Global.scoreToReach))
	
func _process(_delta):
	if Input.is_key_pressed(KEY_ESCAPE):
		setupPlayers()
#		get_tree().change_scene_to_file("res://scenes/menu.tscn")
		

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
	

func setupPlayers():
	if Global.player1Active:
		spawn_player(1)
	if Global.player2Active:
		spawn_player(2)
	if Global.player3Active:
		spawn_player(3)
	if Global.player4Active:
		spawn_player(4)
	for player in get_tree().get_nodes_in_group("activePlayers"):
		for child in player.get_children():
			if child is Timer:
				timers.append(child)
		player.show()
	get_tree().get_first_node_in_group("HUD").set_process(true)
	time_flowing = true
		
func spawn_player(player_id):
	var newPlayer = player_scene.instantiate()
	var spawn_x = spawn_locations[player_id][0]
	var spawn_y = spawn_locations[player_id][1]
	var spawn_range = 150
	
	newPlayer.playerId = player_id
	
	newPlayer.global_position = Vector2(spawn_x + randf_range(-spawn_range,spawn_range),spawn_y + randf_range(-spawn_range,spawn_range))
	print ("Rotation: " + str(rad_to_deg(newPlayer.rotation)))
	newPlayer.rotate( (3/2 * PI) - (player_id * PI/2) - (randf_range(0,PI/2)) + PI/2)
	print("Player ID:" + str(player_id))
	print ("Rotation: " + str(rad_to_deg(newPlayer.rotation)))
	newPlayer.get_node("HeadSprite").modulate = Global.playerColors[player_id]
	newPlayer.get_node("ElementHeadSprite").set_texture(air_earth_texture)
	newPlayer.connect("dead", _on_player_dead.bind(newPlayer))
	newPlayer.connect("score", _on_player_score.bind(player_id))
	newPlayer.name = "Player"+str(player_id)
	add_child(newPlayer)
	newPlayer.add_to_group("activePlayers")
	newPlayer.add_to_group("alivePlayers")
#	print("Player Added")


	if newPlayer.playerId == 4:
		var raycaster = newPlayer.get_node("Raycaster")
		for raycast in raycaster.get_children():
			if raycast.name != "UpPlayer":
				raycast.collision_mask = 0b1
		
#	
#	if player_id == 4, set raycast masks to not 3. Por default marquemoslo como 3 true

func _on_player_dead(player):
	playerDead(player)
	
func playerDead(player):	
	player.powerAvailable = false
	if player.is_in_group("alivePlayers") :
		player.remove_from_group("alivePlayers")
		for alivePlayer in get_tree().get_nodes_in_group("alivePlayers"):
			alivePlayer.emit_signal("score")
	if get_tree().get_nodes_in_group("alivePlayers").size() <= 1 \
	and gameEnded == false and time_flowing:
		restart()

func finishGame(playerId):
	stopTime()
	gameEnded = true
	$Lesson.improvise("Player "+str(playerId)+" Wins")
	$Lesson.show()
	
func stopTime():
	time_flowing = false
	for item in timers:
		if is_instance_valid(item): item.stop()
	for player in get_tree().get_nodes_in_group("activePlayers"):
		player.set_process(false)
	for twinHead in get_tree().get_nodes_in_group("twinHeads"):
		twinHead.set_process(false)
	get_tree().get_first_node_in_group("HUD").set_process(false)
	pass

func restart():
	stopTime()
	if Global.lessons:
		$Lesson.teach("Water")
		$Lesson.show()
	for player in get_tree().get_nodes_in_group("activePlayers"):
		player.remove_from_group("activePlayers")
		player.queue_free()
	for shroom in get_tree().get_nodes_in_group("Shrooms"):
		shroom.queue_free()
#	await(get_tree().create_timer(2.0).timeout)
	call_deferred("setupPlayers")
#

func _on_player_score(player_id):
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
	if Global.player1Score >= Global.scoreToReach:
		finishGame(4)
	
func _on_pause_button_pressed():
	get_tree().paused = false
	$PauseButton.hide()
	
