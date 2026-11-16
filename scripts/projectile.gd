extends Area2D
var speed = 400
var screen_size = Vector2.ZERO
var colorRect
## Seconds of flight before fading out (set by FirePower); 0 = until it hits something
var lifetime = 0.0
## How long the fade-out takes (end of the flight, or after crashing)
const EXPIRE_TIME = 0.4
var age = 0.0
var expiring = false
## Wildfire (set by FirePower): flames left along the flight, burning other snakes
var fire_trail = false
## Its fire's color: white keeps the art's orange; Void's fireballs are purple (FirePower)
var tint = Color.WHITE
## Fanned Flames (set by FirePower): crossing a trail of Air feeds it, a bit bigger and faster
var fanned = false
const FAN_GROWTH = 1.1
const FAN_SPEED = 1.08
const FAN_MAX = 5
const FAN_PAUSE = 0.25
var fan_stacks = 0
var last_fan = -1.0
## Ricochet (set by FirePower): Earth's rocks send it off at an angle instead of stopping it
var bounce = false
const MAX_BOUNCES = 4
const BOUNCE_PAUSE = 0.2
var bounces = 0
var last_bounce = -1.0
const FLAME_SPACING = 16.0
var last_flame = null


func _ready():
#	colorRect = $"../ColorRect/Collider"
#	bodyTimer.connect("timeout", _on_bodyTimer_timeout)
#	gapTimer.connect("timeout", _on_gapTimer_timeout)
	add_to_group("fireballs")
	screen_size = get_viewport_rect().size
	scale = Vector2(1,1)
#	$Meteor.rotate(rotation - PI/2)
	$AnimationPlayer.play("fireball")
#	$AnimationPlayer.rotate(rotation)
	
#	$Meteor.set_offset(Vector2(0,50))
#	$CollisionShape2D.set_position(Vector2(50,0))
#	$Meteor.play("launch")

# The PixelFX fireball (assets/pixelfx/fireball.png, 4 x 9 frames of 136 x 56, flying right,
# its head at (112, 28)) replaces the old sprite and particles. Only Dual Ball's small
# fireballs use it (FirePower calls use_pixelfx)
const PIXELFX_SHEET = preload("res://assets/pixelfx/fireball.png")
const PIXELFX_FPS = 30.0
const PIXELFX_FRAMES = 36
const PIXELFX_SCALE = 1.6
var pixelfx_sprite: Sprite2D

func use_pixelfx():
	$BodySprite.hide()
	$CPUParticles2D.emitting = false
	$CPUParticles2D.hide()
	pixelfx_sprite = Sprite2D.new()
	pixelfx_sprite.texture = PIXELFX_SHEET
	pixelfx_sprite.hframes = 4
	pixelfx_sprite.vframes = 9
	pixelfx_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	pixelfx_sprite.offset = Vector2(-44, 0) # The head sits on the node's origin
	pixelfx_sprite.rotation = -PI / 2 # The art flies right, the projectile flies up
	pixelfx_sprite.scale = Vector2.ONE * PIXELFX_SCALE
	add_child(pixelfx_sprite)

func _process(delta):
	age += delta
	if pixelfx_sprite != null:
		pixelfx_sprite.frame = int(age * PIXELFX_FPS) % PIXELFX_FRAMES
	if lifetime > 0 and age >= lifetime and not expiring:
		expire()
	var	velocity = Vector2.UP.rotated(rotation) * speed
	position += velocity * delta
	_leave_map()
	if fire_trail and not expiring and not outside and (last_flame == null or global_position.distance_to(last_flame) >= FLAME_SPACING):
		_drop_flame()

# The arena's edge doesn't stop it: it flies on out of the map and is gone for good once
# it's off the screen (so a shot fired close to the edge doesn't fizzle on it)
const OFF_SCREEN_MARGIN = 80.0
var outside = false # Past the arena's border: no more Wildfire flames

func _leave_map():
	var shooter = get_parent()
	var playground = shooter.get_parent() if shooter != null else null
	if playground != null and playground.has_method("_arena_rect"):
		outside = not playground._arena_rect().has_point(global_position)
	if not Rect2(Vector2.ZERO, screen_size).grow(OFF_SCREEN_MARGIN).has_point(global_position):
		queue_free()

func _drop_flame():
	last_flame = global_position
	var shooter = get_parent()
	var flame = FireTrail.new()
	flame.owner_id = shooter.playerId if "playerId" in shooter else 0
	flame.color = Color(Global.playerColors[flame.owner_id]) if flame.owner_id in [1, 2, 3, 4, 5] else Color(1, 0.5, 0.1)
	flame.modulate = tint
	flame.radius = FireTrail.RADIUS * scale.x
	flame.global_position = global_position
	# On the playground, so the flames outlive the fireball (and the snake)
	shooter.get_parent().add_child(flame)

