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

@export var playerId : int

var listOfNodes = []
@export var snakeBodyScene: PackedScene
@export var projectileScene: PackedScene
@export var twinHeadScene: PackedScene
@onready var bodyTimer = get_node("BodyTimer")
@onready var gapTimer = get_node("GapTimer")
@onready var gapFrequencyTimer = get_node("GapFrequencyTimer")
@onready var is_water_my_friend = false

func _ready():

#	snakeBodyScene = preload("res://snake_body.tscn")
	twinHeadScene = preload("res://scenes/twin_head.tscn")
#	colorRect = $"../Colliders/ColorRect/Collider"
	bodyTimer.connect("timeout", _on_bodyTimer_timeout)
	set_gap_size()
	gapTimer.connect("timeout", _on_gapTimer_timeout)
	gapFrequencyTimer.connect("timeout", _on_gapFrequencyTimer_timeout)
	screen_size = get_viewport_rect().size
	
	$HulkTimer.connect("timeout", unhulk.bind(Global.playerColors[playerId]))
	$DashTimer.connect("timeout", undash.bind(speed, Global.playerColors[playerId]))
	
	$HulkTimer.add_to_group("timers", true)
	
	$CooldownTimer.connect("timeout", powerReady.bind(Global.playerColors[playerId]))
#	$ShaderSprite.material.set_shader_parameter("darker_color", Global.playerColors[playerId])
#	$ShaderSprite.show()
	
	
func _process(delta):
#	if (is_multiplayer_authority() or Global.isMultiplayerActive == false):
		var direction = 0
		if Input.is_action_pressed("Player"+str(playerId)+"Left"):
			direction = -1
		if Input.is_action_pressed("Player"+str(playerId)+"Right"):
			direction = 1
				
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
	if not gap:
		createBody(snakeBodyScene)
	
func _on_area_entered(area):	
	if area is Shroom:
		emit_signal("score")
		area.queue_free()
	elif area.is_in_group("TwinBodies") and is_water_my_friend:
		pass
	elif invincible == false:
		if listOfNodes.find(area) == -1 and area != twinHeadInstance:
			if (twinHeadInstance == null or twinHeadInstance.alive == false):
				$CollisionShape2D.set_deferred("disabled", true)
				set_process(false)
				emit_signal("dead")
			else: #twinHeadIsAlive
				twinHeadInstance.collider.set_deferred("disabled", true)
				var tempPosition = twinHeadInstance.position
				var tempRotation = twinHeadInstance.rotation
				twinHeadInstance.queue_free()
				position = tempPosition
				rotation = tempRotation
				pass

func createBody(scene):
	var sceneInstance = scene.instantiate()
	add_child(sceneInstance)
	sceneInstance.set_as_top_level(true)
	sceneInstance.global_position = global_position
	
	var bodySprite = sceneInstance.get_node("BodySprite")
	bodySprite.set_texture($HeadSprite.texture)
	bodySprite.modulate = $HeadSprite.modulate

	sceneInstance.apply_scale(transform.get_scale())
	sceneInstance.rotation = rotation
	
	listOfNodes.append(sceneInstance)
	if listOfNodes.size() == 1:
		sceneInstance.rotation = rotation + PI
	if listOfNodes.size() > 4:
		listOfNodes.pop_front()
	return sceneInstance
	
func _input(event):
	if powerAvailable:
		if playerId == 1:
			if event.is_action_pressed("Player1Up"):
				dash()	
				powerCooldown()
				
		if playerId == 2:
			if event.is_action_pressed("Player2Up"):
				hulk()		
				powerCooldown()
		
		if playerId == 3:
			if event.is_action_pressed("Player3Up"):
				shoot()		
				powerCooldown()
				
		if playerId == 4:
			if event.is_action_pressed("Player4Up"):
				twinHead()		
				powerCooldown()
			
func hulk():
	
	$HeadSprite.modulate = Color.DIM_GRAY
	$Hulk.play()
	invincible = true
#	$CollisionShape2D.set_deferred("disabled", true)
	$HulkTimer.start()
	
func unhulk(prevColor):
	$HeadSprite.modulate = prevColor
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

func shoot():
	createBody(projectileScene)
	$Shoot.play()
#	add_child(tirito)
	pass

func twinHead():
	$Split.play()
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
	$ShaderSprite.hide()
func powerReady(prevColor):
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
