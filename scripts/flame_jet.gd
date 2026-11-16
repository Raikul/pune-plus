extends Area2D
class_name FlameJet

# Fire's Flamethrower upgrade: while Punchi is held, a cone of fire in front of the snake.
# Like Wildfire's flames it kills any other snake or twin that touches it and never its
# own Fire snake (Player skips hazards with its own owner_id), and like the fireball it
# burns the trail pieces it sweeps over (not its own snake's). It follows the head. Drawn
# with the PixelFX flamethrower animation.

const LENGTH = 135.0
const HALF_ANGLE_DEGREES = 22.0
## It always burns at least this long, even for a tap
const MIN_TIME = 0.35
## The cone reaches its full length this fast
const GROW_TIME = 0.2

var snake: Node2D
var owner_id = 0
var age = 0.0
## Seconds it burns for once started with run_for (null: until stop(), the held power)
var burn_time = INF
var stopping = false
# The PixelFX flamethrower (assets/pixelfx/flamethrower.png, 6 x 8 frames of 184 x 104, the
# nozzle at (30, 60), jet to the right)
const SHEET = preload("res://assets/pixelfx/flamethrower.png")
const SHEET_FPS = 30.0
const SHEET_FRAMES = 48
const SHEET_SCALE = 0.95
const FADE_TIME = 0.15
var sprite: Sprite2D
var fade = 0.0
var shape: CollisionPolygon2D

static func spawn(owner_snake: Node2D) -> FlameJet:
	var jet = FlameJet.new()
	jet.snake = owner_snake
	jet.owner_id = owner_snake.playerId
	owner_snake.add_child(jet)
	jet._follow()
	return jet

func _ready():
	add_to_group("fire_trail") # Kills count as fire kills (end-screen stats)
	add_to_group("hazards") # Owned dangers: their owner goes through (Player)
	top_level = true
	z_index = 6
	# Flames add up their light
	var glow = CanvasItemMaterial.new()
	glow.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = glow
	collision_layer = 1
	collision_mask = 5
	shape = CollisionPolygon2D.new()
	var points = PackedVector2Array([Vector2(0, -4)])
	var half = deg_to_rad(HALF_ANGLE_DEGREES)
	for i in 7:
		points.append(Vector2.UP.rotated(lerp(-half, half, i / 6.0)) * LENGTH)
	shape.polygon = points
	shape.scale = Vector2.ONE * 0.3
	add_child(shape)
	area_entered.connect(_on_area_entered)
	sprite = Sprite2D.new()
	sprite.texture = SHEET
	sprite.hframes = 6
	sprite.vframes = 8
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.offset = Vector2(62, -8) # The nozzle sits on the node's origin
	sprite.rotation = -PI / 2 # The art points right, the cone points up
	add_child(sprite)

# For a snake whose Punchi was replayed on another machine: it burns for this long
func run_for(seconds: float):
	burn_time = maxf(seconds, MIN_TIME)

# Punchi was let go: it keeps burning to its minimum and then dies out
func stop():
	burn_time = maxf(MIN_TIME, age) if burn_time == INF else burn_time

func put_out():
	stopping = true
	set_deferred("monitorable", false)
	set_deferred("monitoring", false)

func _follow():
	global_position = snake.global_position
	rotation = snake.rotation

func _process(delta):
	if snake == null or not is_instance_valid(snake):
		queue_free()
		return
	age += delta
	_follow()
	if not stopping and age >= burn_time:
		put_out()
	if stopping:
		fade += delta
		if fade >= FADE_TIME:
			queue_free()
			return
	var grow = clampf(0.3 + 0.7 * age / GROW_TIME, 0.3, 1.0)
	shape.scale = Vector2.ONE * grow
	sprite.frame = int(age * SHEET_FPS) % SHEET_FRAMES
	sprite.scale = Vector2.ONE * SHEET_SCALE * lerpf(0.6, 1.0, grow)
	sprite.modulate.a = 1.0 - fade / FADE_TIME

func _on_area_entered(area):
	if stopping or not is_instance_valid(area):
		return
	# Burns the trail it sweeps over, other snakes' only (its own is behind it anyway)
	if area is TrailSegment and area.get_parent() != snake:
		area.queue_free()
