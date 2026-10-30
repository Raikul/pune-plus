class_name WaterPower extends Power

var twin_head_scene: PackedScene = preload("res://scenes/twin_head.tscn")
@onready var split_sound: AudioStreamPlayer = $NewSplit

# APAGADO POR DEFECTO (1 = divide en 2 cabezas, 2 = divide en 3 cabezas)
static var extra_clone_enabled: bool = false
var copies: Array = []

func activate() -> void:
	if twin_head_scene == null or is_active():
		return

	if split_sound:
		split_sound.play()

	# Cantidad de clones a generar: 1 normal (2 cabezas) o 2 clones (3 cabezas)
	var cantidad_clones: int = 2 if extra_clone_enabled else 1

	for i in range(cantidad_clones):
		var twin = player.spawn_twin(twin_head_scene)
		if twin:
			# Si son 2 clones, se abren en abanico (uno a la izquierda y otro a la derecha)
			if cantidad_clones == 2:
				var desvio = 0.55 if i == 0 else -0.55
				twin.rotation = player.rotation + desvio
			copies.append(twin)

	# Bloqueo de dirección temporal original
	player.locked_direction = [-1, 1].pick_random()
	player.locked_movement = true
	get_tree().create_timer(0.2).timeout.connect(func():
		player.locked_movement = false
	)

	activated.emit()

func is_active() -> bool:
	copies = copies.filter(func(c): return is_instance_valid(c) and c.alive)
	return not copies.is_empty()

func should_ignore_collision(area: Area2D) -> bool:
	return (area.is_in_group("TwinBodies") or area.is_in_group("twinHeads")) and is_active()

# Si tienes 2 clones vivos, podrás revivir DOS veces seguidas
func try_prevent_death() -> bool:
	copies = copies.filter(func(c): return is_instance_valid(c) and c.alive)
	if copies.is_empty():
		return false

	var copy = copies.pop_back()
	if "collider" in copy and is_instance_valid(copy.collider):
		copy.collider.set_deferred("disabled", true)

	player.position = copy.position
	player.rotation = copy.rotation
	copy.queue_free()

	finished.emit()
	return true

func ai_should_activate(_direction: int) -> bool:
	return not is_active()
