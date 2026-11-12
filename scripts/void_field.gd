extends Node2D
class_name VoidField

# What Void's power looks like (scripts/void_power.gd), drawn in code around the head:
# while the void is open, a faint wiggling ring with a soft swirl inside. The powers it
# holds don't float over the arena: they color the newest stretch of its trail, like
# scales behind its head, one band per power in the order it got them (the first right
# behind the head), with Void's purple still running down the middle. A power kept for
# the whole round gets a longer band.

## Trail pieces (Player.TRAIL_SPACING apart) per power band, and for a whole-round power
const BAND = 7
const ROUND_BAND = 10

var power: VoidPower
var time = 0.0
var opened = 0.0 # 0..1, eases the ring in and out
var tinted = {} # trail piece -> true: the pieces colored last frame

func _ready():
	top_level = true
	z_index = 9

func _process(delta):
	if power == null or not is_instance_valid(power) or not is_instance_valid(power.player):
		queue_free()
		return
	var snake = power.player
	global_position = snake.global_position
	visible = snake.is_in_group("alivePlayers") and not snake.reviving
	time += delta
	opened = move_toward(opened, 1.0 if power.field_active() else 0.0, delta * 6.0)
	_color_scales(snake)
	queue_redraw()

# The bands of color on the newest trail pieces (Player.recent_trail, newest last)
func _color_scales(snake):
	var colors = []
	for element in power.held: # In the order it got them
		var band = ROUND_BAND if power.held[element].uses == INF else BAND
		for i in band:
			colors.append(Color(Global.playerColors[element]))
	var now = {}
	var recent = snake.recent_trail
	var behind = 0
	for i in range(recent.size() - 1, -1, -1):
		if behind >= colors.size():
			break
		var piece = recent[i]
		if not is_instance_valid(piece) or piece.is_queued_for_deletion():
			continue
		piece.modulate = Color.WHITE
		piece.set_band(colors[behind], snake.head_modulate)
		now[piece] = true
		behind += 1
	# Pieces no longer in a band (the power was cast) go back to Void's own color
	for piece in tinted:
		if not now.has(piece) and is_instance_valid(piece):
			piece.clear_band()
			piece.modulate = snake.head_modulate
	tinted = now

func _draw():
	if opened <= 0.0:
		return
	var color = Color(Global.playerColors[Global.VOID_ID])
	var r = power.radius() * (0.6 + 0.4 * opened)
	# A soft swirl inside
	draw_circle(Vector2.ZERO, r, Color(0.08, 0.02, 0.15, 0.14 * opened), true, -1.0, true)
	for arm in 3:
		var points = PackedVector2Array()
		for i in 16:
			var t = i / 15.0
			var angle = -time * 2.4 + arm * TAU / 3.0 + t * 2.6
			points.append(Vector2.RIGHT.rotated(angle) * r * (0.15 + 0.8 * t))
		draw_polyline(points, Color(color, 0.12 * opened), 2.0, true)
	# The wiggling edge: one faint noisy ring
	var edge = PackedVector2Array()
	var steps = 72
	for i in steps + 1:
		var angle = TAU * i / steps
		var wobble = sin(angle * 7.0 + time * 6.0) * 0.06 + sin(angle * 3.0 - time * 4.0) * 0.05
		edge.append(Vector2.RIGHT.rotated(angle) * r * (1.0 + wobble))
	draw_polyline(edge, Color(color, 0.38 * opened), 2.0, true)
