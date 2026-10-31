class_name FirePower extends Power

var projectile_scene: PackedScene = preload("res://scenes/projectile.tscn")
const DEFAULT_DURATION = 2.5
# Phoenix: seconds as an ember before rising again (once per round)
const PHOENIX_WAIT = 10.0
var phoenix_used = false
var ember = null
# While it is an ember the player turns the arrow (Left/Right) to pick where it flies off
const AIM_SPEED = 3.5
var aim = 0.0

func activate() -> void:
	if projectile_scene == null:
		return

	var proj = player.spawn_projectile(projectile_scene)

	# 1. Aplicar Radio / Escala
	var radius_mult: float = 1.0
	if player.stats != null:
		radius_mult = player.stats.get_stat("fire.radius")
	proj.scale = Vector2(radius_mult, radius_mult)

	# 2. Aplicar Duración en el aire
	# The projectile flies this long, then fades out (projectile.gd); 0 = until it hits something
	var duration: float = DEFAULT_DURATION
	if player.stats != null:
		duration = player.stats.get_stat("fire.duration")
	proj.lifetime = duration

	if has_node("Shoot"):
		$Shoot.play()

	activated.emit()

func ai_should_activate(_direction: int) -> bool:
	var raycaster = player.get_node_or_null("Raycaster")
	if raycaster:
		var up_player = raycaster.get_node_or_null("UpPlayer")
		var is_colliding = up_player.is_colliding() if up_player else false
		var close_distance = raycaster.collision_distance("Up") < 75
		return is_colliding or close_distance
	return false

# Phoenix upgrade: the first death of the round turns the snake to an ember instead
func try_prevent_death() -> bool:
	if phoenix_used or player.stats == null or player.stats.get_stat("fire.phoenix") < 1.0:
		return false
	phoenix_used = true
	player.phoenix_ash()
	aim = player.phoenix_rise_point()[1]
	ember = PowerFx.ember(player.get_parent(), player.global_position, Color(Global.playerColors[player.playerId]), PHOENIX_WAIT)
	ember.heading = aim
	# Paused time doesn't count; a round that ended meanwhile cancels the rise
	get_tree().create_timer(PHOENIX_WAIT, false).timeout.connect(_rise)
	return true

func _rise():
	if not is_instance_valid(player) or not player.is_inside_tree() or not player.is_in_group("alivePlayers"):
		return
	var playground = get_tree().current_scene
	if playground and "time_flowing" in playground and not playground.time_flowing:
		return
	if is_instance_valid(ember):
		ember.queue_free()
	player.phoenix_rise(player.phoenix_rise_point()[0], aim)

func _process(delta):
	if not is_instance_valid(ember) or not player.reviving or player.net_remote or player.input_id == 0:
		return
	var direction = 0
	if Input.is_action_pressed("Player" + str(player.input_id) + "Left"):
		direction -= 1
	if Input.is_action_pressed("Player" + str(player.input_id) + "Right"):
		direction += 1
	aim = wrapf(aim + direction * AIM_SPEED * delta, -PI, PI)
	ember.heading = aim

# Online: another machine's fire snake turned to ash or rose
func remote_phoenix(rising, point, heading):
	if rising:
		if is_instance_valid(ember):
			ember.queue_free()
		player.phoenix_rise(point, heading)
	else:
		phoenix_used = true
		player.global_position = point
		player.phoenix_ash()
		ember = PowerFx.ember(player.get_parent(), point, Color(Global.playerColors[player.playerId]), PHOENIX_WAIT)
		ember.heading = heading
