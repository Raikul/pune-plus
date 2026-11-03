extends Node2D
class_name OffscreenMarker

# While its snake is outside the window (Earth's Off the Map), a small arrow in the
# snake's color sits on the window edge where it went out, so it can find its way back.

const EDGE_INSET = 18.0
const SIZE = 13.0

var snake: Node2D
var color = Color.WHITE

func _ready():
	snake = get_parent()
	top_level = true
	z_index = 30
	color = Color(Global.playerColors[snake.playerId]).lightened(0.3)

func _process(_delta):
	var screen = get_viewport_rect().grow(-2)
	visible = snake.is_in_group("alivePlayers") and not screen.has_point(snake.global_position)
	if visible:
		queue_redraw()

func _draw():
	var screen = get_viewport_rect().grow(-EDGE_INSET)
	var at = snake.global_position.clamp(screen.position, screen.end)
	var outward = (snake.global_position - at).normalized()
	if outward == Vector2.ZERO:
		return
	var side = outward.orthogonal()
	var tip = at + outward * SIZE
	var arrow = PackedVector2Array([at + side * SIZE * 0.8, tip, at - side * SIZE * 0.8])
	var pulse = 0.7 + 0.3 * sin(Time.get_ticks_msec() / 90.0)
	draw_colored_polygon(arrow, Color(color, pulse))
	draw_polyline(PackedVector2Array([arrow[0], arrow[1], arrow[2], arrow[0]]), Color(0, 0, 0, 0.6), 2.0, true)
