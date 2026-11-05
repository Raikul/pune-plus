extends Control
class_name UpgradeIcon

# Animated icon of an upgrade card. Drawn in code so every upgrade gets a small
# looping animation from the art we already have. Trails are drawn like the snakes' own
# (scripts/trail_segment.gd): one smooth antialiased stroke with round ends, not a row of
# dots; circles, arcs and shapes are antialiased too (_stroke, _dot, _shape).

const FIREBALL_SHEET = preload("res://fireball sprite/Fires/Small_Fireball_10x26.png")
const FIREBALL_FRAME_SIZE = Vector2(10, 26)
const FIREBALL_COLUMNS = 10
const FIREBALL_FRAMES = 60
const FIREBALL_FPS = 15.0
const FIRE_WATER_SYMBOL = preload("res://assets/jorge-resources/Game Selection/Fire-Water symbol.png")
const AIR_EARTH_SYMBOL = preload("res://assets/jorge-resources/Game Selection/Air-Earth symbol.png")
const STONE_TEXTURE = preload("res://assets/jorge-resources/Powers/Earth/cuerpo_3.png")
const PUNCHI_ICON = preload("res://assets/jorge-resources/Game Selection/punchi icon.png")
const COOLDOWN_CYCLE = 1.4

var kind = ""
var color = Color.WHITE
var speed_scale = 1.0
var time = 0.0

func _ready():
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# The pixel-art fireball stays crisp, the big symbol art is smoothed when scaled down
	if kind.begins_with("fireball") or kind == "wildfire":
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	else:
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

func _process(delta):
	time += delta * speed_scale
	queue_redraw()

func _draw():
	var center = size / 2
	match kind:
		"fireball":
			_draw_fireball(center + Vector2(sin(time * 3.0) * 8, 0), 1.0)
		"fireball_big":
			var grow = 0.5 + 0.5 * sin(time * 3.0)
			var ball = _draw_fireball(center, 0.7 + 0.35 * grow)
			draw_arc(ball, size.y * (0.16 + 0.12 * grow), 0, TAU, 32, Color(1, 0.6, 0.1, 0.9 - 0.6 * grow), 3.0, true)
		"gap_wide":
			_draw_trail(60.0)
		"gap_narrow":
			_draw_trail(16.0)
		"speed":
			_draw_speed(center)
		"cooldown":
			_draw_cooldown(center)
		"wall_warp":
			_draw_wall_warp(center)
		"second_wind":
			_draw_second_wind()
		"wide_body":
			_draw_wide_body(center)
		"stone_walk":
			_draw_stone_walk(center)
		"burrower":
			_draw_burrower(center)
		"bedrock":
			_draw_bedrock(center)
		"wildfire":
			_draw_wildfire(center)
		"skip":
			_draw_skip(center)
		"phoenix":
			_draw_phoenix(center)
		"shock":
			_draw_shock(center, false)
		"scramble":
			_draw_shock(center, true)
		"storm_fence":
			_draw_storm_fence(center)
		"extra_copy":
			_draw_twins(center, "2 MAX")
		"twin_burst":
			_draw_twins(center, "x2")
		"third_twin":
			_draw_twins(center, "3 MAX")
		"lasting_twin":
			_draw_lasting_twin()
		"hearth":
			_draw_hearth(center, false)
		"pyre":
			_draw_hearth(center, true)
		"ice":
			_draw_gap_patch(center, true)
		"roots":
			_draw_gap_patch(center, false)
		"void_time", "void_wide", "void_memory", "void_mimic", "void_hoard":
			_draw_void(center, kind)

# Water symbols splitting from the middle one, with a caption
func _draw_twins(center, caption):
	var split = 0.5 + 0.5 * sin(time * 2.5)
	var offset = Vector2(size.x * 0.22 * split, 0)
	_draw_symbol(FIRE_WATER_SYMBOL, center - offset, size.x * 0.42, true, 0.5)
	_draw_symbol(FIRE_WATER_SYMBOL, center + offset, size.x * 0.42, true, 0.5)
	_draw_symbol(FIRE_WATER_SYMBOL, center, size.x * 0.42, true)
	_draw_text(caption, size.y * 0.95, 26)

