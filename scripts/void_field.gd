extends Node2D
class_name VoidField

# What Void's power looks like (scripts/void_power.gd), drawn in code around the head:
# while the void is open, a wiggling ring with a dark swirl inside; and always, one small
# orb per power it holds circling the head, in that power's color (blinking when about to
# run out, with a bright rim when it's kept for the whole round).

var power: VoidPower
var time = 0.0
var opened = 0.0 # 0..1, eases the ring in and out

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
	queue_redraw()

func _draw():
	var color = Color(Global.playerColors[Global.VOID_ID])
	if opened > 0.0:
		var r = power.radius() * (0.6 + 0.4 * opened)
		# Dark swirl inside
		draw_circle(Vector2.ZERO, r, Color(0.08, 0.02, 0.15, 0.42 * opened), true, -1.0, true)
		for arm in 3:
			var points = PackedVector2Array()
			for i in 16:
				var t = i / 15.0
				var angle = -time * 2.4 + arm * TAU / 3.0 + t * 2.6
				points.append(Vector2.RIGHT.rotated(angle) * r * (0.15 + 0.8 * t))
			draw_polyline(points, Color(0.62, 0.36, 1.0, 0.35 * opened), 3.0, true)
		# The wiggling edge: two noisy rings, purple under white
		for layer in 2:
			var points = PackedVector2Array()
			var steps = 72
			for i in steps + 1:
				var angle = TAU * i / steps
				var wobble = sin(angle * 7.0 + time * 6.0 + layer) * 0.06 + sin(angle * 3.0 - time * 4.0) * 0.05
				points.append(Vector2.RIGHT.rotated(angle) * r * (1.0 + wobble))
			var ring_color = Color(0.62, 0.36, 1.0, 0.8 * opened) if layer == 0 else Color(color, 0.9 * opened)
			draw_polyline(points, ring_color, 5.0 if layer == 0 else 2.0, true)
	# The powers it holds
	var elements = power.held.keys()
	elements.sort()
	for i in elements.size():
		var element = elements[i]
		var entry = power.held[element]
		var angle = time * 2.0 + TAU * i / max(elements.size(), 1)
		var at = Vector2.RIGHT.rotated(angle) * 26.0
		var alpha = 1.0
		if entry.left != INF and entry.left < 1.5:
			alpha = 0.35 + 0.65 * absf(sin(time * 12.0))
		var orb_color = Color(Global.playerColors[element])
		draw_circle(at, 6.5, Color(orb_color, alpha), true, -1.0, true)
		if entry.left == INF:
			draw_arc(at, 9.0, 0, TAU, 20, Color(1, 1, 1, 0.8 * alpha), 1.5, true)
