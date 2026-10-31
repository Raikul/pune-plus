extends Area2D

var angular_speed = PI
var speed = 150.0
var screen_size = Vector2.ZERO
var gap = false
var powerAvailable = true
var colorRect
var invincible = false
var stats: PlayerStats = null

signal dead()
signal score()
## Online: a trail segment was laid by this (local) snake
signal body_laid(body_position, body_rotation)
## Online: this (local) snake used its power. recast: Air's free second jump (no cooldown)
signal power_used(recast)
## Online: this (local) water snake split off a twin
signal twin_spawned(twin)
## Online: this (local) fire snake turned to ash (rising = false) or rose again (Phoenix)
signal phoenix_changed(rising)

var playerId
var main_power: Power
const FISSURE_Z_INDEX = 5
# Earth's rocks: base size of each piece (across, along the path); earth.scale widens them
const FISSURE_SCALE = Vector2(1.0, 1.0)
# Which Player{N} input actions steer this snake (0 = no keys, e.g. an online AI).
# Online each machine numbers its own players from 1, so the first one there uses the Player 1 keys.
var input_id
# Online: another machine owns this snake. NetSession moves it and lays its trail.
var net_remote = false
var steer_direction = 0
# Air's teleport target (see actualizarPuntoDeTransporte): where it would land without walls,
# and whether the walls wrapped it (Wall Warp) or cut it short
var teleport_target_unwrapped = Vector2.ZERO
var teleport_wrapped = false
var teleport_clamped = false
const TELEPORT_WALL_MARGIN = 40.0

# Air's Static Shock: seconds left without power, and with left/right swapped (Scrambler)
var shocked_time = 0.0
var scrambled_time = 0.0
var scrambled_age = 0.0
# Seconds after Air's teleport in which only walls can kill it (no dying on the spot
# it left or landed on)
var teleport_grace = 0.0
const TELEPORT_GRACE = 0.3
# An AI snake acts confused this long, then gets its grip and steers right again
const AI_SCRAMBLE_CONFUSION = 1.5
const SHOCK_COLOR = Color(0.55, 0.85, 1.0)
# Phoenix: dead for now but rising again (not moving, invisible, can't be hit)
var reviving = false

var listOfNodes = []
var snakeBodyScene: PackedScene
var twinHeadScene: PackedScene
@onready var bodyTimer = get_node("BodyTimer")
@onready var gapTimer = get_node("GapTimer")
@onready var gapFrequencyTimer = get_node("GapFrequencyTimer")
@onready var is_water_my_friend = false
@onready var ai_enabled = true
@onready var locked_movement = false
@onready var head_texture: CompressedTexture2D = $HeadSprite.texture
@onready var head_modulate: Color = $HeadSprite.modulate
var locked_direction
var clonable_id
var clonable_name
var gap_delta_sum = 0
#var has_twin_head = false
var left_limit_x
var right_limit_x
var top_limit_y
var bottom_limit_y

func _ready():
	apply_scale(Vector2(0.1,0.1))
	ai_enabled = Global.AI_Enabled[playerId]
	
	twinHeadScene = preload("res://scenes/twin_head.tscn")
	snakeBodyScene = preload("res://scenes/snake_body.tscn")

	gapTimer.connect("timeout", _on_gapTimer_timeout)
	gapFrequencyTimer.connect("timeout", _on_gapFrequencyTimer_timeout)
	
	set_gap_size()
	screen_size = get_viewport_rect().size
	
	# Powers live in their own nodes now (scripts/*Power.gd); the player only handles the cooldown
	$CooldownTimer.connect("timeout", powerReady.bind(Global.playerColors[playerId]))
	update_power_indicator()

	listOfNodes.append(self)
	if input_id == null:
		input_id = playerId
	if playerId != null:
		clonable_id = playerId
		clonable_name = "Player"+str(playerId)
		main_power = Powers.create(playerId)
		if main_power != null:
			add_child(main_power)
			main_power.setup(self)
	# Earth's head and trail are drawn over its rocks, so it can see where it already went
	if main_power is EarthPower:
		$HeadSprite.z_index = FISSURE_Z_INDEX + 2
		$ElementHeadSprite.z_index = FISSURE_Z_INDEX + 2

	actualizarPuntoDeTransporte()

	if stats != null:
		stats.stats_changed.connect(refresh_stats)
		refresh_stats()
func refresh_stats() -> void:
	if stats != null:
		speed = stats.get_stat("speed")
		
