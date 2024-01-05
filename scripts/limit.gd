extends Area2D

func _ready():
	connect("area_entered", _on_area_entered)
func _on_area_entered(area):
#	if area.has_signal("dead"):
#		area.emit_signal("dead")
#		area.get_node("CollisionShape2D").set_deferred("disabled", true)
#		area.set_process(false)
#		area.emit_signal("dead")
	pass
	
	
