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
	P1Box = $"PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/1"
	P2Box = $"PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/2"
	P3Box = $"PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/3"
	P4Box = $"PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/4"
	pass

func _process(_delta):
	pass
	
func _on_p_1on_pressed():
	player1Active = not player1Active
	activatePlayer(player1Active, P1Box,Color("1ab2ff"))
#	activatePlayer(player1Active, P1Box,Color("775193"))
	
func _on_p_2on_pressed():
	player2Active = not player2Active
	activatePlayer(player2Active, P2Box, Color("e6bf00"))
#	activatePlayer(player2Active, P2Box, Color("aecd53"))
	pass # Replace with function body.

func _on_p_3on_pressed():
	player3Active = not player3Active
	activatePlayer(player3Active, P3Box, Color("ff401a"))
#	activatePlayer(player3Active, P3Box, Color("e8a547"))
	pass # Replace with function body.

func _on_p_4on_pressed():
	player4Active = not player4Active
	activatePlayer(player4Active, P4Box, Color("00e699"))
#	activatePlayer(player4Active, P4Box, Color("13c9ee"))
	pass # Replace with function body.

func activatePlayer(active, playerBox, color):
	var labelNode = playerBox.get_node("PanelContainer").get_node("Label")
	if active:
		labelNode.modulate = color
		playerBox.get_node("TextureRect").modulate = color
		playerBox.get_node("Select").text = "Deselect"
	else :
		labelNode.modulate = Color.WHITE
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
	Global.player1Score = 0
	Global.player2Score = 0
	Global.player3Score = 0
	Global.player4Score = 0
	go.emit()
	pass # Replace with function body.

@rpc("any_peer","call_local")
func StartGame():
	var scene = multiscene.instantiate()
	get_tree().root.add_child(scene)
	scene.connect("restartNotice", reboot.bind(scene))
	self.hide()
	
func reboot(scene):
	StartGame.rpc()
#	var newScene = multiscene.instantiate()
#	scene.queue_free()
#	get_tree().root.add_child(newScene)
#	self.hide()


#region multi
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
#endregion


func _on_redefine_1_pressed():
	$RedefineKeys.show()
	$RedefineKeys.redefinePlayer(1)

func _on_redefine_2_pressed():
	$RedefineKeys.show()
	$RedefineKeys.redefinePlayer(2)

func _on_redefine_3_pressed():
	$RedefineKeys.show()
	$RedefineKeys.redefinePlayer(3)

func _on_redefine_4_pressed():
	$RedefineKeys.show()
	$RedefineKeys.redefinePlayer(4)

func _on_redefine_keys_recalculate_labels(playerId):
	setKeys(playerId, "Left")
	setKeys(playerId, "Right")
	setKeys(playerId, "Up")
	
func setKeys(playerId, control):
	var playerBoxes = $PanelContainer/MarginContainer/VBoxContainer/HBoxContainer as HBoxContainer
	var inputList = playerBoxes.get_node(str(playerId)).get_node("InputList")
	var text = ""
	for i in InputMap.action_get_events("Player"+str(playerId)+control):
		if text != "":
			text += " / "
		text +=  i.as_text().rstrip("(Physical)")
	var label = inputList.get_node(control)
	var string_size = label.get_theme_font("font") \
	.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.get_theme_font_size("font_size"))
#	print(string_size)
	inputList.get_node(control).set_text(text)
	string_size = label.get_theme_font("font") \
	.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.get_theme_font_size("font_size"))
#	print(string_size)
	if string_size.x > 300:
		var ls = LabelSettings.new()
		ls.set_font_size(44)
		label.set_label_settings(ls)
