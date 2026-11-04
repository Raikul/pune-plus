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
	# A small ripple as the snake splits (the big splash is for when a twin saves it)
	PowerFx.splash(player.get_parent(), player.global_position, Color(Global.playerColors[player.playerId]), 0.35, 0.55)

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
	if not player.net_remote:
		Global.add_stat(player.playerId, "water_twins", spawned.size())
	# Only the twins veer off: the water snake keeps its course and its player keeps steering

	activated.emit()

# The ready pulse means "a twin is coming if you press": not with every twin already out.
# When a twin is lost and the power was ready all along, the pulse comes then (twin_lost).
func should_pulse_ready() -> bool:
	return can_activate()

# A twin died or the water snake jumped into it: room for a new one. If the power is
# already recharged, pulse now, so the player knows pressing it will make a twin.
func twin_lost() -> void:
	if player.powerAvailable and player.is_in_group("alivePlayers") and not player.net_remote and alive_twins() == max_twins() - 1:
		player.pulse_power_ready()

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
	Global.add_stat(player.playerId, "water_saves")

	finished.emit()
	return true

func ai_should_activate(_direction: int) -> bool:
	return can_activate()
