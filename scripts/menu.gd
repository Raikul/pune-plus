extends Control

var Options 
@onready var shrooms_button =  $CanvasLayer/Modifiers/PanelContainer/ShroomsContainer/ShroomsButton
func _ready():
	
	Options = $CanvasLayer/Options
	Options.hide()
	shrooms_button.button_pressed = Global.shrooms
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
	pass

func _on_play_pressed():
	$CanvasLayer/PlayerSetup.show()
	$CanvasLayer/TopMenu.hide()
	$CanvasLayer/Modifiers.show()
	$CanvasLayer/PlayerSetup/PanelContainer/PlayerSetup.recalculate_all_labels()

func _on_options_pressed():
	Options.show()
	$CanvasLayer/TopMenu.hide()
#	get_tree().change_scene_to_file("res://options.tscn") # Replace with function body.
	pass # Replace with function body.

func _on_quit_pressed():
	get_tree().quit() # Replace with function body.

func _on_options_back_button_pressed():
	Options.hide()
	$CanvasLayer/TopMenu.show()

func _on_player_setup_go():
	get_tree().change_scene_to_file("res://scenes/Playground.tscn")

func _on_player_setup_back():
	$CanvasLayer/PlayerSetup.hide()
	$CanvasLayer/TopMenu.show()
	$CanvasLayer/Modifiers.hide()

func _on_change_log_button_pressed():
	var details = $CanvasLayer/ChangeLog/VBoxContainer/ChangeLogDetailsContainer
	if details.visible == true:
		details.hide()
	else :
		details.show()

func _on_shrooms_button_toggled(button_pressed):
	Global.shrooms = button_pressed

#Region Multiplayer
func _on_multiplayer_pressed():
	get_tree().change_scene_to_file("res://scenes/multiplayer_setup.tscn")