func _process(delta):
	if net_remote:
		return
	# 1. Primero siempre actualizamos la mirilla:
	actualizarPuntoDeTransporte()

	# 2. Luego el movimiento y la IA:
	var direction = 0
	if locked_movement: direction = locked_direction
	else:
		if input_id != 0 and Input.is_action_pressed("Player"+str(input_id)+"Left") :direction = -1
		elif input_id != 0 and Input.is_action_pressed("Player"+str(input_id)+"Right"): direction = 1
		elif (ai_enabled and $Raycaster.return_steering() == "Left"): direction = -1
		elif (ai_enabled and $Raycaster.return_steering() == "Right"): direction = 1

	if ai_enabled and powerAvailable: ai_punchy(direction)
	elif ai_enabled and main_power and main_power.ai_should_recast(direction): try_use_power()
	_update_shock(delta)
	teleport_grace = max(teleport_grace - delta, 0.0)
	if scrambled_time > 0 and not (ai_enabled and scrambled_age >= AI_SCRAMBLE_CONFUSION):
		direction = -direction
	steer_direction = direction

	rotation += angular_speed * direction * delta
	var velocity = Vector2.UP.rotated(rotation) * speed
	position += velocity * delta
# Air's landing marker is top-level, so it stays on screen unless hidden (death)
func hide_teleport_marker():
	if has_node("DynamicTeleportNode"):
		$DynamicTeleportNode.hide()

func actualizarPuntoDeTransporte():
	if not has_node("DynamicTeleportNode") or not has_node("FixedTeleportNode"):
		return

	# NOTA: Si solo quieres que se vea con el jugador 3 (aire), deja esta condición.
	# Si estás probando con el jugador 1 o 2, comenta estas líneas temporalmente:
	if playerId != 3 or not is_in_group("alivePlayers"):
		$DynamicTeleportNode.hide()
		return
	else:
		$DynamicTeleportNode.show()
		# Shinier when Air can jump now (power ready or its free second jump), fainter
		# while it recharges or is electrocuted
		var second_jump = main_power != null and main_power.has_method("is_recast_ready") and main_power.is_recast_ready()
		$DynamicTeleportNode.can_jump = (powerAvailable or second_jump) and shocked_time <= 0

	# Tomamos la posición base adelante de la serpiente
	var target_pos : Vector2 = $FixedTeleportNode.global_position
	teleport_target_unwrapped = target_pos
	teleport_wrapped = false
	teleport_clamped = false
	if left_limit_x == null or right_limit_x == null or top_limit_y == null or bottom_limit_y == null:
		$DynamicTeleportNode.global_position = target_pos
		return

	if has_wall_warp():
		# Wall Warp: past a wall, the target comes in from the opposite side
		# --- EJE X ---
		if target_pos.x <= left_limit_x:
			var x_difference = target_pos.x - left_limit_x
			target_pos.x = right_limit_x + x_difference
		elif target_pos.x >= right_limit_x:
			var x_difference = target_pos.x - right_limit_x
			target_pos.x = left_limit_x + x_difference

		# --- EJE Y ---
		if target_pos.y <= top_limit_y:
			var y_difference = target_pos.y - top_limit_y
			target_pos.y = bottom_limit_y + y_difference
		elif target_pos.y >= bottom_limit_y:
			var y_difference = target_pos.y - bottom_limit_y
			target_pos.y = top_limit_y + y_difference
		teleport_wrapped = target_pos != teleport_target_unwrapped
	else:
		# Default: the jump stops short of the wall
		var inside = Vector2(
			clamp(target_pos.x, left_limit_x + TELEPORT_WALL_MARGIN, right_limit_x - TELEPORT_WALL_MARGIN),
			clamp(target_pos.y, top_limit_y + TELEPORT_WALL_MARGIN, bottom_limit_y - TELEPORT_WALL_MARGIN))
		teleport_clamped = inside != target_pos
		target_pos = inside

	# Actualizamos la posición
	$DynamicTeleportNode.global_position = target_pos
func _on_gapTimer_timeout():
	gap = false
	gapFrequencyTimer.start()
	
func _on_gapFrequencyTimer_timeout():
	gap = true
	# Corregido: sin stats se usa el hueco de la opción Gap Size (antes quedaba fijo en 0.6)
	var dur = gapTimer.wait_time
	if stats != null:
		dur = stats.get_stat("gap.time")
	gapTimer.start(max(dur, 0.05))
func _on_bodyTimer_timeout():
#	if not gap:
#		createBody(snakeBodyScene)
	pass

