extends VBoxContainer


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


func _on_enable_ai_toggled(button_pressed):
	if button_pressed:
		$"VBoxContainer/Enable AI".text = "Disable AI"
	else: 
		$"VBoxContainer/Enable AI".text = "Enable AI"
	pass # Replace with function body.
