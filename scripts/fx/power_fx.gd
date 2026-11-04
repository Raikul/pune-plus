extends Node2D
class_name PowerFx

# Placeholder power effects drawn in code, until the animator replaces them:
# - lightning: a flickering jagged bolt (Air's teleport), from start to landing
# - splash: rings and droplets bursting out of a point (Water taking its twin's place)
# - ember: a glowing ember with a countdown ring (Phoenix waiting to rise)
# - explosion: a burst of fire (Phoenix rising, clearing the trails around it)
# - shock: electric arcs crackling around a snake while it is electrocuted (Air's Static Shock)
# - pulse: a soft ring around a snake whose power just recharged
# - burst: shards flying out where a snake died
# - score: a "+1" floating up from a snake that scored
# - home: a thick ring closing in on a snake's head (round countdown: where you start)
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
var target: Node2D = null # Shock: the snake it follows
var radius = 90.0         # Explosion size
var sparks = []           # Shock: current small arcs
var heading = null        # Ember: the rotation it will rise with (null = no arrow)
var text = ""             # Score popup
const SCORE_FONT = preload("res://assets/jorge-resources/Game Selection/Odin Rounded - Bold.otf")

# Air: one bolt per straight part of the jump (two when it wrapped around a wall)
static func lightning(parent: Node, parts: Array, bolt_color: Color) -> void:
	var fx = PowerFx.new()
	fx.kind = "lightning"
	fx.color = bolt_color
	fx.duration = LIGHTNING_TIME
	fx.segments = parts
	parent.add_child(fx)

# Water: a burst where the snake appears. opacity < 1 for a subtler one (casting the power)
static func splash(parent: Node, at: Vector2, splash_color: Color, size: float = 1.0, opacity: float = 1.0) -> void:
	var fx = PowerFx.new()
	fx.kind = "splash"
	fx.color = splash_color
	fx.duration = SPLASH_TIME
	fx.center = at
	fx.scale = Vector2(size, size)
	fx.modulate.a = opacity
	parent.add_child(fx)

static func pulse(parent: Node, snake: Node2D, pulse_color: Color) -> void:
	var fx = PowerFx.new()
	fx.kind = "pulse"
	fx.color = pulse_color
	fx.duration = 0.55
	fx.target = snake
	parent.add_child(fx)

static func home(parent: Node, snake: Node2D, ring_color: Color, time: float = 0.85) -> void:
	var fx = PowerFx.new()
	fx.kind = "home"
	fx.color = ring_color
	fx.duration = time
	fx.target = snake
	parent.add_child(fx)

static func burst(parent: Node, at: Vector2, burst_color: Color) -> void:
	var fx = PowerFx.new()
	fx.kind = "burst"
	fx.color = burst_color
	fx.duration = 0.6
	fx.center = at
	parent.add_child(fx)

static func score(parent: Node, at: Vector2, text_color: Color, text: String = "+1") -> void:
	var fx = PowerFx.new()
	fx.kind = "score"
	fx.color = text_color
	fx.duration = 1.0
	fx.center = at
	fx.text = text
	parent.add_child(fx)

# Phoenix: the ember left where the snake died, until it rises
static func ember(parent: Node, at: Vector2, ember_color: Color, wait: float) -> PowerFx:
	var fx = PowerFx.new()
	fx.kind = "ember"
	fx.color = ember_color
	fx.duration = wait
	fx.center = at
	parent.add_child(fx)
	return fx

static func explosion(parent: Node, at: Vector2, fire_color: Color, size: float) -> void:
	var fx = PowerFx.new()
	fx.kind = "explosion"
	fx.color = fire_color
	fx.duration = 0.6
	fx.center = at
	fx.radius = size
	parent.add_child(fx)

static func shock(parent: Node, snake: Node2D, shock_color: Color, time: float) -> void:
	var fx = PowerFx.new()
	fx.kind = "shock"
	fx.color = shock_color
	fx.duration = time
	fx.target = snake
	parent.add_child(fx)

func _ready():
	top_level = true
	z_index = 20 # Above trails and heads
	if kind == "burst":
		position = center
		for i in 10:
			droplets.append(Vector2.RIGHT.rotated(TAU * i / 10.0 + randf_range(-0.25, 0.25)) * randf_range(0.5, 1.1))
	elif kind == "score":
		position = center
		z_index = 30
	elif kind in ["pulse", "home"]:
		position = target.global_position
		if kind == "home":
			z_index = 30
	elif kind in ["ember", "explosion"]:
		position = center
		for i in 18:
			droplets.append(Vector2.RIGHT.rotated(TAU * i / 18.0 + randf_range(-0.15, 0.15)) * randf_range(0.6, 1.15))
	elif kind == "shock":
		_roll_sparks()
	elif kind == "splash":
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
	elif kind in ["pulse", "home"]:
		if is_instance_valid(target) and target.is_inside_tree():
			position = target.global_position
	elif kind == "shock":
		if not is_instance_valid(target) or not target.is_inside_tree():
			queue_free()
			return
		position = target.global_position
		flicker += delta
		if flicker >= FLICKER_INTERVAL:
			flicker = 0.0
			_roll_sparks()
	queue_redraw()