func _physics_process(delta):
	if net_remote:
		return
	# Safety net: a snake that got outside the arena somehow (power, lag) dies instead of
	# wandering off screen forever
	if is_processing() and _outside_arena():
		$CollisionShape2D.set_deferred("disabled", true)
		set_process(false)
		emit_signal("dead")
		return
	gap_delta_sum += delta
	if on_fresh_path and not invincible and not _on_own_rock():
		on_fresh_path = false
	if not gap and not reviving and gap_delta_sum >= 0.05 and not on_fresh_path:
		var body = createBody(snakeBodyScene)
		gap_delta_sum = 0
		body_laid.emit(body.global_position, body.rotation)

func _on_area_entered(area):
	# A remote snake's owner decides its deaths and pickups
	if net_remote:
		return
	if area is Shroom:
		$ShroomEaten.play()
		emit_signal("score")
		area.queue_free()
		return

	# Si el poder activo decide ignorar la colisión (ej. Agua tocando su propio clon):
	if main_power and main_power.should_ignore_collision(area):
		return

	# Earth's stone: deadly like a trail, except its own with the Stone Walker upgrade, or
	# the path it is still on
	if area.is_in_group("Fissures") and (has_stone_walk() or on_fresh_path) and is_ancestor_of(area):
		return

	# Earth's power makes it pass through trails, not walls (it used to slip out of the arena
	# and stay alive off screen)
	if (not invincible and teleport_grace <= 0) or area.is_in_group("limits"):
		if listOfNodes.find(area) == -1:
			# Le preguntamos al poder si puede salvar al jugador de morir (Agua reviviendo)
			if main_power and main_power.try_prevent_death():
				return

			# Muerte normal
			$CollisionShape2D.set_deferred("disabled", true)
			$Split.play()
			set_process(false)
			emit_signal("dead")

# Online: lay a segment of a remote snake where its owner laid it
func create_body_at(body_position, body_rotation):
	var body = createBody(snakeBodyScene)
	body.global_position = body_position
	body.rotation = body_rotation
	return body

# Online: the twin of a remote water snake, moved by NetSession
func spawn_remote_twin():
	is_water_my_friend = true
	var twin = createBody(twinHeadScene)
	twin.net_remote = true
	twin.bufferListOfNodes = listOfNodes
	twin.bufferListOfNodes.append(self)
	return twin

func createBody(scene):
	var sceneInstance = scene.instantiate()

	sceneInstance.set_as_top_level(true)
	sceneInstance.global_position = global_position
	
	var bodySprite = sceneInstance.get_node("BodySprite")
	bodySprite.set_texture(head_texture)
	bodySprite.modulate = head_modulate

	sceneInstance.apply_scale(get_scale())
	sceneInstance.rotation = rotation
	if main_power is EarthPower:
		sceneInstance.z_index = FISSURE_Z_INDEX + 1
	
	listOfNodes.append(sceneInstance)
	if listOfNodes.size() == 1:
		sceneInstance.rotation = rotation + PI
	if listOfNodes.size() > 4:
		listOfNodes.pop_front()
	add_child(sceneInstance)
	return sceneInstance

func spawn_projectile(scene: PackedScene) -> Node2D:
	var sceneInstance = scene.instantiate()
	sceneInstance.set_as_top_level(true)
	sceneInstance.global_position = global_position
	sceneInstance.rotation = rotation

	# Vital: registrar en listOfNodes para no suicidarse con su propio proyectil
	# Corregido: se agregaba dos veces y sacaba de la lista dos segmentos propios
	listOfNodes.append(sceneInstance)
	if listOfNodes.size() == 1:
		sceneInstance.rotation = rotation + PI
	if listOfNodes.size() > 4:
		listOfNodes.pop_front()
	add_child(sceneInstance)
	return sceneInstance
	
# Seconds of rocky path (EarthPower sets it to its duration, so path and invincibility match)
var rock_time = 1.2
# True from the power until the head is off the path it just laid: those rocks don't kill
# it (the last one can reach the head right after the invincibility ends) and get no trail
var on_fresh_path = false
func start_fissure(fissure_step, fissure_scene, previous_body_list = []):	
	var fissure_instance : Fissure = fissure_scene.instantiate()

	fissure_instance.set_as_top_level(true)
	fissure_instance.global_position = global_position
	# As many rocks as fit in the power's duration (one every fissure_gap seconds)
	fissure_instance.maximum_step_number = max(2, roundi(rock_time / fissure_instance.fissure_gap))
	var body_list = fissure_instance.set_body(fissure_step, previous_body_list)
	if fissure_step < fissure_instance.maximum_step_number:
		fissure_instance.connect("fissure_ready", start_fissure.bind(fissure_scene, body_list) )

