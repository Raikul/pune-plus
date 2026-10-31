class_name AirPower extends Power

@onready var dash_sound: AudioStreamPlayer = $Dash

# Second jump (Second Wind upgrade): seconds to jump again for free after a teleport, 0 = off
var recast_active: bool = false

func setup(p: Node2D) -> void:
	super.setup(p)
	var reticle = player.get_node_or_null("DynamicTeleportNode")
	if reticle:
		reticle.show()

func is_recast_ready() -> bool:
	return recast_active

func recast_window() -> float:
	return player.stats.get_stat("air.recast_window") if player.stats != null else 0.0

func execute_recast() -> void:
	recast_active = false
	realizar_salto()

func activate() -> void:
	realizar_salto()

	var window = recast_window()
	if window > 0:
		recast_active = true
		get_tree().create_timer(window).timeout.connect(func():
			if recast_active:
				recast_active = false
		)

func realizar_salto() -> void:
	if player.has_method("actualizarPuntoDeTransporte"):
		player.actualizarPuntoDeTransporte()

	player.gap = true
	player.gap_delta_sum = 0.0

	var start = player.global_position
	var reticle = player.get_node_or_null("DynamicTeleportNode")
	if reticle:
		player.global_position = reticle.global_position
	_lightning(start, player.global_position)

	if dash_sound:
		dash_sound.play()

	get_tree().create_timer(0.12).timeout.connect(func():
		player.gap = false
		finished.emit()
	)
	
	activated.emit()

# Placeholder bolt from where the jump starts to where it lands (scripts/fx/power_fx.gd)
func _lightning(start: Vector2, landing: Vector2) -> void:
	var parts = [[start, landing]]
	if player.teleport_wrapped:
		# Through the wall: one bolt out of the arena, one coming in on the other side
		var jump = player.teleport_target_unwrapped - start
		parts = [[start, player.teleport_target_unwrapped], [landing - jump, landing]]
	PowerFx.lightning(player.get_parent(), parts, Color(Global.playerColors[player.playerId]))

# --- AI ---
# Teleport when something is about to be hit and the landing spot is free. Without
# Wall Warp it doesn't jump into a wall; with it, a wall ahead is a reason to jump.
const AI_DANGER_DISTANCE = 90.0
const AI_LANDING_RADIUS = 20.0

func ai_should_activate(_direction: int) -> bool:
	return _ai_wants_to_jump()

# Second Wind: jump again if the landing turned out to be dangerous too
func ai_should_recast(_direction: int) -> bool:
	return is_recast_ready() and _ai_wants_to_jump()

func _ai_wants_to_jump() -> bool:
	var raycaster = player.get_node_or_null("Raycaster")
	if raycaster == null or raycaster.collision_distance("Up") > AI_DANGER_DISTANCE:
		return false
	player.actualizarPuntoDeTransporte()
	if player.teleport_clamped:
		return false # Would land right in front of a wall
	return _landing_is_clear(player.get_node("DynamicTeleportNode").global_position)

func _landing_is_clear(at: Vector2) -> bool:
	var shape = CircleShape2D.new()
	shape.radius = AI_LANDING_RADIUS
	var query = PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, at)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	query.collision_mask = player.collision_mask
	query.exclude = [player.get_rid()]
	return player.get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()
