extends Area2D
var speed = Global.baseSpeed
var screen_size = Vector2.ZERO
var colorRect
var angular_speed = PI
var bufferListOfNodes = []
var listOfNodes = []
var gap = false
var alive = true
var collider

signal dead

@export var snakeBodyScene : PackedScene
#var syncGapTimer

func _ready():
	collider = $CollisionShape2D
	var gapTimer = $GapTimer
	var bodyTimer = $BodyTimer
	snakeBodyScene = preload("res://scenes/snake_body.tscn")
#	colorRect = $"../ColorRect/Collider"
	bodyTimer.connect("timeout", _on_bodyTimer_timeout)
	gapTimer.connect("timeout", _on_gapTimer_timeout)
	screen_size = get_viewport_rect().size

func _process(delta):
	var direction = 0
	if Input.is_key_pressed(KEY_KP_4):
		direction = 1
	if Input.is_key_pressed(KEY_KP_6):
		direction = -1
	
	rotation += angular_speed * direction * delta

	var	velocity = Vector2.UP.rotated(rotation) * speed
	position += velocity * delta
	position.x = clamp(position.x, 0, screen_size.x)
	position.y = clamp(position.y, 0, screen_size.y)
	
#	if (position.x == 0 
#	or position.x == screen_size.x 
#	or position.y == colorRect.position.y * colorRect.scale.y	
#	or position.y == screen_size.y):
#		_on_area_entered(null)

func _on_gapTimer_timeout():
	gap = not gap
	
func _on_bodyTimer_timeout():
	if not gap:
#		createBody(snakeBodyScene)
		pass

func createBody(scene):
	var snakeBody = scene.instantiate()
	add_child(snakeBody)
	snakeBody.set_as_top_level(true)
	snakeBody.global_position = global_position
	
	var bodySprite = snakeBody.get_node("BodySprite")
	bodySprite.set_texture(get_parent().get_node("HeadSprite").texture)
#		if $HeadSprite != null:
	bodySprite.modulate = get_parent().get_node("HeadSprite").modulate

#		snakeBody.transform.scaled(transform.get_scale())
	snakeBody.apply_scale(transform.get_scale())
	snakeBody.rotation = rotation
	
#	$Sprite2D.set_offset(Vector2(100,100))
	listOfNodes.append(snakeBody)
	
	if listOfNodes.size() > 4:
		listOfNodes.pop_front()
	return snakeBody
	
func _on_area_entered(area):
#	if area.playerId == null or area.playerId != 4:
	if listOfNodes.find(area) == -1 and bufferListOfNodes.find(area) == -1:
#		if area.is_in_group("activePlayers"):
		$CollisionShape2D.set_deferred("disabled", true)
		alive = false
		set_process(false)
		if (!get_parent().is_in_group("alivePlayers")):
			get_parent().emit_signal("dead")
	pass # Replace with function body.

