class_name FirePower extends Power

var projectile_scene: PackedScene = preload("res://scenes/projectile.tscn")

func activate() -> void:
	if projectile_scene == null:
		return
		
	# Instanciamos el proyectil usando un helper del jugador
	var proj = player.spawn_projectile(projectile_scene)
	
	# Si en el futuro tenemos stats de radio, aquí se le pasarían:
	# proj.radius = player.stats.get_stat("fire.radius")
	
	if has_node("Shoot"):
		$Shoot.play()
	
	activated.emit()

func ai_should_activate(_direction: int) -> bool:
	var raycaster = player.get_node_or_null("Raycaster")
	if raycaster:
		var up_player = raycaster.get_node_or_null("UpPlayer")
		var is_colliding = up_player.is_colliding() if up_player else false
		var close_distance = raycaster.collision_distance("Up") < 75
		return is_colliding or close_distance
	return false
