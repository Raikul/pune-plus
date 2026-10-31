class_name AirPower extends Power

@onready var dash_sound: AudioStreamPlayer = $Dash

static var double_jump_enabled: bool = false
var recast_active: bool = false

func setup(p: Node2D) -> void:
	super.setup(p)
	var reticle = player.get_node_or_null("DynamicTeleportNode")
	if reticle:
		reticle.show()

func is_recast_ready() -> bool:
	return double_jump_enabled and recast_active

func execute_recast() -> void:
	recast_active = false
	realizar_salto()

func activate() -> void:
	realizar_salto()

	if double_jump_enabled:
		recast_active = true
		get_tree().create_timer(1.0).timeout.connect(func():
			if recast_active:
				recast_active = false
		)

func realizar_salto() -> void:
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
