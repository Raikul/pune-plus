extends Node2D
class_name ArenaShrink

# The round's time limit, battle royale style: after SHRINK_DELAY seconds of a round the
# arena starts closing in from all four sides towards the middle, down to nothing in
# SHRINK_TIME seconds. Outside the safe area it's a wall: a snake (or a twin) there dies.
# Four Area2D walls in "limits" (deadly, and the AI's raycasts see them; fireballs fly
# through them, "arena_border") plus a check every frame for snakes already outside (Earth
# with Burrower slips through walls while its armor lasts). Online every machine runs its
# own (from its own round clock) and only kills its own snakes, like any other death.
# The Playground adds it (not in the campaign's boss fight) and resets it every round.

const SHRINK_DELAY = 60.0
const SHRINK_TIME = 25.0
## Seconds of warning (the edge flashes) before it starts closing
const WARNING_TIME = 5.0
const EDGE_COLOR = Color(1.0, 0.25, 0.3)
const OUTSIDE_COLOR = Color(0.35, 0.0, 0.05, 0.55)
const WALL_DEPTH = 2000.0

var playground
var round_time = 0.0
var walls = []
var announced = false
var time = 0.0

func _ready():
	z_index = 19 # Over the trails and the level, under the effects and the HUD
	for i in 4:
		var wall = Area2D.new()
		wall.name = "ShrinkWall%d" % i
		wall.add_to_group("limits")
		wall.add_to_group("arena_border")
		wall.collision_layer = 1
		wall.collision_mask = 0
		wall.monitoring = false
		var shape = CollisionShape2D.new()
		shape.shape = RectangleShape2D.new()
		shape.disabled = true
		wall.add_child(shape)
		add_child(wall)
		walls.append(wall)

# A new round: the arena is whole again
func reset():
	round_time = 0.0
	announced = false
	for wall in walls:
		wall.get_child(0).set_deferred("disabled", true)
	queue_redraw()

# 0 (whole arena) .. 1 (closed)
func progress() -> float:
	return clampf((round_time - SHRINK_DELAY) / SHRINK_TIME, 0.0, 1.0)

func safe_rect() -> Rect2:
	var arena = playground._arena_rect()
	var keep = 1.0 - progress()
	var size = arena.size * keep
	return Rect2(arena.get_center() - size / 2.0, size)

func _process(delta):
	time += delta
	if playground.time_flowing:
		round_time += delta
	if round_time >= SHRINK_DELAY and not announced:
		announced = true
		_announce()
	queue_redraw()

func _physics_process(_delta):
	if progress() <= 0.0:
		return
	var safe = safe_rect()
	_place_walls(safe)
	if not playground.time_flowing:
		return
	# Whoever is outside dies (this machine's snakes only)
	for snake in get_tree().get_nodes_in_group("alivePlayers"):
		if snake.net_remote or not snake.is_processing() or safe.has_point(snake.global_position):
			continue
		snake._on_area_entered(walls[0])
	for twin in get_tree().get_nodes_in_group("twinHeads"):
		if twin.net_remote or not twin.alive or safe.has_point(twin.global_position):
			continue
		twin._on_area_entered(walls[0])

# The walls fill everything around the safe area
func _place_walls(safe: Rect2):
	var big = safe.grow(WALL_DEPTH)
	var pieces = [
		Rect2(big.position, Vector2(big.size.x, safe.position.y - big.position.y)), # Top
		Rect2(Vector2(big.position.x, safe.end.y), Vector2(big.size.x, big.end.y - safe.end.y)), # Bottom
		Rect2(Vector2(big.position.x, safe.position.y), Vector2(safe.position.x - big.position.x, safe.size.y)), # Left
		Rect2(Vector2(safe.end.x, safe.position.y), Vector2(big.end.x - safe.end.x, safe.size.y)), # Right
	]
	for i in 4:
		var shape = walls[i].get_child(0)
		shape.shape.size = pieces[i].size
		walls[i].global_position = pieces[i].get_center()
		if shape.disabled:
			shape.set_deferred("disabled", false)

func _announce():
	PowerFx.score(playground, playground._arena_rect().get_center() - Vector2(0, 60), EDGE_COLOR.lightened(0.3), tr("ARENA_CLOSING"))

func _draw():
	var warning = round_time >= SHRINK_DELAY - WARNING_TIME and round_time < SHRINK_DELAY
	var shrinking = progress() > 0.0
	if not warning and not shrinking:
		return
	var arena = playground._arena_rect()
	var safe = safe_rect()
	if shrinking:
		# The closed-off part, darkened
		draw_rect(Rect2(arena.position, Vector2(arena.size.x, safe.position.y - arena.position.y)), OUTSIDE_COLOR)
		draw_rect(Rect2(Vector2(arena.position.x, safe.end.y), Vector2(arena.size.x, arena.end.y - safe.end.y)), OUTSIDE_COLOR)
		draw_rect(Rect2(Vector2(arena.position.x, safe.position.y), Vector2(safe.position.x - arena.position.x, safe.size.y)), OUTSIDE_COLOR)
		draw_rect(Rect2(Vector2(safe.end.x, safe.position.y), Vector2(arena.end.x - safe.end.x, safe.size.y)), OUTSIDE_COLOR)
	var pulse = 0.5 + 0.5 * sin(time * (14.0 if warning else 8.0))
	var edge = Color(EDGE_COLOR, 0.55 + 0.45 * pulse)
	draw_rect(safe, edge, false, 4.0)
	draw_rect(safe.grow(4.0), Color(EDGE_COLOR, 0.2 * pulse), false, 6.0)