# A few short jagged arcs jumping around the head
func _roll_sparks():
	sparks.clear()
	for i in 4:
		var angle = randf() * TAU
		var from = Vector2.RIGHT.rotated(angle) * randf_range(6, 12)
		var to = Vector2.RIGHT.rotated(angle + randf_range(0.6, 1.6)) * randf_range(14, 26)
		var points = PackedVector2Array([from])
		for k in range(1, 4):
			points.append(from.lerp(to, k / 4.0) + Vector2(randf_range(-5, 5), randf_range(-5, 5)))
		points.append(to)
		sparks.append(points)

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
	if kind == "ember":
		# Pulsing ember and a ring that fills up until the phoenix rises
		var pulse = 0.5 + 0.5 * sin(age * 6.0)
		draw_circle(Vector2.ZERO, 26.0 + 6.0 * pulse, Color(color, 0.18))
		draw_circle(Vector2.ZERO, 9.0 + 3.0 * pulse, Color(color.lightened(0.3), 0.9))
		draw_circle(Vector2.ZERO, 4.0, Color(1, 1, 0.8, 0.95))
		draw_arc(Vector2.ZERO, 34.0, -PI / 2, -PI / 2 + TAU * t, 48, Color(color, 0.85), 4.0, true)
		for i in 3:
			var rise = fmod(age * 0.7 + i / 3.0, 1.0)
			draw_circle(Vector2(sin(age * 3.0 + i * 2.0) * 10.0, -rise * 40.0), 3.0 * (1.0 - rise), Color(color.lightened(0.4), 1.0 - rise))
		if heading != null:
			# Where it will fly when it rises: a dotted line and an arrowhead past the ring
			var dir = Vector2.UP.rotated(heading)
			var side = dir.orthogonal()
			for i in 3:
				draw_circle(dir * (16.0 + i * 7.0), 2.0, Color(1, 1, 0.85, 0.5 + 0.15 * i))
			var tip = dir * (48.0 + 3.0 * pulse)
			var base = dir * 38.0
			draw_colored_polygon(PackedVector2Array([tip, base + side * 7.0, base - side * 7.0]), Color(1, 0.95, 0.75, 0.95))
	elif kind == "explosion":
		var grow = ease(t, 0.3)
		draw_circle(Vector2.ZERO, radius * grow, Color(color, 0.35 * fade))
		draw_circle(Vector2.ZERO, radius * 0.55 * (1.0 - t), Color(1, 0.95, 0.7, 0.8 * fade))
		draw_arc(Vector2.ZERO, radius * grow, 0, TAU, 64, Color(color.lightened(0.3), fade), 6.0, true)
		for direction in droplets:
			draw_circle(direction * radius * 1.1 * grow, 7.0 * fade, Color(color.lightened(0.2), fade))
	elif kind == "pulse":
		# One ring growing out of the head and fading: subtle, never covers the trail
		var grow = ease(t, 0.35)
		draw_arc(Vector2.ZERO, 10.0 + 26.0 * grow, 0, TAU, 40, Color(color.lightened(0.25), 0.55 * fade), 3.0 * fade + 1.0, true)
		draw_circle(Vector2.ZERO, 10.0 + 18.0 * grow, Color(color, 0.12 * fade))
	elif kind == "home":
		# Starts wide and closes in on the head, fading in then out: hard to miss
		var close = ease(t, 0.5)
		var ring = lerp(260.0, 18.0, close)
		var alpha = min(t * 5.0, 1.0) * (1.0 - max(t - 0.75, 0.0) * 4.0)
		draw_circle(Vector2.ZERO, ring, Color(color, 0.12 * alpha))
		draw_arc(Vector2.ZERO, ring, 0, TAU, 72, Color(0, 0, 0, 0.55 * alpha), 14.0, true)
		draw_arc(Vector2.ZERO, ring, 0, TAU, 72, Color(color.lightened(0.2), alpha), 8.0, true)
		draw_circle(Vector2.ZERO, 7.0, Color(color.lightened(0.4), alpha))
	elif kind == "burst":
		# Shards of the snake's color flying apart, and a quick flash
		var grow = ease(t, 0.3)
		draw_circle(Vector2.ZERO, 22.0 * (1.0 - t), Color(1, 1, 1, 0.55 * fade))
		draw_arc(Vector2.ZERO, 8.0 + 30.0 * grow, 0, TAU, 32, Color(color, 0.7 * fade), 3.0, true)
		for direction in droplets:
			var tip = direction * 48.0 * grow
			draw_line(tip * 0.6, tip, Color(color.lightened(0.2), fade), 3.0, true)
	elif kind == "score":
		var rise = ease(t, 0.4) * 34.0
		var alpha = 1.0 if t < 0.6 else 1.0 - (t - 0.6) / 0.4
		var pop = 1.0 + 0.35 * max(0.0, 1.0 - t * 6.0)
		draw_set_transform(Vector2(0, -26.0 - rise), 0.0, Vector2.ONE * pop)
		var font_size = 26
		var width = SCORE_FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		draw_string_outline(SCORE_FONT, Vector2(-width / 2, 9), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 6, Color(0, 0, 0, 0.7 * alpha))
		draw_string(SCORE_FONT, Vector2(-width / 2, 9), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(color.lightened(0.15), alpha))
		draw_set_transform(Vector2.ZERO)
	elif kind == "shock":
		var flash = 0.6 + 0.4 * sin(age * 40.0)
		draw_circle(Vector2.ZERO, 18.0, Color(color, 0.12 * flash))
		for points in sparks:
			draw_polyline(points, Color(color, 0.5 * flash), 5.0, true)
			draw_polyline(points, Color(1, 1, 1, flash), 1.6, true)
	elif kind == "lightning":
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
