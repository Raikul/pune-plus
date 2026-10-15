class_name AirPower extends Power

@onready var dash_sound: AudioStreamPlayer = $Dash

func setup(p: Node2D) -> void:
	super.setup(p)
	# Si este es el poder principal, aseguramos que la mirilla esté visible
	var reticle = player.get_node_or_null("DynamicTeleportNode")
	if reticle:
		reticle.show()

func activate() -> void:
	# 1. Creamos el espacio en la estela (gap)
	player.gap = true
	player.gap_delta_sum = 0.0

	# 2. Teletransportamos la serpiente a donde apunta la mirilla
	var reticle = player.get_node_or_null("DynamicTeleportNode")
	if reticle:
		player.global_position = reticle.global_position

	# 3. Sonido de dash
	if dash_sound:
		dash_sound.play()

	# 4. Timer para volver a dejar estela sólida tras el salto
	get_tree().create_timer(0.12).timeout.connect(func():
		player.gap = false
		finished.emit()
	)
	
	activated.emit()

func ai_should_activate(direction: int) -> bool:
	# Lógica original de la IA de Aire: se activa cuando va recto (direction == 0)
	return direction == 0
