extends Area2D
var speed = 400
var screen_size = Vector2.ZERO
var colorRect


func _ready():
#	colorRect = $"../ColorRect/Collider"
#	bodyTimer.connect("timeout", _on_bodyTimer_timeout)
#	gapTimer.connect("timeout", _on_gapTimer_timeout)
	screen_size = get_viewport_rect().size
	scale = Vector2(8,8)
#	$Meteor.rotate(rotation - PI/2)
	$AnimationPlayer.play("fireball")
#	$AnimationPlayer.rotate(rotation)
	
#	$Meteor.set_offset(Vector2(0,50))
#	$CollisionShape2D.set_position(Vector2(50,0))
#	$Meteor.play("launch")

func _process(delta):
	var	velocity = Vector2.UP.rotated(rotation) * speed
	position += velocity * delta
	position.x = clamp(position.x, 0, screen_size.x)
#	position.y = clamp(position.y, colorRect.position.y * colorRect.scale.y, screen_size.y)
	position.y = clamp(position.y, 0, screen_size.y)

func _on_area_entered(area):
	
	if area != get_parent(): 
		if not area.is_in_group("limits") and not area.is_in_group("activePlayers"):
			area.queue_free()
		if area.is_in_group("activePlayers") or area.is_in_group("limits") :
			set_process(false)
			await(get_tree().create_timer(2.0).timeout)
			queue_free()
	pass # Replace with function body.
