extends Node2D
class_name PowerFx

# Placeholder power effects drawn in code, until the animator replaces them:
# - lightning: a flickering jagged bolt (Air's teleport), from start to landing
# - splash: rings and droplets bursting out of a point (Water taking its twin's place)
# Each effect is its own node on the playground, so it outlives the snake that made it.

const LIGHTNING_TIME = 0.35
const SPLASH_TIME = 0.7
const LIGHTNING_STEP = 18.0     # Pixels between the bolt's kinks
const LIGHTNING_JITTER = 14.0   # How far the kinks stray from the straight line
const FLICKER_INTERVAL = 0.05

var kind = ""
var color = Color.WHITE
var duration = 0.5
var age = 0.0
var segments = [] # Lightning: [[from, to], ...]
var center = Vector2.ZERO
var droplets = [] # Splash: directions
var bolts = []    # Lightning: current jagged polylines
var flicker = 0.0

# Air: one bolt per straight part of the jump (two when it wrapped around a wall)
static func lightning(parent: Node, parts: Array, bolt_color: Color) -> void:
	var fx = PowerFx.new()
	fx.kind = "lightning"
	fx.color = bolt_color
	fx.duration = LIGHTNING_TIME
	fx.segments = parts
	parent.add_child(fx)

# Water: a burst where the snake appears
static func splash(parent: Node, at: Vector2, splash_color: Color, size: float = 1.0) -> void:
	var fx = PowerFx.new()
	fx.kind = "splash"
	fx.color = splash_color
	fx.duration = SPLASH_TIME
	fx.center = at
	fx.scale = Vector2(size, size)
	parent.add_child(fx)

func _ready():
	top_level = true
	z_index = 20 # Above trails and heads
	if kind == "splash":
		position = center
		for i in 14:
			droplets.append(Vector2.RIGHT.rotated(TAU * i / 14.0 + randf_range(-0.2, 0.2)) * randf_range(0.7, 1.2))
	else:
		_roll_bolts()

func _process(delta):
	age += delta
	if age >= duration:
		queue_free()
		return
	if kind == "lightning":
		flicker += delta
		if flicker >= FLICKER_INTERVAL:
			flicker = 0.0
			_roll_bolts()
	queue_redraw()

func _roll_bolts():
	bolts.clear()
	for part in segments:
		var from: Vector2 = part[0]
		var to: Vector2 = part[1]
		var steps = max(2, int(from.distance_to(to) / LIGHTNING_STEP))
		var normal = (to - from).normalized().orthogonal()
		var points = PackedVector2Array([from])
		for i in range(1, steps):
			points.append(from.lerp(to, float(i) / steps) + normal * randf_range(-LIGHTNING_JITTER, LIGHTNING_JITTER))
		points.append(to)
		bolts.append(points)

func _draw():
	var t = age / duration
	var fade = 1.0 - t
	if kind == "lightning":
		for points in bolts:
			draw_polyline(points, Color(color, 0.35 * fade), 10.0, true)
			draw_polyline(points, Color(Color.WHITE, fade), 3.0, true)
		for part in segments:
			draw_circle(part[0], 10.0 * fade, Color(color, 0.6 * fade))
			draw_circle(part[1], 16.0 * fade, Color(Color.WHITE, 0.8 * fade))
	else:
		var grow = ease(t, 0.4)
		draw_circle(Vector2.ZERO, 40.0 * (1.0 - t), Color(Color.WHITE, 0.6 * fade))
		for i in 3:
			var ring_t = clamp(t * 1.4 - i * 0.18, 0.0, 1.0)
			if ring_t > 0.0:
				draw_arc(Vector2.ZERO, 15.0 + 95.0 * ease(ring_t, 0.4), 0, TAU, 40, Color(color, 1.0 - ring_t), 6.0 - i * 1.5, true)
		for direction in droplets:
			draw_circle(direction * 110.0 * grow, 6.0 * fade, Color(color.lightened(0.3), fade))
