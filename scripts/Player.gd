extends Area2D

var angular_speed = PI
var speed = 150.0
var screen_size = Vector2.ZERO
var gap = false
var powerAvailable = true
var colorRect
var twinHeadInstance
var invincible = false


signal dead()
signal score()

var playerId

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

func _ready():
	apply_scale(Vector2(0.1,0.1))
	ai_enabled = Global.AI_Enabled[playerId]
	
	twinHeadScene = preload("res://scenes/twin_head.tscn")
	projectileScene = preload("res://scenes/projectile.tscn")
	snakeBodyScene = preload("res://scenes/snake_body.tscn")
	fissure_scene = preload("res://scenes/fissure.tscn")
	
#	bodyTimer.connect("timeout", _on_bodyTimer_timeout)
	gapTimer.connect("timeout", _on_gapTimer_timeout)
	gapFrequencyTimer.connect("timeout", _on_gapFrequencyTimer_timeout)
	
	set_gap_size()
	screen_size = get_viewport_rect().size
	
	$HulkTimer.connect("timeout", unhulk.bind(Global.playerColors[playerId]))
	$DashTimer.connect("timeout", stop_and_breathe.bind(speed, Global.playerColors[playerId]))
	$CooldownTimer.connect("timeout", powerReady.bind(Global.playerColors[playerId]))
	
	#With Stop:
	#$DashTimer.connect("timeout", stop_and_breathe.bind(speed, Global.playerColors[playerId]))
	#$StopAndBreatheTimer.connect("timeout", undash.bind(speed, Global.playerColors[playerId]))
	##No Stop
	$DashTimer.connect("timeout", undash.bind(speed, Global.playerColors[playerId]))
	
	$HulkTimer.add_to_group("timers", true)
	
	
	listOfNodes.append(self)
	if playerId != null:
		clonable_id = playerId
		clonable_name = "Player"+str(playerId)
	
func _process(delta):
#	if not gap:
#		createBody(snakeBodyScene)
#	if (is_multiplayer_authority() or Global.isMultiplayerActive == false):
		var direction = 0
		if locked_movement: direction = locked_direction
		else:
			if Input.is_action_pressed("Player"+str(playerId)+"Left") :direction = -1
			elif Input.is_action_pressed("Player"+str(playerId)+"Right"): direction = 1
			elif (ai_enabled and $Raycaster.return_steering() == "Left"): direction = -1
			elif (ai_enabled and $Raycaster.return_steering() == "Right"): direction = 1
		
#		elif $Raycaster.collision_distance("Left") < 400: direction = -1
#		elif $Raycaster.collision_distance("Right") < 400: direction = 1
		if ai_enabled and powerAvailable: ai_punchy(direction)

		rotation += angular_speed * direction * delta
		var	velocity = Vector2.UP.rotated(rotation) * speed
		position += velocity * delta

func _on_gapTimer_timeout():
	gap = false
	gapFrequencyTimer.start()
	
func _on_gapFrequencyTimer_timeout():
	gap = true
	gapTimer.start()
	
func _on_bodyTimer_timeout():
#	if not gap:
#		createBody(snakeBodyScene)
	pass

func _physics_process(delta):
	gap_delta_sum += delta
	if not gap and gap_delta_sum >= 0.05:
		createBody(snakeBodyScene)
		gap_delta_sum = 0

func _on_area_entered(area):	
#	print(area)
	if area is Shroom:
		emit_signal("score")
		area.queue_free()
	elif (area.is_in_group("TwinBodies") or area.is_in_group("twinHeads"))  and is_water_my_friend:
		pass
	elif area.is_in_group("Fissures"):
		pass
	elif invincible == false:
		if listOfNodes.find(area) == -1:
			var currentTwinHeadInstance = get_tree().get_first_node_in_group("twinHeads")
#			if (twinHeadInstance == null or twinHeadInstance.alive == false):
			if !is_instance_valid(currentTwinHeadInstance) or currentTwinHeadInstance.alive == false or !is_water_my_friend:
				$CollisionShape2D.set_deferred("disabled", true)
				set_process(false)
				emit_signal("dead")
			elif is_water_my_friend: #twinHeadIsAlive
				currentTwinHeadInstance.collider.set_deferred("disabled", true)
				var tempPosition = currentTwinHeadInstance.position
				var tempRotation = currentTwinHeadInstance.rotation
				currentTwinHeadInstance.queue_free()
				position = tempPosition
				rotation = tempRotation
				pass

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

func shoot_fireball(scene):	
	var sceneInstance = scene.instantiate()

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
	add_child(fissure_instance)
	return fissure_instance
	
	
func _input(event):
	if powerAvailable:
		if playerId == 1:
			if event.is_action_pressed(&"Player1Up"):
				shoot()		
				powerCooldown()
				
		if playerId == 2:
			if event.is_action_pressed(&"Player2Up"):
				hulk()		
				powerCooldown()
		
		if playerId == 3:
			if event.is_action_pressed(&"Player3Up"):
				dash()
				powerCooldown()
				
		if playerId == 4:
			if event.is_action_pressed(&"Player4Up"):
				twinHead()		
				powerCooldown()


func activate_power():
	if powerAvailable:	
		if playerId == 1:
			powerCooldown()	
			shoot()		
		if playerId == 2:
			powerCooldown()	
			hulk()		
		if playerId == 3:
			powerCooldown()	
			dash()
		if playerId == 4:
				if !is_there_twin_head():
					powerCooldown()	
					twinHead()
					locked_direction = [-1,1].pick_random()
					locked_movement = true
					await get_tree().create_timer(0.2).timeout
					locked_movement = false		
	
func is_there_twin_head():
	return is_instance_valid(get_tree().get_first_node_in_group("twinHeads"))

func ai_punchy(direction):
	if playerId == 1:
		if $Raycaster/UpPlayer.is_colliding() or $Raycaster.collision_distance("Up") < 75:
			activate_power()
	if playerId == 2:
		if $Raycaster.collision_distance("Up") < 25:
			activate_power()
	if playerId == 3 and direction == 0: 
		activate_power()
	if powerAvailable and playerId == 4:
		activate_power()
			
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
	
func dash():
	speed = speed*2
	$Dash.play()
	$HeadSprite.modulate = Color.YELLOW
	$DashTimer.start()
	
func undash(prevSpeed, prevColor):
	speed = prevSpeed
	$HeadSprite.modulate = prevColor
	
func stop_and_breathe(prevSpeed,prevColor):
	speed = 0
	$HeadSprite.modulate = Color.ORANGE
	$StopAndBreatheTimer.start()

func shoot():
	shoot_fireball(projectileScene)
	$Shoot.play()
#	add_child(tirito)
	pass

func twinHead():
	$Split.play()
#	has_twin_head = true
	is_water_my_friend = true
	twinHeadInstance = createBody(twinHeadScene)
#	twinHeadInstance.colorRect = colorRect
	twinHeadInstance.bufferListOfNodes = listOfNodes
	twinHeadInstance.bufferListOfNodes.append(self)
	twinHeadInstance.snakeBodyScene = snakeBodyScene
#	twinHead.syncBodyTimer = bodyTimer

	pass
	
func powerCooldown():
	powerAvailable = false
	$CooldownTimer.start()
	#$ShaderSprite.hide()
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
