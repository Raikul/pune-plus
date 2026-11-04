extends Node2D
class_name Celebration

# The win screen's victory lap: the winning snake (both, in 2v2) loops around behind the
# text. Its player steers it with Left/Right (PUNCHI is for closing the screen); it can't
# crash, and the edges wrap it around to the other side. AI snakes, and online the snakes
# of other machines, wander on their own. Each element shows off its power on a loop:
# - Fire: four fireballs, one each way, every 2 s
# - Earth: rocky mode all the time
# - Air: zaps ahead every 1.5 s
# - Water: three twins every 3 s, up to nine
# Placed inside the win screen's backdrop (a Control): its size is the play area.

const FIRE_INTERVAL = 2.0
const AIR_INTERVAL = 1.5
const WATER_INTERVAL = 3.0
const WATER_PER_CAST = 3
const WATER_MAX = 9
const AIR_JUMP = 200.0
const FIREBALL_LIFETIME = 1.3
const ROCK_SPACING = 22.0
const ROCK_LIFE = 2.5
const ROCK_TEXTURES = "res://assets/jorge-resources/Powers/Earth/cuerpo_%d.png"
const PROJECTILE_SCENE = preload("res://scenes/projectile.tscn")

var rocks: Node2D
var snakes = []
var twins = {} # Water snake -> its twins
var timers = {} # Snake -> seconds to its next power

# winners: [{"id": player id, "input_id": Player{N} keys that steer it (0 = wanders)}]
func setup(winners: Array):
	rocks = Node2D.new()
	add_child(rocks)
	var area = _area()
	for i in winners.size():
		var snake = Snake.new()
		snake.player_id = winners[i].id
		snake.input_id = winners[i].input_id
		snake.color = Color(Global.playerColors[snake.player_id])
		snake.position = area * Vector2((i + 1.0) / (winners.size() + 1.0), 0.62)
		snake.heading = randf_range(-PI, PI)
		# Earth's rocks are all you'd see of its trail in rocky mode
		snake.draw_trail = snake.player_id != 2
		snake.moved.connect(_on_snake_moved.bind(snake))
		add_child(snake)
		snakes.append(snake)
		timers[snake] = 0.8 # The first show-off comes quickly
		twins[snake] = []

func _area() -> Vector2:
	var parent = get_parent()
	return parent.size if parent is Control else get_viewport_rect().size

func _process(delta):
	var area = _area()
	for snake in snakes:
		snake.area = area
		for twin in twins[snake]:
			twin.area = area
		timers[snake] -= delta
		if timers[snake] <= 0:
			match snake.player_id:
				1:
					_fire(snake)
					timers[snake] = FIRE_INTERVAL
				3:
					_zap(snake)
					timers[snake] = AIR_INTERVAL
				4:
					_split(snake)
					timers[snake] = WATER_INTERVAL
				_:
					timers[snake] = INF

func _fire(snake):
	for i in 4:
		var fireball = PROJECTILE_SCENE.instantiate()
		# Just for show: it doesn't burn anything (the frozen arena is still under the screen)
		fireball.monitoring = false
		fireball.monitorable = false
		fireball.position = snake.position
		fireball.rotation = snake.heading + i * PI / 2
		fireball.lifetime = FIREBALL_LIFETIME
		add_child(fireball)

func _zap(snake):
	var start = snake.position
	var unwrapped = start + Vector2.UP.rotated(snake.heading) * AIR_JUMP
	var landing = Vector2(fposmod(unwrapped.x, snake.area.x), fposmod(unwrapped.y, snake.area.y))
	var parts = [[start, unwrapped]]
	if landing != unwrapped:
		# Through the edge: one bolt out, one coming in on the other side
		parts.append([landing - (unwrapped - start), landing])
	snake.jump_to(landing)
	var global_parts = parts.map(func(part): return [to_global(part[0]), to_global(part[1])])
	PowerFx.lightning(self, global_parts, snake.color)
	_lift_last_fx()

func _split(snake):
	twins[snake] = twins[snake].filter(func(t): return is_instance_valid(t))
	var count = mini(WATER_PER_CAST, WATER_MAX - twins[snake].size())
	if count <= 0:
		return
	PowerFx.splash(self, to_global(snake.position), snake.color, 0.8)
	_lift_last_fx()
	for i in count:
		var twin = Snake.new()
		twin.player_id = snake.player_id
		twin.ghost = true
		twin.color = Color.AQUA
		twin.position = snake.position
		# Fanned out: one to each side and one straight ahead
		twin.heading = snake.heading + (i - (count - 1) / 2.0) * 0.7
		twin.area = snake.area
		add_child(twin)
		move_child(twin, rocks.get_index() + 1) # Under the real snakes
		twins[snake].append(twin)

