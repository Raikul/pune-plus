extends Control
class_name WinnerFlair

# Decoration of a winner's column on the match stats screen (scripts/match_stats_screen.gd):
# golden laurel branches in its four corners and two serpentine dragons on either side of
# its header, facing the element symbol, breathing a little fire now and then. Drawn in
# code over the whole column (it ignores the mouse), animated.

const GOLD = Color(1.0, 0.82, 0.3)
const GOLD_DARK = Color(0.62, 0.42, 0.08)
const GOLD_LIGHT = Color(1.0, 0.95, 0.7)
## The header band the dragons sit in: from the top of the column, in pixels
var header_top = 40.0
var header_height = 120.0
var accent = Color.WHITE # The snake's color (the dragons' eyes and breath)
var time = 0.0

func _ready():
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	time = randf() * 10.0

func _process(delta):
	time += delta
	queue_redraw()

func _draw():
	# Laurels on the column's border, around each rounded corner. The border is outside
	# this control (in the column's padding): BORDER_INSET to the middle of its line, and
	# the corner's curve is centered CORNER_RADIUS in from there
	var edge = -BORDER_INSET
	var r = BORDER_RADIUS
	_laurel_corner(Vector2(edge + r, edge + r), 1, 1)
	_laurel_corner(Vector2(size.x - edge - r, edge + r), -1, 1)
	_laurel_corner(Vector2(edge + r, size.y - edge - r), 1, -1)
	_laurel_corner(Vector2(size.x - edge - r, size.y - edge - r), -1, -1)
	# Dragons facing each other across the header
	var mid_y = header_top + header_height * 0.55
	# Far enough apart that their heads stay clear of the element symbol in the middle
	_dragon(Vector2(size.x * 0.2, mid_y), 1, 0.0)
	_dragon(Vector2(size.x * 0.8, mid_y), -1, PI)

# --- Laurels ---

## Where the column's border runs, from the edge of this control (the column's padding
## minus half the winner's border width) and the radius of its rounded corners there
## (match_stats_screen.gd: padding 26, border 6, corner radius 22)
const BORDER_INSET = 23.0
const BORDER_RADIUS = 19.0

# Around a rounded corner of the border (`center`: the center of its curve; sx/sy point
# into the column): a stem along the curve and a branch along each of the two edges
func _laurel_corner(center: Vector2, sx: int, sy: int):
	var r = BORDER_RADIUS
	var along_top = center + Vector2(0, -sy * r)  # Where the curve meets the top/bottom edge
	var along_side = center + Vector2(-sx * r, 0) # ...and the side edge
	var from_angle = Vector2(0, -sy).angle()
	var to_angle = Vector2(-sx, 0).angle()
	var arc = PackedVector2Array()
	for i in 9:
		arc.append(center + Vector2.RIGHT.rotated(lerp_angle(from_angle, to_angle, i / 8.0)) * r)
	draw_polyline(arc, GOLD_DARK, 4.0, true)
	draw_polyline(arc, GOLD, 2.0, true)
	var sway = sin(time * 1.6) * 0.03
	_laurel_branch(along_top, Vector2(sx, 0).rotated(sway * sx), 96.0)
	_laurel_branch(along_side, Vector2(0, sy).rotated(-sway * sy), 96.0)
	# A knot and a berry where the corner is
	var joint = center + Vector2(-sx, -sy).normalized() * r
	draw_circle(joint, 7.0, GOLD_DARK)
	draw_circle(joint, 5.0, GOLD)
	draw_circle(joint + Vector2(sx, sy).normalized() * 3.0, 2.5, GOLD_LIGHT)

# A stem straight along the border, with leaves in pairs (one each side of the line)
# getting smaller
func _laurel_branch(start: Vector2, direction: Vector2, length: float):
	var points = PackedVector2Array()
	var steps = 12
	for i in steps + 1:
		var t = float(i) / steps
		points.append(start + direction * length * t)
	draw_polyline(points, GOLD_DARK, 4.0, true)
	draw_polyline(points, GOLD, 2.0, true)
	var leaves = 6
	for i in leaves:
		var t = (i + 0.7) / leaves
		var at = start + direction * length * t
		var leaf_size = lerp(15.0, 8.0, t)
		var angle = direction.angle()
		for side in [-1, 1]:
			var tilt = angle + side * 0.75 - 0.25 * side * t
			_leaf(at, tilt, leaf_size)
	# The tip
	_leaf(points[points.size() - 1], direction.angle(), 9.0)

func _leaf(base: Vector2, angle: float, length: float):
	var tip = base + Vector2.RIGHT.rotated(angle) * length
	var side = Vector2.RIGHT.rotated(angle).orthogonal() * length * 0.32
	var mid = (base + tip) / 2
	var outline = PackedVector2Array([base, mid + side, tip, mid - side])
	draw_colored_polygon(outline, GOLD)
	draw_polyline(PackedVector2Array([base, mid + side, tip, mid - side, base]), GOLD_DARK, 1.2, true)
	draw_line(base, tip, GOLD_DARK, 1.0, true)

# --- Dragons ---

