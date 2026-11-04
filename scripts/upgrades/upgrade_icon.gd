extends Control
class_name UpgradeIcon

# Animated icon of an upgrade card. Drawn in code so every upgrade gets a small
# looping animation from the art we already have.

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
			draw_arc(ball, size.y * (0.16 + 0.12 * grow), 0, TAU, 32, Color(1, 0.6, 0.1, 0.9 - 0.6 * grow), 3.0)
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
	draw_circle(ball, width * 0.9, Color(1, 0.55, 0.1, 0.25))
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
	var x = 4.0
	while x < head_x - 10:
		if fposmod(x - time * 70.0, period) < dash:
			draw_circle(Vector2(x, _trail_y(x)), 7, color)
		x += 8.0
	draw_circle(Vector2(head_x, _trail_y(head_x)), 11, color.lightened(0.35))

# An aqua twin trail with a shimmer running along it: it never fades to the water color
func _draw_lasting_twin():
	var head_x = size.x - 16
	var x = 4.0
	while x < head_x - 10:
		var shimmer = 0.5 + 0.5 * sin(x * 0.08 - time * 6.0)
		draw_circle(Vector2(x, _trail_y(x)), 7, Color.AQUA.lerp(Color.WHITE, shimmer * 0.45))
		x += 8.0
	draw_circle(Vector2(head_x, _trail_y(head_x)), 11, Color.AQUA.lightened(0.35))

func _trail_y(x):
	return size.y / 2 + sin(x * 0.045 - time * 2.0) * 14

# Snake head rushing to the right with speed streaks and chevrons
func _draw_speed(center):
	var head = Vector2(size.x * 0.62 + sin(time * 9.0) * 3, center.y)
	for i in 5:
		var y = center.y + (i - 2) * 12
		var length = 22 + 14 * ((i * 37) % 3)
		var x = size.x - fposmod(time * 260.0 + i * 47, size.x + length)
		draw_line(Vector2(x, y), Vector2(x + length, y), Color(color, 0.45), 3)
	var trail_x = 8.0
	while trail_x < head.x - 10:
		draw_circle(Vector2(trail_x, center.y), 6, color)
		trail_x += 8.0
	draw_circle(head, 12, color.lightened(0.35))
	for i in 2:
		var tip_x = size.x * 0.82 + i * 13 + fposmod(time * 30.0, 6.0)
		draw_polyline([Vector2(tip_x - 9, center.y - 11), Vector2(tip_x, center.y), Vector2(tip_x - 9, center.y + 11)], Color.WHITE, 4)

# Cooldown ring around the Punchi icon that refills quickly and pops when ready
func _draw_cooldown(center):
	var progress = fmod(time, COOLDOWN_CYCLE) / (COOLDOWN_CYCLE * 0.7)
	var radius = size.y * 0.38
	draw_arc(center, radius, 0, TAU, 48, Color(0.35, 0.35, 0.35), 8)
	if progress < 1.0:
		draw_arc(center, radius, -PI / 2, -PI / 2 + TAU * progress, 48, color, 8)
	else:
		# Ready: full ring with a burst expanding outward
		var burst = (progress - 1.0) / 0.43
		draw_arc(center, radius, 0, TAU, 48, color.lightened(0.4), 8)
		draw_arc(center, radius + 4 + burst * 14, 0, TAU, 48, Color(color, 1.0 - burst), 3)
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
		draw_line(base, tip, color, 4)
		draw_line(tip, tip + Vector2(-side * 8, -8), color, 4)
		draw_line(tip, tip + Vector2(-side * 8, 8), color, 4)

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
			draw_circle(bit, 2.5, Color(0.8, 0.7, 0.55))

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
		draw_colored_polygon(PackedVector2Array([Vector2(x, center.y - 16), Vector2(x + 18, center.y), Vector2(x, center.y + 16)]), Color(1, 1, 1, 0.85))

# A fireball flying across, a strip of flickering flames behind it
func _draw_wildfire(center):
	var x = fposmod(time * 60.0, size.x + 30.0) - 15.0
	var flame_x = 4.0
	while flame_x < x - 10:
		var age = (x - flame_x) / size.x
		var flicker = 0.7 + 0.3 * sin(time * 20.0 + flame_x)
		var height = (14.0 - age * 8.0) * flicker
		draw_colored_polygon(PackedVector2Array([
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
		draw_circle(center, 6.0 + 3.0 * pulse, Color(1, 0.6, 0.15, 0.9))
		draw_arc(center, 20.0, -PI / 2, -PI / 2 + TAU * (cycle - 0.35) / 0.4, 32, Color(1, 0.5, 0.1), 3.0, true)
	else:
		var burst = (cycle - 0.75) / 0.25
		draw_circle(center, size.x * 0.4 * burst, Color(1, 0.55, 0.1, 0.4 * (1.0 - burst)))
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
	draw_circle(head, 12.0, Color(color, 0.9))
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
		draw_colored_polygon(PackedVector2Array([Vector2(left - 8, y), Vector2(left + 6, y - 9), Vector2(left + 6, y + 9)]), Color.WHITE)
		draw_colored_polygon(PackedVector2Array([Vector2(right + 8, y), Vector2(right - 6, y - 9), Vector2(right - 6, y + 9)]), Color.WHITE)
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
		draw_line(Vector2(a, y), Vector2(a + stroke, y), trail_color, 7.0, true)
		draw_circle(Vector2(a, y), 3.5, trail_color)
		draw_circle(Vector2(a + stroke, y), 3.5, trail_color)
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
			draw_circle(a, 5.0, Color(1, 1, 1, 0.8 * flash))
			draw_circle(b, 5.0, Color(1, 1, 1, 0.8 * flash))
	# A snake head about to cross the second gap from below
	var head_x = left + 2 * stroke + gap * 1.5
	var head_y = lerp(size.y * 0.95, y + 16.0, clamp(cycle / 0.7, 0.0, 1.0))
	draw_circle(Vector2(head_x, head_y), 7.0, Color(1, 1, 1, 0.9) if not lit else Color(1, 0.4, 0.3, 0.9))

func _draw_symbol(texture, pos, width, flipped, alpha = 1.0, stretch = Vector2.ONE):
	var height = width * texture.get_height() / float(texture.get_width())
	draw_set_transform(pos, 0, Vector2(stretch.x, stretch.y * (-1 if flipped else 1)))
	draw_texture_rect(texture, Rect2(-width / 2, -height / 2, width, height), false, Color(color, alpha))
	draw_set_transform(Vector2.ZERO)

func _draw_text(text, baseline_y, font_size):
	var font = get_theme_font("font", "Label")
	draw_string(font, Vector2(0, baseline_y), text, HORIZONTAL_ALIGNMENT_RIGHT, size.x - 4, font_size, Color.WHITE)
