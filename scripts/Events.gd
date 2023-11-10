extends Node2D

@export var shroomScene : PackedScene

var topLimit
var bottomLimit

@onready var rng = RandomNumberGenerator.new()

func _ready():
	if Global.shrooms:
		$ShroomTimer.start()


func _on_shroom_timer_timeout():
	var shroom = shroomScene.instantiate() as Node2D
	shroom.set_as_top_level(true)
	var verticalPosition = rng.randf_range(topLimit,bottomLimit)
	var horizontalPosition = rng.randf_range(0,get_viewport_rect().size.x)
	
	shroom.show()
#	shroom.apply_scale(Vector2(2,2))
	shroom.set_global_position(Vector2(horizontalPosition, verticalPosition))
	add_child(shroom)
	pass # Replace with function body.
	
func set_space(top,bottom):
	topLimit = top
	bottomLimit = bottom
	
