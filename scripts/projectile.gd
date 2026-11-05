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

func _process(delta):
	age += delta
	if lifetime > 0 and age >= lifetime and not expiring:
		expire()
	var	velocity = Vector2.UP.rotated(rotation) * speed
	position += velocity * delta
	_wrap()
	if fire_trail and not expiring and (last_flame == null or global_position.distance_to(last_flame) >= FLAME_SPACING):
		_drop_flame()

# The arena's edge doesn't stop it: it flies out one side and comes back in on the other,
# like Air's Wall Warp (so a shot fired along the edge doesn't fizzle). The shooter knows
# where the edges are.
func _wrap():
	var shooter = get_parent()
	if shooter == null or not ("left_limit_x" in shooter) or shooter.left_limit_x == null:
		position.x = clamp(position.x, 0, screen_size.x)
		position.y = clamp(position.y, 0, screen_size.y)
		return
	var p = global_position
	var left = shooter.left_limit_x
	var right = shooter.right_limit_x
	var top = shooter.top_limit_y
	var bottom = shooter.bottom_limit_y
	if p.x < left:
		p.x += right - left
	elif p.x > right:
		p.x -= right - left
	if p.y < top:
		p.y += bottom - top
	elif p.y > bottom:
		p.y -= bottom - top
	if p != global_position:
		global_position = p
		last_flame = null # No flame bridge across the arena

func _drop_flame():
	last_flame = global_position
	var shooter = get_parent()
	var flame = FireTrail.new()
	flame.owner_id = shooter.playerId if "playerId" in shooter else 0
	flame.color = Color(Global.playerColors[flame.owner_id]) if flame.owner_id in [1, 2, 3, 4, 5] else Color(1, 0.5, 0.1)
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
			PowerFx.explosion(playground, global_position, Color(1.0, 0.55, 0.15), 34.0 * scale.x)
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
	# Flames, Storm Fence lightning and the arena's edge (it wraps around, _wrap) don't stop it
	if area == get_parent() or expiring or area.is_in_group("hazards") or area.is_in_group("arena_border"):
		return
	# Walls, snakes (and Water's twin heads) and Earth's stone stop it: it crashes and fades
	# away. Freeing a twin head would also free its whole trail (the segments are its children);
	# the twin may already have died of this same hit, so the check is "twins", not "twinHeads".
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
		area.queue_free()
