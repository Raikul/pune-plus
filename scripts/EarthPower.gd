class_name EarthPower extends Power

@export var fissure_scene: PackedScene
@export var duration: float = 1.2

@onready var timer: Timer = $Timer
@onready var hulk_sound: AudioStreamPlayer = $Hulk

func activate() -> void:
	if is_active():
		return

	# 1. Invencibilidad
	# (The trail used to turn invisible here, but it was still solid: snakes died on
	# walls they couldn't see)
	player.set_invincible(true)
	player.set_head_visible(false)

	var dur: float = duration
	if player.stats != null:
		dur = player.stats.get_stat("earth.duration")

	# 2. Rocky path: its width grows with earth.scale (Tectonic Bulk); it lasts as long
	# as the invincibility
	player.rock_time = dur
	player.on_fresh_path = true
	if fissure_scene:
		player.start_fissure(1, fissure_scene)
	# The first rock needs a physics frame before the head overlaps it: no trail meanwhile
	player.gap_delta_sum = 0.0

	if hulk_sound:
		hulk_sound.play()
	
	timer.start(dur)
	activated.emit()

func _on_timer_timeout() -> void:
	# Vuelve al tamaño normal y quita invencibilidad
	player.set_invincible(false)
	player.set_head_visible(true)
	finished.emit()

func is_active() -> bool:
	return not timer.is_stopped()

func ai_should_activate(_direction: int) -> bool:
	var raycaster = player.get_node_or_null("Raycaster")
	if raycaster:
		return raycaster.collision_distance("Up") < 25
	return false
