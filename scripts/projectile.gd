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


func _ready():
#	colorRect = $"../ColorRect/Collider"
#	bodyTimer.connect("timeout", _on_bodyTimer_timeout)
#	gapTimer.connect("timeout", _on_gapTimer_timeout)
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
	position.x = clamp(position.x, 0, screen_size.x)
#	position.y = clamp(position.y, colorRect.position.y * colorRect.scale.y, screen_size.y)
	position.y = clamp(position.y, 0, screen_size.y)

# End of the flight: it stops burning and fades away.
# Placeholder look: shrinks and fades. For a custom effect, add an "expire" animation
# (about EXPIRE_TIME long) to the AnimationPlayer and it is played instead.
func expire():
	if expiring:
		return
	expiring = true
	set_deferred("monitoring", false)
	var tween = create_tween()
	if $AnimationPlayer.has_animation("expire"):
		$AnimationPlayer.play("expire")
		tween.tween_interval(EXPIRE_TIME)
	else:
		tween.set_parallel()
		tween.tween_property(self, "scale", scale * 0.1, EXPIRE_TIME).set_ease(Tween.EASE_IN)
		tween.tween_property(self, "modulate:a", 0.0, EXPIRE_TIME)
		tween.chain()
	tween.tween_callback(queue_free)

func _on_area_entered(area):
	if area == get_parent() or expiring:
		return
	# Walls, snakes and Earth's stone stop it: it crashes and fades away
	if area.is_in_group("activePlayers") or area.is_in_group("limits") or area.is_in_group("Fissures"):
		set_process(false)
		expire()
	else:
		area.queue_free()