# A coiling eastern dragon, head at `head` facing `facing` (1 = right, -1 = left), its
# body trailing away behind it in waves
func _dragon(head: Vector2, facing: int, phase: float):
	var length = min(150.0, size.x * 0.27)
	var steps = 26
	var spine = []
	for i in steps + 1:
		var s = float(i) / steps
		var wave = sin(s * 2.6 * PI - time * 3.0 + phase)
		# Rising up behind the head, then coiling
		var p = head + Vector2(-facing * length * s, -wave * 22.0 * (0.3 + s) + s * s * -20.0)
		spine.append(p)
	# Body: overlapping discs, thick at the neck and thin at the tail, over a dark outline
	# so it stands out on any column color
	for i in range(steps, -1, -1):
		draw_circle(spine[i], lerp(14.0, 3.5, float(i) / steps) + 4.0, Color(0, 0, 0, 0.55))
	for i in range(steps, -1, -1):
		var s = float(i) / steps
		var radius = lerp(14.0, 3.5, s)
		draw_circle(spine[i], radius + 1.6, GOLD_DARK)
	for i in range(steps, -1, -1):
		var s = float(i) / steps
		var radius = lerp(14.0, 3.5, s)
		draw_circle(spine[i], radius, GOLD)
		# Lighter belly scales
		if i % 2 == 0:
			draw_circle(spine[i] + Vector2(0, radius * 0.35), radius * 0.45, GOLD_LIGHT)
	# Spines along the back
	for i in range(2, steps - 2, 2):
		var forward = (spine[i - 1] - spine[i + 1]).normalized()
		var up = Vector2(forward.y, -forward.x) * (1 if facing > 0 else -1)
		if up.y > 0:
			up = -up
		var s = float(i) / steps
		var radius = lerp(14.0, 3.5, s)
		var base = spine[i] + up * radius * 0.8
		var tri = PackedVector2Array([base - forward * 4.0, base + up * (7.0 - 4.0 * s) - forward * 6.0, base + forward * 3.0])
		draw_colored_polygon(tri, GOLD_DARK)
	# A flame tuft at the tail
	var tail = spine[steps]
	var tail_dir = (spine[steps] - spine[steps - 1]).normalized()
	for k in 3:
		var angle = tail_dir.angle() + (k - 1) * 0.5
		var tip = tail + Vector2.RIGHT.rotated(angle) * (12.0 + 3.0 * sin(time * 8.0 + k))
		draw_colored_polygon(PackedVector2Array([tail + tail_dir.orthogonal() * 3.0, tip, tail - tail_dir.orthogonal() * 3.0]), GOLD)
	# Two little claws
	for i in [7, 16]:
		var s = float(i) / steps
		var foot = spine[i] + Vector2(facing * 3.0, lerp(14.0, 3.5, s) + 5.0)
		draw_line(spine[i], foot, GOLD_DARK, 3.0, true)
		for c in 3:
			draw_line(foot, foot + Vector2(facing * (2.0 + c * 2.5), 4.0), GOLD_DARK, 1.5, true)
	_dragon_head(head, facing)

func _dragon_head(at: Vector2, facing: int):
	var f = float(facing)
	var bob = sin(time * 3.0) * 1.5
	# Drawn around the origin, a size up from the body
	draw_set_transform(at + Vector2(0, bob), 0.0, Vector2(1.45, 1.45))
	at = Vector2.ZERO
	# Horns sweeping back
	for k in 2:
		var root = at + Vector2(-f * (2.0 + k * 5.0), -9.0)
		var horn = PackedVector2Array([root, root + Vector2(-f * (20.0 + k * 4.0), -14.0 + k * 3.0), root + Vector2(f * 4.0, -2.0)])
		draw_colored_polygon(horn, GOLD_DARK)
	# Skull and snout
	var skull = PackedVector2Array([
		at + Vector2(-f * 12.0, -10.0), at + Vector2(f * 6.0, -11.0), at + Vector2(f * 22.0, -5.0),
		at + Vector2(f * 26.0, 1.0), at + Vector2(f * 20.0, 4.0), at + Vector2(f * 4.0, 5.0),
		at + Vector2(-f * 12.0, 8.0)])
	draw_colored_polygon(skull, GOLD)
	draw_polyline(skull + PackedVector2Array([skull[0]]), GOLD_DARK, 1.6, true)
	# Lower jaw, opening when it breathes fire
	var breath = clamp(sin(time * 1.3) * 2.0 - 1.0, 0.0, 1.0)
	var jaw = PackedVector2Array([at + Vector2(f * 2.0, 6.0), at + Vector2(f * 20.0, 6.0 + breath * 7.0), at + Vector2(f * 14.0, 10.0 + breath * 6.0), at + Vector2(-f * 8.0, 10.0)])
	draw_colored_polygon(jaw, GOLD_DARK)
	# Eye in the snake's color
	var eye = at + Vector2(f * 4.0, -4.0)
	draw_circle(eye, 3.6, Color.WHITE)
	draw_circle(eye + Vector2(f * 0.8, 0), 2.0, accent.darkened(0.2))
	# Whiskers, drooping down and back under the jaw (pointing forward they reached the
	# element symbol between the dragons)
	for k in 2:
		var root = at + Vector2(f * 20.0, 2.0 + k * 3.0)
		var points = PackedVector2Array()
		for i in 8:
			var t = i / 7.0
			points.append(root + Vector2(f * (6.0 * t - 16.0 * t * t), 18.0 * t + sin(t * 5.0 + time * 4.0 + k) * 2.0 * t))
		draw_polyline(points, GOLD_DARK, 1.4, true)
	# Fire breath: short and rising, so it never covers the element symbol between them
	if breath > 0.05:
		var mouth = at + Vector2(f * 24.0, 6.0)
		for k in 5:
			var t = fmod(time * 2.5 + k * 0.2, 1.0)
			var puff = mouth + Vector2(f * (6.0 + 14.0 * t), -22.0 * t + sin(k * 2.3 + time * 6.0) * 3.0 * t)
			var flame = Color(1.0, 0.55 + 0.4 * (1.0 - t), 0.15, breath * (1.0 - t))
			draw_circle(puff, (3.0 + 6.0 * t) * breath, flame)
		draw_circle(mouth + Vector2(f * 6.0, 0), 4.0 * breath, Color(accent.lightened(0.3), 0.8 * breath))
	draw_set_transform(Vector2.ZERO)
