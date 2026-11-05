extends Area2D

var angular_speed = PI
var speed = 150.0
var screen_size = Vector2.ZERO
var gap = false
var powerAvailable = true
var colorRect
var invincible = false
var stats: PlayerStats = null

signal dead()
signal score()
## Online: a trail segment was laid by this (local) snake
signal body_laid(body_position, body_rotation)
## Online: this (local) snake used its power. recast: Air's free second jump (no cooldown)
signal power_used(recast)
## Online: this (local) water snake split off a twin
signal twin_spawned(twin)
## Online: this (local) fire snake turned to ash (rising = false) or rose again (Phoenix)
signal phoenix_changed(rising)

var playerId
var main_power: Power
const FISSURE_Z_INDEX = 5
# Earth's rocks: base size of each piece (across, along the path); earth.scale widens them
const FISSURE_SCALE = Vector2(1.0, 1.0)
# Which Player{N} input actions steer this snake (0 = no keys, e.g. an online AI).
# Online each machine numbers its own players from 1, so the first one there uses the Player 1 keys.
var input_id
# Online: another machine owns this snake. NetSession moves it and lays its trail.
var net_remote = false
var steer_direction = 0
# Air's teleport target (see actualizarPuntoDeTransporte): where it would land without walls,
# and whether the walls wrapped it (Wall Warp) or cut it short
var teleport_target_unwrapped = Vector2.ZERO
var teleport_wrapped = false
var teleport_clamped = false
const TELEPORT_WALL_MARGIN = 40.0

# Air's Static Shock: seconds left without power, and with left/right swapped (Scrambler)
var shocked_time = 0.0
var scrambled_time = 0.0
var scrambled_age = 0.0
var scrambled_by = 0 # The Air snake that scrambled it (end-screen stats)
# Seconds after Air's teleport in which only walls can kill it (no dying on the spot
# it left or landed on)
var teleport_grace = 0.0
const TELEPORT_GRACE = 0.3
# An AI snake acts confused this long, then gets its grip and steers right again
const AI_SCRAMBLE_CONFUSION = 1.5
const SHOCK_COLOR = Color(0.55, 0.85, 1.0)
# Phoenix: dead for now but rising again (not moving, invisible, can't be hit)
var reviving = false

var listOfNodes = []
var snakeBodyScene: PackedScene
var twinHeadScene: PackedScene
@onready var bodyTimer = get_node("BodyTimer")
@onready var gapTimer = get_node("GapTimer")
@onready var gapFrequencyTimer = get_node("GapFrequencyTimer")
@onready var is_water_my_friend = false
@onready var ai_enabled = true
@onready var locked_movement = false
@onready var head_texture: CompressedTexture2D = $HeadSprite.texture
@onready var head_modulate: Color = $HeadSprite.modulate
var locked_direction
var clonable_id
var clonable_name
var gap_delta_sum = 0
#var has_twin_head = false
var left_limit_x
var right_limit_x
var top_limit_y
var bottom_limit_y

func _ready():
	apply_scale(Vector2(0.1,0.1))
	ai_enabled = Global.AI_Enabled[playerId]
	
	twinHeadScene = preload("res://scenes/twin_head.tscn")
	snakeBodyScene = preload("res://scenes/snake_body.tscn")

	gapTimer.connect("timeout", _on_gapTimer_timeout)
	gapFrequencyTimer.connect("timeout", _on_gapFrequencyTimer_timeout)
	
	set_gap_size()
	screen_size = get_viewport_rect().size
	
	# Powers live in their own nodes now (scripts/*Power.gd); the player only handles the cooldown
	$CooldownTimer.connect("timeout", powerReady.bind(Global.playerColors[playerId]))
	update_power_indicator()

	listOfNodes.append(self)
	if input_id == null:
		input_id = playerId
	if playerId != null:
		clonable_id = playerId
		clonable_name = "Player"+str(playerId)
		main_power = Powers.create(playerId)
		if main_power != null:
			add_child(main_power)
			main_power.setup(self)
	# Earth's head and trail are drawn over its rocks, so it can see where it already went
	if main_power is EarthPower:
		$HeadSprite.z_index = FISSURE_Z_INDEX + 2
		$ElementHeadSprite.z_index = FISSURE_Z_INDEX + 2

	actualizarPuntoDeTransporte()
	if Global.snake_eyes:
		face = SnakeFace.new()
		add_child(face)
	if Global.nameplates or Global.direction_arrow:
		add_child(SnakeOverlay.new())
	add_child(OffscreenMarker.new())

	if stats != null:
		stats.stats_changed.connect(refresh_stats)
		refresh_stats()
	# Hearth (Fire): a circle of fire where it starts the round. Deferred: the playground
	# is still adding the snake.
	if has_hearth() and not net_remote:
		(func(): FireRing.spawn(self, global_position)).call_deferred()
	move_heading = rotation
var face: SnakeFace

# "effort" for a moment when it uses its power, "dead" when it crashes
func set_face(mood, seconds = 0.0):
	if face:
		face.set_mood(mood, seconds)

func refresh_stats() -> void:
	if stats != null:
		speed = stats.get_stat("speed")
		
