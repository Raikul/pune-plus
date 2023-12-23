extends Node2D

var scored = false
var timers = []
var gameEnded = false
#
#@onready var player1 = $Node/Player1
#@onready var player2 = $Node/Player2
@export var playerScene : PackedScene
var p1
var p2
signal restartNotice

@onready var nextRound = load("res://scenes/multiplayer_playground.tscn")

func _ready():
#	if multiplayer.is_server():
		spawnplayers()
#	if (multiplayer.is_server()):
	
	
func spawnplayers():
	var index = 0
	for i in Global.Players:
		var currentPlayer = playerScene.instantiate()
		currentPlayer.playerId = index +1
		currentPlayer.name = str(Global.Players[i].id)
#		currentPlayer.name = "Player"+str(index + 1)
		add_child(currentPlayer, true)
		currentPlayer.add_to_group("alivePlayers")
		currentPlayer.add_to_group("activePlayers")
		for spawn in get_tree().get_nodes_in_group("PlayerSpawnPoint"):
#			spawn is Node2D
			if spawn.name == str(index):
				currentPlayer.global_position = spawn.global_position
				currentPlayer.rotate(spawn.rotation)
				if not currentPlayer.is_connected("dead", on_player_dead.bind(currentPlayer)):
					currentPlayer.connect("dead",on_player_dead.bind(currentPlayer))
					currentPlayer.connect("score",on_player_scored.bind(currentPlayer))
		index += 1		
#				currentPlayer.playerId = index +1
	
func on_player_dead(player):
	playerDead(player)
	
func on_player_scored(player):
	
#	print(Global.Players[player.playerId -1])
#	get_node("a")
	match player.playerId:
		1:
			Global.player1Score += 1
			if Global.player1Score >= Global.scoreToReach:
				finishGame(1)
		2:
			Global.player2Score += 1
			if Global.player2Score >= Global.scoreToReach:
				finishGame(2)
		3:
			Global.player3Score += 1
			if Global.player3Score >= Global.scoreToReach:
				finishGame(3)
		4:
			Global.player4Score += 1
			if Global.player4Score >= Global.scoreToReach:
				finishGame(4)
			
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

#func _on_player_1_dead():
#	playerDead(p1)
#
#func _on_player_2_dead():
#	playerDead(p2)
#
#func _on_player_3_dead():
#	playerDead($Player3)
#
#func _on_player_4_dead():
#	playerDead($Player4)
#
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
		
	await(get_tree().create_timer(2.0).timeout)
	for player in get_tree().get_nodes_in_group("activePlayers"):
		player.queue_free()
	await(get_tree().create_timer(1.0).timeout)
	if multiplayer.is_server():
		reboot.rpc()
#	

@rpc("any_peer","call_local", "reliable")
func reboot():
#	if multiplayer.is_server():
	spawnplayers()	
#	var scene = nextRound.instantiate()
#
#	get_tree().root.add_child(scene)
#	self.queue_free()
#	scene.connect("restartNotice", reboot.bind(scene))
	
	pass

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
	