# Draws one frame of the fireball sprite sheet flying to the right and returns where the ball is
func _draw_fireball(pos, scale_mult) -> Vector2:
	var frame = int(time * FIREBALL_FPS) % FIREBALL_FRAMES
	var cell = Vector2(frame % FIREBALL_COLUMNS, frame / FIREBALL_COLUMNS)
	var region = Rect2(cell * FIREBALL_FRAME_SIZE, FIREBALL_FRAME_SIZE)
	var length = min(size.x, size.y * 1.6) * 0.8 * scale_mult
	var width = length * FIREBALL_FRAME_SIZE.x / FIREBALL_FRAME_SIZE.y
	var ball = pos + Vector2(length * 0.2, 0)
	_dot(ball, width * 0.9, Color(1, 0.55, 0.1, 0.25))
	# The sheet's flames point up: flip and turn it so the flames trail to the left
	draw_set_transform(pos, PI / 2, Vector2(1, -1))
	draw_texture_rect_region(FIREBALL_SHEET, Rect2(-width / 2, -length / 2, width, length), region)
	draw_set_transform(Vector2.ZERO)
	return ball

# A snake trail scrolling to the right with holes of gap_length pixels
func _draw_trail(gap_length):
	var dash = 52.0
	var period = dash + gap_length
	var head_x = size.x - 16
	var stroke = PackedVector2Array()
	var x = 4.0
	while x <= head_x - 10:
		if fposmod(x - time * 70.0, period) < dash:
			stroke.append(Vector2(x, _trail_y(x)))
		elif not stroke.is_empty():
			_stroke(stroke, color, TRAIL_WIDTH)
			stroke = PackedVector2Array()
		x += 2.0
	_stroke(stroke, color, TRAIL_WIDTH)
	_dot(Vector2(head_x, _trail_y(head_x)), 11, color.lightened(0.35))

# An aqua twin trail with a shimmer running along it: it never fades to the water color
func _draw_lasting_twin():
	var head_x = size.x - 16
	var points = PackedVector2Array()
	var colors = PackedColorArray()
	var x = 4.0
	while x <= head_x - 10:
		var shimmer = 0.5 + 0.5 * sin(x * 0.08 - time * 6.0)
		points.append(Vector2(x, _trail_y(x)))
		colors.append(Global.twin_color().lerp(Color.WHITE, shimmer * 0.45))
		x += 2.0
	draw_polyline_colors(points, colors, TRAIL_WIDTH, true)
	_dot(points[0], TRAIL_WIDTH / 2, colors[0])
	_dot(points[points.size() - 1], TRAIL_WIDTH / 2, colors[colors.size() - 1])
	_dot(Vector2(head_x, _trail_y(head_x)), 11, Global.twin_color().lightened(0.35))

func _trail_y(x):
	return size.y / 2 + sin(x * 0.045 - time * 2.0) * 14

# Snake head rushing to the right with speed streaks and chevrons
func _draw_speed(center):
	var head = Vector2(size.x * 0.62 + sin(time * 9.0) * 3, center.y)
	for i in 5:
		var y = center.y + (i - 2) * 12
		var length = 22 + 14 * ((i * 37) % 3)
		var x = size.x - fposmod(time * 260.0 + i * 47, size.x + length)
		_stroke(PackedVector2Array([Vector2(x, y), Vector2(x + length, y)]), Color(color, 0.45), 3.0)
	_stroke(PackedVector2Array([Vector2(8, center.y), Vector2(head.x - 10, center.y)]), color, TRAIL_WIDTH - 2.0)
	_dot(head, 12, color.lightened(0.35))
	for i in 2:
		var tip_x = size.x * 0.82 + i * 13 + fposmod(time * 30.0, 6.0)
		_stroke(PackedVector2Array([Vector2(tip_x - 9, center.y - 11), Vector2(tip_x, center.y), Vector2(tip_x - 9, center.y + 11)]), Color.WHITE, 4.0)

