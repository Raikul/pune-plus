extends Area2D
class_name StormArc

# Air's Storm Fence upgrade: lightning crackling across one gap of Air's trail, from the
# end of one stroke to the start of the next. For LIFETIME seconds any other snake caught
# in the gap is electrocuted like by Static Shock: no power for shock_time, and left/right
# swapped for scramble_time (Scrambler). It doesn't kill, and Air itself and the twins go
# through (Player._storm_shock). Drawn in code: a few jagged bolts rerolled every FLICKER
# seconds.

const LIFETIME = 1.0
const FADE_TIME = 0.25
## How thick the electrified band is, in pixels (a little wider than the trail)
const WIDTH = 14.0
const FLICKER = 0.05
const STEP = 9.0
const JITTER = 7.0

var owner_id = 0
var shock_time = 5.0
var scramble_time = 0.0
var color = Color(0.55, 0.85, 1.0)
var from = Vector2.ZERO
var to = Vector2.ZERO
var age = 0.0
var flicker = 0.0
var bolts = []

# Lightning across [a, b] (world positions), owned by an Air snake
static func spawn(parent: Node, a: Vector2, b: Vector2, owner: int, arc_color: Color) -> StormArc:
	var arc = StormArc.new()
	arc.owner_id = owner
	arc.color = arc_color
	arc.from = a
	arc.to = b
	parent.add_child(arc)
	return arc

func _ready():
	add_to_group("hazards")
	add_to_group("storm_arcs")
	top_level = true
	z_index = 8 # Over the trails and Earth's rocks, under the heads
	collision_layer = 1
	collision_mask = 0
	monitoring = false
	global_position = (from + to) / 2
	var shape = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = Vector2(from.distance_to(to), WIDTH)
	shape.shape = rect
	shape.rotation = (to - from).angle()
	add_child(shape)
	_roll()

func _process(delta):
	age += delta
	if age >= LIFETIME:
		queue_free()
		return
	# Harmless while it fades out
	if age >= LIFETIME - FADE_TIME and monitorable:
		set_deferred("monitorable", false)
	flicker += delta
	if flicker >= FLICKER:
		flicker = 0.0
		_roll()
	queue_redraw()

func _roll():
	bolts.clear()
	var a = from - global_position
	var b = to - global_position
	var normal = (b - a).normalized().orthogonal()
	for i in 2:
		var steps = max(2, int(a.distance_to(b) / STEP))
		var points = PackedVector2Array([a])
		for k in range(1, steps):
			points.append(a.lerp(b, float(k) / steps) + normal * randf_range(-JITTER, JITTER))
		points.append(b)
		bolts.append(points)

func _draw():
	var fade = clamp((LIFETIME - age) / FADE_TIME, 0.0, 1.0)
	var flash = 0.75 + 0.25 * sin(age * 50.0)
	var a = from - global_position
	var b = to - global_position
	# The glow of the deadly band, then the bolts on top
	draw_line(a, b, Color(color, 0.18 * fade), WIDTH + 6.0, true)
	for i in bolts.size():
		draw_polyline(bolts[i], Color(color, 0.45 * fade * flash), 7.0 - i * 2.0, true)
		draw_polyline(bolts[i], Color(1, 1, 1, fade * flash), 2.2 - i * 0.8, true)
	# Sparks where it plugs into the trail
	for end in [a, b]:
		draw_circle(end, 7.0 * fade * flash, Color(Color.WHITE, 0.85 * fade))
		draw_circle(end, 12.0 * fade, Color(color, 0.35 * fade))