#	var bodySprite = sceneInstance.get_node("BodySprite")
#	bodySprite.set_texture(head_texture)
#	bodySprite.modulate = head_modulate

	

		
#	sceneInstance.apply_scale(get_scale())
	fissure_instance.rotation = rotation
	var width = stats.get_stat("earth.scale") if stats != null else 1.0
	fissure_instance.scale = FISSURE_SCALE * Vector2(width, 1.0)
	
	listOfNodes.append(fissure_instance)
	if listOfNodes.size() == 1:
		fissure_instance.rotation = rotation + PI
	if listOfNodes.size() > 4:
		listOfNodes.pop_front()
	
	fissure_instance.add_to_group("Fissures", true)
	# Above every trail and head, whichever snake was spawned later
	fissure_instance.z_index = FISSURE_Z_INDEX
	add_child(fissure_instance)
	return fissure_instance
	
func set_invincible(state: bool) -> void:
	invincible = state	

# Earth hides its head while it lays the rocky path (the rocks are all you see)
func set_head_visible(state: bool) -> void:
	$HeadSprite.visible = state
	$ElementHeadSprite.visible = state
func _input(event):
	if net_remote:
		return
	# Una sola línea universal para todos los jugadores:
	if playerId != null and input_id != 0 and event.is_action_pressed("Player" + str(input_id) + "Up"):
		try_use_power()

func try_use_power() -> void:
	# Stopped (dead, an ember, or the round/game is over): no power and no sound
	if not is_processing():
		return
	# Electrocuted: no power at all, not even Air's free second jump
	if shocked_time > 0:
		return
	# 1. Si el poder tiene el segundo salto listo, salta DE INMEDIATO sin cooldown:
	if main_power != null and main_power.has_method("is_recast_ready") and main_power.is_recast_ready():
		main_power.execute_recast()
		power_used.emit(true)
		return

	# 2. Si está en cooldown normal y no hay segundo salto, no hace nada:
	if not powerAvailable:
		return
	
	powerCooldown()
	
	if main_power != null:
		main_power.activate()
	power_used.emit(false)

	if stats != null:
		for entry in stats.active_buffs.values():
			if entry.behavior != null:
				entry.behavior.on_power_activated(self, entry.stacks)

# Online: replays another machine's power use on our copy of its snake (no cooldown checks)
func use_power():
	if main_power != null:
		main_power.activate()
func ai_punchy(direction):
	if powerAvailable and main_power and main_power.ai_should_activate(direction):
		try_use_power()
func spawn_twin(scene: PackedScene) -> Node2D:
	var twin = createBody(scene)
	twin.bufferListOfNodes = listOfNodes
	twin.bufferListOfNodes.append(self)
	twin.snakeBodyScene = snakeBodyScene
	twin_spawned.emit(twin)
	return twin

func powerCooldown():
	powerAvailable = false
	var cd = $CooldownTimer.wait_time
	if stats != null:
		cd = stats.get_stat("cooldown")

	# Usamos max(cd, 0.05) para que nunca dé error si pones 0 en la consola
	$CooldownTimer.start(max(cd, 0.05))
	update_power_indicator()
func powerReady(_prevColor = null):
	# A dead snake's cooldown can still run out; its power stays off
	if not is_in_group("alivePlayers"):
		return
	powerAvailable = true
	update_power_indicator()

# The element symbol on the head is white while the power is ready and dark while it recharges
func update_power_indicator():
	if has_node("ElementHeadSprite"):
		if shocked_time > 0:
			$ElementHeadSprite.modulate = SHOCK_COLOR
		else:
			$ElementHeadSprite.modulate = Color.WHITE if powerAvailable else Color.BLACK

# Air's Static Shock went through this snake's head. Every machine runs it on its own
# copy of the snake (Air's jump is replayed everywhere); only the owner's matters.
# scramble: seconds with left and right swapped (0 = none)
func shock(duration, scramble = 0.0):
	if not is_in_group("alivePlayers") or reviving:
		return
	var parent = get_parent()
	if shocked_time <= 0 and parent:
		PowerFx.shock(parent, self, SHOCK_COLOR, duration)
	shocked_time = max(shocked_time, duration)
	if scramble > 0:
		scrambled_time = max(scrambled_time, scramble)
		scrambled_age = 0.0
	update_power_indicator()

