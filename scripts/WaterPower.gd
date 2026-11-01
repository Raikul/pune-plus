class_name WaterPower extends Power

var twin_head_scene: PackedScene = preload("res://scenes/twin_head.tscn")
@onready var split_sound: AudioStreamPlayer = $NewSplit

var copies: Array = []

# Twins it can have alive at once, and how many one cast summons (upgrades raise both)
func max_twins() -> int:
	return int(player.stats.get_stat("water.max_twins")) if player.stats != null else 1

func twins_per_cast() -> int:
	return int(player.stats.get_stat("water.twins_per_cast")) if player.stats != null else 1

func alive_twins() -> int:
	copies = copies.filter(func(c): return is_instance_valid(c) and c.alive)
	return copies.size()

# With every twin already out, the power can't be cast (and doesn't go on cooldown)
func can_activate() -> bool:
	return alive_twins() < max_twins()

func activate() -> void:
	if twin_head_scene == null or not can_activate():
		return

	if split_sound:
		split_sound.play()

	# One twin per cast, two with Twin Burst, never past the maximum
	var cantidad_clones: int = mini(twins_per_cast(), max_twins() - alive_twins())
	var lasting = player.stats != null and player.stats.get_stat("water.lasting_twin") >= 1.0

	var spawned = []
	for i in range(cantidad_clones):
		var twin = player.spawn_twin(twin_head_scene)
		if twin:
			# Lasting Twin: its trail stays aqua and never blocks the water snake
			twin.sheds_trail = not lasting
			# Si son 2 clones, se abren en abanico (uno a la izquierda y otro a la derecha)
			if cantidad_clones == 2:
				var desvio = 0.55 if i == 0 else -0.55
				twin.rotation = player.rotation + desvio
				# The twin's forced split keeps turning the way it was fanned out
				twin.split_direction = 1 if desvio > 0 else -1
			copies.append(twin)
			spawned.append(twin)
	if spawned.is_empty():
		return

	# The snake turns away from its twin while they split (straight between two twins)
	player.locked_direction = -spawned.back().split_direction if spawned.size() == 1 else 0
	player.locked_movement = true
	get_tree().create_timer(0.2).timeout.connect(func():
		player.locked_movement = false
	)

	activated.emit()

func is_active() -> bool:
	return alive_twins() > 0

# Twin trails never hurt their water snake, even after the twin is gone: segments
# block it again only once they shed back to the water color (twin_head.gd removes
# them from "TwinBodies"). This also makes landing on a twin's tail safe.
func should_ignore_collision(area: Area2D) -> bool:
	return area.is_in_group("TwinBodies") or area.is_in_group("twinHeads")

# Each living twin saves the water snake once (the newest goes first)
func try_prevent_death() -> bool:
	copies = copies.filter(func(c): return is_instance_valid(c) and c.alive)
	if copies.is_empty():
		return false

	var copy = copies.pop_back()
	if "collider" in copy and is_instance_valid(copy.collider):
		copy.collider.set_deferred("disabled", true)

	# Small splash where the snake leaves; the twin's absorb() makes the big one where it lands
	PowerFx.splash(player.get_parent(), player.global_position, Color(Global.playerColors[player.playerId]), 0.6)
	player.position = copy.position
	player.rotation = copy.rotation
	# The twin's head goes, but its trail stays on the field
	copy.absorb()

	finished.emit()
	return true

func ai_should_activate(_direction: int) -> bool:
	return can_activate()
