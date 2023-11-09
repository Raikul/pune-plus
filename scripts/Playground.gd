extends Node2D

var scored = false
var timers = []

func _ready():
	groupColliders()
	setupPlayers()
	$MusicPlayer.play(Global.musicProgress)

func _process(delta):
	if Input.is_key_pressed(KEY_ESCAPE):
		get_tree().change_scene_to_file("res://scenes/menu.tscn")

func groupColliders():
	$Colliders/Control/LimitBottom.add_to_group("limits")
	$Colliders/LimitTop.add_to_group("limits")
	$Colliders/LimitLeft.add_to_group("limits")
	$Colliders/LimitRight.add_to_group("limits")

func setupPlayers():
	if Global.player1Active:
		$Player1.add_to_group("activePlayers")
		$Player1.add_to_group("alivePlayers")
		$Player1/HeadSprite.modulate = Global.player1Color
		$Player1/HeadColor.modulate = Global.player1Color
	else:
		$Player1.queue_free()
	if Global.player2Active:
		$Player2.add_to_group("activePlayers")
		$Player2.add_to_group("alivePlayers")
		$Player2/HeadSprite.modulate = Global.player2Color
		$Player1/HeadColor.modulate = Global.player2Color
	else:
		$Player2.queue_free()
	if Global.player3Active:
		$Player3.add_to_group("activePlayers")
		$Player3.add_to_group("alivePlayers")
		$Player3/HeadSprite.modulate = Global.player3Color
	else:
		$Player3.queue_free()
	if Global.player4Active:
		$Player4.add_to_group("activePlayers")
		$Player4.add_to_group("alivePlayers")
		$Player4/HeadSprite.modulate = Global.player4Color
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
	if get_tree().get_nodes_in_group("alivePlayers").size() <= 1:
		restart()

func restart():
	for item in timers:
		item.stop()
	for player in get_tree().get_nodes_in_group("activePlayers"):
		player.set_process(false)
	
	$Lesson.teach("Water")
	$Lesson.show()
	await(get_tree().create_timer(2.0).timeout)
	Global.musicProgress = $MusicPlayer.get_playback_position()
	get_tree().reload_current_scene()
	
func _on_player_1_score():
	Global.player1Score += 1
	pass # Replace with function body.

func _on_player_2_score():
	Global.player2Score += 1
	pass # Replace with function body.

func _on_player_3_score():
	Global.player3Score += 1
	pass # Replace with function body.

func _on_player_4_score():
	Global.player4Score += 1
	pass # Replace with function body.

func _on_pause_button_pressed():
	get_tree().paused = false
	$PauseButton.hide()
	