# Cooldown ring around the Punchi icon that refills quickly and pops when ready
func _draw_cooldown(center):
	var progress = fmod(time, COOLDOWN_CYCLE) / (COOLDOWN_CYCLE * 0.7)
	var radius = size.y * 0.38
	draw_arc(center, radius, 0, TAU, 64, Color(0.35, 0.35, 0.35), 8, true)
	if progress < 1.0:
		var end = -PI / 2 + TAU * progress
		draw_arc(center, radius, -PI / 2, end, 64, color, 8, true)
		# Round ends, like a trail
		_dot(center + Vector2.UP * radius, 4, color)
		_dot(center + Vector2.RIGHT.rotated(end) * radius, 4, color)
	else:
		# Ready: full ring with a burst expanding outward
		var burst = (progress - 1.0) / 0.43
		draw_arc(center, radius, 0, TAU, 64, color.lightened(0.4), 8, true)
		draw_arc(center, radius + 4 + burst * 14, 0, TAU, 64, Color(color, 1.0 - burst), 3, true)
	var icon_height = radius * 1.2
	var icon_width = icon_height * PUNCHI_ICON.get_width() / float(PUNCHI_ICON.get_height())
	draw_texture_rect(PUNCHI_ICON, Rect2(center - Vector2(icon_width, icon_height) / 2, Vector2(icon_width, icon_height)), false)

func _draw_wall_warp(center):
	var span = size.x
	var x = fposmod(time * 80.0, span)
	for offset in [-span, 0.0, span]:
		_draw_symbol(AIR_EARTH_SYMBOL, Vector2(x + offset, center.y), size.x * 0.4, false)
	# Walls light up while the symbol passes through them
	var crossing = clamp(1.0 - min(x, span - x) / 30.0, 0.0, 1.0)
	var wall_color = Color(0.55, 0.55, 0.55).lerp(Color.WHITE, crossing)
	draw_rect(Rect2(0, 8, 6, size.y - 16), wall_color)
	draw_rect(Rect2(size.x - 6, 8, 6, size.y - 16), wall_color)

func _draw_second_wind():
	var cycle = fmod(time, 1.8)
	var spots = [
		Vector2(size.x * 0.2, size.y * 0.6),
		Vector2(size.x * 0.5, size.y * 0.35),
		Vector2(size.x * 0.8, size.y * 0.6),
	]
	var current = 0
	if cycle > 0.5:
		current = 1
	if cycle > 0.8:
		current = 2
	for i in current:
		_draw_symbol(AIR_EARTH_SYMBOL, spots[i], size.x * 0.28, false, 0.25)
	_draw_symbol(AIR_EARTH_SYMBOL, spots[current], size.x * 0.28, false)
	_draw_text("2x", size.y * 0.95, 26)

func _draw_wide_body(center):
	var widen = 0.5 + 0.5 * sin(time * 3.0)
	var stretch = 1.0 + 0.6 * widen
	var symbol_width = size.x * 0.38
	_draw_symbol(AIR_EARTH_SYMBOL, center, symbol_width, true, 1.0, Vector2(stretch, 1.0))
	var half_width = symbol_width * stretch / 2
	for side in [-1, 1]:
		var base = center + Vector2(side * (half_width + 4), 0)
		var tip = base + Vector2(side * 14, 0)
		_stroke(PackedVector2Array([base, tip]), color, 4.0)
		_stroke(PackedVector2Array([tip + Vector2(-side * 8, -8), tip, tip + Vector2(-side * 8, 8)]), color, 4.0)

