extends Node2D

func _process(delta):
	pass
#	if $Up.is_colliding():
#		print("Down")
#		$"..".direction = -1

func return_steering():
	var danger_distance_left = INF
	var danger_distance_right = INF
	var danger_distance_up = INF
	if $UpLeft.is_colliding():
		danger_distance_left = $UpLeft.get_collision_point().distance_to(global_position)
	if $Up.is_colliding():
		danger_distance_up = $UpLeft.get_collision_point().distance_to(global_position)
	if $UpLeft2.is_colliding():
		danger_distance_left = min (danger_distance_left,$UpLeft2.get_collision_point().distance_to(global_position))
	if $UpLeft3.is_colliding():
		danger_distance_left = min (danger_distance_left,$UpLeft3.get_collision_point().distance_to(global_position))
	
	if $UpRight.is_colliding():
		danger_distance_right = $UpRight.get_collision_point().distance_to(global_position)
	if $UpRight2.is_colliding():
		danger_distance_right = min (danger_distance_right,$UpRight2.get_collision_point().distance_to(global_position))
	if $UpRight3.is_colliding():
		danger_distance_right = min (danger_distance_right,$UpRight3.get_collision_point().distance_to(global_position))
		
	danger_distance_left = min(danger_distance_left,danger_distance_up)
	if danger_distance_left > danger_distance_right: return "Left"
	if danger_distance_right > danger_distance_left: return "Right"