func _process(delta):
	if net_remote:
		return
	# 1. Primero siempre actualizamos la mirilla:
	actualizarPuntoDeTransporte()

	# 2. Luego el movimiento y la IA:
	var direction = 0
	if locked_movement: direction = locked_direction
	else:
		if input_id != 0 and Input.is_action_pressed("Player"+str(input_id)+"Left") :direction = -1
		elif input_id != 0 and Input.is_action_pressed("Player"+str(input_id)+"Right"): direction = 1
		elif (ai_enabled and $Raycaster.return_steering() == "Left"): direction = -1
		elif (ai_enabled and $Raycaster.return_steering() == "Right"): direction = 1
		if ai_enabled and not _human_steering():
			direction = _ai_keep_from_ally(direction)
			direction = _ai_dodge_moving_walls(direction)
			if invincible and has_border_pass():
				# Burrower: back towards the middle from off the map; straight through a wall
				if _beyond_border(false):
					direction = _ai_steer_home()
				elif _beyond_border():
					direction = 0

	if ai_enabled and powerAvailable: ai_punchi(direction)
	elif ai_enabled and main_power and main_power.ai_should_recast(direction): try_use_power()
	_update_shock(delta)
	teleport_grace = max(teleport_grace - delta, 0.0)
	if phoenix_grace > 0:
		_update_phoenix_grace(delta)
	if scrambled_time > 0 and not (ai_enabled and scrambled_age >= AI_SCRAMBLE_CONFUSION):
		direction = -direction
	steer_direction = direction

	_move(direction, delta)

# --- Ground: the patches other snakes leave in their gaps (scripts/gap_patch.gd) ---
## On ice the head turns slower and the body keeps drifting the way it was going,
## catching up with the head at this rate (higher = grippier)
const ICE_TURN = 0.7
const ICE_GRIP = 1.6
## On roots it crawls
const ROOTS_SPEED = 0.3
# The direction it actually moves in (on ice it lags behind where the head points)
var move_heading = 0.0
var on_ice = false
var on_roots = false

func _move(direction, delta):
	_ground_patches()
	rotation += angular_speed * direction * delta * (ICE_TURN if on_ice else 1.0)
	if on_ice:
		move_heading = lerp_angle(move_heading, rotation, clamp(ICE_GRIP * delta, 0.0, 1.0))
	else:
		move_heading = rotation
	var velocity = Vector2.UP.rotated(move_heading) * speed * (ROOTS_SPEED if on_roots else 1.0)
	position += velocity * delta

# The ice and roots under the head, except its own (and its teammate's)
func _ground_patches():
	on_ice = false
	on_roots = false
	if get_tree().get_nodes_in_group("gap_patches").is_empty():
		return
	for patch in GapPatch.at_point(get_world_2d(), global_position):
		if patch.owner_id == playerId:
			continue
		var maker = get_parent().get_node_or_null("Player%d" % patch.owner_id) if get_parent() else null
		if maker != null and is_ally(maker):
			continue
		if patch.kind == "ice":
			on_ice = true
		else:
			on_roots = true
# Off the Map: outside the arena the raycasts see the border from behind and would steer
# further out; head back to the middle instead
func _ai_steer_home() -> int:
	var middle = Vector2((left_limit_x + right_limit_x) / 2.0, (top_limit_y + bottom_limit_y) / 2.0)
	var turn = Vector2.UP.rotated(rotation).angle_to(middle - global_position)
	if abs(turn) < 0.1:
		return 0
	return 1 if turn > 0 else -1

func _human_steering() -> bool:
	return input_id != 0 and (Input.is_action_pressed("Player%dLeft" % input_id) or Input.is_action_pressed("Player%dRight" % input_id))

# --- AI and moving level walls ---
# The raycasts only see what's ahead right now, so a spinning or sliding wall coming from
# the side catches the AI. Near one, it plays its three options (turn left, straight, turn
# right) forward for a moment against where the walls will be, and if its choice would hit,
# takes the one that stays clear the longest.
const AI_LOOKAHEAD_STEPS = 8
const AI_LOOKAHEAD_STEP = 0.1
const AI_WALL_CLEARANCE = 14.0
const AI_WALL_NOTICE = 260.0

func _ai_dodge_moving_walls(preferred) -> int:
	var level = get_parent().get("level") if get_parent() else null
	if level == null:
		return preferred
	var near = []
	for wall in level.walls():
		if wall.is_moving() and _distance_to_polygon(global_position, wall.global_polygon()) < AI_WALL_NOTICE:
			near.append(wall)
	if near.is_empty():
		return preferred
	var futures = [] # Each step's wall outlines
	for step in range(1, AI_LOOKAHEAD_STEPS + 1):
		futures.append(near.map(func(wall): return wall.global_polygon_in(step * AI_LOOKAHEAD_STEP)))
	var best = preferred
	var best_steps = _steps_clear(preferred, futures)
	if best_steps >= AI_LOOKAHEAD_STEPS:
		return preferred
	for option in [-1, 0, 1]:
		var steps = _steps_clear(option, futures)
		if steps > best_steps:
			best = option
			best_steps = steps
	return best