# The Earth symbol walks through a stone wall, which turns see-through while it passes
func _draw_stone_walk(center):
	var span = size.x
	var x = fposmod(time * 60.0, span)
	var crossing = clamp(1.0 - abs(x - center.x) / 30.0, 0.0, 1.0)
	var wall_height = size.y * 0.8
	var wall_width = wall_height * STONE_TEXTURE.get_height() / float(STONE_TEXTURE.get_width())
	draw_set_transform(center, PI / 2, Vector2.ONE)
	draw_texture_rect(STONE_TEXTURE, Rect2(-wall_height / 2, -wall_width / 2, wall_height, wall_width), false,
		Color(1, 1, 1, 1.0 - 0.6 * crossing))
	draw_set_transform(Vector2.ZERO)
	_draw_symbol(AIR_EARTH_SYMBOL, Vector2(x, center.y), size.x * 0.32, true)

# The Earth symbol digs through a wall block, dimmed while it's inside
func _draw_burrower(center):
	var block = Rect2(center.x - size.x * 0.13, size.y * 0.15, size.x * 0.26, size.y * 0.7)
	var x = fposmod(time * 70.0, size.x + 40.0) - 20.0
	var inside = x > block.position.x and x < block.end.x
	draw_rect(block, Color(0.62, 0.36, 1.0, 0.35))
	draw_rect(block, Color(0.62, 0.36, 1.0), false, 3.0)
	_draw_symbol(AIR_EARTH_SYMBOL, Vector2(x, center.y), size.x * 0.3, true, 0.45 if inside else 1.0)
	if inside:
		# Bits of rock flying off where it digs
		for i in 3:
			var bit = Vector2(x, center.y) + Vector2(randf_range(-8, 8), randf_range(-size.y * 0.25, size.y * 0.25))
			_dot(bit, 2.5, Color(0.8, 0.7, 0.55))

# The Earth symbol with a ring that runs past a full turn: the armor lasts longer
func _draw_bedrock(center):
	var cycle = fmod(time, 2.0) / 2.0
	_draw_symbol(AIR_EARTH_SYMBOL, center, size.x * 0.36, true)
	var radius = size.x * 0.34
	draw_arc(center, radius, -PI / 2, -PI / 2 + TAU * min(cycle * 1.25, 1.0), 40, Color(color, 0.8), 4.0, true)
	if cycle > 0.8:
		draw_arc(center, radius + 7, -PI / 2, -PI / 2 + TAU * (cycle - 0.8) * 1.25, 40, Color.WHITE, 3.0, true)
	_draw_text("+", size.y * 0.95, 30)

# Two arrows pointing on, past an empty slot
func _draw_skip(center):
	var nudge = sin(time * 4.0) * 4.0
	draw_rect(Rect2(center.x - size.x * 0.36, center.y - size.y * 0.2, size.x * 0.24, size.y * 0.4), Color(1, 1, 1, 0.35), false, 3.0)
	for i in 2:
		var x = center.x + i * 18.0 + nudge
		_shape(PackedVector2Array([Vector2(x, center.y - 16), Vector2(x + 18, center.y), Vector2(x, center.y + 16)]), Color(1, 1, 1, 0.85))

# A fireball flying across, a strip of flickering flames behind it
func _draw_wildfire(center):
	var x = fposmod(time * 60.0, size.x + 30.0) - 15.0
	var flame_x = 4.0
	while flame_x < x - 10:
		var age = (x - flame_x) / size.x
		var flicker = 0.7 + 0.3 * sin(time * 20.0 + flame_x)
		var height = (14.0 - age * 8.0) * flicker
		_shape(PackedVector2Array([
			Vector2(flame_x - 6, center.y + 8), Vector2(flame_x, center.y + 8 - height * 1.6), Vector2(flame_x + 6, center.y + 8)]),
			Color(1.0, 0.45 + 0.3 * flicker, 0.1, 0.9 - age * 0.6))
		flame_x += 10.0
	_draw_fireball(Vector2(x, center.y), 0.55)

