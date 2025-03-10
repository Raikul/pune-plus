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
#@onready var multiscene = load("res://scenes/multiplayer_playground.tscn")

func _ready():
	P1Box = $"PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/1"
	P2Box = $"PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/2"
	P3Box = $"PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/3"
	P4Box = $"PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/4"
	P1Box.set_ai_status(Global.AI_Enabled[1])
	P2Box.set_ai_status(Global.AI_Enabled[2])
	P3Box.set_ai_status(Global.AI_Enabled[3])
	P4Box.set_ai_status(Global.AI_Enabled[4])	
	

func recalculate_all_labels():
	_on_redefine_keys_recalculate_labels(1)
	_on_redefine_keys_recalculate_labels(2)
	_on_redefine_keys_recalculate_labels(3)
	_on_redefine_keys_recalculate_labels(4)
	
	P1Box.get_node("VBoxContainer/Select").grab_focus.call_deferred()
	
func _on_p_1on_pressed():
	player1Active = not player1Active
	activatePlayer(player1Active, P1Box, Global.playerColors[1])
#	activatePlayer(player1Active, P1Box,Color("1ab2ff"))
	
func _on_p_2on_pressed():
	player2Active = not player2Active
	activatePlayer(player2Active, P2Box, Global.playerColors[2])
#	activatePlayer(player2Active, P2Box, Color("aecd53"))

func _on_p_3on_pressed():
	player3Active = not player3Active
	activatePlayer(player3Active, P3Box, Global.playerColors[3])
#	activatePlayer(player3Active, P3Box, Color("e8a547"))

func _on_p_4on_pressed():
	player4Active = not player4Active
	activatePlayer(player4Active, P4Box, Global.playerColors[4])
#	activatePlayer(player4Active, P4Box, Color("13c9ee"))

func activatePlayer(active, playerBox, color):
#	var labelNode = playerBox.get_node("PanelContainer").get_node("Label")
	if active:
		playerBox.modulate = color
#		playerBox.get_node("TextureRect").modulate = color
		playerBox.get_node("VBoxContainer/Select").text = "Deselect"
	else :
		playerBox.modulate = Color.WHITE
#		playerBox.get_node("TextureRect").modulate = Color.WHITE
		playerBox.get_node("VBoxContainer/Select").text = "Select"
	
func _on_color_picker_color_changed(color):
	P4Box.get_node("Label").modulate = color
	P4Box.get_node("TextureRect").modulate = color

func _on_back_pressed():
	back.emit()

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

@rpc("any_peer","call_local")
func StartGame():
#	var scene = multiscene.instantiate()
#	get_tree().root.add_child(scene)
#	scene.connect("restartNotice", reboot.bind(scene))
	self.hide()
	
func reboot(_scene):
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
	var label
	
	for i in InputMap.action_get_events("Player"+str(playerId)+control):
		if text != "":
			text += " / "
		text +=  i.as_text().rstrip("(Physical)")
		
		
	if control == "Up":
		label =  inputList.get_node(control).get_node("MarginContainer/PanelContainer").get_node(control)
	else: label = inputList.get_node(control).get_node(control)
	
	var string_size = label.get_theme_font("font") \
	.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.get_theme_font_size("font_size"))
#	print(string_size)
	label.set_text(text)
	string_size = label.get_theme_font("font") \
	.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.get_theme_font_size("font_size"))
#	print(string_size)
	if string_size.x > 300:
		var ls = LabelSettings.new()
		ls.set_font_size(44)
		label.set_label_settings(ls)
		label.set_text(label.text.substr(0,20))
	#if label.text .size() > 300:
		#label.text.substr(300)

func _on_enable_ai_toggled(button_pressed, player_id):
	#Connected through Scene - TODO: Connect through code
	Global.AI_Enabled[player_id] = button_pressed
	if button_pressed: enable_player(player_id)
	pass # Replace with function body.

func enable_player(player_id:int) -> void:
	match player_id:
		1:
			if !player1Active : _on_p_1on_pressed()
		2:
			if !player2Active : _on_p_2on_pressed()
		3:
			if !player3Active : _on_p_3on_pressed()
		4:
			if !player4Active : _on_p_4on_pressed()