# How many look-ahead steps this steering stays off the walls (and inside the arena)
func _steps_clear(steer, futures) -> int:
	var at = global_position
	var heading = rotation
	for step in futures.size():
		heading += angular_speed * steer * AI_LOOKAHEAD_STEP
		at += Vector2.UP.rotated(heading) * speed * AI_LOOKAHEAD_STEP
		if left_limit_x != null and (at.x < left_limit_x + AI_WALL_CLEARANCE or at.x > right_limit_x - AI_WALL_CLEARANCE 				or at.y < top_limit_y + AI_WALL_CLEARANCE or at.y > bottom_limit_y - AI_WALL_CLEARANCE):
			return step
		for shape in futures[step]:
			if Geometry2D.is_point_in_polygon(at, shape) or _distance_to_polygon(at, shape) < AI_WALL_CLEARANCE:
				return step
	return futures.size()

static func _distance_to_polygon(point, shape) -> float:
	var best = INF
	for i in shape.size():
		best = min(best, Geometry2D.get_closest_point_to_segment(point, shape[i], shape[(i + 1) % shape.size()]).distance_to(point))
	return best

# Air's landing marker is top-level, so it stays on screen unless hidden (death)
func hide_teleport_marker():
	if has_node("DynamicTeleportNode"):
		$DynamicTeleportNode.hide()

func actualizarPuntoDeTransporte():
	if not has_node("DynamicTeleportNode") or not has_node("FixedTeleportNode"):
		return

	# NOTA: Si solo quieres que se vea con el jugador 3 (aire), deja esta condición.
	# Si estás probando con el jugador 1 o 2, comenta estas líneas temporalmente:
	if not can_teleport() or not is_in_group("alivePlayers"):
		$DynamicTeleportNode.hide()
		return
	else:
		# Online, another machine's Air never shows it: our copy only places it when it
		# jumps, so it would sit frozen where that jump landed
		$DynamicTeleportNode.visible = not net_remote
		# Shinier when Air can jump now (power ready or its free second jump), fainter
		# while it recharges or is electrocuted
		var second_jump = main_power != null and main_power.has_method("is_recast_ready") and main_power.is_recast_ready()
		$DynamicTeleportNode.can_jump = (powerAvailable or second_jump) and shocked_time <= 0

	# Tomamos la posición base adelante de la serpiente
	var target_pos : Vector2 = $FixedTeleportNode.global_position
	teleport_target_unwrapped = target_pos
	teleport_wrapped = false
	teleport_clamped = false
	if left_limit_x == null or right_limit_x == null or top_limit_y == null or bottom_limit_y == null:
		$DynamicTeleportNode.global_position = target_pos
		return

	if has_wall_warp():
		# Wall Warp: past a wall, the target comes in from the opposite side
		# --- EJE X ---
		if target_pos.x <= left_limit_x:
			var x_difference = target_pos.x - left_limit_x
			target_pos.x = right_limit_x + x_difference
		elif target_pos.x >= right_limit_x:
			var x_difference = target_pos.x - right_limit_x
			target_pos.x = left_limit_x + x_difference

		# --- EJE Y ---
		if target_pos.y <= top_limit_y:
			var y_difference = target_pos.y - top_limit_y
			target_pos.y = bottom_limit_y + y_difference
		elif target_pos.y >= bottom_limit_y:
			var y_difference = target_pos.y - bottom_limit_y
			target_pos.y = top_limit_y + y_difference
		teleport_wrapped = target_pos != teleport_target_unwrapped
	else:
		# Default: the jump stops short of the wall
		var inside = Vector2(
			clamp(target_pos.x, left_limit_x + TELEPORT_WALL_MARGIN, right_limit_x - TELEPORT_WALL_MARGIN),
			clamp(target_pos.y, top_limit_y + TELEPORT_WALL_MARGIN, bottom_limit_y - TELEPORT_WALL_MARGIN))
		teleport_clamped = inside != target_pos
		target_pos = inside

	# Actualizamos la posición
	$DynamicTeleportNode.global_position = target_pos
func _on_gapTimer_timeout():
	gap = false
	gapFrequencyTimer.start()
	
func _on_gapFrequencyTimer_timeout():
	gap = true
	# Corregido: sin stats se usa el hueco de la opción Gap Size (antes quedaba fijo en 0.6)
	var dur = gapTimer.wait_time
	if stats != null:
		dur = stats.get_stat("gap.time")
	gapTimer.start(max(dur, 0.05))
func _on_bodyTimer_timeout():
#	if not gap:
#		createBody(snakeBodyScene)
	pass

func _physics_process(delta):
	if net_remote:
		return
	# Safety net: a snake that got outside the arena somehow (power, lag) dies instead of
	# wandering off screen forever. Earth with Off the Map may roam out there while its
	# armor lasts (set_invincible checks where it is when the armor ends).
	if is_processing() and _outside_arena() and not (invincible and has_border_pass()):
		$CollisionShape2D.set_deferred("disabled", true)
		set_process(false)
		emit_signal("dead")
		return
	gap_delta_sum += delta
	if on_fresh_path and not invincible and not _on_own_rock():
		on_fresh_path = false
	if gap or reviving or on_fresh_path:
		# The stroke ends here; the next piece starts a new one
		trail_tail = null
	# Laid by distance, not time, so the trail is just as dense at any speed
	elif trail_tail == null or not is_instance_valid(trail_tail) 			or global_position.distance_to(trail_tail.global_position) >= TRAIL_SPACING:
		var body = createBody(snakeBodyScene)
		_extend_trail(body)
		gap_delta_sum = 0
		Global.add_stat(playerId, "length", TRAIL_SPACING)
		body_laid.emit(body.global_position, body.rotation)

