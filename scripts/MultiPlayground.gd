extends Node2D

var scored = false
var timers = []
#
#@onready var player1 = $Node/Player1
#@onready var player2 = $Node/Player2
@export var playerScene : PackedScene
var p1
var p2
signal restartNotice

func _ready():
	var index = 0
	for i in Global.Players:
		var currentPlayer = playerScene.instantiate()
		currentPlayer.playerId = index +1
		currentPlayer.name = str(Global.Players[i].id)
		add_child(currentPlayer)
		for spawn in get_tree().get_nodes_in_group("PlayerSpawnPoint"):
			if spawn.name == str(index):
				currentPlayer.global_position = spawn.global_position
#				currentPlayer.connect("dead",on_player_dead.bind(currentPlayer))
		index += 1		
#				currentPlayer.playerId = index +1
#	spawn_p1()
#	spawn_p2()
#	if multiplayer.is_server():
#
#		spawn_p1()
#		spawn_p2.rpc()
#		spawn_p1.rpc()
#		spawn_p2.rpc()
	pass
	
func on_player_dead(player):
	playerDead(player)
	
@rpc
func spawn_p1():
	p1 = playerScene.instantiate()
	p1.name = "Player1"
	p1.position = Vector2(400,400)
	p1.playerId = 1
	
	add_child(p1,true)
	p1.set_multiplayer_authority(1)
	
	p1.connect("dead", _on_player_1_dead)
		


@rpc
func spawn_p2():
	p2 = playerScene.instantiate()
	p2.name = "Player2"
	p2.position = Vector2(500,500)
	p2.playerId = 2
#	var test = Global.multiplayerIds[2]
	add_child(p2, true)
	p2.set_multiplayer_authority(Global.multiplayerIds[2])
#	p2.set_multiplayer_authority(multiplayer.get_unique_id())
	
	p2.connect("dead", _on_player_2_dead)
#	if Global.player1Active:
#		$Player1.add_to_group("activePlayers")
#		$Player1.add_to_group("alivePlayers")
#		$Player1/HeadSprite.modulate = Global.player1Color
#	else:
#		$Player1.queue_free()
#	if Global.player2Active:
#		$Player2.add_to_group("activePlayers")
#		$Player2.add_to_group("alivePlayers")
#		$Player2/HeadSprite.modulate = Global.player2Color
#	else:
#		$Player2.queue_free()
#	if Global.player3Active:
#		$Player3.add_to_group("activePlayers")
#		$Player3.add_to_group("alivePlayers")
#		$Player3/HeadSprite.modulate = Global.player3Color
#	else:
#		$Player3.queue_free()
#	if Global.player4Active:
#		$Player4.add_to_group("activePlayers")
#		$Player4.add_to_group("alivePlayers")
#		$Player4/HeadSprite.modulate = Global.player4Color
#	else:
#		$Player4.queue_free()
#
#	for player in get_tree().get_nodes_in_group("activePlayers"):
#		for child in player.get_children():
#			if child is Timer:
#				timers.append(child)
#		player.show()



func _on_player_1_dead():
	playerDead(p1)

func _on_player_2_dead():
	playerDead(p2)
	
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
#	for player in get_tree().get_nodes_in_group("activePlayers"):
#		player.set_process(false)
	
	await(get_tree().create_timer(2.0).timeout)
	emit_signal("restartNotice")
#	get_tree().reload_current_scene()

func _process(_delta):
	if Global.isMultiplayerActive:
		multiplayerProcess()

func multiplayerProcess():
#	if Global.player1Active:
#	if multiplayer.is_server():
	if p1!= null:
		$HUD/Player1Id.text = str(p1.get_multiplayer_authority())
#	if Global.player2Active:
	if p2!= null:
		$HUD/Player2Id.text = str(p2.get_multiplayer_authority())
	pass	

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
	
