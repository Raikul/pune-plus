extends Control
var player1Active = false
var player2Active = false
var player3Active = false
var player4Active = false

var P1Box
var P2Box
var P3Box
var P4Box

signal back
signal go
signal multigo
@onready var multiscene = load("res://scenes/multiplayer_playground.tscn")

func _ready():
	P1Box = $PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/P1Vbox
	P2Box = $PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/P2Vbox
	P3Box = $PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/P3Vbox
	P4Box = $PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/P4Vbox

	
#	_on_p_1on_pressed()
#	_on_p_2on_pressed()
func _process(_delta):
	pass
	
func _on_p_1on_pressed():
	player1Active = not player1Active
	activatePlayer(player1Active, P1Box,Color("775193"))
	

func _on_p_2on_pressed():
	player2Active = not player2Active
	activatePlayer(player2Active, P2Box, Color("aecd53"))
	pass # Replace with function body.


func _on_p_3on_pressed():
	player3Active = not player3Active
	activatePlayer(player3Active, P3Box, Color("e8a547"))
	pass # Replace with function body.


func _on_p_4on_pressed():
	player4Active = not player4Active
	activatePlayer(player4Active, P4Box, Color("13c9ee"))
	pass # Replace with function body.

func activatePlayer(active, playerBox, color):
	if active:
		playerBox.get_node("Label").modulate = color
		playerBox.get_node("TextureRect").modulate = color
		playerBox.get_node("Select").text = "Deselect"
	else :
		playerBox.get_node("Label").modulate = Color.WHITE
		playerBox.get_node("TextureRect").modulate = Color.WHITE
		playerBox.get_node("Select").text = "Select"
	


func _on_color_picker_color_changed(color):
	P4Box.get_node("Label").modulate = color
	P4Box.get_node("TextureRect").modulate = color
	pass # Replace with function body.


func _on_back_pressed():
	back.emit()
	pass # Replace with function body.


func _on_go_pressed():
	Global.player1Active = player1Active
	Global.player2Active = player2Active
	Global.player3Active = player3Active
	Global.player4Active = player4Active
	go.emit()
	pass # Replace with function body.

@rpc("any_peer","call_local")
func StartGame():
	var scene = multiscene.instantiate()
	get_tree().root.add_child(scene)
	scene.connect("restartNotice", reboot.bind(scene))
	self.hide()
	
func reboot(scene):
	var newScene = multiscene.instantiate()
	scene.queue_free()
	get_tree().root.add_child(newScene)
	self.hide()

func _on_multi_go():
#	Global.isMultiplayerActive = true
#	Global.player1Active = player1Active
#	Global.player2Active = player2Active
	
	StartGame.rpc()
#	get_tree().change_scene_to_file("res://scenes/multiplayer_playground.tscn")
#	get_tree().change_scene_to_file(multiscene)
	pass # Replace with function body.

func _on_multiplayer_test_hosted():
	_on_p_1on_pressed()
	pass # Replace with function body.


func _on_multiplayer_test_joined():
	_on_p_2on_pressed()
	pass # Replace with function body.
