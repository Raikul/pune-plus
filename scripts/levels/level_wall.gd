@tool
extends Polygon2D
class_name LevelWall

# A wall inside the arena: deadly like the outer walls (snakes crash on it, fireballs
# stop on it, Earth's armor doesn't get through). Its shape is the polygon: select the
# node and draw it with the point tools in the 2D editor's toolbar. It can slide back and
# forth and/or spin around its origin (the node's position), set below. In the editor a
# faint copy shows where the slide ends and an arc shows the spin.

## How far it slides (there and back), in pixels; zero = it stays put
@export var move_offset = Vector2.ZERO:
	set(value):
		move_offset = value
		queue_redraw()
## Seconds for one slide there and back
@export var move_time = 4.0
## Spin speed in degrees per second (negative = counter-clockwise); 0 = no spin
@export var rotation_speed = 0.0:
	set(value):
		rotation_speed = value
		queue_redraw()
## Where in its slide it starts (0..1), to put several walls out of step
@export_range(0.0, 1.0) var phase = 0.0
@export var outline_color = Color(0.62, 0.36, 1.0):
	set(value):
		outline_color = value
		queue_redraw()
@export var outline_width = 3.0

var base_position = Vector2.ZERO
var base_rotation = 0.0

func _ready():
	base_position = position
	base_rotation = rotation
	if Engine.is_editor_hint():
		return
	var area = Area2D.new()
	area.collision_layer = 1
	area.collision_mask = 0
	area.monitoring = false
	area.add_to_group("limits")
	var shape = CollisionPolygon2D.new()
	shape.polygon = polygon
	area.add_child(shape)
	add_child(area)

func _physics_process(_delta):
	if Engine.is_editor_hint():
		return
	if is_moving():
		var pose = _pose_at(Level.now())
		position = pose[0]
		rotation = pose[1]

func is_moving() -> bool:
	return (move_offset != Vector2.ZERO and move_time > 0) or rotation_speed != 0

# [position, rotation] at a time on the level clock
func _pose_at(t) -> Array:
	var at = base_position
	if move_offset != Vector2.ZERO and move_time > 0:
		# Eases in and out at both ends
		at = base_position + move_offset * (0.5 - 0.5 * cos(TAU * (t / move_time + phase)))
	return [at, base_rotation + deg_to_rad(rotation_speed) * t]

# Its outline in the playground's coordinates, where it is right now
func global_polygon() -> PackedVector2Array:
	return global_transform * polygon

# Its outline some seconds from now (the AI looks ahead with it)
func global_polygon_in(seconds) -> PackedVector2Array:
	if not is_moving():
		return global_polygon()
	var pose = _pose_at(Level.now() + seconds)
	var local = Transform2D(pose[1], scale, skew, pose[0])
	return get_parent().global_transform * local * polygon

func _draw():
	if polygon.size() >= 3:
		var closed = polygon.duplicate()
		closed.append(polygon[0])
		draw_polyline(closed, outline_color, outline_width, true)
	if not Engine.is_editor_hint():
		return
	if move_offset != Vector2.ZERO and polygon.size() >= 3:
		# Where the slide ends (move_offset is in the parent's frame)
		var shift = move_offset.rotated(-rotation) / scale
		var ghost = PackedVector2Array()
		for point in polygon:
			ghost.append(point + shift)
		ghost.append(ghost[0])
		draw_polyline(ghost, Color(outline_color, 0.4), 2.0, true)
		draw_dashed_line(Vector2.ZERO, shift, Color(1, 1, 1, 0.6), 2.0, 10.0)
	if rotation_speed != 0:
		var radius = 30.0
		var sweep = sign(rotation_speed) * PI * 1.4
		draw_arc(Vector2.ZERO, radius, 0, sweep, 24, Color(1, 1, 1, 0.7), 2.0, true)
		var tip = Vector2.RIGHT.rotated(sweep) * radius
		var forward = Vector2.RIGHT.rotated(sweep + sign(rotation_speed) * PI / 2)
		draw_colored_polygon(PackedVector2Array([tip + forward * 8, tip + forward.orthogonal() * 5, tip - forward.orthogonal() * 5]), Color(1, 1, 1, 0.7))
		draw_circle(Vector2.ZERO, 4, Color(1, 1, 1, 0.8))
