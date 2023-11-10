extends Control

signal back

func _on_back_pressed():
	emit_signal("back")
	pass # Replace with function body.


func _on_reset_controls_pressed():
	InputMap.load_from_project_settings()
	pass # Replace with function body.
