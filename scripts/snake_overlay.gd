extends Node2D
class_name SnakeOverlay

# Accessibility aids drawn over a snake (Options > Accessibility, both off by default):
# - nameplate: its player's name, small, under the head (over it while heading down)
# - direction arrow: a small chevron a little ahead of the head
# Hidden while the snake is dead, an ember or hiding its head (Earth's rocky path).

const FONT = preload("res://assets/jorge-resources/Game Selection/Odin Rounded - Bold.otf")
const NAME_SIZE = 17
const NAME_OFFSET = 24.0
const ARROW_DISTANCE = 26.0

var snake: Node2D
var label = ""
var color = Color.WHITE

func _ready():
	snake = get_parent()
	top_level = true
	z_index = 25
	label = Global.player_name(snake.playerId)
	color = Color(Global.playerColors[snake.playerId])

func _process(_delta):
	global_position = snake.global_position
	visible = snake.is_in_group("alivePlayers") and snake.get_node("HeadSprite").visible
	queue_redraw()

func _draw():
	if Global.direction_arrow:
		var forward = Vector2.UP.rotated(snake.global_rotation)
		var side = forward.orthogonal()
		var tip = forward * (ARROW_DISTANCE + 7)
		var base = forward * ARROW_DISTANCE
		var arrow = PackedVector2Array([base + side * 6, tip, base - side * 6])
		draw_polyline(arrow, Color(0, 0, 0, 0.5), 5.0, true)
		draw_polyline(arrow, Color(color.lightened(0.3), 0.9), 2.5, true)
	if Global.nameplates:
		var width = FONT.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, NAME_SIZE).x
		# Under the head, or over it while heading down (out of the arrow's way)
		var below = Vector2.UP.rotated(snake.global_rotation).y < 0.3
		var at = Vector2(-width / 2, NAME_OFFSET + NAME_SIZE * 0.5 if below else -NAME_OFFSET)
		draw_string_outline(FONT, at, label, HORIZONTAL_ALIGNMENT_LEFT, -1, NAME_SIZE, 5, Color(0, 0, 0, 0.75))
		draw_string(FONT, at, label, HORIZONTAL_ALIGNMENT_LEFT, -1, NAME_SIZE, Color(color.lightened(0.45), 0.9))