# Online: a snake run by another machine; its owner applies the effect, we only show it
func shock_visual(duration):
	if get_parent():
		PowerFx.shock(get_parent(), self, SHOCK_COLOR, duration)

func _update_shock(delta):
	if shocked_time <= 0 and scrambled_time <= 0:
		return
	if scrambled_time > 0:
		scrambled_age += delta
	scrambled_time = max(scrambled_time - delta, 0.0)
	shocked_time = max(shocked_time - delta, 0.0)
	if shocked_time <= 0:
		update_power_indicator()

# --- Phoenix (Fire's legendary upgrade) ---
const PHOENIX_CLEAR_RADIUS = 90.0
const PHOENIX_WALL_MARGIN = 90.0

# Dies for a while: stays where it fell as an ember (FirePower rises it again)
func phoenix_ash():
	reviving = true
	set_process(false)
	$CollisionShape2D.set_deferred("disabled", true)
	$HeadSprite.hide()
	$ElementHeadSprite.hide()
	if has_node("DynamicTeleportNode"):
		$DynamicTeleportNode.hide()
	if not net_remote:
		phoenix_changed.emit(false)

# Where it can rise: its death spot, moved away from the walls (it would die on them again),
# and the heading the arrow starts with
func phoenix_rise_point() -> Array:
	var point = global_position
	var heading = rotation
	if left_limit_x != null:
		var inside = Vector2(
			clamp(point.x, left_limit_x + PHOENIX_WALL_MARGIN, right_limit_x - PHOENIX_WALL_MARGIN),
			clamp(point.y, top_limit_y + PHOENIX_WALL_MARGIN, bottom_limit_y - PHOENIX_WALL_MARGIN))
		if inside != point:
			# Face the middle of the arena instead of the wall it hit
			var middle = Vector2((left_limit_x + right_limit_x) / 2, (top_limit_y + bottom_limit_y) / 2)
			heading = Vector2.UP.angle_to(middle - inside)
		point = inside
	return [point, heading]

func phoenix_rise(point, heading):
	global_position = point
	rotation = heading
	_clear_area(point, PHOENIX_CLEAR_RADIUS)
	PowerFx.explosion(get_parent(), point, Color(Global.playerColors[playerId]), PHOENIX_CLEAR_RADIUS)
	$HeadSprite.show()
	$ElementHeadSprite.show()
	reviving = false
	gap_delta_sum = 0
	if not net_remote:
		$CollisionShape2D.set_deferred("disabled", false)
		set_process(true)
		actualizarPuntoDeTransporte()
		phoenix_changed.emit(true)

# Burns every trail piece and rock within the radius (walls, heads and pickups stay)
func _clear_area(point, radius):
	var circle = CircleShape2D.new()
	circle.radius = radius
	var query = PhysicsShapeQueryParameters2D.new()
	query.shape = circle
	query.transform = Transform2D(0, point)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	query.collision_mask = 0b101 # Trails and rocks (1) and the Water twin's trail (4)
	for hit in get_world_2d().direct_space_state.intersect_shape(query, 512):
		var area = hit.collider
		if not is_instance_valid(area) or area.is_queued_for_deletion():
			continue
		if area.is_in_group("limits") or area.is_in_group("activePlayers") or area.is_in_group("twins") or area is Shroom:
			continue
		if area.is_in_group("Fissures"):
			area.get_parent().queue_free()
		else:
			area.queue_free()

const OUTSIDE_ARENA_MARGIN = 30.0

func _outside_arena() -> bool:
	if left_limit_x == null or right_limit_x == null or top_limit_y == null or bottom_limit_y == null:
		return false
	var p = global_position
	return p.x < left_limit_x - OUTSIDE_ARENA_MARGIN or p.x > right_limit_x + OUTSIDE_ARENA_MARGIN 		or p.y < top_limit_y - OUTSIDE_ARENA_MARGIN or p.y > bottom_limit_y + OUTSIDE_ARENA_MARGIN

func _on_own_rock() -> bool:
	for area in get_overlapping_areas():
		if area.is_in_group("Fissures") and is_ancestor_of(area):
			return true
	return false

func has_stone_walk() -> bool:
	return stats != null and stats.get_stat("earth.stone_walk") >= 1.0

func has_wall_warp() -> bool:
	return stats != null and stats.get_stat("air.wall_warp") >= 1.0

func set_gap_size():
	gapTimer.set_wait_time(Global.gap_time())
