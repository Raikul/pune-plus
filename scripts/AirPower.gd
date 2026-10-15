class_name AirPower extends Power

@onready var dash_sound: AudioStreamPlayer = $Dash

func setup(p: Node2D) -> void:
	super.setup(p)
	var reticle = player.get_node_or_null("DynamicTeleportNode")
	if reticle:
		reticle.show()

func activate() -> void:
	# Forzamos a calcular la posición del frente justo antes de saltar
	if player.has_method("actualizarPuntoDeTransporte"):
		player.actualizarPuntoDeTransporte()

	player.gap = true
	player.gap_delta_sum = 0.0

	var reticle = player.get_node_or_null("DynamicTeleportNode")
	if reticle:
		player.global_position = reticle.global_position

	if dash_sound:
		dash_sound.play()

	get_tree().create_timer(0.12).timeout.connect(func():
		player.gap = false
		finished.emit()
	)
	
	activated.emit()

func ai_should_activate(direction: int) -> bool:
	return direction == 0
