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
## How long the twin is forced to turn away from the original snake after it appears
const SPLIT_TIME = 0.3
# Side the twin turns to while splitting off (-1 left, 1 right)
var split_direction = 1
var split_time_left = SPLIT_TIME
var steer_direction = 0
# Online: another machine owns this twin. NetSession moves it and lays its trail.
var net_remote = false
# The water snake took this twin's place: the head is gone but its trail stays
var absorbed = false
## Seconds before a twin trail segment sheds its aqua skin and blocks the water snake again
const SHED_TIME = 5.0
## How long one segment takes to fade into the water color
const SHED_FADE = 0.4
# False keeps the trail aqua and harmless to the water snake forever (upgrade placeholder, not connected yet)
var sheds_trail = true
# [segment, trail_clock when laid], oldest first: the tail sheds first, then towards the head
var unshed_segments = []
var trail_clock = 0.0

signal dead
signal twinScore
## Online: a trail segment was laid by this (local) twin
signal body_laid(body_position, body_rotation)

@export var snakeBodyScene : PackedScene

func _ready():
	add_to_group("twinHeads")
	collider = $CollisionShape2D
	var gapTimer = $GapTimer
	var bodyTimer = $BodyTimer
	snakeBodyScene = preload("res://scenes/snake_body.tscn")
#	colorRect = $"../ColorRect/Collider"
	bodyTimer.connect("timeout", _on_bodyTimer_timeout)
	gapTimer.connect("timeout", _on_gapTimer_timeout)
	screen_size = get_viewport_rect().size
	# Split away from wherever the original snake is turning (random if it goes straight)
	var parent_direction = get_parent().steer_direction
	split_direction = -parent_direction if parent_direction != 0 else [-1, 1].pick_random()

func _process(delta):
	if net_remote:
		return
	# Forced split first, then the AI steers on its own
	var direction = 0
	if split_time_left > 0:
		split_time_left -= delta
		direction = split_direction
	elif $Raycaster.return_steering() == "Left":
		direction = -1
	elif $Raycaster.return_steering() == "Right":
		direction = 1
	steer_direction = direction
	
	rotation += angular_speed * direction * delta

	var	velocity = Vector2.UP.rotated(rotation) * speed
	position += velocity * delta
	position.x = clamp(position.x, 0, screen_size.x)
	position.y = clamp(position.y, 0, screen_size.y)

# Runs even after the twin died or was absorbed: its trail keeps shedding
func _physics_process(delta):
	trail_clock += delta
	if not sheds_trail:
		return
	while not unshed_segments.is_empty() and trail_clock - unshed_segments[0][1] >= SHED_TIME:
		_shed(unshed_segments.pop_front()[0])

func _shed(segment):
	if not is_instance_valid(segment):
		return
	var water_color = Color(Global.playerColors[get_parent().playerId])
	var tween = segment.create_tween()
	tween.tween_property(segment, "modulate", water_color, SHED_FADE)
	# Once it looks like the water snake's own trail, it blocks it like one
	tween.tween_callback(segment.remove_from_group.bind("TwinBodies"))

func _on_gapTimer_timeout():
	gap = not gap
	
func _on_bodyTimer_timeout():
	if net_remote:
		return
	if not gap:
		var body = createBody(snakeBodyScene)
		body_laid.emit(body.global_position, body.rotation)

# Online: lay a segment of a remote twin where its owner laid it
func create_body_at(body_position, body_rotation):
	var body = createBody(snakeBodyScene)
	body.global_position = body_position
	body.rotation = body_rotation
	return body

func createBody(scene):
	var snakeBody = scene.instantiate()

	snakeBody.set_as_top_level(true)
	snakeBody.global_position = global_position

	var bodySprite = snakeBody.get_node("BodySprite")
	bodySprite.set_texture(get_parent().get_node("HeadSprite").texture)
#		if $HeadSprite != null:
#	bodySprite.modulate = get_parent().get_node("HeadSprite").modulate

#		snakeBody.transform.scaled(transform.get_scale())
	snakeBody.apply_scale(transform.get_scale())
	snakeBody.rotation = rotation

#	$Sprite2D.set_offset(Vector2(100,100))}
	snakeBody.add_to_group("TwinBodies")
	snakeBody.modulate = Color.AQUA
	snakeBody.collision_layer = 0b100
#	print (snakeBody.collision_layer)
	add_child(snakeBody)
	listOfNodes.append(snakeBody)
	unshed_segments.append([snakeBody, trail_clock])

	if listOfNodes.size() > 4:
		listOfNodes.pop_front()
	return snakeBody
	
# The water snake jumps into this twin's place: stop it and hide its head, keep its trail
func absorb():
	absorbed = true
	alive = false
	set_process(false)
	$BodyTimer.stop()
	$GapTimer.stop()
	collider.set_deferred("disabled", true)
	remove_from_group("twinHeads")
	$BodySprite.hide()

func _on_area_entered(area):
	if net_remote:
		return
	if area is Shroom:
		get_parent().emit_signal("score")
		area.queue_free()
	else:
#	if area.playerId == null or area.playerId != 4:
		if listOfNodes.find(area) == -1 and bufferListOfNodes.find(area) == -1:
	#		if area.is_in_group("activePlayers"):
			$CollisionShape2D.set_deferred("disabled", true)
			remove_from_group("twinHeads")
			alive = false
			set_process(false)
			if (!get_parent().is_in_group("alivePlayers")):
				get_parent().emit_signal("dead")
		pass # Replace with function body.
