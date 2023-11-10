extends Area2D

var angular_speed = PI
var speed = 150.0
var screen_size = Vector2.ZERO
var gap = false
var powerAvailable = true
var colorRect
var twinHeadInstance

signal dead()
signal score()

var playerId : int

var listOfNodes = []
@export var snakeBodyScene: PackedScene
@export var projectileScene: PackedScene
@export var twinHeadScene: PackedScene
@onready var bodyTimer = get_node("BodyTimer")
@onready var gapTimer = get_node("GapTimer")

func _ready():
	set_scale(Vector2(0.1,0.1))
	set_multi_id()
	
#	snakeBodyScene = preload("res://snake_body.tscn")
	twinHeadScene = preload("res://scenes/twin_head.tscn")
#	colorRect = $"../Colliders/ColorRect/Collider"
	bodyTimer.connect("timeout", _on_bodyTimer_timeout)
	gapTimer.connect("timeout", _on_gapTimer_timeout)
	screen_size = get_viewport_rect().size
	
	$HulkTimer.connect("timeout", unhulk.bind(Global.playerColors[playerId]))
	$DashTimer.connect("timeout", undash.bind(200, Global.playerColors[playerId]))
	
	$HulkTimer.add_to_group("timers", true)
	$CooldownTimer.connect("timeout", powerReady)

func _process(delta):
	var multiSync = $MultiplayerSynchronizer.get_multiplayer_authority()
	var uniqueId = multiplayer.get_unique_id()
	if ($MultiplayerSynchronizer.get_multiplayer_authority() == multiplayer.get_unique_id()):
		var direction = 0
		if playerId == 1:
			if Input.is_key_pressed(KEY_A):
				direction = -1
			if Input.is_key_pressed(KEY_D):
				direction = 1
		if playerId == 2:
			if Input.is_action_pressed("ui_left"):
				direction = -1
			if Input.is_action_pressed("ui_right"):
				direction = 1
		if playerId == 3:
			if Input.is_key_pressed(KEY_J):
				direction = -1
			if Input.is_key_pressed(KEY_L):
				direction = 1
		if playerId == 4:
			if Input.is_key_pressed(KEY_KP_4):
				direction = -1
			if Input.is_key_pressed(KEY_KP_6):
				direction = 1
		
		rotation += angular_speed * direction * delta

		var	velocity = Vector2.UP.rotated(rotation) * speed
		position += velocity * delta
#
#		if (position.x == 0 
#		or position.x == screen_size.x - 1
#		or position.y == colorRect.position.y * colorRect.scale.y	
#		or position.y == screen_size.y - 1):
#			_on_area_entered(colorRect)
			
	#	position.x = clamp(position.x, 0, screen_size.x)
	#	position.y = clamp(position.y, colorRect.position.y * colorRect.scale.y, screen_size.y)
#

func set_multi_id():
#	if multiplayer.is_server():
#		set_multiplayer_authority(Global.multiplayerIds[playerId])
		var pname = str(name).to_int()
		$MultiplayerSynchronizer.set_multiplayer_authority(str(name).to_int())
#		set_multiplayer_authority(1)
		
func _enter_tree():
	pass

func _on_gapTimer_timeout():
	gap = not gap
	
func _on_bodyTimer_timeout():
#	if not gap:
#		createBody(snakeBodyScene)
	pass
	
func _on_area_entered(area):
#	if listOfNodes.find(area) == -1 and area != twinHeadInstance:
#		if (twinHeadInstance == null or twinHeadInstance.alive == false):
#			$CollisionShape2D.set_deferred("disabled", true)
#			set_process(false)
#			emit_signal("dead")
#		else: #twinHeadIsAlive
#			twinHeadInstance.collider.set_deferred("disabled", true)
#			var tempPosition = twinHeadInstance.position
#			var tempRotation = twinHeadInstance.rotation
#			twinHeadInstance.queue_free()
#			position = tempPosition
#			rotation = tempRotation
	pass

func createBody(scene):
	var snakeBody = scene.instantiate()
	add_child(snakeBody)
	snakeBody.set_as_top_level(true)
	snakeBody.global_position = global_position
	
	var bodySprite = snakeBody.get_node("BodySprite")
	bodySprite.set_texture($HeadSprite.texture)
#		if $HeadSprite != null:
	bodySprite.modulate = $HeadSprite.modulate

#		snakeBody.transform.scaled(transform.get_scale())
	snakeBody.apply_scale(transform.get_scale())
	snakeBody.rotation = rotation
	
#	$Sprite2D.set_offset(Vector2(100,100))
	listOfNodes.append(snakeBody)
	
	if listOfNodes.size() > 4:
		listOfNodes.pop_front()
	return snakeBody
	
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
	$CollisionShape2D.set_deferred("disabled", true)
	$HulkTimer.start()
	
func unhulk(prevColor):
	$HeadSprite.modulate = prevColor
	$CollisionShape2D.set_deferred("disabled", false)

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
#	add_child(tirito)
	pass

func twinHead():
	twinHeadInstance = createBody(twinHeadScene)
	twinHeadInstance.colorRect = colorRect
	twinHeadInstance.bufferListOfNodes = listOfNodes
	twinHeadInstance.bufferListOfNodes.append(self)
	twinHeadInstance.snakeBodyScene = snakeBodyScene
#	twinHead.syncBodyTimer = bodyTimer
	pass
	
func powerCooldown():
	powerAvailable = false
	$CooldownTimer.start()
	
func powerReady():
	powerAvailable = true

