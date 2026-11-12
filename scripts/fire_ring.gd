extends Area2D
class_name FireRing

# Fire's Hearth upgrade (and Pyre): a circle of fire that burns for the rest of the round.
# Like Wildfire's flames it kills any other snake or twin that touches it and never its
# own Fire snake (Player skips hazards with its own owner_id). It lives under the snake
# that made it, so it goes away with the round. Drawn in code: a ring of flickering
# tongues of fire around a glowing middle.

const RADIUS = 46.0
const FLAMES = 12
const GROW_TIME = 0.35

var owner_id = 0
var color = Color(1, 0.5, 0.1)
var radius = RADIUS
var age = 0.0
var seed_offset = 0.0

# A ring at `at` (world position) owned by `snake`, which keeps it until the round ends
static func spawn(snake: Node2D, at: Vector2, ring_radius = RADIUS) -> FireRing:
	var ring = FireRing.new()
	ring.owner_id = snake.playerId
	ring.color = Color(Global.playerColors[snake.playerId])
	ring.radius = ring_radius
	snake.add_child(ring)
	ring.global_position = at
	return ring

func _ready():
	add_to_group("fire_trail") # Kills count as fire kills (end-screen stats)
	add_to_group("hazards") # Owned dangers: their owner goes through (Player), fireballs too
	top_level = true
	z_index = 4
	collision_layer = 1
	collision_mask = 0
	monitoring = false
	var shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = radius
	shape.shape = circle
	add_child(shape)
	seed_offset = randf() * TAU
	PowerFx.explosion(get_parent().get_parent(), global_position, Color(1.0, 0.55, 0.15), radius)

func _process(delta):
	age += delta
	queue_redraw()

func _draw():
	var grow = clamp(age / GROW_TIME, 0.0, 1.0)
	var r = radius * grow
	draw_circle(Vector2.ZERO, r * 1.15, Color(1.0, 0.35, 0.05, 0.16), true, -1.0, true)
	draw_circle(Vector2.ZERO, r * 0.8, Color(1.0, 0.45, 0.1, 0.22), true, -1.0, true)
	draw_arc(Vector2.ZERO, r, 0, TAU, 48, Color(1.0, 0.55, 0.15, 0.7), 3.0, true)
	for i in FLAMES:
		var angle = TAU * i / FLAMES + seed_offset
		var phase = age * 12.0 + seed_offset + i * 1.7
		var flicker = 0.7 + 0.3 * sin(phase)
		var base = Vector2.RIGHT.rotated(angle) * r * 0.82
		var out = Vector2.RIGHT.rotated(angle)
		var side = out.orthogonal() * r * 0.16
		var height = r * (0.42 + 0.16 * sin(phase * 0.7)) * flicker
		var tip = base + out * height + side * sin(phase * 1.3) * 0.6
		var tongue = PackedVector2Array([base - side, tip, base + side])
		draw_colored_polygon(tongue, Color(1.0, 0.42 + 0.35 * flicker, 0.08, 0.9))
		draw_polyline(PackedVector2Array([base - side, tip, base + side]), Color(1.0, 0.75, 0.3, 0.6), 1.0, true)
	# A touch of the owner's color in the middle, so everyone knows whose fire it is
	draw_circle(Vector2.ZERO, r * 0.28, Color(color, 0.55), true, -1.0, true)
