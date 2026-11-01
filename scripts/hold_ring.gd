extends Control
class_name HoldRing

# "Hold PUNCHI to continue": a ring that fills while any PUNCHI (or Enter) is held and
# drains when it's let go. Keys already held when it appears must be released first, so
# a PUNCHI from the previous screen doesn't carry over. Used by the win screen and the
# end-of-match stats.

var hold_time = 1.2
var radius = 22.0
var fill_color = Color.WHITE
var back_color = Color(0, 0, 0, 0.35)
var hold = 0.0
var armed = false

func _init():
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2.ONE * (radius * 2 + 8)

func reset():
	hold = 0.0
	armed = false
	queue_redraw()

# Call every frame; true once it's full
func advance(delta, pressed) -> bool:
	if not armed:
		armed = not pressed
		return false
	if pressed:
		hold = min(hold + delta, hold_time)
	else:
		hold = max(hold - delta * 2.0, 0.0)
	queue_redraw()
	return hold >= hold_time

static func punchi_pressed() -> bool:
	if Input.is_action_pressed("ui_accept"):
		return true
	for id in range(1, 5):
		if Input.is_action_pressed("Player%dUp" % id):
			return true
	return false

func _draw():
	var center = size / 2
	draw_circle(center, radius, back_color)
	draw_arc(center, radius, 0, TAU, 48, Color(1, 1, 1, 0.6), 3.0, true)
	if hold > 0:
		var t = hold / hold_time
		draw_arc(center, radius, -PI / 2, -PI / 2 + TAU * t, 48, fill_color, 7.0, true)
		draw_circle(center, radius * 0.45 * t, fill_color)
