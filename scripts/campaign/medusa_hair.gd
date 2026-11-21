extends Area2D
class_name MedusaHair

# One of the Medusa's snakes (MedusaBoss): it hunts the nearest snake and drags a trail of
# limited length behind it (the oldest piece goes as a new one is laid), so the trail
# follows it instead of staying on the map. The pieces are ordinary trail pieces
# (TrailSegment): they kill a snake that touches them, a fireball burns them, Earth's armor
# breaks them. The hair snake dies on walls, rocks, the players' trails and heads, fire,
# a fireball (which burns the head and its trail), and withers after LIFETIME seconds.

signal died(crashed)

const SNAKE_BODY = preload("res://scenes/snake_body.tscn")
const COLOR = Color(0.45, 0.85, 0.35)
const SPEED = 165.0
const TURN_SPEED = 2.4
const PIECE_SPACING = 7.5
const LIFETIME = 16.0
const EDGE_MARGIN = 70.0
const HEAD_RADIUS = 7.0

var medusa
var length = 220.0
var heading = 0.0
var pieces = []
var since_piece = 0.0
var age = 0.0
var wobble_phase = 0.0
var dead = false
var arena: Rect2
## Online, not the host: it follows the host's hair (MedusaBoss.boss_state) and the host
## decides when it dies; it still blocks this machine's snakes
var puppet = false
var net_position = Vector2.ZERO

func _ready():
	add_to_group("medusa_hair")
	top_level = true
	z_index = 3
	collision_layer = 1
	collision_mask = 0xFFFFFFFF
	var shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = HEAD_RADIUS
	shape.shape = circle
	add_child(shape)
	if puppet:
		monitoring = false
	else:
		area_entered.connect(_on_area_entered)
	wobble_phase = randf() * TAU
	rotation = heading

func _process(delta):
	if dead or medusa == null or not is_instance_valid(medusa) or not medusa.active:
		return
	age += delta
	var step: Vector2
	if puppet:
		var before = global_position
		global_position = global_position.lerp(net_position, clampf(delta * 12.0, 0.0, 1.0))
		step = global_position - before
	else:
		if age >= LIFETIME:
			die(false)
			return
		_steer(delta)
		step = Vector2.UP.rotated(heading) * SPEED * delta
		global_position += step
	rotation = heading
	since_piece += step.length()
	if since_piece >= PIECE_SPACING or pieces.is_empty():
		since_piece = 0.0
		_lay_piece()
	queue_redraw()

# Towards the nearest snake, with a lazy wiggle; away from the walls when close to them
func _steer(delta):
	var target = global_position + Vector2.UP.rotated(heading) * 100.0
	var nearest = INF
	for snake in get_tree().get_nodes_in_group("alivePlayers"):
		var distance = snake.global_position.distance_to(global_position)
		if distance < nearest:
			nearest = distance
			target = snake.global_position
	var inner = arena.grow(-EDGE_MARGIN)
	if not inner.has_point(global_position):
		target = arena.get_center()
	var wanted = Vector2.UP.angle_to(target - global_position) + 0.6 * sin(age * 2.2 + wobble_phase)
	var turn = wrapf(wanted - heading, -PI, PI)
	heading += clampf(turn, -TURN_SPEED * delta, TURN_SPEED * delta)

func _lay_piece():
	var piece = SNAKE_BODY.instantiate()
	piece.set_as_top_level(true)
	piece.scale = Vector2(0.1, 0.1)
	piece.modulate = COLOR
	piece.thickness = 0.8
	piece.add_to_group("medusa_hair_trail")
	add_child(piece)
	piece.global_position = global_position
	piece.rotation = heading
	if not pieces.is_empty() and is_instance_valid(pieces.back()):
		piece.link_to(pieces.back())
	pieces.append(piece)
	# A trail of limited length: the oldest piece goes
	while pieces.size() > int(length / PIECE_SPACING):
		var oldest = pieces.pop_front()
		if is_instance_valid(oldest):
			oldest.queue_free()

func _on_area_entered(area):
	if dead or not is_instance_valid(area):
		return
	if area.get_parent() == self or area.is_in_group("medusa_hair") or area.is_in_group("medusa_hair_trail") or area.is_in_group("medusa_body"):
		return
	if area.is_in_group("Shrooms") or area.is_in_group("storm_arcs"):
		return
	# A twin's ghost trail is harmless to it, like it is to Water
	if area.is_in_group("TwinBodies"):
		return
	die(true)

func die(crashed = true):
	if dead:
		return
	dead = true
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	died.emit(crashed)
	if crashed:
		PowerFx.burst(get_parent(), global_position, COLOR)
	# The trail crumbles from the tail
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.35)
	tween.tween_callback(queue_free)

# The head: a small green snake head with a yellow eye
func _draw():
	draw_circle(Vector2.ZERO, HEAD_RADIUS + 1.5, COLOR.darkened(0.35), true, -1.0, true)
	draw_circle(Vector2(0, -2), HEAD_RADIUS, COLOR, true, -1.0, true)
	draw_circle(Vector2(0, -4), 2.2, Color(1, 0.9, 0.2), true, -1.0, true)
