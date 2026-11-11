extends CanvasLayer
class_name CursorFade

# During a match the mouse pointer fades out after a couple of seconds without moving, so
# it doesn't sit over the arena. Any mouse movement or click brings it right back; while
# the game is paused (menus) it always stays.
# The OS pointer can't fade, so a copy of it (project setting mouse_cursor/custom_image)
# fades where it was, after the real one is hidden.

const IDLE_TIME = 2.0
const FADE_TIME = 0.4

var idle = 0.0
var ghost: TextureRect
var hotspot = Vector2.ZERO
var fade: Tween

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 128
	ghost = TextureRect.new()
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var path = ProjectSettings.get_setting("display/mouse_cursor/custom_image", "")
	if path != "":
		ghost.texture = load(path)
	hotspot = ProjectSettings.get_setting("display/mouse_cursor/custom_image_hotspot", Vector2.ZERO)
	ghost.hide()
	add_child(ghost)

func _exit_tree():
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _input(event):
	if event is InputEventMouseMotion or event is InputEventMouseButton:
		_wake()

func _process(delta):
	if get_tree().paused:
		_wake()
		return
	if Input.mouse_mode == Input.MOUSE_MODE_HIDDEN:
		return
	idle += delta
	if idle >= IDLE_TIME:
		_fade_out()

func _wake():
	idle = 0.0
	if Input.mouse_mode == Input.MOUSE_MODE_HIDDEN:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if fade:
		fade.kill()
	ghost.hide()

func _fade_out():
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	if ghost.texture == null:
		return
	ghost.position = get_viewport().get_mouse_position() - hotspot
	ghost.modulate.a = 1.0
	ghost.show()
	fade = create_tween()
	fade.tween_property(ghost, "modulate:a", 0.0, FADE_TIME)
	fade.tween_callback(ghost.hide)
