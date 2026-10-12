extends CanvasLayer

var menu_font = preload("res://assets/fonts/Flat Earth Scribe.TTF")

var label1: Label
var label2: Label
var label3: Label
var label4: Label
var player1cooldown: TextureProgressBar
var player2cooldown: TextureProgressBar
var player3cooldown: TextureProgressBar
var player4cooldown: TextureProgressBar

# Diccionario para saber quién murio
var dead_players = {1: false, 2: false, 3: false, 4: false}

func _ready():
	label1 = $PanelContainer/MarginContainer/HBoxContainer/PanelContainer/HBoxContainer/Player1ScoreLabel
	label2 = $PanelContainer/MarginContainer/HBoxContainer/PanelContainer2/HBoxContainer/Player2ScoreLabel
	label3 = $PanelContainer/MarginContainer/HBoxContainer/PanelContainer3/HBoxContainer/Player3ScoreLabel
	label4 = $PanelContainer/MarginContainer/HBoxContainer/PanelContainer4/HBoxContainer/Player4ScoreLabel
	player1cooldown  = $PanelContainer/MarginContainer/HBoxContainer/PanelContainer/HBoxContainer/Player1Cooldown
	player2cooldown = $PanelContainer/MarginContainer/HBoxContainer/PanelContainer2/HBoxContainer/Player2Cooldown
	player3cooldown = $PanelContainer/MarginContainer/HBoxContainer/PanelContainer3/HBoxContainer/Player3Cooldown
	player4cooldown = $PanelContainer/MarginContainer/HBoxContainer/PanelContainer4/HBoxContainer/Player4Cooldown
	

	label1.add_theme_font_override("font", menu_font)
	label2.add_theme_font_override("font", menu_font)
	label3.add_theme_font_override("font", menu_font)
	label4.add_theme_font_override("font", menu_font)
	
	add_to_group("HUD")

func set_cooldown(player_id, time_left):
	var cooldown
	match player_id:
		1:
			cooldown = player1cooldown
		2:
			cooldown = player2cooldown
		3:
			cooldown = player3cooldown
		4:
			cooldown = player4cooldown
	cooldown.value = time_left

func set_player_dead(player_id: int):
	dead_players[player_id] = true

func reset_labels():
	label1.self_modulate = Color.WHITE
	label2.self_modulate = Color.WHITE
	label3.self_modulate = Color.WHITE
	label4.self_modulate = Color.WHITE
	# Reiniciar el estado de muerte para la siguiente ronda
	for id in dead_players:
		dead_players[id] = false

func _process(_delta):
	var mensaje_muerte = "(DISABLED)"

	if Global.player1Active:
		var texto = str(Global.player1Score)
		if dead_players[1]:
			texto += mensaje_muerte
		label1.text = texto

	if Global.player2Active:	
		var texto = str(Global.player2Score)
		if dead_players[2]:
			texto += mensaje_muerte
		label2.text = texto

	if Global.player3Active:	
		var texto = str(Global.player3Score)
		if dead_players[3]:
			texto += mensaje_muerte
		label3.text = texto

	if Global.player4Active:	
		var texto = str(Global.player4Score)
		if dead_players[4]:
			texto += mensaje_muerte
		label4.text = texto
