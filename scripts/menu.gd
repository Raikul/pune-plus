extends Control

var Options 
func _ready():
	Options = $CanvasLayer/Options
	Options.hide()
	pass

func _on_play_pressed():
	$CanvasLayer/PlayerSetup.show()
	$CanvasLayer/TopMenu.hide()
	$CanvasLayer/Modifiers.show()

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
	pass # Replace with function body.

func _on_player_setup_go():
	get_tree().change_scene_to_file("res://scenes/Playground.tscn")
	pass # Replace with function body.

func _on_player_setup_back():
	$CanvasLayer/PlayerSetup.hide()
	$CanvasLayer/TopMenu.show()
	$CanvasLayer/Modifiers.hide()
	pass # Replace with function body.

func _on_multiplayer_pressed():
#	get_tree().change_scene_to_file("res://scenes/MultiPlayground.tscn")
	get_tree().change_scene_to_file("res://scenes/multiplayer_setup.tscn")
	pass # Replace with function body.

func _on_change_log_button_pressed():
	var details = $CanvasLayer/ChangeLog/VBoxContainer/ChangeLogDetailsContainer
	if details.visible == true:
		details.hide()
	else :
		details.show()
	pass # Replace with function body.