## Distance between trail pieces (what 0.05 s at the base speed used to give)
const TRAIL_SPACING = 7.5
# The newest piece of the trail being laid (null at the start of a stroke)
var trail_tail = null

func _extend_trail(body):
	if main_power is AirPower or _gap_patch_kind() != "":
		_note_gap(body)
	body.link_to(trail_tail)
	trail_tail = body
	last_laid = body

# Air's Storm Fence: every gap in its trail, as [end of a stroke, start of the next]. A new
# stroke after a teleport isn't a gap (skip_next_gap), nor are pieces too far apart.
var gaps = []
var last_laid = null
var skip_next_gap = false
const MAX_GAPS = 400
const MAX_GAP_LENGTH = 400.0

func _note_gap(body):
	if last_laid == null or not is_instance_valid(last_laid):
		return
	var length = last_laid.global_position.distance_to(body.global_position)
	if trail_tail != null and length <= TrailSegment.MAX_LINK:
		return # Same stroke
	if skip_next_gap:
		skip_next_gap = false
		return
	if length > MAX_GAP_LENGTH:
		return
	var kind = _gap_patch_kind()
	if kind != "" and not net_remote:
		var middle = (last_laid.global_position + body.global_position) / 2.0
		GapPatch.spawn(get_parent(), middle, kind, playerId, max(GapPatch.RADIUS, length * 0.6))
	gaps.append([last_laid, body])
	if gaps.size() > MAX_GAPS:
		gaps.pop_front()

# Black Ice (Water) or Strangling Roots (Earth): what its gaps leave behind ("" = nothing)
func _gap_patch_kind() -> String:
	if stat_value("water.ice") >= 1.0:
		return "ice"
	if stat_value("earth.roots") >= 1.0:
		return "roots"
	return ""

# The gaps whose both ends are still there (a fireball may have burnt one)
func intact_gaps() -> Array:
	gaps = gaps.filter(func(gap): return gap.all(func(end): return is_instance_valid(end) and not end.is_queued_for_deletion()))
	return gaps

func _on_area_entered(area):
	# Air's Storm Fence: lightning in a gap of Air's trail shocks, it never kills
	if area.is_in_group("storm_arcs"):
		if area.owner_id != playerId:
			_storm_shock(area)
		return
	# A remote snake's owner decides its deaths and pickups
	if net_remote:
		return
	if area is Shroom:
		$ShroomEaten.play()
		emit_signal("score")
		area.queue_free()
		return

	# A fireball that's fading out (spent, or swallowed by Void) is harmless
	if area.is_in_group("fireballs") and area.expiring:
		return

	# Just risen from its ashes: untouchable for a moment (_end_phoenix_grace checks again)
	if phoenix_grace > 0:
		return

	# Si el poder activo decide ignorar la colisión (ej. Agua tocando su propio clon):
	if main_power and main_power.should_ignore_collision(area):
		return

	# Earth's stone: deadly like a trail, except its own with the Stone Walker upgrade, or
	# the path it is still on
	if area.is_in_group("Fissures") and (has_stone_walk() or on_fresh_path) and is_ancestor_of(area):
		return

	# Earth's power makes it pass through trails, not walls (it used to slip out of the arena
	# and stay alive off screen). Burrower lets it through every wall: the arena's border and
	# the level's obstacles.
	if invincible and has_border_pass() and area.is_in_group("limits"):
		return
	# Its own hazards never hurt it (Fire's Wildfire flames, Air's Storm Fence)
	if area.is_in_group("hazards") and area.owner_id == playerId:
		return
	if invincible and area is TrailSegment and area.get_parent() == self and listOfNodes.find(area) == -1:
		_count_own_trail_pass()
	if (not invincible and teleport_grace <= 0) or area.is_in_group("limits"):
		if listOfNodes.find(area) == -1:
			# Le preguntamos al poder si puede salvar al jugador de morir (Agua reviviendo)
			if main_power and main_power.try_prevent_death():
				return

			# Muerte normal
			_crash(area)

func _crash(cause):
	_credit_death(cause)
	_feed_void(cause)
	$CollisionShape2D.set_deferred("disabled", true)
	$Split.play()
	set_process(false)
	emit_signal("dead")

# Died on Void's trail while its void was open: Void keeps this snake's power for the round
func _feed_void(cause):
	if not (cause is TrailSegment) or cause.get_parent() == self:
		return
	var void_snake = cause.get_parent()
	if void_snake == null or not ("main_power" in void_snake) or not (void_snake.main_power is VoidPower):
		return
	if void_snake.main_power.field_active() and playerId != Global.VOID_ID:
		void_snake.main_power.absorb(playerId, playerId, true)

