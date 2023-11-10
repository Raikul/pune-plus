class_name Shroom extends Node2D


func _ready():
	var frameCount = $ShroomSprite.get_sprite_frames().get_frame_count("altShroomPack")
	var frameNumber = RandomNumberGenerator.new().randi_range(0,frameCount-1)
	$ShroomSprite.frame = frameNumber
	print("spawnedShroom")
	
