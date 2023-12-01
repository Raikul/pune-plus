extends Control

var logo_duration = 3

func _input(event):
	if not event is InputEventMouseMotion and not event is InputEventJoypadMotion:
		if event.is_pressed():
			change_to_main_menu()
#	$Transition.transition_to("res://scenes/menu.tscn")
	
func _ready():
	var timer = $Timer
	timer.wait_time = logo_duration
	timer.start()
	
func change_to_main_menu():
	$Transition.transition_to("res://scenes/menu.tscn")
#	get_tree().change_scene_to_file("res://scenes/menu.tscn")