# End-screen stats: Earth's armor taking it through its own trail. One crossing touches a
# few pieces in a row, so touches close together count once.
const OWN_PASS_GAP_MS = 400
var last_own_pass = -OWN_PASS_GAP_MS
func _count_own_trail_pass():
	var now = Time.get_ticks_msec()
	if now - last_own_pass >= OWN_PASS_GAP_MS:
		Global.add_stat(playerId, "earth_own_trail")
	last_own_pass = now

# End-screen stats: a rival's fireball, or dying while a rival Air had it scrambled
func _credit_death(cause):
	var killer = killer_of(cause)
	if cause.is_in_group("fire_trail") and killer != 0:
		Global.add_stat(killer, "fire_kills")
	if cause.is_in_group("fireballs") and killer != 0:
		Global.add_stat(killer, "fire_kills")
		# Pyre (Fire): the fire stays where its fireball killed
		var shooter = cause.get_parent()
		if shooter != null and shooter.has_method("has_pyre") and shooter.has_pyre():
			FireRing.spawn.call_deferred(shooter, global_position)
	if scrambled_time > 0 and scrambled_by != 0 and scrambled_by != playerId:
		Global.add_stat(scrambled_by, "air_scramble_kills")
		if killer == 0:
			killer = scrambled_by
	if killer != 0:
		Global.add_stat(killer, "kills")
	# The play of the game (scripts/replay/replay_recorder.gd): a kill, flashier with powers
	if killer != 0:
		var weight = 4.0 if cause.is_in_group("fireballs") or cause.is_in_group("hazards") else 3.0
		Global.note_highlight(killer, "kill", weight, playerId)
	else:
		Global.note_highlight(playerId, "crash", 0.5, playerId)

# Caught in Storm Fence lightning: no power for a while, and left/right swapped if the Air
# snake has Scrambler (like Static Shock). Only the snake's own machine applies it; the
# other machines just show it.
func _storm_shock(arc):
	if net_remote:
		shock_visual(arc.shock_time)
		return
	var fresh = shocked_time <= 0 and is_in_group("alivePlayers") and not reviving
	shock(arc.shock_time, arc.scramble_time, arc.owner_id)
	if fresh:
		Global.add_stat(arc.owner_id, "air_shocks")

# The other snake that killed this one (its trail, rocks, fireball, flames, head), 0 = none
func killer_of(cause) -> int:
	if cause == null or not is_instance_valid(cause):
		return 0
	var id = 0
	if cause.is_in_group("hazards"):
		id = cause.owner_id
	elif cause.is_in_group("fireballs"):
		var shooter = cause.get_parent()
		id = shooter.playerId if "playerId" in shooter else 0
	elif cause.is_in_group("Fissures"):
		var earth = Fissure.owner_of(cause)
		id = earth.playerId if earth != null else 0
	else:
		# A trail piece (its snake, or the twin whose snake it is), a head or a twin head
		var node = cause
		for i in 3:
			if node == null:
				break
			if "playerId" in node and node.playerId != null and node.get_script() == get_script():
				id = node.playerId
				break
			node = node.get_parent()
	return id if id != playerId else 0

# Online: lay a segment of a remote snake where its owner laid it
func create_body_at(body_position, body_rotation):
	var body = createBody(snakeBodyScene)
	body.global_position = body_position
	body.rotation = body_rotation
	# Gaps aren't sent: pieces too far apart start a new stroke (TrailSegment.MAX_LINK)
	_extend_trail(body)
	return body

# Online: the twin of a remote water snake, moved by NetSession
func spawn_remote_twin():
	is_water_my_friend = true
	var twin = createBody(twinHeadScene)
	twin.net_remote = true
	PowerFx.splash(get_parent(), global_position, Color(Global.playerColors[playerId]), 0.35, 0.55)
	twin.bufferListOfNodes = listOfNodes
	twin.bufferListOfNodes.append(self)
	return twin

func createBody(scene):
	var sceneInstance = scene.instantiate()

	sceneInstance.set_as_top_level(true)
	sceneInstance.global_position = global_position
	
	if sceneInstance is TrailSegment:
		# Drawn as a line in the snake's color (scripts/trail_segment.gd)
		sceneInstance.modulate = head_modulate
	else:
		var bodySprite = sceneInstance.get_node("BodySprite")
		bodySprite.set_texture(head_texture)
		bodySprite.modulate = head_modulate

	sceneInstance.apply_scale(get_scale())
	sceneInstance.rotation = rotation
	if main_power is EarthPower:
		sceneInstance.z_index = FISSURE_Z_INDEX + 1
	
	listOfNodes.append(sceneInstance)
	if listOfNodes.size() == 1:
		sceneInstance.rotation = rotation + PI
	if listOfNodes.size() > 4:
		listOfNodes.pop_front()
	add_child(sceneInstance)
	return sceneInstance

func spawn_projectile(scene: PackedScene) -> Node2D:
	var sceneInstance = scene.instantiate()
	sceneInstance.set_as_top_level(true)
	sceneInstance.global_position = global_position
	sceneInstance.rotation = rotation

	# Vital: registrar en listOfNodes para no suicidarse con su propio proyectil
	# Corregido: se agregaba dos veces y sacaba de la lista dos segmentos propios
	listOfNodes.append(sceneInstance)
	if listOfNodes.size() == 1:
		sceneInstance.rotation = rotation + PI
	if listOfNodes.size() > 4:
		listOfNodes.pop_front()
	add_child(sceneInstance)
	return sceneInstance
	
