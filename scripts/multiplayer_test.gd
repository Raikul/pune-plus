extends Node2D

var peer 
@export var player_scene : PackedScene
@export var Address ="127.0.0.1"
@export var port = 8910

signal hosted
signal joined


func _ready():
	multiplayer.peer_connected.connect(peer_connected)
	multiplayer.peer_disconnected.connect(peer_disconnected)
	multiplayer.connected_to_server.connect(connected_to_server)
	multiplayer.connection_failed.connect(connection_failed)

func peer_connected(id):
	print("Player Connected" + str(id))
	
	
func peer_disconnected(id):
	print("Player Disconnected" + str(id))

func connected_to_server():
	print ("Connected to Server")
	SendPlayerInformation.rpc_id(1, $NameEdit.text, multiplayer.get_unique_id())
	
func connection_failed():
	print("Couldn´t connect")
	
@rpc("any_peer")
func SendPlayerInformation(name,id):
	if not Global.Players.has(id):
		Global.Players[id] = {
			"name" : name,
			"id" : id,
			"score" : 0
		}
	if multiplayer.is_server():
		for i in Global.Players:
			SendPlayerInformation.rpc(Global.Players[i].name,i)

func _on_host_pressed():
	peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(port,2)
	if error != OK:
		print("Cannot host: " + str(error))
		return
	multiplayer.multiplayer_peer = peer
#	multiplayer.peer_connected.connect(_add_player)
	SendPlayerInformation($NameEdit.text, multiplayer.get_unique_id())
#	hosted.emit()
#	_add_player()
	pass # Replace with function body.


func _add_player(id):
	Global.multiplayerIds[2] = id
	joined.emit()
#	var player = player_scene.instantiate()
#	if id == 1:
#		player.name = "Player1"
#		player.position = Vector2(400,400)
##		Global.player1Active = true
#	if id == 2:
#		player.name = "Player2"
##		Global.player2Active = true
#	player.playerId = id
#	call_deferred("add_child", player)
	pass

func _on_join_pressed():
#	Global.player2Active = true
	peer = ENetMultiplayerPeer.new()
	peer.create_client(Address, port)
	multiplayer.multiplayer_peer = peer
	print(multiplayer.get_unique_id())
	Global.multiplayerIds[2] = multiplayer.get_unique_id()
	print("I connected to the server at IP", Address)
	
	pass # Replace with function body.


func _on_address_edit_text_submitted(new_text):
	Address = new_text
	pass # Replace with function body.


func _on_port_edit_text_submitted(new_text):
	port = new_text.to_int()
	pass # Replace with function body.
