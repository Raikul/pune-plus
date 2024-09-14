extends Button


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	

func _process(_delta):
	if Input.is_action_just_pressed("ui_cancel"):
		if visible and get_tree().paused:
			hide()
			get_tree().paused = false
		elif not get_tree().paused:
			show()
			get_tree().paused = true
	
	if Input.is_action_just_pressed("ui_accept"):
		if visible and get_tree().paused:
			get_tree().change_scene_to_file("res://scenes/menu.tscn")


func unpause():
	get_tree().paused = false

func _on_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/menu.tscn")