# Fire symbol burns down to an ember and bursts back
func _draw_phoenix(center):
	var cycle = fmod(time, 2.4) / 2.4
	if cycle < 0.35:
		_draw_symbol(FIRE_WATER_SYMBOL, center, size.x * 0.42, false, 1.0 - cycle / 0.35)
	elif cycle < 0.75:
		var pulse = 0.5 + 0.5 * sin(time * 9.0)
		_dot(center, 6.0 + 3.0 * pulse, Color(1, 0.6, 0.15, 0.9))
		draw_arc(center, 20.0, -PI / 2, -PI / 2 + TAU * (cycle - 0.35) / 0.4, 32, Color(1, 0.5, 0.1), 3.0, true)
	else:
		var burst = (cycle - 0.75) / 0.25
		_dot(center, size.x * 0.4 * burst, Color(1, 0.55, 0.1, 0.4 * (1.0 - burst)))
		_draw_symbol(FIRE_WATER_SYMBOL, center, size.x * 0.42, false, burst)

# A bolt hits a head, which crackles; the Scrambler swaps its arrows too
func _draw_shock(center, scramble):
	var head = center + Vector2(size.x * 0.18, 0)
	var flash = 0.5 + 0.5 * sin(time * 30.0)
	var from = Vector2(4, 10)
	var points = PackedVector2Array([from])
	for i in range(1, 5):
		points.append(from.lerp(head, i / 5.0) + Vector2(0, (8 if i % 2 == 0 else -8)))
	points.append(head)
	draw_polyline(points, Color(0.55, 0.85, 1.0, 0.6), 6.0, true)
	draw_polyline(points, Color(1, 1, 1, 0.6 + 0.4 * flash), 2.0, true)
	_dot(head, 12.0, Color(color, 0.9))
	for i in 3:
		var angle = time * 5.0 + i * TAU / 3.0
		var a = head + Vector2.RIGHT.rotated(angle) * 15.0
		var b = head + Vector2.RIGHT.rotated(angle + 0.7) * 24.0
		draw_line(a, b, Color(0.7, 0.95, 1.0, flash), 2.0, true)
	if scramble:
		var swap = 0.5 + 0.5 * sin(time * 3.0)
		var y = size.y * 0.85
		var left = lerp(center.x - 24.0, center.x + 24.0, swap)
		var right = lerp(center.x + 24.0, center.x - 24.0, swap)
		# Left arrow and right arrow trading places
		_shape(PackedVector2Array([Vector2(left - 8, y), Vector2(left + 6, y - 9), Vector2(left + 6, y + 9)]), Color.WHITE)
		_shape(PackedVector2Array([Vector2(right + 8, y), Vector2(right - 6, y - 9), Vector2(right - 6, y + 9)]), Color.WHITE)
	else:
		_draw_text("5s", size.y * 0.95, 24)

# A trail with gaps; every so often lightning fills the gaps
func _draw_storm_fence(center):
	var y = center.y + size.y * 0.08
	var left = 6.0
	var right = size.x - 6.0
	var gap = size.x * 0.13
	var stroke = (right - left - 2 * gap) / 3.0
	var cycle = fmod(time, 1.6)
	var lit = cycle < 0.7
	var flash = 0.6 + 0.4 * sin(time * 45.0)
	var trail_color = color
	for i in 3:
		var a = left + i * (stroke + gap)
		_stroke(PackedVector2Array([Vector2(a, y), Vector2(a + stroke, y)]), trail_color, 7.0)
	for i in 2:
		var a = Vector2(left + stroke + i * (stroke + gap), y)
		var b = a + Vector2(gap, 0)
		if lit:
			var points = PackedVector2Array([a])
			for k in range(1, 4):
				points.append(a.lerp(b, k / 4.0) + Vector2(0, randf_range(-7, 7)))
			points.append(b)
			draw_polyline(points, Color(0.55, 0.85, 1.0, 0.55 * flash), 7.0, true)
			draw_polyline(points, Color(1, 1, 1, flash), 2.2, true)
			_dot(a, 5.0, Color(1, 1, 1, 0.8 * flash))
			_dot(b, 5.0, Color(1, 1, 1, 0.8 * flash))
	# A snake head about to cross the second gap from below
	var head_x = left + 2 * stroke + gap * 1.5
	var head_y = lerp(size.y * 0.95, y + 16.0, clamp(cycle / 0.7, 0.0, 1.0))
	_dot(Vector2(head_x, head_y), 7.0, Color(1, 1, 1, 0.9) if not lit else Color(1, 0.4, 0.3, 0.9))

