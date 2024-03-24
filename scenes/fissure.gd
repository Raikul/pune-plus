extends Node2D
class_name Fissure

var texture_path = "res://assets/jorge-resources/Powers/Earth/"
@onready var fissure_rect: TextureRect = $FissureBody
var _fissure_step: = 1
var delta_sum : float = 0
var next_created := false
var fissure_gap := 0.1
var maximum_step_number := 8
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

func set_body(fissure_step: int) -> void:
	_fissure_step = fissure_step
	var random_number = randi_range(1,4)
	if fissure_step == 1 or fissure_step == maximum_step_number:
		$FissureBody.texture = load(texture_path + "inicio " + str(random_number) + ".png")
		if fissure_step == 1:
			$FissureBody.set_flip_h(true)
	else: 
		$FissureBody.texture = load(texture_path + "cuerpo " + str(random_number) + ".png")
