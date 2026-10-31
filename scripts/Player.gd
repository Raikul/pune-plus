extends Area2D

var angular_speed = PI
var speed = 150.0
var screen_size = Vector2.ZERO
var gap = false
var powerAvailable = true
var colorRect
var twinHeadInstance
var invincible = false
var stats: PlayerStats = null
var is_chaining_power: bool = false
var orig_col_scale: Vector2 = Vector2.ONE
var orig_head_scale: Vector2 = Vector2.ONE

signal dead()
signal score()
## Online: a trail segment was laid by this (local) snake
signal body_laid(body_position, body_rotation)
## Online: this (local) snake used its power
signal power_used()
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

var listOfNodes = []
var snakeBodyScene: PackedScene
var projectileScene: PackedScene
var twinHeadScene: PackedScene
var fissure_scene: PackedScene
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
	projectileScene = preload("res://scenes/projectile.tscn")
	snakeBodyScene = preload("res://scenes/snake_body.tscn")
	fissure_scene = preload("res://scenes/fissure.tscn")
	
	gapTimer.connect("timeout", _on_gapTimer_timeout)
	gapFrequencyTimer.connect("timeout", _on_gapFrequencyTimer_timeout)
	
	set_gap_size()
	screen_size = get_viewport_rect().size
	
	$HulkTimer.connect("timeout", unhulk.bind(Global.playerColors[playerId]))
	$DashTimer.connect("timeout", stop_and_breathe.bind(speed, Global.playerColors[playerId]))
	$CooldownTimer.connect("timeout", powerReady.bind(Global.playerColors[playerId]))
	$DashTimer.connect("timeout", undash.bind(speed, Global.playerColors[playerId]))
	
	$HulkTimer.add_to_group("timers", true)
	if has_node("CollisionShape2D"):
		orig_col_scale = $CollisionShape2D.scale
	if has_node("HeadSprite"):
		orig_head_scale = $HeadSprite.scale
		
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

	# --- EJE X ---
	if left_limit_x != null and target_pos.x <= left_limit_x:
		var x_difference = target_pos.x - left_limit_x
		target_pos.x = right_limit_x + x_difference
	elif right_limit_x != null and target_pos.x >= right_limit_x:
		var x_difference = target_pos.x - right_limit_x
		target_pos.x = left_limit_x + x_difference

	# --- EJE Y ---
	if top_limit_y != null and target_pos.y <= top_limit_y:
		var y_difference = target_pos.y - top_limit_y
		target_pos.y = bottom_limit_y + y_difference
	elif bottom_limit_y != null and target_pos.y >= bottom_limit_y:
		var y_difference = target_pos.y - bottom_limit_y
		target_pos.y = top_limit_y + y_difference

	# Actualizamos la posición
	$DynamicTeleportNode.global_position = target_pos
func _on_gapTimer_timeout():
	gap = false
	gapFrequencyTimer.start()
	
func _on_gapFrequencyTimer_timeout():
	gap = true
	var dur = 0.6
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

	if area.is_in_group("Fissures"):
		return

	if not invincible:
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
	listOfNodes.append(sceneInstance)
	if listOfNodes.size() == 1:
		sceneInstance.rotation = rotation + PI
	if listOfNodes.size() > 4:
		listOfNodes.pop_front()


	sceneInstance.set_as_top_level(true)
	sceneInstance.global_position = global_position
#
#	var bodySprite = sceneInstance.get_node("BodySprite")
#	bodySprite.set_texture(head_texture)
#	bodySprite.modulate = head_modulate

#	sceneInstance.apply_scale(get_scale())
	sceneInstance.rotation = rotation
	
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
		power_used.emit()
		return

	# 2. Si está en cooldown normal y no hay segundo salto, no hace nada:
	if not powerAvailable:
		return
	
	powerCooldown()
	
	if main_power != null:
		main_power.activate()
	power_used.emit()
	
	if stats != null:
		for entry in stats.active_buffs.values():
			if entry.behavior != null:
				entry.behavior.on_power_activated(self, entry.stacks)

func activate_power():
	try_use_power()

# Online: replays another machine's power use on our copy of its snake (no cooldown checks)
func use_power():
	if main_power != null:
		main_power.activate()
