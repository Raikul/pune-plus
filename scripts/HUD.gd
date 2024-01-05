extends CanvasLayer

var label1: Label
var label2: Label
var label3: Label
var label4: Label
var player1cooldown: TextureProgressBar
var player2cooldown: TextureProgressBar
var player3cooldown: TextureProgressBar
var player4cooldown: TextureProgressBar
#
func _ready():
	label1 = $PanelContainer/MarginContainer/HBoxContainer/PanelContainer/HBoxContainer/Player1ScoreLabel
	label2 = $PanelContainer/MarginContainer/HBoxContainer/PanelContainer2/HBoxContainer/Player2ScoreLabel
	label3 = $PanelContainer/MarginContainer/HBoxContainer/PanelContainer3/HBoxContainer/Player3ScoreLabel
	label4 = $PanelContainer/MarginContainer/HBoxContainer/PanelContainer4/HBoxContainer/Player4ScoreLabel
	player1cooldown  = $PanelContainer/MarginContainer/HBoxContainer/PanelContainer/HBoxContainer/Player1Cooldown
	player2cooldown = $PanelContainer/MarginContainer/HBoxContainer/PanelContainer2/HBoxContainer/Player2Cooldown
	player3cooldown = $PanelContainer/MarginContainer/HBoxContainer/PanelContainer3/HBoxContainer/Player3Cooldown
	player4cooldown = $PanelContainer/MarginContainer/HBoxContainer/PanelContainer4/HBoxContainer/Player4Cooldown
	add_to_group("HUD")

func _process(_delta):
	
	if Global.player1Active:
		label1.text = str(Global.player1Score)
		if is_instance_valid($"../Player1"):
			player1cooldown.value = $"../Player1/CooldownTimer".time_left
	if Global.player2Active:	
		label2.text = str(Global.player2Score)
		if is_instance_valid($"../Player2"):
			player2cooldown.value = $"../Player2/CooldownTimer".time_left
	if Global.player3Active:	
		label3.text = str(Global.player3Score)
		if is_instance_valid($"../Player3"):
			player3cooldown.value = $"../Player3/CooldownTimer".time_left
	if Global.player4Active:	
		label4.text = str(Global.player4Score)
		if is_instance_valid($"../Player4"):
			player4cooldown.value = $"../Player4/CooldownTimer".time_left
		
		
