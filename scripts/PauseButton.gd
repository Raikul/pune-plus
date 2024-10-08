extends Button


# Called when the node enters the scene tree for the first time.
func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	

func _process(_delta):
	if Input.is_action_just_pressed("Pause"):
		if visible and get_tree().paused:
			hide()
			get_tree().paused = false
		elif not get_tree().paused:
			show()
			get_tree().paused = true
	
	if Input.is_action_just_pressed("ui_cancel"):
		if visible and get_tree().paused:
			get_parent().restart(0)
	
