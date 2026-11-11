class_name EarthPower extends Power

@export var fissure_scene: PackedScene
@export var duration: float = 1.2

@onready var timer: Timer = $Timer
@onready var hulk_sound: AudioStreamPlayer = $Hulk

var walker_enabled: bool = false
var burrow_enabled: bool = false

func activate() -> void:
	if is_active():
		return

	player.set_invincible(true)
	player.set_head_visible(false)

	var dur: float = duration
	if _stats() != null:
		dur = stat("earth.duration")

	player.rock_time = dur
	player.on_fresh_path = true
	if fissure_scene:
		player.start_fissure(1, fissure_scene)
	player.gap_delta_sum = 0.0

	if hulk_sound:
		hulk_sound.play()
	
	timer.start(dur)
	activated.emit()

# CAMINANTE DE PIEDRA: Ignora el choque si la roca es tuya
func should_ignore_collision(area: Area2D) -> bool:
	# CAMINANTE DE PIEDRA:
	if area.is_in_group("Fissures") or "fissure" in area.name.to_lower() or "rock" in area.name.to_lower():
		if Global.debug_walker:
			print(">>> [CAMINANTE DE PIEDRA] ¡Atravesaste la roca sin morir!")
			return true

	# EXCAVADOR:
	if area.is_in_group("limits") or "limit" in area.name.to_lower():
		if Global.debug_burrow and is_active():
			print(">>> [EXCAVADOR] ¡Cavando a través del muro!")
			return true

	return false
func _on_timer_timeout() -> void:
	player.set_invincible(false)
	player.set_head_visible(true)
	
	# EXCAVADOR: Si se terminó el tiempo y quedaste adentro de una pared, mueres aplastado
	var es_excavador = burrow_enabled or (_stats() != null and stat("earth.burrow") >= 1.0)
	if es_excavador and player.has_method("is_inside_wall") and player.is_inside_wall():
		print("¡APLASTADO POR LA ROCA!")
		player.crush_death()
		
	finished.emit()

func is_active() -> bool:
	return not timer.is_stopped()

func ai_should_activate(_direction: int) -> bool:
	var raycaster = player.get_node_or_null("Raycaster")
	if raycaster:
		return raycaster.collision_distance("Up") < 25
	return false