# A ring of fire around the Fire symbol; Pyre: a fireball flies in and lights a second one
func _draw_hearth(center, pyre):
	var ring_center = center + (Vector2(size.x * 0.14, 0) if pyre else Vector2.ZERO)
	var r = size.y * 0.3
	_dot(ring_center, r * 1.1, Color(1.0, 0.4, 0.05, 0.2))
	for i in 10:
		var angle = TAU * i / 10.0 + time * 0.6
		var flicker = 0.7 + 0.3 * sin(time * 12.0 + i * 1.7)
		var out = Vector2.RIGHT.rotated(angle)
		var base = ring_center + out * r * 0.8
		var side = out.orthogonal() * r * 0.17
		_shape(PackedVector2Array([base - side, base + out * r * 0.45 * flicker, base + side]), Color(1.0, 0.45 + 0.3 * flicker, 0.1, 0.9))
	if pyre:
		var t = fmod(time, 1.6) / 1.6
		_draw_fireball(Vector2(lerp(-10.0, ring_center.x - r, t), center.y), 0.4)
		_draw_text("+", size.y * 0.95, 30)
	else:
		_draw_symbol(FIRE_WATER_SYMBOL, ring_center, size.x * 0.26, false)

# A trail with a gap; in the gap a patch of ice (a head sliding across it) or roots
func _draw_gap_patch(center, ice):
	var y = center.y + size.y * 0.12
	var gap_from = size.x * 0.38
	var gap_to = size.x * 0.62
	_stroke(PackedVector2Array([Vector2(8, y), Vector2(gap_from, y)]), color, TRAIL_WIDTH - 3.0)
	_stroke(PackedVector2Array([Vector2(gap_to, y), Vector2(size.x - 8, y)]), color, TRAIL_WIDTH - 3.0)
	var patch = Vector2((gap_from + gap_to) / 2.0, y)
	var r = size.y * 0.3
	if ice:
		_dot(patch, r, Color(0.75, 0.92, 1.0, 0.35))
		draw_arc(patch, r, 0, TAU, 40, Color(0.85, 0.96, 1.0, 0.9), 2.0, true)
		for i in 3:
			var a = TAU * i / 3.0 + 0.4
			draw_line(patch, patch + Vector2.RIGHT.rotated(a) * r * 0.7, Color(1, 1, 1, 0.7), 1.5, true)
		# A head sliding sideways across it
		var t = fmod(time, 1.8) / 1.8
		var head = patch + Vector2(lerp(-r, r, t), -r * 0.9 + sin(t * PI) * r * 0.5)
		_dot(head, 7.0, Color(1, 0.4, 0.3))
		_stroke(PackedVector2Array([head + Vector2(-14, 4), head]), Color(1, 0.4, 0.3, 0.6), 4.0)
	else:
		_dot(patch, r, Color(0.3, 0.2, 0.08, 0.6))
		for i in 5:
			var a = TAU * i / 5.0 + sin(time * 2.0 + i) * 0.2
			var tip = patch + Vector2.RIGHT.rotated(a) * r * 0.95
			var mid = patch.lerp(tip, 0.5) + Vector2.RIGHT.rotated(a).orthogonal() * 5.0
			_stroke(PackedVector2Array([patch, mid, tip]), Color(0.5, 0.36, 0.16), 3.0)
		# A head crawling over it
		var t = fmod(time, 3.0) / 3.0
		_dot(patch + Vector2(lerp(-r, r, t), -r * 0.6), 7.0, Color(1, 0.4, 0.3))

