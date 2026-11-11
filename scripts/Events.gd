extends Node2D

@export var shroomScene : PackedScene

var topLimit
var bottomLimit

@onready var rng = RandomNumberGenerator.new()

func _ready():
	if Global.shrooms_enabled():
		$ShroomTimer.start()


## How far from a level's walls a shroom must be, and from another shroom on a spot
const SHROOM_WALL_MARGIN = 40.0
const SHROOM_SPOT_TAKEN = 40.0

func _on_shroom_timer_timeout():
	var point = _shroom_point()
	if point == null:
		return
	var shroom = shroomScene.instantiate() as Node2D
	shroom.set_as_top_level(true)
	shroom.show()
#	shroom.apply_scale(Vector2(2,2))
	shroom.set_global_position(point)
	add_child(shroom)
	shroom.add_to_group("Shrooms")
	pass # Replace with function body.
	
# Where the next shroom goes: one of the level's shroom spots that's free, or a random
# point away from its walls (null = every spot is taken)
func _shroom_point():
	var level = get_parent().get("level")
	var spots = level.shroom_spots() if is_instance_valid(level) else []
	if not spots.is_empty():
		var shrooms = get_tree().get_nodes_in_group("Shrooms")
		var free = spots.filter(func(spot): return not shrooms.any(func(s): return s.global_position.distance_to(spot) < SHROOM_SPOT_TAKEN))
		if free.is_empty():
			return null
		return free[rng.randi_range(0, free.size() - 1)]
	var point = Vector2.ZERO
	for attempt in 20:
		point = Vector2(rng.randf_range(0, get_viewport_rect().size.x), rng.randf_range(topLimit, bottomLimit))
		if not is_instance_valid(level) or level.is_clear(point, SHROOM_WALL_MARGIN):
			break
	return point

func set_space(top,bottom):
	topLimit = top
	bottomLimit = bottom
	
