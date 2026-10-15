class_name WaterPower extends Power

@onready var split_sound: AudioStreamPlayer = $NewSplit

var twin_head_scene: PackedScene = preload("res://scenes/twin_head.tscn")
var copies: Array = []

func activate() -> void:
	if twin_head_scene == null or is_active():
		return

	if split_sound:
		split_sound.play()

	# 1. Generamos la copia con el helper del jugador
	var twin = player.spawn_twin(twin_head_scene)
	if twin:
		copies.append(twin)

	# 2. Bloqueo de dirección temporal (mecánica original de agua)
	player.locked_direction = [-1, 1].pick_random()
	player.locked_movement = true
	get_tree().create_timer(0.2).timeout.connect(func():
		player.locked_movement = false
	)

	activated.emit()

func is_active() -> bool:
	# Limpiamos referencias de copias destruidas y vemos si queda alguna viva
	copies = copies.filter(func(c): return is_instance_valid(c) and c.alive)
	return not copies.is_empty()

# Ignora colisiones con las copias de agua
func should_ignore_collision(area: Area2D) -> bool:
	return (area.is_in_group("TwinBodies") or area.is_in_group("twinHeads")) and is_active()

# Intercepta la muerte: si hay copia viva, revivimos en ella
func try_prevent_death() -> bool:
	copies = copies.filter(func(c): return is_instance_valid(c) and c.alive)
	if copies.is_empty():
		return false

	var copy = copies.pop_back()
	if "collider" in copy and is_instance_valid(copy.collider):
		copy.collider.set_deferred("disabled", true)

	# Transferimos posición y rotación del clon al jugador original
	player.position = copy.position
	player.rotation = copy.rotation
	copy.queue_free()

	finished.emit()
	return true # ¡Salvado de la muerte!

func ai_should_activate(_direction: int) -> bool:
	# La IA activa agua si no tiene copias vivas
	return not is_active()