func ai_punchy(direction):
	if powerAvailable and main_power and main_power.ai_should_activate(direction):
		try_use_power()
func is_there_twin_head():
	return is_instance_valid(get_tree().get_first_node_in_group("twinHeads"))
func hulk():
	

	$Hulk.play()
	invincible = true
	head_modulate.a = 0
	start_fissure( 1, fissure_scene)
	#$HeadSprite.modulate = Color.BLACK
#	$CollisionShape2D.set_deferred("disabled", true)
	$HulkTimer.start()
	
func unhulk(prevColor):
	$HeadSprite.modulate = prevColor
	head_modulate = prevColor
#	$CollisionShape2D.set_deferred("disabled", false)
	invincible = false
	
func teleport():
	# The target is only refreshed in _process; the AI can teleport before that first runs
	actualizarPuntoDeTransporte()
	gap = true
	gap_delta_sum = 0.0

	# Teletransporta la serpiente directo a la posición del indicador visual
	if has_node("DynamicTeleportNode"):
		global_position = $DynamicTeleportNode.global_position

	$Dash.play()
	get_tree().create_timer(0.12).timeout.connect(func(): gap = false)
func undash(prevSpeed, prevColor):
	speed = prevSpeed
	$HeadSprite.modulate = prevColor
	
func stop_and_breathe(prevSpeed,prevColor):
	speed = 0
	$HeadSprite.modulate = Color.ORANGE
	$StopAndBreatheTimer.start()
	
func shoot():
	if projectileScene != null:
		spawn_projectile(projectileScene)
	if has_node("Shoot"):
		$Shoot.play()

func spawn_twin(scene: PackedScene) -> Node2D:
	var twin = createBody(scene)
	twin.bufferListOfNodes = listOfNodes
	twin.bufferListOfNodes.append(self)
	twin.snakeBodyScene = snakeBodyScene
	twin_spawned.emit(twin)
	return twin
	$NewSplit.play()
#	has_twin_head = true
	is_water_my_friend = true
	twinHeadInstance = createBody(twinHeadScene)
#	twinHeadInstance.colorRect = colorRect
	twinHeadInstance.bufferListOfNodes = listOfNodes
	twinHeadInstance.bufferListOfNodes.append(self)
	twinHeadInstance.snakeBodyScene = snakeBodyScene
#	twinHead.syncBodyTimer = bodyTimer

	pass

func twinHead():
	if has_node("NewSplit"):
		$NewSplit.play()
	is_water_my_friend = true
	if twinHeadScene != null:
		twinHeadInstance = spawn_twin(twinHeadScene)
		return twinHeadInstance
func powerCooldown():
	powerAvailable = false
	var cd = 5.0
	if stats != null:
		cd = stats.get_stat("cooldown")
	elif has_node("CooldownTimer"):
		cd = $CooldownTimer.wait_time
	
	# Usamos max(cd, 0.05) para que nunca dé error si pones 0 en la consola
	$CooldownTimer.start(max(cd, 0.05))
func powerReady(_prevColor):
	powerAvailable = true
#	print(Global.playerColors[playerId])
#	$ShaderSprite.material.set_shader_parameter("darker_color", prevColor)
#	$ShaderSprite.show()
	$ElementHeadSprite.modulate = Color.WHITE

func set_gap_size():
	match Global.gapSize:
		0:
			gapTimer.set_wait_time(0.4)
		1:
			gapTimer.set_wait_time(0.7)
		2:
			gapTimer.set_wait_time(1)
func set_earth_collision_scale(mult: float) -> void:
	if has_node("CollisionShape2D"):
		$CollisionShape2D.scale = orig_col_scale * mult
	if has_node("HeadSprite"):
		$HeadSprite.scale = orig_head_scale * mult
	if has_node("ElementHeadSprite"):
		$ElementHeadSprite.scale = orig_head_scale * mult

func reset_earth_collision_scale() -> void:
	if has_node("CollisionShape2D"):
		$CollisionShape2D.scale = orig_col_scale
	if has_node("HeadSprite"):
		$HeadSprite.scale = orig_head_scale
	if has_node("ElementHeadSprite"):
		$ElementHeadSprite.scale = orig_head_scale
