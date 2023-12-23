extends Node2D

var node_paths = ["UpLeft", "Up", "UpLeft2", "UpLeft3", "UpRight", "UpRight2", "UpRight3"]

@onready var u_turn = false

func _process(delta):
	if $UpPlayer.is_colliding():
		print ("player detected")
#	print ($UpLeft.get_collision_point().distance_to(global_position))
	pass
#	if $Up.is_colliding():
#		print("Down")
#		$"..".direction = -1

func return_steering():
#	if is_fully_surrounded() : return "Left"
	var danger_distance_left = INF
	var danger_distance_right = INF
	var danger_distance_up = INF
	if $Up.is_colliding(): 	danger_distance_up = collision_distance("Up")
	if $UpLeft.is_colliding(): 	danger_distance_left = collision_distance("UpLeft")
	if $UpLeft2.is_colliding(): danger_distance_left = min (danger_distance_left,collision_distance("UpLeft2"))
	if $UpLeft3.is_colliding(): danger_distance_left = min (danger_distance_left,collision_distance("UpLeft3"))	
	if $UpRight.is_colliding():	danger_distance_right = collision_distance("UpRight")
	if $UpRight2.is_colliding(): danger_distance_right = min (danger_distance_right,collision_distance("UpRight2"))
	if $UpRight3.is_colliding(): danger_distance_right = min (danger_distance_right,collision_distance("UpRight3"))
		
	danger_distance_left = min(danger_distance_left,danger_distance_up)
	if danger_distance_left > danger_distance_right: return "Left"
	if danger_distance_right > danger_distance_left: return "Right"
	
	var danger_full_left = collision_distance("Left")
	var danger_full_right =  collision_distance("Right")
	if danger_full_left < danger_full_right:
		return "Right"
	elif danger_full_left > danger_full_right:
		return "Left"

func collision_distance(node_path : NodePath):
	return get_node(node_path).get_collision_point().distance_to(global_position)
	
func is_fully_surrounded():
#	if u_turn and $Up.is_colliding() and collistion_distance("Up") < 50:
#		print(str(u_turn) + " : "+ str(collistion_distance("Up")))
#		return true
#	else: u_turn = false
	
	var max_distance = 0
	for node_path in node_paths:
		max_distance = max(max_distance, collision_distance(node_path))
	if max_distance <= 50: 
#		u_turn = true
		return true
	else: return false
	


