class_name EarthPower extends Power

@export var fissure_scene: PackedScene
@export var duration: float = 2.0  # Duración base de la invencibilidad

@onready var timer: Timer = $Timer
@onready var hulk_sound: AudioStreamPlayer = $Hulk

func activate() -> void:
	if is_active():
		return # Ya está activo, evitamos reiniciar bruscamente

	# 1. Hacemos invencible al jugador y ocultamos la cabeza
	player.set_invincible(true)
	player.head_modulate.a = 0

	# 2. Generamos la fisura (usando la función que ya tiene Player)
	if fissure_scene:
		player.start_fissure(1, fissure_scene)

	# 3. Sonido y timer
	if hulk_sound:
		hulk_sound.play()
	
	# Si en el futuro tenemos stats, aquí leerá player.stats.get_stat("earth.duration")
	timer.start(duration)
	activated.emit()

func _on_timer_timeout() -> void:
	# Al terminar la invulnerabilidad, restauramos al jugador
	player.set_invincible(false)
	player.head_modulate.a = 1.0
	finished.emit()

func is_active() -> bool:
	return not timer.is_stopped()

func ai_should_activate(_direction: int) -> bool:
	# Lógica original de la IA de Tierra: si está a menos de 25px de chocar de frente
	var raycaster = player.get_node_or_null("Raycaster")
	if raycaster:
		return raycaster.collision_distance("Up") < 25
	return false
