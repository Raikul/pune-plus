extends VBoxContainer

func set_ai_status(status):
	$"VBoxContainer/Enable AI".button_pressed = status
	_on_enable_ai_toggled(status)
	
func _on_enable_ai_toggled(button_pressed):

	if button_pressed:
		$"VBoxContainer/Enable AI".text = "Disable AI"
	else: 
		$"VBoxContainer/Enable AI".text = "Enable AI"
	pass # Replace with function body.
