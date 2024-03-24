extends Node2D
class_name Fissure

var texture_path = "res://assets/jorge-resources/Powers/Earth/"
@onready var fissure_rect: TextureRect = $FissureBody
var _fissure_step: = 1
var delta_sum : float = 0
var next_created := false
var fissure_gap := 0.1
var maximum_step_number := 8
var available_bodies : Array
var available_ends : Array
signal fissure_ready(step)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta: float) -> void:
	delta_sum += delta
	if delta_sum >= fissure_gap and !next_created:
		next_created = true
		emit_signal("fissure_ready", _fissure_step + 1)

func set_body(fissure_step: int, body_list = []) -> Array:
	if fissure_step == 1:
		var index = 1
		while index < maximum_step_number:
			available_bodies.append(index)
			index += 1
		#index = 0
		#while index < 4:
			#available_ends.append(index)
			#index += 1
		
	if body_list!=[]:
		available_bodies = body_list
	_fissure_step = fissure_step
	#var random_end = available_ends[randi_range(0,available_ends.size())]
	var random_end = randi_range(1,4)
	if fissure_step == 1 or fissure_step == maximum_step_number:
		$FissureBody.texture = load(texture_path + "inicio_" + str(random_end) + ".png")
		#available_ends.erase(random_end)
		if fissure_step == 1:
			$FissureBody.set_flip_v(true)
	else: 
		var random_body = available_bodies[randi_range(0,available_bodies.size() - 1)]
		available_bodies.erase(random_body)
		$FissureBody.texture = load(texture_path + "cuerpo_" + str(random_body) + ".png")
		var random_flip = randi_range(0,1)
		if random_flip:
			$FissureBody.set_flip_h(true)
	
	return available_bodies
