extends Node2D

var scored = false
var timers = []
var topLimit
var bottomLimit
var gameEnded = false
var air_earth_texture :Texture= preload("res://assets/jorge-resources/Game Selection/Air-Earth symbol.png")
var fire_water_texure :Texture= preload("res://assets/jorge-resources/Game Selection/Fire-Water symbol.png")

func _ready():
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
		get_tree().change_scene_to_file("res://scenes/menu.tscn")
		

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
		$Player1.add_to_group("activePlayers")
		$Player1.add_to_group("alivePlayers")
		$Player1/HeadSprite.modulate = Global.playerColors[1]
		$Player1/ElementHeadSprite.set_texture(air_earth_texture)
	else:
		$Player1.queue_free()
	if Global.player2Active:
		$Player2.add_to_group("activePlayers")
		$Player2.add_to_group("alivePlayers")
		$Player2/HeadSprite.modulate = Global.playerColors[2]
	else:
		$Player2.queue_free()
	if Global.player3Active:
		$Player3.add_to_group("activePlayers")
		$Player3.add_to_group("alivePlayers")
		$Player3/HeadSprite.modulate = Global.playerColors[3]
	else:
		$Player3.queue_free()
	if Global.player4Active:
		$Player4.add_to_group("activePlayers")
		$Player4.add_to_group("alivePlayers")
		$Player4/HeadSprite.modulate = Global.playerColors[4]
	else:
		$Player4.queue_free()

	for player in get_tree().get_nodes_in_group("activePlayers"):
		for child in player.get_children():
			if child is Timer:
				timers.append(child)
		player.show()

func _on_player_1_dead():
	playerDead($Player1)

func _on_player_2_dead():
	playerDead($Player2)
	
func _on_player_3_dead():
	playerDead($Player3)

func _on_player_4_dead():
	playerDead($Player4)
	
func playerDead(player):	
	if player.is_in_group("alivePlayers") :
		player.remove_from_group("alivePlayers")
		for alivePlayer in get_tree().get_nodes_in_group("alivePlayers"):
			alivePlayer.emit_signal("score")
	if get_tree().get_nodes_in_group("alivePlayers").size() <= 1 and gameEnded ==false:
		restart()

func finishGame(playerId):
	stopTime()
	gameEnded = true
	$Lesson.improvise("Player "+str(playerId)+" Wins")
	$Lesson.show()
	
func stopTime():
	for item in timers:
		item.stop()
	for player in get_tree().get_nodes_in_group("activePlayers"):
		player.set_process(false)
	for twinHead in get_tree().get_nodes_in_group("twinHeads"):
		twinHead.set_process(false)
	pass

func restart():
	stopTime()
	if Global.lessons:
		$Lesson.teach("Water")
		$Lesson.show()
	await(get_tree().create_timer(2.0).timeout)
	Global.musicProgress = $MusicPlayer.get_playback_position()
	get_tree().reload_current_scene()
	
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
	