# It stops burning and fades away. crashed: it hit something and stopped there (a burst
# of sparks shows what it hit); otherwise its flight ran out: it slows down and fizzles
# out in the air, so the two never look alike.
# Placeholder look. For a custom effect, add an "expire" animation (about EXPIRE_TIME
# long) to the AnimationPlayer and it is played instead.
func expire(crashed = false):
	if expiring:
		return
	expiring = true
	# Harmless from now on: it only fades (a void that swallowed it isn't hit by it)
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	var tween = create_tween()
	if crashed:
		var shooter = get_parent()
		var playground = shooter.get_parent() if shooter else null
		if playground:
			PowerFx.explosion(playground, global_position, tint if tint != Color.WHITE else Color(1.0, 0.55, 0.15), 34.0 * scale.x)
	if $AnimationPlayer.has_animation("expire"):
		$AnimationPlayer.play("expire")
		tween.tween_interval(EXPIRE_TIME)
	elif crashed:
		tween.set_parallel()
		tween.tween_property(self, "scale", scale * 0.1, EXPIRE_TIME * 0.5).set_ease(Tween.EASE_IN)
		tween.tween_property(self, "modulate:a", 0.0, EXPIRE_TIME * 0.5)
		tween.chain()
	else:
		tween.set_parallel()
		tween.tween_property(self, "speed", speed * 0.15, EXPIRE_TIME).set_ease(Tween.EASE_OUT)
		tween.tween_property(self, "scale", scale * 0.6, EXPIRE_TIME)
		tween.tween_property(self, "modulate", Color(0.6, 0.6, 0.6, 0.0), EXPIRE_TIME).set_ease(Tween.EASE_IN)
		tween.chain()
	tween.tween_callback(queue_free)

func _on_area_entered(area):
	# Flames, Storm Fence lightning and the arena's edge (it flies out of the map, _leave_map)
	# don't stop it
	if area == get_parent() or expiring or area.is_in_group("hazards") or area.is_in_group("arena_border"):
		return
	# Fireballs of the same snake pass through each other (Dual Ball throws two at once)
	if area.is_in_group("fireballs") and area.get_parent() == get_parent():
		return
	# Walls, snakes (and Water's twin heads) and Earth's stone stop it: it crashes and fades
	# away. Freeing a twin head would also free its whole trail (the segments are its children);
	# the twin may already have died of this same hit, so the check is "twins", not "twinHeads".
	if bounce and area.is_in_group("Fissures") and _bounce_off(area):
		return
	if area.is_in_group("activePlayers") or area.is_in_group("twins") or area.is_in_group("limits") or area.is_in_group("Fissures"):
		# End-screen stats: Earth's rock stopped it (counted on the shooter's machine only)
		var shooter = get_parent()
		if area.is_in_group("Fissures") and "net_remote" in shooter and not shooter.net_remote:
			var earth = Fissure.owner_of(area)
			if earth != null:
				Global.add_stat(earth.playerId, "earth_blocked")
		set_process(false)
		expire(true)
	else:
		_feed_on_air(area)
		area.queue_free()

# Fanned Flames: burning through Air's trail makes it a little bigger and faster
func _feed_on_air(area):
	if not fanned or not (area is TrailSegment) or fan_stacks >= FAN_MAX:
		return
	var snake = area.get_parent()
	if snake == null or not ("main_power" in snake) or snake.main_power == null or snake.main_power.element != 3:
		return
	var now = Time.get_ticks_msec() / 1000.0
	if now - last_fan < FAN_PAUSE:
		return
	last_fan = now
	fan_stacks += 1
	speed *= FAN_SPEED
	scale *= FAN_GROWTH
	var shooter = get_parent()
	var playground = shooter.get_parent() if shooter else null
	if playground:
		PowerFx.burst(playground, global_position, Color(0.85, 0.95, 1.0))

# Ricochet: off the rock's side, at the angle it came in. False when it can't bounce (it
# crashes as usual): out of bounces, or it is already flying away from the rock.
func _bounce_off(rock_area) -> bool:
	var now = Time.get_ticks_msec() / 1000.0
	if now - last_bounce < BOUNCE_PAUSE:
		return true # Still leaving the rock it just bounced off
	if bounces >= MAX_BOUNCES:
		return false
	var rock = rock_area.get_parent()
	var normal = (global_position - _rock_center(rock)).normalized()
	var heading = Vector2.UP.rotated(rotation)
	if normal == Vector2.ZERO or heading.dot(normal) >= 0.0:
		return false
	bounces += 1
	last_bounce = now
	var away = heading.bounce(normal)
	rotation = away.angle() + PI / 2
	global_position += normal * 6.0
	var shooter = get_parent()
	var playground = shooter.get_parent() if shooter else null
	if playground:
		PowerFx.burst(playground, global_position, Color(1.0, 0.6, 0.2))
	return true

# Where a rock piece is (the middle of its picture)
func _rock_center(rock) -> Vector2:
	var body = rock.get("fissure_rect")
	if body == null:
		return rock.global_position
	return rock.to_global(body.position + body.size * body.scale / 2.0)
