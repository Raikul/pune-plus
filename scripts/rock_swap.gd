extends RefCounted
class_name RockSwap

# Water and Earth turning each other's things into their own:
# - Earth's Absorbent: Water died on a common trail, and that bit of trail becomes hard rock
# - Water's Rock Borer: a twin runs into one of Earth's rocks, and the rock gives way to
#   common trail (it kills like any trail, a fireball burns it)

const ROCK_SCENE = preload("res://scenes/fissure.tscn")
## Trail pieces within this distance of the hit go into the rock
const CLEAR_RADIUS = 20.0
## How far ahead of its origin a rock piece's picture is centered (see Fissure)
const ROCK_CENTER_AHEAD = 16.0
## The new trail appears this late, so the twin that went through is already past it
const TRAIL_DELAY = 0.3
const TRAIL_PIECES = 5
const TRAIL_SPACING = 8.0

# Earth with Absorbent in this round turns the trail Water died on into rock
static func trail_to_rock(trail: Area2D, _at: Vector2) -> void:
	if not is_instance_valid(trail) or trail.is_in_group("TwinBodies") or trail.is_in_group("Fissures"):
		return
	for snake in trail.get_tree().get_nodes_in_group("alivePlayers"):
		# (By element id: naming the power classes here would loop the preloads of the scenes)
		if snake.main_power != null and snake.main_power.element == 2 and snake.stat_value("earth.absorbent") >= 1.0:
			_make_rock.call_deferred(snake, trail.global_position, trail.rotation)
			return

static func _make_rock(earth: Node2D, at: Vector2, heading: float) -> void:
	if not is_instance_valid(earth) or not earth.is_inside_tree():
		return
	# The trail pieces around the hit go
	var circle = CircleShape2D.new()
	circle.radius = CLEAR_RADIUS
	var query = PhysicsShapeQueryParameters2D.new()
	query.shape = circle
	query.transform = Transform2D(0.0, at)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	for hit in earth.get_world_2d().direct_space_state.intersect_shape(query, 64):
		var piece = hit.collider
		if is_instance_valid(piece) and piece is TrailSegment and not piece.is_in_group("TwinBodies"):
			piece.queue_free()
	var rock: Fissure = ROCK_SCENE.instantiate()
	rock.set_as_top_level(true)
	rock.set_body(2)
	rock.global_position = at - Vector2.UP.rotated(heading) * ROCK_CENTER_AHEAD
	rock.rotation = heading
	rock.z_index = earth.FISSURE_Z_INDEX
	rock.add_to_group("Fissures", true)
	if earth.main_power.element == 5:
		rock.get_node("FissureBody").material = earth._void_rock_material()
	earth.add_child(rock)
	PowerFx.burst(earth.get_parent(), at, Color(Global.playerColors[2]))

# A twin hit this rock and Rock Borer lets it through: the rock turns to common trail.
# False if it isn't Earth's rock (it stays solid then).
static func rock_to_trail(rock_area: Area2D) -> bool:
	var rock = rock_area.get_parent()
	var earth = Fissure.owner_of(rock_area)
	if earth == null or rock == null or not rock.has_method("set_body"):
		return false
	var body = rock.fissure_rect
	var center = rock.to_global(body.position + body.size * body.scale / 2.0)
	var heading = rock.rotation
	rock.queue_free()
	PowerFx.burst(earth.get_parent(), center, Color(Global.playerColors[2]))
	earth.get_tree().create_timer(TRAIL_DELAY, false).timeout.connect(func(): _lay_trail(earth, center, heading))
	return true

# A short crossbar of the Earth snake's own trail, where the rock stood
static func _lay_trail(earth: Node2D, center: Vector2, heading: float) -> void:
	if not is_instance_valid(earth) or not earth.is_inside_tree():
		return
	var across = Vector2.RIGHT.rotated(heading)
	var previous = null
	for i in TRAIL_PIECES:
		var at = center + across * (i - (TRAIL_PIECES - 1) / 2.0) * TRAIL_SPACING
		previous = earth.lay_loose_trail(at, heading, previous)
