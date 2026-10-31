extends Area2D

var angular_speed = PI
var speed = 150.0
var screen_size = Vector2.ZERO
var gap = false
var powerAvailable = true
var colorRect
var invincible = false
var stats: PlayerStats = null
var orig_col_scale: Vector2 = Vector2.ONE
var orig_head_scale: Vector2 = Vector2.ONE
var orig_element_scale: Vector2 = Vector2.ONE

signal dead()
signal score()
## Online: a trail segment was laid by this (local) snake
signal body_laid(body_position, body_rotation)
## Online: this (local) snake used its power. recast: Air's free second jump (no cooldown)
signal power_used(recast)
## Online: this (local) water snake split off a twin
signal twin_spawned(twin)

var playerId
var main_power: Power
const FISSURE_Z_INDEX = 5
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
	if has_node("CollisionShape2D"):
		orig_col_scale = $CollisionShape2D.scale
	if has_node("HeadSprite"):
		orig_head_scale = $HeadSprite.scale
	if has_node("ElementHeadSprite"):
		orig_element_scale = $ElementHeadSprite.scale
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
	steer_direction = direction

	rotation += angular_speed * direction * delta
	var velocity = Vector2.UP.rotated(rotation) * speed
	position += velocity * delta
func actualizarPuntoDeTransporte():
	if not has_node("DynamicTeleportNode") or not has_node("FixedTeleportNode"):
		return

	# NOTA: Si solo quieres que se vea con el jugador 3 (aire), deja esta condición.
	# Si estás probando con el jugador 1 o 2, comenta estas líneas temporalmente:
	if playerId != 3:
		$DynamicTeleportNode.hide()
		return
	else:
		$DynamicTeleportNode.show()

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
	if not gap and gap_delta_sum >= 0.05:
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

	# Earth's stone: deadly like a trail, except its own with the Stone Walker upgrade
	if area.is_in_group("Fissures") and has_stone_walk() and is_ancestor_of(area):
		return

	# Earth's power makes it pass through trails, not walls (it used to slip out of the arena
	# and stay alive off screen)
	if not invincible or area.is_in_group("limits"):
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
	
func start_fissure(fissure_step, fissure_scene, previous_body_list = []):	
	var fissure_instance : Fissure = fissure_scene.instantiate()

	fissure_instance.set_as_top_level(true)
	fissure_instance.global_position = global_position
	var body_list = fissure_instance.set_body(fissure_step, previous_body_list)
	if fissure_step < fissure_instance.maximum_step_number:
		fissure_instance.connect("fissure_ready", start_fissure.bind(fissure_scene, body_list) )

#	var bodySprite = sceneInstance.get_node("BodySprite")
#	bodySprite.set_texture(head_texture)
#	bodySprite.modulate = head_modulate

	

		
#	sceneInstance.apply_scale(get_scale())
	fissure_instance.rotation = rotation
	
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
func _input(event):
	if net_remote:
		return
	# Una sola línea universal para todos los jugadores:
	if playerId != null and input_id != 0 and event.is_action_pressed("Player" + str(input_id) + "Up"):
		try_use_power()

func try_use_power() -> void:
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
		$ElementHeadSprite.modulate = Color.WHITE if powerAvailable else Color.BLACK

const OUTSIDE_ARENA_MARGIN = 30.0

func _outside_arena() -> bool:
	if left_limit_x == null or right_limit_x == null or top_limit_y == null or bottom_limit_y == null:
		return false
	var p = global_position
	return p.x < left_limit_x - OUTSIDE_ARENA_MARGIN or p.x > right_limit_x + OUTSIDE_ARENA_MARGIN 		or p.y < top_limit_y - OUTSIDE_ARENA_MARGIN or p.y > bottom_limit_y + OUTSIDE_ARENA_MARGIN

func has_stone_walk() -> bool:
	return stats != null and stats.get_stat("earth.stone_walk") >= 1.0

func has_wall_warp() -> bool:
	return stats != null and stats.get_stat("air.wall_warp") >= 1.0

func set_gap_size():
	gapTimer.set_wait_time(Global.gap_time())
func set_earth_collision_scale(mult: float) -> void:
	if has_node("CollisionShape2D"):
		$CollisionShape2D.scale = orig_col_scale * mult
	if has_node("HeadSprite"):
		$HeadSprite.scale = orig_head_scale * mult
	if has_node("ElementHeadSprite"):
		$ElementHeadSprite.scale = orig_element_scale * mult

func reset_earth_collision_scale() -> void:
	if has_node("CollisionShape2D"):
		$CollisionShape2D.scale = orig_col_scale
	if has_node("HeadSprite"):
		$HeadSprite.scale = orig_head_scale
	if has_node("ElementHeadSprite"):
		$ElementHeadSprite.scale = orig_element_scale