# PowerFx draws in screen space on top of the arena; lift it over the win screen too
func _lift_last_fx():
	var fx = get_child(get_child_count() - 1)
	fx.z_as_relative = false
	fx.z_index = RenderingServer.CANVAS_ITEM_Z_MAX

# Earth: a rock every few steps, crumbling away after a while
var rock_distance = {}
func _on_snake_moved(distance, snake):
	if snake.player_id != 2:
		return
	rock_distance[snake] = rock_distance.get(snake, ROCK_SPACING) + distance
	if rock_distance[snake] < ROCK_SPACING:
		return
	rock_distance[snake] = 0.0
	var rock = Sprite2D.new()
	rock.texture = load(ROCK_TEXTURES % randi_range(1, 8))
	rock.scale = Vector2(0.3, 0.5)
	rock.flip_h = randf() < 0.5
	rock.position = snake.position
	rock.rotation = snake.heading
	rocks.add_child(rock)
	var tween = rock.create_tween()
	tween.tween_interval(ROCK_LIFE)
	tween.tween_property(rock, "modulate:a", 0.0, 0.6)
	tween.tween_callback(rock.queue_free)


# One celebrating snake (or a water twin): moves, wraps at the edges, draws its trail
class Snake extends Node2D:
	const SPEED = 240.0
	const TURN_SPEED = PI * 1.3
	const TRAIL_POINTS = 140
	const TRAIL_STEP = 6.0
	# A bit bigger than in the arena: it's the star of the screen
	const WIDTH = 13.0
	const HEAD_TEXTURE = preload("res://assets/jorge-resources/Gameplay scene/head.png")
	const SYMBOL_TEXTURE = preload("res://assets/jorge-resources/Game Selection/Air-Earth symbol.png")
	const HEAD_SCALE = 0.22
	const SYMBOL_SCALE = 0.03

	signal moved(distance)

	var player_id = 1
	var input_id = 0
	var color = Color.WHITE
	var heading = 0.0
	var area = Vector2(1920, 1000)
	var ghost = false
	var draw_trail = true
	# Trail points, newest last; null where it broke (wrapped around or jumped)
	var trail = []
	var since_point = 0.0
	var wander = 0
	var wander_time = 0.0

	func _ready():
		# The twins' see-through aqua (the game's glowing ghost shader washes out on the
		# bright backdrop)
		if ghost:
			modulate = Color(1, 1, 1, 0.6)

	func _process(delta):
		var direction = _steering(delta)
		heading += direction * TURN_SPEED * delta
		var step = Vector2.UP.rotated(heading) * SPEED * delta
		position += step
		var wrapped = Vector2(fposmod(position.x, area.x), fposmod(position.y, area.y))
		if wrapped != position:
			position = wrapped
			trail.append(null)
		since_point += step.length()
		if since_point >= TRAIL_STEP or trail.is_empty() or trail.back() == null:
			since_point = 0.0
			trail.append(position)
			while trail.size() > TRAIL_POINTS:
				trail.pop_front()
		moved.emit(step.length())
		queue_redraw()

	func jump_to(point):
		position = point
		trail.append(null)
		trail.append(point)

	# Its player's Left/Right; with nobody steering it wanders in lazy curves
	func _steering(delta) -> int:
		if input_id != 0:
			if Input.is_action_pressed("Player%dLeft" % input_id):
				return -1
			if Input.is_action_pressed("Player%dRight" % input_id):
				return 1
			return 0
		wander_time -= delta
		if wander_time <= 0:
			wander = [-1, 0, 0, 1].pick_random()
			wander_time = randf_range(0.4, 1.3)
		return wander

	func _draw():
		# Drawn around its own position, which keeps moving: trail points are made local
		if draw_trail:
			var run = PackedVector2Array()
			var colors = PackedColorArray()
			for i in trail.size():
				var point = trail[i]
				if point == null:
					_draw_run(run, colors)
					run = PackedVector2Array()
					colors = PackedColorArray()
					continue
				run.append(point - position)
				# Fades towards the tail
				colors.append(Color(color, float(i + 1) / trail.size()))
			run.append(Vector2.ZERO)
			colors.append(color)
			_draw_run(run, colors)
		draw_set_transform(Vector2.ZERO, heading, Vector2.ONE * HEAD_SCALE)
		draw_texture(HEAD_TEXTURE, -HEAD_TEXTURE.get_size() / 2, color)
		if not ghost:
			# Where the game puts it (player.tscn's ElementHeadSprite, under the snake's 0.1 scale)
			draw_set_transform(Vector2(0, -2.6).rotated(heading), heading, Vector2.ONE * SYMBOL_SCALE)
			draw_texture(SYMBOL_TEXTURE, -SYMBOL_TEXTURE.get_size() / 2)
		draw_set_transform(Vector2.ZERO)

	func _draw_run(run, colors):
		if run.size() >= 2:
			draw_polyline_colors(run, colors, WIDTH, true)
