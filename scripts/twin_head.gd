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
const SHED_TIME = 7.0
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

# Ghostly look, so the twin can't be mistaken for the water snake itself: its usual aqua
# (light blue in the colorblind mode: Global.twin_color), but see-through and shimmering
# (scripts/fx/twin_ghost.gdshader). (No particles behind the head: during a gap they
# looked like real trail.)
static func ghost_color() -> Color:
	return Global.twin_color()
static var ghost_material: ShaderMaterial
static func get_ghost_material() -> ShaderMaterial:
	if ghost_material == null:
		ghost_material = ShaderMaterial.new()
		ghost_material.shader = preload("res://scripts/fx/twin_ghost.gdshader")
	return ghost_material

func _ready():
	add_to_group("twinHeads")
	# "twinHeads" is only the live ones; this group keeps every twin (alive, dead or absorbed)
	add_to_group("twins")
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
	_add_ghost_fx()

func _add_ghost_fx():
	$BodySprite.modulate = ghost_color()
	$BodySprite.material = get_ghost_material()

## Void with Earth held: seconds of stone armor (walks through trails, like Earth)
var armor_time = 0.0

func _process(delta):
	if net_remote:
		return
	armor_time = max(armor_time - delta, 0.0)
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
	_update_shed_marker(delta)

# A soft glow that rides the point where the trail is turning solid, so players can
# see which part of the ghost trail is about to block the water snake
var shed_marker: Node2D
var shed_marker_idle = 0.0
func _update_shed_marker(delta):
	if shed_marker == null:
		return
	shed_marker_idle += delta
	shed_marker.visible = shed_marker_idle < 0.15
	shed_marker.queue_redraw()

func _place_shed_marker(at):
	if shed_marker == null:
		shed_marker = Node2D.new()
		shed_marker.top_level = true
		shed_marker.z_index = 20
		var glow = CanvasItemMaterial.new()
		glow.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		shed_marker.material = glow
		shed_marker.draw.connect(_draw_shed_marker)
		add_child(shed_marker)
	shed_marker.global_position = at
	shed_marker_idle = 0.0

func _draw_shed_marker():
	var water_color = Color(Global.playerColors[get_parent().playerId])
	var pulse = 0.5 + 0.5 * sin(trail_clock * 14.0)
	shed_marker.draw_circle(Vector2.ZERO, 16.0 + 4.0 * pulse, Color(water_color, 0.25))
	shed_marker.draw_circle(Vector2.ZERO, 5.0, Color(1, 1, 1, 0.9))

func _shed(segment):
	if not is_instance_valid(segment):
		return
	var water_color = Color(Global.playerColors[get_parent().playerId])
	segment.material = null
	segment.round_joints = true
	_place_shed_marker(segment.global_position)
	# White flash and a small pop (the drawn line only, not the collider), then it settles
	# into the water color
	segment.modulate = Color(1.6, 1.6, 1.6)
	segment.thickness = 1.6
	var tween = segment.create_tween()
	tween.set_parallel()
	tween.tween_property(segment, "thickness", 1.0, SHED_FADE)
	tween.tween_property(segment, "modulate", water_color, SHED_FADE)
	tween.chain()
	# Once it looks like the water snake's own trail, it blocks it like one
	tween.tween_callback(segment.remove_from_group.bind("TwinBodies"))

func _on_gapTimer_timeout():
	gap = not gap
	
func _on_bodyTimer_timeout():
	if net_remote or not alive:
		return
	if gap:
		trail_tail = null
	else:
		var body = createBody(snakeBodyScene)
		_extend_trail(body)
		body_laid.emit(body.global_position, body.rotation)

# The newest piece of the ghost trail (null at the start of a stroke)
var trail_tail = null

func _extend_trail(body):
	body.link_to(trail_tail)
	trail_tail = body

# Online: lay a segment of a remote twin where its owner laid it
func create_body_at(body_position, body_rotation):
	var body = createBody(snakeBodyScene)
	body.global_position = body_position
	body.rotation = body_rotation
	_extend_trail(body)
	return body

func createBody(scene):
	var snakeBody = scene.instantiate()

	snakeBody.set_as_top_level(true)
	snakeBody.global_position = global_position

	snakeBody.apply_scale(transform.get_scale())
	snakeBody.rotation = rotation

	snakeBody.add_to_group("TwinBodies")
	# Drawn as a line (scripts/trail_segment.gd); see-through, so no overlapping joints
	snakeBody.modulate = ghost_color()
	snakeBody.material = get_ghost_material()
	snakeBody.round_joints = false
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
	# Placeholder effect (scripts/fx/power_fx.gd): the water snake bursts out here
	PowerFx.splash(get_parent().get_parent(), global_position, Color(Global.playerColors[get_parent().playerId]))
	absorbed = true
	alive = false
	set_process(false)
	$BodyTimer.stop()
	$GapTimer.stop()
	collider.set_deferred("disabled", true)
	remove_from_group("twinHeads")
	$BodySprite.hide()
	_tell_twin_lost()

# Its water snake can make a new twin now (WaterPower pulses if its power is ready)
func _tell_twin_lost():
	var water = get_parent()
	if water and water.has_method("water_power") and water.water_power() != null:
		water.water_power().twin_lost()

func _on_area_entered(area):
	if net_remote:
		return
	# Air's Storm Fence shocks snakes (no power to lock on a twin): harmless here
	if area.is_in_group("storm_arcs"):
		return
	# Its own snake's fire never burns it; stone armor (Void) goes through all but walls
	if area.is_in_group("hazards") and area.owner_id == get_parent().playerId:
		return
	if armor_time > 0 and not area.is_in_group("limits"):
		return
	if area is Shroom:
		get_parent().emit_signal("score")
		area.queue_free()
	else:
#	if area.playerId == null or area.playerId != 4:
		if listOfNodes.find(area) == -1 and bufferListOfNodes.find(area) == -1:
	#		if area.is_in_group("activePlayers"):
			# End-screen stats: crashed on Earth's rock
			if area.is_in_group("Fissures"):
				var earth = Fissure.owner_of(area)
				if earth != null:
					Global.add_stat(earth.playerId, "earth_blocked")
			$CollisionShape2D.set_deferred("disabled", true)
			remove_from_group("twinHeads")
			alive = false
			set_process(false)
			_tell_twin_lost()
			# Stop laying trail: it kept piling hidden segments under the dead head, which
			# later flashed one by one as they shed
			$BodyTimer.stop()
			$GapTimer.stop()
			if (!get_parent().is_in_group("alivePlayers")):
				get_parent().emit_signal("dead")
		pass # Replace with function body.
