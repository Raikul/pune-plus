extends Node2D
class_name AirBlizzard

# Air's Blizzard upgrade: a held jump let go at its fullest doesn't jump, it blows. A gust
# shoves everything inside a cone in front of the snake for a moment: other snakes and
# twins, trail pieces, fireballs (they turn to fly with the wind), flames of fire, and it
# thins out steam. Earth's rocks and the arena's walls hold. Whatever was in the cone when
# the gust started is carried along, so a pushed thing doesn't slip out of the wind.

const HALF_ANGLE_DEGREES = 32.0
const REACH = 160.0
const DURATION = 0.5
## How far the gust carries things in all, in pixels
const PUSH = 130.0
const WALL_MARGIN = 16.0

var direction = Vector2.UP
var owner_snake: Node2D
var age = 0.0
var carried = [] # [node, kind]
var neighbors = [] # Trail pieces next to the carried ones, redrawn while they move

static func spawn(snake: Node2D) -> AirBlizzard:
	var gust = AirBlizzard.new()
	gust.owner_snake = snake
	gust.direction = Vector2.UP.rotated(snake.rotation)
	gust.top_level = true
	gust.z_index = 22
	snake.get_parent().add_child(gust)
	gust.global_position = snake.global_position
	gust.rotation = gust.direction.angle() + PI / 2
	gust._collect()
	return gust

func _cone(grow = 0.0) -> PackedVector2Array:
	var points = PackedVector2Array([global_position - direction * grow])
	var half = deg_to_rad(HALF_ANGLE_DEGREES)
	for i in 9:
		var angle = lerp(-half, half, i / 8.0)
		points.append(global_position + direction.rotated(angle) * (REACH + grow))
	return points

func _collect():
	var shape = ConvexPolygonShape2D.new()
	shape.points = _cone()
	var query = PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.collide_with_areas = true
	query.collide_with_bodies = false
	query.collision_mask = 0xFFFFFFFF
	var seen = {}
	for hit in get_world_2d().direct_space_state.intersect_shape(query, 1024):
		var area = hit.collider
		if not is_instance_valid(area) or seen.has(area) or area == owner_snake:
			continue
		seen[area] = true
		_sort(area)
	# The pieces touching the carried ones need to follow the line they draw
	var wide = ConvexPolygonShape2D.new()
	wide.points = _cone(30.0)
	query.shape = wide
	for hit in get_world_2d().direct_space_state.intersect_shape(query, 2048):
		var area = hit.collider
		if is_instance_valid(area) and area is TrailSegment and not seen.has(area):
			neighbors.append(area)

func _sort(area):
	if area.is_in_group("limits") or area.is_in_group("Fissures") or area.is_in_group("arena_border") or area is FireRing or area is Shroom:
		return
	if area.is_in_group("fireballs"):
		# It flies with the wind from here on
		if not area.expiring:
			area.rotation = direction.angle() + PI / 2
		return
	if area.is_in_group("steam"):
		area.disperse(direction)
		return
	if area is TrailSegment:
		carried.append([area, "trail"])
	elif area is FireTrail:
		carried.append([area, "flame"])
	elif area.is_in_group("twinHeads") and not area.net_remote:
		carried.append([area, "twin"])
	elif area.is_in_group("alivePlayers") and not area.net_remote and not area.reviving and area != owner_snake:
		carried.append([area, "snake"])

func _process(delta):
	age += delta
	if age >= DURATION:
		queue_free()
		return
	# Strong at first, dying down
	var step = direction * (PUSH / DURATION) * delta * 2.0 * (1.0 - age / DURATION)
	for entry in carried:
		var node = entry[0]
		if not is_instance_valid(node) or node.is_queued_for_deletion():
			continue
		node.global_position += step
		if entry[1] == "snake":
			node.global_position = _inside(node.global_position, node)
		elif entry[1] == "twin":
			node.global_position = _inside(node.global_position, node.get_parent())
		if node is TrailSegment:
			node.queue_redraw()
	for node in neighbors:
		if is_instance_valid(node):
			node.queue_redraw()
	queue_redraw()

# Stays inside the arena (the wind never throws a snake out of the map)
func _inside(point: Vector2, snake) -> Vector2:
	if snake == null or snake.left_limit_x == null:
		return point
	return Vector2(
		clamp(point.x, snake.left_limit_x + WALL_MARGIN, snake.right_limit_x - WALL_MARGIN),
		clamp(point.y, snake.top_limit_y + WALL_MARGIN, snake.bottom_limit_y - WALL_MARGIN))

# Streaks of wind blowing out of the head
func _draw():
	var t = age / DURATION
	var fade = 1.0 - t
	draw_set_transform(Vector2.ZERO, -rotation + direction.angle(), Vector2.ONE)
	var half = deg_to_rad(HALF_ANGLE_DEGREES)
	for i in 14:
		var lane = lerp(-0.9, 0.9, i / 13.0)
		var angle = half * lane
		var start = fposmod(t * 1.5 + i * 0.17, 1.0)
		var near = Vector2.RIGHT.rotated(angle) * (REACH * start)
		var far = Vector2.RIGHT.rotated(angle) * (REACH * min(start + 0.28, 1.0))
		draw_line(near, far, Color(0.85, 0.97, 1.0, 0.75 * fade), 2.0, true)
