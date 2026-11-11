extends Node2D
class_name SnakeFace

# Snake eyes (Options > Accessibility, off by default): two amber eyes with slit pupils at
# the front of the head, leaving the power symbol in the middle readable. The slits follow
# the nearest snake around (or look ahead) and the eyes blink now and then, narrow with
# effort when the power is used, go round when electrocuted and turn to X's on a crash.
# Every few seconds a forked tongue flicks out of the tip.
# Drawn in screen pixels: it cancels the snake's 0.1 scale.

const LOOK_RADIUS = 300.0
const EYE_OFFSET = Vector2(3.3, -4.4)
const EYE_SIZE = Vector2(2.1, 2.7) # Half width, half height
const IRIS = Color(0.98, 0.84, 0.25)
const OUTLINE = Color(0.06, 0.06, 0.08, 0.95)
const TONGUE = Color(0.92, 0.2, 0.32)
const TIP_Y = -8.0

var snake: Node2D
var mood = "normal" # normal, effort, dead
var mood_left = 0.0 # Seconds until a passing mood (effort) wears off
var look = Vector2.ZERO # Where the pupils point, in the head's frame (length 0..1)
var blink_left = 0.0
var next_blink = 3.0
var tongue_left = 0.0
var next_tongue = 2.0

func _ready():
	snake = get_parent()
	scale = Vector2.ONE / snake.scale.x if snake.scale.x != 0 else Vector2.ONE
	z_index = 11 # Over the head and its symbol

func set_mood(new_mood, seconds = 0.0):
	if mood == "dead" and new_mood != "normal":
		return
	mood = new_mood
	mood_left = seconds
	queue_redraw()

func _process(delta):
	if mood_left > 0:
		mood_left -= delta
		if mood_left <= 0 and mood != "dead":
			mood = "normal"
	next_blink -= delta
	if next_blink <= 0:
		blink_left = 0.12
		next_blink = randf_range(2.0, 5.0)
	blink_left = max(blink_left - delta, 0.0)
	next_tongue -= delta
	if next_tongue <= 0:
		tongue_left = 0.35
		next_tongue = randf_range(2.5, 6.0)
	tongue_left = max(tongue_left - delta, 0.0)
	look = look.lerp(_look_target(), min(1.0, delta * 8.0))
	queue_redraw()

# The nearest other snake within reach, else straight ahead
func _look_target() -> Vector2:
	if mood == "dead":
		return Vector2.ZERO
	var nearest = null
	var best = LOOK_RADIUS
	for other in get_tree().get_nodes_in_group("alivePlayers"):
		if other == snake or not other.visible:
			continue
		var distance = other.global_position.distance_to(snake.global_position)
		if distance < best:
			best = distance
			nearest = other
	if nearest == null:
		return Vector2.UP * 0.5
	return (nearest.global_position - snake.global_position).rotated(-snake.global_rotation).normalized()

func _ellipse(center, half, color, filled = true, width = 0.6):
	var points = PackedVector2Array()
	for i in 16:
		var angle = TAU * i / 16.0
		points.append(center + Vector2(cos(angle) * half.x, sin(angle) * half.y))
	if filled:
		draw_colored_polygon(points, color)
	else:
		points.append(points[0])
		draw_polyline(points, color, width, true)

func _draw():
	var shocked = "shocked_time" in snake and snake.shocked_time > 0
	if tongue_left > 0 and mood != "dead":
		# Flicks out and back: a thin line ending in a fork
		var reach = sin(PI * (1.0 - tongue_left / 0.35)) * 5.0
		var root = Vector2(0, TIP_Y + 1.0)
		var tip = root + Vector2(0, -reach)
		draw_line(root, tip, TONGUE, 0.7, true)
		draw_line(tip, tip + Vector2(-1.1, -1.4) * reach / 5.0, TONGUE, 0.6, true)
		draw_line(tip, tip + Vector2(1.1, -1.4) * reach / 5.0, TONGUE, 0.6, true)
	for side in [-1, 1]:
		var center = Vector2(EYE_OFFSET.x * side, EYE_OFFSET.y)
		if mood == "dead":
			_ellipse(center, EYE_SIZE, IRIS.darkened(0.4))
			var a = EYE_SIZE.x * 0.7
			draw_line(center + Vector2(-a, -a), center + Vector2(a, a), OUTLINE, 0.8, true)
			draw_line(center + Vector2(-a, a), center + Vector2(a, -a), OUTLINE, 0.8, true)
			continue
		if blink_left > 0:
			draw_line(center - Vector2(0, EYE_SIZE.y), center + Vector2(0, EYE_SIZE.y), OUTLINE, 0.8, true)
			continue
		# Narrowed with effort, round when electrocuted
		var half = EYE_SIZE
		if mood == "effort":
			half = Vector2(EYE_SIZE.x * 0.45, EYE_SIZE.y)
		elif shocked:
			half = Vector2.ONE * EYE_SIZE.y
		_ellipse(center, half, IRIS)
		_ellipse(center, half, OUTLINE, false)
		# Slit pupil along the head, sliding towards what it looks at
		var slit = Vector2(0.45 if not shocked else 0.9, half.y * 0.85)
		var jitter = Vector2(randf_range(-0.3, 0.3), randf_range(-0.3, 0.3)) if shocked else Vector2.ZERO
		var shift = Vector2(look.x * (half.x - slit.x), look.y * (half.y - slit.y) * 0.6)
		_ellipse(center + shift + jitter, slit, OUTLINE)
