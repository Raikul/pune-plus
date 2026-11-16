extends Area2D
class_name SteamCloud

# Water's Steam upgrade: when a fireball burns one of its twins the water boils into a
# cloud of steam that stays for LIFETIME seconds. It kills any snake or twin that touches
# it except the water snake and its own twins (Player and TwinHead skip hazards with their
# owner's id). Air's Blizzard blows it away (disperse). It lives under the water snake, so
# it goes away with the round. Drawn in code: soft overlapping puffs of white.

const LIFETIME = 10.0
const RADIUS = 58.0
const FADE_TIME = 1.0
const PUFFS = 9

var owner_id = 0
var radius = RADIUS
var age = 0.0
var life = LIFETIME
var drift = Vector2.ZERO
var puffs = [] # {angle, distance, size, speed}

# A cloud at `at` (world position) owned by the water snake, which keeps it until the round ends
static func spawn(snake: Node2D, at: Vector2) -> SteamCloud:
	if not is_instance_valid(snake):
		return null
	var cloud = SteamCloud.new()
	cloud.owner_id = snake.playerId
	snake.add_child(cloud)
	cloud.global_position = at
	return cloud

func _ready():
	add_to_group("steam")
	add_to_group("hazards") # Owned dangers: their owner goes through (Player, TwinHead)
	top_level = true
	z_index = 7
	collision_layer = 1
	collision_mask = 0
	monitoring = false
	var shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = radius * 0.9
	shape.shape = circle
	add_child(shape)
	for i in PUFFS:
		puffs.append({"angle": randf() * TAU, "distance": randf_range(0.0, 0.6), "size": randf_range(0.35, 0.6), "speed": randf_range(-0.6, 0.6)})

# The wind thins it out: it drifts off and is gone in a moment
func disperse(direction: Vector2):
	drift += direction * 130.0
	life = minf(life, age + 1.2)

func _process(delta):
	age += delta
	if age >= life:
		queue_free()
		return
	global_position += drift * delta
	drift = drift.move_toward(Vector2.ZERO, 90.0 * delta)
	# Harmless while it fades out
	if age >= life - FADE_TIME and monitorable:
		set_deferred("monitorable", false)
	queue_redraw()

func _draw():
	var fade = clampf((life - age) / FADE_TIME, 0.0, 1.0)
	var grow = clampf(age / 0.5, 0.0, 1.0)
	var r = radius * (0.6 + 0.4 * grow)
	draw_circle(Vector2.ZERO, r, Color(0.85, 0.95, 1.0, 0.16 * fade), true, -1.0, true)
	for puff in puffs:
		var angle = puff.angle + age * puff.speed
		var at = Vector2.RIGHT.rotated(angle) * r * puff.distance
		var pulse = 1.0 + 0.08 * sin(age * 2.0 + puff.angle * 3.0)
		draw_circle(at, r * puff.size * pulse, Color(1.0, 1.0, 1.0, 0.2 * fade), true, -1.0, true)
	# A soft edge, so it reads as a danger
	draw_arc(Vector2.ZERO, r * 0.95, 0, TAU, 48, Color(0.8, 0.93, 1.0, 0.55 * fade), 2.0, true)
