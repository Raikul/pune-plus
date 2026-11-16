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
	_fire(null)

# --- Dual Ball and Flamethrower: held powers ---
# Dual Ball: two arrows open up while held; letting go throws a small fireball down each
# Flamethrower: a cone of fire once it is held past a tap (a quick tap still throws the fireball)
const DUAL_MIN_SPREAD = 0.06
const DUAL_MAX_SPREAD = 0.7
const DUAL_TIME = 1.0
const DUAL_SIZE = 0.65
const FLAME_MAX = 1.5
## Held less than this, Flamethrower throws a fireball; past it the jet starts
const FLAME_DELAY = 0.2
var dual_fx: HoldFx
var jet: FlameJet

func has_dual() -> bool:
	return _stats() != null and stat("fire.dual") >= 1.0

func has_flamethrower() -> bool:
	return _stats() != null and stat("fire.flamethrower") >= 1.0

func hold_mode() -> bool:
	return has_dual() or has_flamethrower()

func hold_max() -> float:
	return FLAME_MAX if has_flamethrower() else 0.0

func hold_begin() -> void:
	if has_flamethrower():
		pass # The jet starts in hold_update once it is clear it isn't a tap
	else:
		dual_fx = HoldFx.spawn(player, "dual", Color(Global.playerColors[player.playerId]))
		dual_fx.spread = DUAL_MIN_SPREAD

func hold_update(seconds: float, _delta: float) -> void:
	if has_flamethrower() and not is_instance_valid(jet) and seconds >= FLAME_DELAY:
		jet = FlameJet.spawn(player)
		if has_node("Shoot"):
			$Shoot.play()
	if is_instance_valid(dual_fx):
		dual_fx.progress = minf(seconds / DUAL_TIME, 1.0)
		dual_fx.spread = _dual_spread(seconds)

func hold_cancel() -> void:
	if is_instance_valid(dual_fx):
		dual_fx.queue_free()
	if is_instance_valid(jet):
		jet.put_out()
	jet = null

func activate_held(seconds: float) -> void:
	if has_flamethrower():
		if seconds < FLAME_DELAY:
			_fire(null) # A tap: the plain fireball
			jet = null
			return
		if is_instance_valid(jet):
			jet.stop() # Held here: it has been burning all along
		else:
			# Another machine's snake: its jet plays out now, as long as it was held
			var remote_jet = FlameJet.spawn(player)
			remote_jet.run_for(seconds - FLAME_DELAY)
		jet = null
		activated.emit()
	elif has_dual():
		if is_instance_valid(dual_fx):
			dual_fx.queue_free()
		var spread = _dual_spread(seconds)
		_fire(null, spread, DUAL_SIZE)
		_fire(null, -spread, DUAL_SIZE)
	else:
		_fire(null)

func _dual_spread(seconds: float) -> float:
	return lerpf(DUAL_MIN_SPREAD, DUAL_MAX_SPREAD, clampf(seconds / DUAL_TIME, 0.0, 1.0))

func ai_hold_time() -> float:
	return 1.0 if has_flamethrower() else 0.5

# Void with Fire and Water held: its twins shoot too (from where they are, where they head)
func shoot_from(origin: Node2D) -> void:
	_fire(origin)

func _fire(origin, turn = 0.0, size = 1.0) -> void:
	if projectile_scene == null:
		return

	var proj = player.spawn_projectile(projectile_scene)
	if origin != null and is_instance_valid(origin):
		proj.global_position = origin.global_position
		proj.rotation = origin.rotation

	# 1. Aplicar Radio / Escala
	var radius_mult: float = 1.0
	if _stats() != null:
		radius_mult = stat("fire.radius")
	proj.rotation += turn
	if size < 1.0:
		proj.use_pixelfx() # Dual Ball's small fireballs have their own look
	proj.scale = Vector2(radius_mult, radius_mult) * size

	# 2. Aplicar Duración en el aire
	# The projectile flies this long, then fades out (projectile.gd); 0 = until it hits something
	var duration: float = DEFAULT_DURATION
	if _stats() != null:
		duration = stat("fire.duration")
	proj.lifetime = duration
	proj.fire_trail = _stats() != null and stat("fire.trail") >= 1.0
	proj.fanned = _stats() != null and stat("fire.fanned") >= 1.0
	proj.bounce = _stats() != null and stat("fire.bounce") >= 1.0
	# Void's borrowed fireball burns purple (its flames and its burst too)
	if player.main_power is VoidPower:
		proj.tint = Global.void_tint()
		proj.modulate = proj.tint

	if has_node("Shoot"):
		$Shoot.play()

	activated.emit()

func ai_should_activate(_direction: int) -> bool:
	var raycaster = player.get_node_or_null("Raycaster")
	if raycaster:
		var up_player = raycaster.get_node_or_null("UpPlayer")
		var is_colliding = up_player.is_colliding() if up_player else false
		# 2v2: never at a teammate in the line of fire (one closer than any wall ahead)
		if is_colliding and player.is_ally(up_player.get_collider()):
			var ally_distance = up_player.get_collision_point().distance_to(raycaster.global_position)
			if ally_distance < raycaster.collision_distance("Up"):
				return false
			is_colliding = false
		var close_distance = raycaster.collision_distance("Up") < 75
		return is_colliding or close_distance
	return false

# Phoenix upgrade: the first death of the round turns the snake to an ember instead
func try_prevent_death() -> bool:
	if phoenix_used or _stats() == null or stat("fire.phoenix") < 1.0:
		return false
	# Down to a duel (one other snake left): rising would only keep the winner waiting
	var others = get_tree().get_nodes_in_group("alivePlayers").filter(func(p): return p != player)
	if others.size() <= 1:
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