# Seconds of rocky path (EarthPower sets it to its duration, so path and invincibility match)
var rock_time = 1.2
# True from the power until the head is off the path it just laid: those rocks don't kill
# it (the last one can reach the head right after the invincibility ends) and get no trail
var on_fresh_path = false
# origin: where the path is laid (a Void twin with Earth held); null = this snake
func start_fissure(fissure_step, fissure_scene, previous_body_list = [], origin = null):
	if origin != null and (not is_instance_valid(origin) or not origin.alive):
		return null
	var source = origin if origin != null else self
	var fissure_instance : Fissure = fissure_scene.instantiate()

	fissure_instance.set_as_top_level(true)
	fissure_instance.global_position = source.global_position
	# As many rocks as fit in the power's duration (one every fissure_gap seconds)
	fissure_instance.maximum_step_number = max(2, roundi(rock_time / fissure_instance.fissure_gap))
	var body_list = fissure_instance.set_body(fissure_step, previous_body_list)
	if fissure_step < fissure_instance.maximum_step_number:
		fissure_instance.connect("fissure_ready", start_fissure.bind(fissure_scene, body_list, origin))

#	var bodySprite = sceneInstance.get_node("BodySprite")
#	bodySprite.set_texture(head_texture)
#	bodySprite.modulate = head_modulate

	

		
#	sceneInstance.apply_scale(get_scale())
	fissure_instance.rotation = source.rotation
	var width = stat_value("earth.scale") if stats != null else 1.0
	fissure_instance.scale = FISSURE_SCALE * Vector2(width, 1.0)
	
	listOfNodes.append(fissure_instance)
	if listOfNodes.size() == 1:
		fissure_instance.rotation = rotation + PI
	if listOfNodes.size() > 4:
		listOfNodes.pop_front()
	
	fissure_instance.add_to_group("Fissures", true)
	# Above every trail and head, whichever snake was spawned later
	fissure_instance.z_index = FISSURE_Z_INDEX
	add_child(fissure_instance)
	return fissure_instance
	
func set_invincible(state: bool) -> void:
	invincible = state
	# Burrower: the armor wore off with the snake outside the arena or inside a wall
	if not state and has_border_pass() and is_processing() and not net_remote and _beyond_border():
		_crash(self)

# Start-of-match countdown: the snake waits in place, no trail, no power, no gap clock
func set_frozen(state: bool) -> void:
	set_process(not state)
	set_physics_process(not state)
	if state:
		gapFrequencyTimer.stop()
	else:
		gapFrequencyTimer.start()

# 2v2: a dead human teammate takes this AI snake over (AiTakeover) until the round ends
func take_control(new_input_id) -> void:
	ai_enabled = false
	input_id = new_input_id

# Earth hides its head while it lays the rocky path (the rocks are all you see)
func set_head_visible(state: bool) -> void:
	$HeadSprite.visible = state
	$ElementHeadSprite.visible = state
	if face:
		face.visible = state
func _input(event):
	if net_remote:
		return
	# Una sola línea universal para todos los jugadores:
	if playerId != null and input_id != 0 and event.is_action_pressed("Player" + str(input_id) + "Up"):
		try_use_power()

func try_use_power() -> void:
	# Stopped (dead, an ember, or the round/game is over): no power and no sound
	if not is_processing():
		return
	# Electrocuted: no power at all, not even Air's free second jump
	if shocked_time > 0:
		return
	# 1. Si el poder tiene el segundo salto listo, salta DE INMEDIATO sin cooldown:
	if main_power != null and main_power.has_method("is_recast_ready") and main_power.is_recast_ready():
		main_power.execute_recast()
		set_face("effort", 0.5)
		power_used.emit(true)
		Global.add_stat(playerId, "powers")
		return

	# 2. Si está en cooldown normal y no hay segundo salto, no hace nada:
	if not powerAvailable:
		return
	# Nothing to cast (Water with every twin already out): no cooldown, no sound
	if main_power != null and not main_power.can_activate():
		return
	
	powerCooldown()
	
	if main_power != null:
		main_power.activate()
	set_face("effort", 0.5)
	power_used.emit(false)
	Global.add_stat(playerId, "powers")

	if stats != null:
		for entry in stats.active_buffs.values():
			if entry.behavior != null:
				entry.behavior.on_power_activated(self, entry.stacks)

# Online: replays another machine's power use on our copy of its snake (no cooldown checks)
func use_power():
	if main_power != null:
		main_power.activate()
	set_face("effort", 0.5)
# 2v2: the snake's teammate (a snake of the same team, not itself)
func is_ally(other) -> bool:
	var playground = get_parent()
	if other == null or other == self or not is_instance_valid(other) or not ("playerId" in other) or other.playerId == null:
		return false
	if playground == null or not playground.get("teams_mode"):
		return false
	return Global.team_of(other.playerId) == Global.team_of(playerId)

func allies() -> Array:
	return get_tree().get_nodes_in_group("alivePlayers").filter(is_ally)

