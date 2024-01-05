class_name Shroom extends Node2D

var animation = "shroomPack"
func _ready():
	var frameCount = $ShroomSprite.get_sprite_frames().get_frame_count(animation)
	var frameNumber = RandomNumberGenerator.new().randi_range(0,frameCount-1)
	$ShroomSprite.frame = frameNumber
#	print("spawnedShroom")
	
