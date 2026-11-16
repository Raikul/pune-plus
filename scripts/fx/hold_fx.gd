extends Node2D
class_name HoldFx

# What a held power looks like while Punchi is down (Power.hold_begin), drawn in code
# around the head and freed when it is let go:
# - "dual": two arrows ahead that spread apart (Dual Ball)
# - "breath": a ring that fills, and a cone once it is full (Breath Control with Blizzard)
# - "ice": a frost shell growing around the head (Ice)

var snake: Node2D
var kind = ""
var color = Color.WHITE
## 0..1: how far the hold is (spread of the arrows, ring, ice)
var progress = 0.0
## The hold is at its limit: Blizzard is ready, the ice is at its thickest
var full = false
## Dual Ball: the arrows' spread (radians) at this progress
var spread = 0.0
var time = 0.0

static func spawn(snake_node: Node2D, hold_kind: String, hold_color: Color) -> HoldFx:
	var fx = HoldFx.new()
	fx.snake = snake_node
	fx.kind = hold_kind
	fx.color = hold_color
	fx.top_level = true
	fx.z_index = 25
	snake_node.add_child(fx)
	fx.global_position = snake_node.global_position
	return fx

func _process(delta):
	if snake == null or not is_instance_valid(snake):
		queue_free()
		return
	time += delta
	global_position = snake.global_position
	rotation = snake.rotation
	queue_redraw()

func _draw():
	match kind:
		"dual":
			_draw_arrows()
		"breath":
			_draw_breath()
		"ice":
			_draw_ice()

# Two arrows, one on each side of the heading, opening as the hold grows
func _draw_arrows():
	for side in [-1, 1]:
		var dir = Vector2.UP.rotated(spread * side)
		var base = dir * 22.0
		var tip = dir * 52.0
		var wing = dir.orthogonal() * 6.0
		var shade = Color(1.0, 0.55 + 0.3 * progress, 0.15, 0.95)
		draw_line(base, tip, shade, 3.0, true)
		draw_colored_polygon(PackedVector2Array([tip + dir * 9.0, tip + wing, tip - wing]), shade)

func _draw_breath():
	var ring = Color(0.7, 0.92, 1.0, 0.85)
	draw_arc(Vector2.ZERO, 17.0, -PI / 2, -PI / 2 + TAU * progress, 32, ring, 2.5, true)
	if full:
		# Blizzard is ready: the cone it will push in
		var pulse = 0.5 + 0.5 * sin(time * 14.0)
		var length = AirBlizzard.REACH
		var half = deg_to_rad(AirBlizzard.HALF_ANGLE_DEGREES)
		var a = Vector2.UP.rotated(-half) * length
		var b = Vector2.UP.rotated(half) * length
		draw_colored_polygon(PackedVector2Array([Vector2.ZERO, a, b]), Color(0.7, 0.92, 1.0, 0.10 + 0.08 * pulse))
		draw_line(Vector2.ZERO, a, Color(0.8, 0.95, 1.0, 0.7), 2.0, true)
		draw_line(Vector2.ZERO, b, Color(0.8, 0.95, 1.0, 0.7), 2.0, true)

func _draw_ice():
	var grow = 0.35 + 0.65 * min(progress * 2.0, 1.0)
	var shell = 20.0 * grow
	draw_circle(Vector2.ZERO, shell, Color(0.65, 0.9, 1.0, 0.22), true, -1.0, true)
	draw_arc(Vector2.ZERO, shell, 0, TAU, 40, Color(0.85, 0.97, 1.0, 0.9), 2.0, true)
	# A six-armed snowflake
	for i in 6:
		var dir = Vector2.RIGHT.rotated(TAU * i / 6.0 + time * 0.4)
		var reach = shell * 1.25
		draw_line(dir * shell * 0.2, dir * reach, Color(0.9, 0.98, 1.0, 0.9), 1.6, true)
		var fork = dir * reach * 0.7
		draw_line(fork, fork + dir.rotated(0.6) * reach * 0.28, Color(0.9, 0.98, 1.0, 0.8), 1.2, true)
		draw_line(fork, fork + dir.rotated(-0.6) * reach * 0.28, Color(0.9, 0.98, 1.0, 0.8), 1.2, true)
	# How long it can still be held
	draw_arc(Vector2.ZERO, shell + 6.0, -PI / 2, -PI / 2 + TAU * (1.0 - progress), 32, Color(0.5, 0.8, 1.0, 0.8), 2.0, true)
