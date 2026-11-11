extends Area2D
class_name GapPatch

# Left in the gaps of a snake's trail by two legendary upgrades, for LIFETIME seconds:
#  - "ice" (Water's Black Ice): other snakes on it slide; they turn slower and their body
#    keeps drifting the way it was going (Player._move).
#  - "roots" (Earth's Strangling Roots): other snakes on it crawl (Player._move).
# Never deadly and never felt by the snake that made it or its 2v2 teammate. It sits on
# its own physics layer (LAYER), which no head, fireball or AI ray collides with; snakes
# look for it under their head (Player._ground_patches).

const LIFETIME = 10.0
const FADE_TIME = 0.6
const GROW_TIME = 0.3
const RADIUS = 48.0
## Physics layer bit of the patches (5th layer)
const LAYER = 16

var kind = "ice"
var owner_id = 0
var color = Color.WHITE
var radius = RADIUS
var age = 0.0
var seed_offset = 0.0
var details = [] # Cracks (ice) or root curves (roots), made once

static func spawn(parent: Node, at: Vector2, patch_kind: String, owner: int, patch_radius = RADIUS) -> GapPatch:
	var patch = GapPatch.new()
	patch.kind = patch_kind
	patch.owner_id = owner
	patch.color = Color(Global.playerColors[owner]) if owner > 0 and owner < Global.playerColors.size() else Color.WHITE
	patch.radius = patch_radius
	parent.add_child(patch)
	patch.global_position = at
	return patch

func _ready():
	add_to_group("gap_patches")
	top_level = true
	z_index = 1 # Under the trails
	collision_layer = LAYER
	collision_mask = 0
	monitoring = false
	var shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = radius
	shape.shape = circle
	add_child(shape)
	seed_offset = randf() * TAU
	_make_details()

func _process(delta):
	age += delta
	if age >= LIFETIME:
		queue_free()
		return
	if age >= LIFETIME - FADE_TIME and monitorable:
		set_deferred("monitorable", false)
	queue_redraw()

func _make_details():
	if kind == "ice":
		# A few cracks from near the middle
		for i in 5:
			var angle = seed_offset + TAU * i / 5.0 + randf_range(-0.3, 0.3)
			var points = PackedVector2Array([Vector2.RIGHT.rotated(angle) * radius * 0.1])
			var at = points[0]
			for step in 3:
				angle += randf_range(-0.5, 0.5)
				at += Vector2.RIGHT.rotated(angle) * radius * randf_range(0.18, 0.28)
				points.append(at)
			details.append(points)
	else:
		# Roots: curling strands across the patch
		for i in 7:
			var angle = seed_offset + TAU * i / 7.0
			var start = Vector2.RIGHT.rotated(angle) * radius * 0.95
			var points = PackedVector2Array()
			var bend = randf_range(-1.2, 1.2)
			for step in 9:
				var t = step / 8.0
				var along = start.lerp(-start * 0.2, t)
				points.append(along + start.orthogonal().normalized() * sin(t * PI) * radius * 0.3 * bend)
			details.append(points)

func _draw():
	var grow = clamp(age / GROW_TIME, 0.0, 1.0)
	var fade = clamp((LIFETIME - age) / FADE_TIME, 0.0, 1.0)
	var r = radius * grow
	var s = grow
	if kind == "ice":
		draw_circle(Vector2.ZERO, r, Color(0.75, 0.92, 1.0, 0.28 * fade), true, -1.0, true)
		draw_circle(Vector2.ZERO, r * 0.7, Color(0.9, 0.97, 1.0, 0.18 * fade), true, -1.0, true)
		draw_arc(Vector2.ZERO, r, 0, TAU, 48, Color(0.85, 0.96, 1.0, 0.75 * fade), 2.0, true)
		for points in details:
			var scaled = PackedVector2Array()
			for p in points:
				scaled.append(p * s)
			draw_polyline(scaled, Color(1, 1, 1, 0.6 * fade), 1.5, true)
		# A glint sliding across
		var glint = Vector2(-r * 0.5 + fmod(age * 40.0, r), -r * 0.3)
		draw_circle(glint, 3.0, Color(1, 1, 1, 0.8 * fade), true, -1.0, true)
	else:
		draw_circle(Vector2.ZERO, r, Color(0.25, 0.18, 0.08, 0.45 * fade), true, -1.0, true)
		draw_arc(Vector2.ZERO, r, 0, TAU, 48, Color(0.45, 0.65, 0.2, 0.6 * fade), 2.0, true)
		for i in details.size():
			var scaled = PackedVector2Array()
			var sway = sin(age * 2.0 + i) * 2.0
			for p in details[i]:
				scaled.append(p * s + Vector2(0, sway))
			draw_polyline(scaled, Color(0.42, 0.3, 0.14, 0.95 * fade), 4.0, true)
			draw_polyline(scaled, Color(0.55, 0.75, 0.25, 0.6 * fade), 1.5, true)
	# The owner's color on the rim
	draw_arc(Vector2.ZERO, r + 2.0, 0, TAU, 48, Color(color, 0.35 * fade), 2.0, true)

# The patches under a point (world position), as GapPatch nodes
static func at_point(world: World2D, point: Vector2) -> Array:
	var query = PhysicsPointQueryParameters2D.new()
	query.position = point
	query.collide_with_areas = true
	query.collide_with_bodies = false
	query.collision_mask = LAYER
	var found = []
	for hit in world.direct_space_state.intersect_point(query, 8):
		if hit.collider is GapPatch and not hit.collider.is_queued_for_deletion():
			found.append(hit.collider)
	return found
