extends ColorRect

# Path to the next scene to transition to
@export var next_scene_path : String

# Reference to the _AnimationPlayer_ node
@onready var _anim_player := $AnimationPlayer

func _ready() -> void:
	# Plays the animation backward to fade in
	_anim_player.play_backwards("transition_to")
	
func transition_to(next_scene) -> void:
	# Plays the Fade animation and wait until it finishes
	_anim_player.play("transition_to")
	_anim_player.connect("animation_finished", _on_animation_player_animation_finished.bind(next_scene))
	# Changes the scene
	


func _on_animation_player_animation_finished(_anim_name, next_scene ):
	get_tree().change_scene_to_file(next_scene)
