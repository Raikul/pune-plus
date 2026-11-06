extends Area2D
class_name TrailSegment

# One piece of a snake's trail. Its circle collider is what kills; what you see is a
# rounded stroke from the previous piece to this one, so a run of pieces reads as one
# smooth line. Pieces are laid by distance (Player.TRAIL_SPACING), so the line looks the
# same at any speed. The color comes from modulate (the snake's color, or the twin's aqua).

## Visual width of the trail, in screen pixels (about the width of the old stamped trail)
const WIDTH = 9.0
## Farther than this from the previous piece, it's not the same stroke (a gap, a teleport,
## the water snake jumping into its twin): the line starts fresh here instead of bridging
const MAX_LINK = 24.0

var previous: Node2D = null
# Round joints hide the seams on curves. See-through trails (the twin's additive ghost)
# skip them: overlapping dots would glow brighter at every joint.
var round_joints = true
## Grows the stroke for effects (the twin's shedding pop)
var thickness = 1.0:
	set(value):
		thickness = value
		queue_redraw()

# Call after both pieces are placed. A piece that's freed (a fireball burns it) leaves a
# clean gap: the next piece stops drawing towards it.
func link_to(segment):
	if segment == null or not is_instance_valid(segment) or segment.is_queued_for_deletion():
		return
	if segment.global_position.distance_to(global_position) > MAX_LINK:
		return
	previous = segment
	segment.tree_exiting.connect(_on_previous_gone)
	queue_redraw()

## Void's power bands (VoidField): the piece is drawn in `band` with a `core` line down
## the middle (Void's own purple), so its trail still reads as one line. Alpha 0 = no band.
var band = Color(0, 0, 0, 0)
var core = Color.WHITE
const CORE_WIDTH = 0.4

func set_band(band_color: Color, core_color: Color):
	if band == band_color and core == core_color:
		return
	band = band_color
	core = core_color
	queue_redraw()

func clear_band():
	if band.a > 0.0:
		band = Color(0, 0, 0, 0)
		queue_redraw()

func _on_previous_gone():
	previous = null
	queue_redraw()

func _draw():
	# The node is scaled down like the snake (0.1), so world sizes are divided by the scale
	var world_to_local = 1.0 / max(global_scale.x, 0.0001)
	var width = WIDTH * thickness * world_to_local
	var radius = width / 2
	var banded = band.a > 0.0
	# With a band the colors are drawn as they are (modulate stays white)
	var outer = band if banded else Color.WHITE
	if previous != null:
		draw_line(to_local(previous.global_position), Vector2.ZERO, outer, width, true)
		if round_joints:
			draw_circle(Vector2.ZERO, radius, outer, true, -1.0, true)
		if banded:
			draw_line(to_local(previous.global_position), Vector2.ZERO, core, width * CORE_WIDTH, true)
			draw_circle(Vector2.ZERO, radius * CORE_WIDTH, core, true, -1.0, true)
	else:
		# The start of a stroke: a round end
		draw_circle(Vector2.ZERO, radius, outer, true, -1.0, true)
		if banded:
			draw_circle(Vector2.ZERO, radius * CORE_WIDTH, core, true, -1.0, true)
