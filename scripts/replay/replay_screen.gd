extends Control
class_name ReplayScreen

# The play of the game (picked by ReplayRecorder), after the win screen and before the
# match stats. It plays in a loop until someone skips it: any PUNCHI, Enter, Escape or a
# click (a press, after a short moment, so holding PUNCHI to close the win screen doesn't
# skip it too). A ring follows the snake whose moment it is.

signal finished

const ODIN = preload("res://assets/jorge-resources/Game Selection/Odin Rounded - Bold.otf")
const LOCKOUT = 0.6
## Seconds on the last frame before it loops
const LOOP_PAUSE = 0.8
const RED = Color(1.0, 0.25, 0.25)

var clip = {}
var star_color = Color.WHITE
var video: TextureRect
var texture: ImageTexture
var marker: Control
var progress: ColorRect
var rec_dot: Control
var playhead = 0.0
var shown_frame = -1
var age = 0.0
var done = false

func setup(play: Dictionary):
	clip = play
	var star = clip.get("player", 0)
	star_color = Color(Global.playerColors[star]) if star in [1, 2, 3, 4, 5] else Color.WHITE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var backdrop = ColorRect.new()
	backdrop.color = Color.BLACK
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)

	video = TextureRect.new()
	video.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	video.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	video.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	# Blown up smoothly, not in 2x2 blocks (the project's default filter is Nearest)
	video.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(video)

	# The featured snake's ring
	marker = Control.new()
	marker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marker.draw.connect(_draw_marker)
	add_child(marker)

	# Old-TV feel: dark bands at the top and bottom with the titles
	var top = ColorRect.new()
	top.color = Color(0, 0, 0, 0.88)
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_bottom = 150
	add_child(top)
	var bottom = ColorRect.new()
	bottom.color = Color(0, 0, 0, 0.88)
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_top = -96
	add_child(bottom)

	var title = _label(tr("REPLAY_TITLE"), 64, Color.WHITE)
	title.position = Vector2(60, 18)
	add_child(title)
	var who = Global.player_name(star) if star in [1, 2, 3, 4, 5] else ""
	var caption_text = tr(clip.get("caption", ""))
	var caption = _label(("%s  -  %s" % [who.to_upper(), caption_text]) if who != "" else caption_text, 34, star_color)
	caption.position = Vector2(64, 92)
	add_child(caption)

	rec_dot = Control.new()
	rec_dot.position = Vector2(1650, 40)
	rec_dot.size = Vector2(220, 60)
	rec_dot.draw.connect(_draw_rec)
	add_child(rec_dot)

	var hint = _label(tr("REPLAY_SKIP"), 30, Color(1, 1, 1, 0.85))
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	hint.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
	hint.offset_right = -60
	hint.offset_bottom = -30
	add_child(hint)

	var bar_back = ColorRect.new()
	bar_back.color = Color(1, 1, 1, 0.15)
	bar_back.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bar_back.offset_top = -96
	bar_back.offset_bottom = -90
	add_child(bar_back)
	progress = ColorRect.new()
	progress.color = star_color
	progress.position = Vector2(0, 0)
	progress.size = Vector2(0, 6)
	bar_back.add_child(progress)
	_show_frame(0)

func _frames() -> Array:
	return clip.get("frames", [])

func _process(delta):
	age += delta
	var frames = _frames()
	if frames.is_empty():
		_skip()
		return
	var length = frames.size() / ReplayRecorder.FPS
	playhead += delta
	if playhead >= length + LOOP_PAUSE:
		playhead = 0.0
	var index = min(int(playhead * ReplayRecorder.FPS), frames.size() - 1)
	if index != shown_frame:
		_show_frame(index)
	progress.size.x = progress.get_parent().size.x * clamp(playhead / length, 0.0, 1.0)
	marker.queue_redraw()
	rec_dot.queue_redraw()

func _show_frame(index):
	var frames = _frames()
	if index >= frames.size():
		return
	var jpg = frames[index].jpg
	if jpg.is_empty():
		return
	var image = Image.new()
	if image.load_jpg_from_buffer(jpg) != OK:
		return
	if texture == null or texture.get_size() != Vector2(image.get_size()):
		texture = ImageTexture.create_from_image(image)
		video.texture = texture
	else:
		texture.update(image)
	shown_frame = index

# Where the video is drawn on screen (kept 16:9)
func _video_rect() -> Rect2:
	var area = video.size
	var aspect = float(ReplayRecorder.SIZE.x) / ReplayRecorder.SIZE.y
	var draw_size = Vector2(area.x, area.x / aspect)
	if draw_size.y > area.y:
		draw_size = Vector2(area.y * aspect, area.y)
	return Rect2(video.position + (area - draw_size) / 2, draw_size)

func _draw_marker():
	var frames = _frames()
	if shown_frame < 0 or shown_frame >= frames.size():
		return
	var star = clip.get("player", 0)
	var heads = frames[shown_frame].heads
	if not heads.has(star):
		return
	var rect = _video_rect()
	var at = rect.position + heads[star] * rect.size
	var pulse = 0.5 + 0.5 * sin(age * 6.0)
	marker.draw_arc(at, 44.0 + 8.0 * pulse, 0, TAU, 48, Color(star_color, 0.9), 5.0, true)
	marker.draw_arc(at, 60.0 + 8.0 * pulse, 0, TAU, 48, Color(star_color, 0.35), 3.0, true)

func _draw_rec():
	var on = fmod(age, 1.0) < 0.6
	if on:
		rec_dot.draw_circle(Vector2(18, 30), 13, RED)
	rec_dot.draw_string(ODIN, Vector2(42, 44), tr("REPLAY_TAG"), HORIZONTAL_ALIGNMENT_LEFT, -1, 38, Color.WHITE)

func _input(event):
	if done or age < LOCKOUT:
		return
	var skip = event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel")
	for id in range(1, 6):
		skip = skip or event.is_action_pressed("Player%dUp" % id)
	if event is InputEventMouseButton and event.pressed:
		skip = true
	if skip and not event.is_echo():
		get_viewport().set_input_as_handled()
		_skip()

func _skip():
	if done:
		return
	done = true
	set_process(false)
	finished.emit()
	queue_free()

func _label(text, font_size, color):
	var label = Label.new()
	label.text = text
	label.add_theme_font_override("font", ODIN)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 8)
	return label
