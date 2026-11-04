extends Area2D
class_name FireTrail

# Fire's Wildfire upgrade: one flame left behind by the fireball. For LIFETIME seconds it
# kills any snake or twin that touches it, except the Fire snake that threw it (Player
# skips flames with its own owner_id). Drawn in code: a few flickering tongues of fire.

const LIFETIME = 2.0
const RADIUS = 13.0
const FADE_TIME = 0.4

var owner_id = 0
var color = Color(1, 0.5, 0.1)
var radius = RADIUS
var age = 0.0
var seed_offset = 0.0

func _ready():
	add_to_group("fire_trail")
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

func _process(delta):
	age += delta
	if age >= LIFETIME:
		queue_free()
		return
	# Harmless while it fades out
	if age >= LIFETIME - FADE_TIME and monitorable:
		set_deferred("monitorable", false)
	queue_redraw()

func _draw():
	var fade = clamp((LIFETIME - age) / FADE_TIME, 0.0, 1.0)
	draw_circle(Vector2.ZERO, radius * 1.25, Color(1.0, 0.35, 0.05, 0.22 * fade))
	for i in 3:
		var phase = age * 14.0 + seed_offset + i * 2.1
		var flicker = 0.75 + 0.25 * sin(phase)
		var base_x = (i - 1) * radius * 0.55
		var height = radius * (1.5 + 0.5 * sin(phase * 0.7)) * flicker
		var tongue = PackedVector2Array([
			Vector2(base_x - radius * 0.45, radius * 0.4),
			Vector2(base_x + sin(phase) * radius * 0.2, radius * 0.4 - height),
			Vector2(base_x + radius * 0.45, radius * 0.4)])
		draw_colored_polygon(tongue, Color(1.0, 0.45 + 0.35 * flicker, 0.1, 0.85 * fade))
	# A touch of the thrower's color at the base, so everyone knows whose fire it is
	draw_circle(Vector2(0, radius * 0.35), radius * 0.35, Color(color, 0.6 * fade))