# 2v2 AI: with nothing to dodge, it drifts away from a teammate up ahead, so the two
# don't run into each other by accident
const AI_ALLY_SPACE = 240.0
func _ai_keep_from_ally(direction):
	if direction != 0:
		return direction
	var forward = Vector2.UP.rotated(rotation)
	for ally in allies():
		var to_ally = ally.global_position - global_position
		if to_ally.length() > AI_ALLY_SPACE or forward.dot(to_ally.normalized()) < 0.2:
			continue
		# Ally on the right (screen y goes down): turn left, and the other way round
		return -1 if forward.cross(to_ally) > 0 else 1
	return direction

func ai_punchi(direction):
	if powerAvailable and main_power and main_power.ai_should_activate(direction):
		try_use_power()
func spawn_twin(scene: PackedScene) -> Node2D:
	var twin = createBody(scene)
	twin.bufferListOfNodes = listOfNodes
	twin.bufferListOfNodes.append(self)
	twin.snakeBodyScene = snakeBodyScene
	twin_spawned.emit(twin)
	return twin

func powerCooldown():
	powerAvailable = false
	var cd = $CooldownTimer.wait_time
	if stats != null:
		cd = stats.get_stat("cooldown")

	# Usamos max(cd, 0.05) para que nunca dé error si pones 0 en la consola
	$CooldownTimer.start(max(cd, 0.05))
	update_power_indicator()
func powerReady(_prevColor = null):
	# A dead snake's cooldown can still run out; its power stays off
	if not is_in_group("alivePlayers"):
		return
	powerAvailable = true
	update_power_indicator()
	if main_power == null or main_power.should_pulse_ready():
		pulse_power_ready()

# A soft ring around the head: the power can be used now
func pulse_power_ready():
	if get_parent() and is_processing():
		PowerFx.pulse(get_parent(), self, Color(Global.playerColors[playerId]))

# The element symbol on the head is white while the power is ready and dark while it recharges
func update_power_indicator():
	if has_node("ElementHeadSprite"):
		if shocked_time > 0:
			$ElementHeadSprite.modulate = SHOCK_COLOR
		else:
			$ElementHeadSprite.modulate = Color.WHITE if powerAvailable else Color.BLACK

# Air's Static Shock went through this snake's head. Every machine runs it on its own
# copy of the snake (Air's jump is replayed everywhere); only the owner's matters.
# scramble: seconds with left and right swapped (0 = none); by: the Air snake that did it
func shock(duration, scramble = 0.0, by = 0):
	if not is_in_group("alivePlayers") or reviving:
		return
	# Void with its void open drinks the lightning: it absorbs Air instead
	if main_power is VoidPower and main_power.field_active():
		main_power.absorb(3, by if by != 0 else 3)
		return
	var parent = get_parent()
	if shocked_time <= 0 and parent:
		PowerFx.shock(parent, self, SHOCK_COLOR, duration)
	shocked_time = max(shocked_time, duration)
	if scramble > 0:
		scrambled_time = max(scrambled_time, scramble)
		scrambled_age = 0.0
		scrambled_by = by
	update_power_indicator()

# Online: a snake run by another machine; its owner applies the effect, we only show it
func shock_visual(duration):
	if get_parent():
		PowerFx.shock(get_parent(), self, SHOCK_COLOR, duration)

func _update_shock(delta):
	if shocked_time <= 0 and scrambled_time <= 0:
		return
	if scrambled_time > 0:
		scrambled_age += delta
	scrambled_time = max(scrambled_time - delta, 0.0)
	shocked_time = max(shocked_time - delta, 0.0)
	if shocked_time <= 0:
		update_power_indicator()

# --- Phoenix (Fire's legendary upgrade) ---
const PHOENIX_CLEAR_RADIUS = 90.0
const PHOENIX_WALL_MARGIN = 90.0

# Dies for a while: stays where it fell as an ember (FirePower rises it again)
func phoenix_ash():
	reviving = true
	set_process(false)
	$CollisionShape2D.set_deferred("disabled", true)
	$HeadSprite.hide()
	$ElementHeadSprite.hide()
	if face:
		face.hide()
	if has_node("DynamicTeleportNode"):
		$DynamicTeleportNode.hide()
	if not net_remote:
		phoenix_changed.emit(false)

# Where it can rise: its death spot, moved away from the walls (it would die on them again),
# and the heading the arrow starts with
func phoenix_rise_point() -> Array:
	var point = global_position
	var heading = rotation
	if left_limit_x != null:
		var inside = Vector2(
			clamp(point.x, left_limit_x + PHOENIX_WALL_MARGIN, right_limit_x - PHOENIX_WALL_MARGIN),
			clamp(point.y, top_limit_y + PHOENIX_WALL_MARGIN, bottom_limit_y - PHOENIX_WALL_MARGIN))
		var middle = Vector2((left_limit_x + right_limit_x) / 2, (top_limit_y + bottom_limit_y) / 2)
		# A level wall there: step towards the middle until it's clear
		var level = get_parent().get("level") if get_parent() else null
		if level != null:
			for step in 30:
				if level.is_clear(inside, PHOENIX_WALL_MARGIN * 0.6):
					break
				inside = inside.move_toward(middle, 30.0)
		if inside != point:
			# Face the middle of the arena instead of the wall it hit
			heading = Vector2.UP.angle_to(middle - inside)
		point = inside
	return [point, heading]

