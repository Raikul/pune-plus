class_name FirePower extends Power

var projectile_scene: PackedScene = preload("res://scenes/projectile.tscn")
const DEFAULT_DURATION = 4.0

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
	# The projectile flies this long, then fades out (projectile.gd); 0 = until it hits something
	var duration: float = DEFAULT_DURATION
	if player.stats != null:
		duration = player.stats.get_stat("fire.duration")
	proj.lifetime = duration

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
