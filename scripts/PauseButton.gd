extends Button


# Called when the node enters the scene tree for the first time.
func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	

func _process(_delta):
	if Input.is_action_pressed("Pause"):
		if get_tree().paused:
			hide()
			get_tree().paused = false
		if not get_tree().paused:
			show()
			get_tree().paused = true
	pass # Replace with function body.
#func _input(event):
#	if event.is_action_pressed("Pause"):
#		if get_tree().paused:
#			hide()
#			get_tree().paused = false
#		if not get_tree().paused:
#			show()
#			get_tree().paused = true
