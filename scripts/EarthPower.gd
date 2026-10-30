class_name EarthPower extends Power

@export var fissure_scene: PackedScene
@export var duration: float = 2.0

@onready var timer: Timer = $Timer
@onready var hulk_sound: AudioStreamPlayer = $Hulk

func activate() -> void:
	if is_active():
		return

	# 1. Invencibilidad
	player.set_invincible(true)
	player.head_modulate.a = 0

	# 2. Agrandar colisión (2.0x por defecto o lo que diga la consola/stats)
	var scale_mult: float = 2.0
	if player.stats != null:
		scale_mult = player.stats.get_stat("earth.scale")
	player.set_earth_collision_scale(scale_mult)

	# 3. Fisuras y sonido
	if fissure_scene:
		player.start_fissure(1, fissure_scene)

	if hulk_sound:
		hulk_sound.play()
	
	var dur: float = duration
	if player.stats != null:
		dur = player.stats.get_stat("earth.duration")
	timer.start(dur)
	activated.emit()

func _on_timer_timeout() -> void:
	# Vuelve al tamaño normal y quita invencibilidad
	player.set_invincible(false)
	player.head_modulate.a = 1.0
	player.reset_earth_collision_scale()
	finished.emit()

func is_active() -> bool:
	return not timer.is_stopped()

func ai_should_activate(_direction: int) -> bool:
	var raycaster = player.get_node_or_null("Raycaster")
	if raycaster:
		return raycaster.collision_distance("Up") < 25
	return false