## Seconds after rising in which nothing can kill it (it can rise next to a level wall)
const PHOENIX_GRACE = 0.8
var phoenix_grace = 0.0

func phoenix_rise(point, heading):
	global_position = point
	rotation = heading
	phoenix_grace = PHOENIX_GRACE
	if not net_remote:
		Global.add_stat(playerId, "fire_revives")
	_clear_area(point, PHOENIX_CLEAR_RADIUS)
	PowerFx.explosion(get_parent(), point, Color(Global.playerColors[playerId]), PHOENIX_CLEAR_RADIUS)
	# Hearth: rising lights a new fire where it rises
	if has_hearth() and not net_remote:
		FireRing.spawn.call_deferred(self, point)
	move_heading = heading
	$HeadSprite.show()
	$ElementHeadSprite.show()
	if face:
		face.show()
		face.set_mood("normal")
	reviving = false
	gap_delta_sum = 0
	if not net_remote:
		$CollisionShape2D.set_deferred("disabled", false)
		set_process(true)
		actualizarPuntoDeTransporte()
		phoenix_changed.emit(true)

# The risen phoenix flickers while untouchable; when that ends, whatever it's still
# touching counts (an overlap that started during the grace sends no new signal)
func _update_phoenix_grace(delta):
	phoenix_grace = max(phoenix_grace - delta, 0.0)
	$HeadSprite.modulate.a = 0.45 + 0.55 * absf(sin(phoenix_grace * 18.0)) if phoenix_grace > 0 else 1.0
	if phoenix_grace <= 0:
		for area in get_overlapping_areas():
			if is_processing():
				_on_area_entered(area)

# Burns every trail piece and rock within the radius (walls, heads and pickups stay)
func _clear_area(point, radius):
	var circle = CircleShape2D.new()
	circle.radius = radius
	var query = PhysicsShapeQueryParameters2D.new()
	query.shape = circle
	query.transform = Transform2D(0, point)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	query.collision_mask = 0b101 # Trails and rocks (1) and the Water twin's trail (4)
	for hit in get_world_2d().direct_space_state.intersect_shape(query, 512):
		var area = hit.collider
		if not is_instance_valid(area) or area.is_queued_for_deletion():
			continue
		if area.is_in_group("limits") or area.is_in_group("activePlayers") or area.is_in_group("twins") or area is Shroom:
			continue
		if area.is_in_group("Fissures"):
			area.get_parent().queue_free()
		else:
			area.queue_free()

const OUTSIDE_ARENA_MARGIN = 30.0

func _outside_arena() -> bool:
	if left_limit_x == null or right_limit_x == null or top_limit_y == null or bottom_limit_y == null:
		return false
	var p = global_position
	return p.x < left_limit_x - OUTSIDE_ARENA_MARGIN or p.x > right_limit_x + OUTSIDE_ARENA_MARGIN 		or p.y < top_limit_y - OUTSIDE_ARENA_MARGIN or p.y > bottom_limit_y + OUTSIDE_ARENA_MARGIN

func _on_own_rock() -> bool:
	for area in get_overlapping_areas():
		if area.is_in_group("Fissures") and is_ancestor_of(area):
			return true
	return false

# Past the arena's border lines, or (with walls) touching a border or a level wall
func _beyond_border(walls = true) -> bool:
	if left_limit_x == null or right_limit_x == null or top_limit_y == null or bottom_limit_y == null:
		return false
	var p = global_position
	if p.x < left_limit_x or p.x > right_limit_x or p.y < top_limit_y or p.y > bottom_limit_y:
		return true
	if walls:
		for area in get_overlapping_areas():
			if area.is_in_group("limits"):
				return true
	return false

func has_border_pass() -> bool:
	return stat_value("earth.border_pass") >= 1.0

func has_stone_walk() -> bool:
	return stat_value("earth.stone_walk") >= 1.0

func has_wall_warp() -> bool:
	return stat_value("air.wall_warp") >= 1.0

func has_hearth() -> bool:
	return stat_value("fire.hearth") >= 1.0

func has_pyre() -> bool:
	return stat_value("fire.pyre") >= 1.0

# A stat of this snake's upgrades; for Void, also of the snakes whose powers it holds with
# their upgrades (Epic): the higher one counts
func stat_value(key: String) -> float:
	var value = stats.get_stat(key) if stats != null else 0.0
	if main_power is VoidPower:
		for power in main_power.instances.values():
			if power.stats_source != null:
				value = max(value, power.stats_source.get_stat(key))
	return value

# Air's jump marker: Air itself, or Void holding Air
func can_teleport() -> bool:
	return playerId == 3 or (main_power is VoidPower and main_power.holds(3))

# The Water power that makes this snake's twins (Water's own, or one Void holds)
func water_power():
	if main_power is WaterPower:
		return main_power
	if main_power is VoidPower and main_power.instances.has(4):
		return main_power.instances[4]
	return null

# Void absorbed a power: Punchi is ready again right away
func reset_cooldown():
	$CooldownTimer.stop()
	if not powerAvailable:
		powerAvailable = true
		update_power_indicator()
		pulse_power_ready()

func set_gap_size():
	gapTimer.set_wait_time(Global.gap_time())