# Void: its symbol, with what each upgrade does to the void around it
func _draw_void(center, which):
	var symbol = Global.element_symbol(Global.VOID_ID)
	var r = size.y * 0.36
	match which:
		"void_wide":
			r *= 0.8 + 0.25 * (0.5 + 0.5 * sin(time * 2.5))
		"void_time":
			var cycle = fmod(time, 2.4) / 2.4
			draw_arc(center, size.y * 0.46, -PI / 2, -PI / 2 + TAU * cycle, 40, Color(color, 0.85), 3.0, true)
	_draw_void_ring(center, r)
	_draw_symbol(symbol, center, size.x * 0.24, false)
	match which:
		"void_time":
			_draw_text("+1s", size.y * 0.95, 22)
		"void_memory":
			# Two absorbed powers circling, slowly
			for i in 2:
				var a = time * 1.5 + PI * i
				_dot(center + Vector2.RIGHT.rotated(a) * r * 0.9, 6.0, Color(Global.playerColors[1 + i * 3]))
			_draw_text("8s", size.y * 0.95, 22)
		"void_mimic":
			# A power orb with its upgrade badge
			var a = time * 1.8
			var orb = center + Vector2.RIGHT.rotated(a) * r * 0.9
			_dot(orb, 7.0, Color(Global.playerColors[1]))
			draw_arc(orb, 10.0, 0, TAU, 20, Color(1, 0.82, 0.3), 2.0, true)
			_draw_text("+", size.y * 0.95, 30)
		"void_hoard":
			# Every element orbiting, held for good
			for i in 4:
				var a = time * 1.2 + TAU * i / 4.0
				var orb = center + Vector2.RIGHT.rotated(a) * r * 0.95
				_dot(orb, 6.0, Color(Global.playerColors[i + 1]))
				draw_arc(orb, 8.5, 0, TAU, 16, Color(1, 1, 1, 0.8), 1.2, true)

func _draw_void_ring(center, r):
	_dot(center, r, Color(0.1, 0.03, 0.18, 0.5))
	var points = PackedVector2Array()
	for i in 49:
		var angle = TAU * i / 48.0
		var wobble = sin(angle * 7.0 + time * 6.0) * 0.07 + sin(angle * 3.0 - time * 4.0) * 0.05
		points.append(center + Vector2.RIGHT.rotated(angle) * r * (1.0 + wobble))
	draw_polyline(points, Color(0.62, 0.36, 1.0, 0.85), 3.0, true)

## Width of the trails in the icons
const TRAIL_WIDTH = 13.0

# A smooth trail stroke: an antialiased line through the points with round ends
func _stroke(points: PackedVector2Array, stroke_color, width):
	if points.is_empty():
		return
	if points.size() > 1:
		draw_polyline(points, stroke_color, width, true)
	_dot(points[0], width / 2, stroke_color)
	if points.size() > 1:
		_dot(points[points.size() - 1], width / 2, stroke_color)

func _dot(pos, radius, dot_color):
	draw_circle(pos, radius, dot_color, true, -1.0, true)

# A filled shape with a soft (antialiased) edge
func _shape(points: PackedVector2Array, shape_color):
	draw_colored_polygon(points, shape_color)
	var outline = points.duplicate()
	outline.append(points[0])
	draw_polyline(outline, shape_color, 1.0, true)

func _draw_symbol(texture, pos, width, flipped, alpha = 1.0, stretch = Vector2.ONE):
	var height = width * texture.get_height() / float(texture.get_width())
	draw_set_transform(pos, 0, Vector2(stretch.x, stretch.y * (-1 if flipped else 1)))
	draw_texture_rect(texture, Rect2(-width / 2, -height / 2, width, height), false, Color(color, alpha))
	draw_set_transform(Vector2.ZERO)

func _draw_text(text, baseline_y, font_size):
	var font = get_theme_font("font", "Label")
	draw_string(font, Vector2(0, baseline_y), text, HORIZONTAL_ALIGNMENT_RIGHT, size.x - 4, font_size, Color.WHITE)
