class_name FirePower extends Power

var projectile_scene: PackedScene = preload("res://scenes/projectile.tscn")

func activate() -> void:
	if projectile_scene == null:
		return

	var proj = player.spawn_projectile(projectile_scene)

	# 1. Aplicar Radio / Escala
	var radius_mult: float = 1.0
	if player.stats != null:
		radius_mult = player.stats.get_stat("fire.radius")
	proj.scale = Vector2(radius_mult, radius_mult)

	# 2. Aplicar Duración en el aire
	var duration: float = 0.0 # 0 = sin límite
	if player.stats != null:
		duration = player.stats.get_stat("fire.duration")

	# Corregido: con 0 (el valor por defecto) la bola vuela hasta chocar, como antes.
	# Antes desaparecía a los 2 s (~800 px) y no llegaba al otro lado del mapa.
	if duration > 0:
		# Le pasamos la duración al proyectil si tiene variables internas o timers
		if "duration" in proj:
			proj.duration = duration
		if "lifetime" in proj:
			proj.lifetime = duration
		for child in proj.get_children():
			if child is Timer:
				child.wait_time = duration
				child.start()

		# Respaldo: destruye el proyectil cuando termine el tiempo de vuelo
		get_tree().create_timer(duration).timeout.connect(func():
			if is_instance_valid(proj):
				proj.queue_free()
		)

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
