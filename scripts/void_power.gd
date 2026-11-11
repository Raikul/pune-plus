class_name VoidPower extends Power

# Void (EXPERIMENTAL, element 5). Punchi opens a wiggly void around the head for a few
# seconds (void.duration, radius void.radius). While it's open the void absorbs powers:
#  - a rival's fireball it touches: Fire (the fireball is swallowed)
#  - a rival's rock (Earth's stone path): Earth
#  - a rival water twin's head: Water
#  - being electrocuted (Static Shock, Storm Fence): Air, and the shock does nothing
#  - a snake that crashes into Void's trail: that snake's power, for the whole round
# Absorbing resets the Punchi cooldown (10 s: Global.VOID_COOLDOWN). An absorbed power
# lasts void.absorb_time seconds (4) and is cast on the next Punchi press, together with every other one held (and the
# void opens again). Powers kept for the round are cast on every press. With Water held,
# its twins copy the other powers too (fireballs, stone armor and path, jumps).
# Upgrades: longer, wider, longer-held absorbs, absorbs with their owner's upgrades (Epic,
# void.keep_upgrades) and absorbs kept for the whole round (Legendary, void.round_absorbs).

const ORDER = [4, 2, 1, 3] # Water first (its twins copy the rest), the jump last
const TWIN_JUMP = 160.0
## Seconds before the same snake's power can be absorbed again (one rock path or twin
## would otherwise be eaten over and over: absorbing recharges Punchi)
const ABSORB_LOCKOUT = 4.0

var field_left = 0.0
var held = {} # element -> {"left": seconds (INF = the whole round), "source": player id}
var instances = {} # element -> its Power, created the first time it's absorbed
var lockouts = {} # "element:source" -> seconds before it can be absorbed again
var field: VoidField

func setup(p: Node2D) -> void:
	super.setup(p)
	field = VoidField.new()
	field.power = self
	player.add_child.call_deferred(field)

func activate() -> void:
	for element in ORDER:
		if held.has(element):
			_cast(element)
			if held.has(element) and held[element].left != INF:
				held.erase(element)
	field_left = stat("void.duration")
	activated.emit()

func field_active() -> bool:
	return field_left > 0.0

func radius() -> float:
	return stat("void.radius")

func holds(element) -> bool:
	return held.has(element)

func _process(delta):
	for key in lockouts.keys():
		lockouts[key] -= delta
		if lockouts[key] <= 0.0:
			lockouts.erase(key)
	for element in held.keys():
		if held[element].left != INF:
			held[element].left -= delta
			if held[element].left <= 0.0:
				held.erase(element)
	if field_left > 0.0:
		field_left = max(field_left - delta, 0.0)
		if not player.net_remote and player.is_in_group("alivePlayers"):
			_scan()

# --- Absorbing ---

# What the open void touches: rivals' fireballs, rocks and twin heads
func _scan():
	var circle = CircleShape2D.new()
	circle.radius = radius()
	var query = PhysicsShapeQueryParameters2D.new()
	query.shape = circle
	query.transform = Transform2D(0, player.global_position)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	query.collision_mask = 0xFFFFFFFF
	for hit in player.get_world_2d().direct_space_state.intersect_shape(query, 64):
		var area = hit.collider
		if not is_instance_valid(area) or area.is_queued_for_deletion():
			continue
		if area.is_in_group("fireballs"):
			var shooter = area.get_parent()
			if shooter != player and not area.expiring and "playerId" in shooter:
				absorb(1, shooter.playerId)
				area.expire(true)
		elif area.is_in_group("Fissures"):
			var earth = Fissure.owner_of(area)
			if earth != null and earth != player:
				absorb(2, earth.playerId)
		elif area.is_in_group("twinHeads"):
			var water = area.get_parent()
			if water != player and "playerId" in water:
				absorb(4, water.playerId)

# Takes `element`'s power from snake `source_id`. whole_round: kept (and cast on every
# press) until the round ends; otherwise for void.absorb_time seconds, one press.
func absorb(element, source_id, whole_round = false):
	if element < 1 or element > 4:
		return
	var lock_key = "%d:%d" % [element, source_id]
	if lockouts.has(lock_key) and not whole_round:
		return
	lockouts[lock_key] = ABSORB_LOCKOUT
	var keep = whole_round or stat("void.round_absorbs") >= 1.0 or (held.has(element) and held[element].left == INF)
	var fresh = not held.has(element) or (keep and held[element].left != INF)
	held[element] = {"left": INF if keep else stat("void.absorb_time"), "source": source_id}
	var power = _instance(element)
	power.stats_source = Global.player_stats.get(source_id) if stat("void.keep_upgrades") >= 1.0 else null
	player.reset_cooldown()
	if fresh:
		var color = Color(Global.playerColors[element])
		PowerFx.pulse(player.get_parent(), player, color)
		PowerFx.explosion(player.get_parent(), player.global_position, color, radius() * 0.6)
		if not player.net_remote:
			Global.add_stat(player.playerId, "void_absorbs")
			if keep:
				Global.add_stat(player.playerId, "void_round_absorbs")
			Global.note_highlight(player.playerId, "absorb", 2.5 if keep else 2.0)

func _instance(element) -> Power:
	if not instances.has(element):
		var power = Powers.create(element)
		add_child(power)
		power.setup(player)
		instances[element] = power
	return instances[element]

# --- Casting what it holds ---

func _cast(element):
	var power = _instance(element)
	if element == 4:
		if power.can_activate():
			power.activate()
		return
	power.activate()
	# The water twins copy it
	for twin in _twins():
		match element:
			1:
				power.shoot_from(twin)
			2:
				power.armor_twin(twin)
			3:
				_twin_jump(twin)

func _twins() -> Array:
	if not instances.has(4):
		return []
	return instances[4].copies.filter(func(twin): return is_instance_valid(twin) and twin.alive)

# A twin's jump: straight ahead, kept inside the arena
func _twin_jump(twin):
	var start = twin.global_position
	var landing = start + Vector2.UP.rotated(twin.rotation) * TWIN_JUMP
	if player.left_limit_x != null:
		var margin = player.TELEPORT_WALL_MARGIN
		landing.x = clamp(landing.x, player.left_limit_x + margin, player.right_limit_x - margin)
		landing.y = clamp(landing.y, player.top_limit_y + margin, player.bottom_limit_y - margin)
	twin.global_position = landing
	twin.armor_time = max(twin.armor_time, 0.15)
	PowerFx.lightning(player.get_parent(), [[start, landing]], Color(Global.playerColors[player.playerId]))

# --- What the held powers do on their own ---

func should_ignore_collision(area: Area2D) -> bool:
	return instances.has(4) and instances[4].should_ignore_collision(area)

# Held twins save it like they save Water; a held Phoenix (with its owner's upgrades) too
func try_prevent_death() -> bool:
	for element in [4, 1]:
		if instances.has(element) and instances[element].try_prevent_death():
			return true
	return false

# Air's free second jump (Second Wind, with the Epic upgrade)
func is_recast_ready() -> bool:
	return instances.has(3) and instances[3].is_recast_ready()

func execute_recast() -> void:
	if instances.has(3):
		instances[3].execute_recast()

# --- AI ---
# Casts what it holds when that power's own AI would; opens the void when something it
# can eat is close (a rival's fireball, rock or twin)
const AI_REACH = 2.0

func ai_should_activate(direction: int) -> bool:
	for element in held:
		var power = _instance(element)
		if element != 4 and power.ai_should_activate(direction):
			return true
	if held.has(4) and instances[4].can_activate():
		return true
	var reach = radius() * AI_REACH
	for fireball in player.get_tree().get_nodes_in_group("fireballs"):
		if fireball.get_parent() != player and not fireball.expiring and fireball.global_position.distance_to(player.global_position) < reach:
			return true
	for twin in player.get_tree().get_nodes_in_group("twinHeads"):
		if twin.get_parent() != player and twin.global_position.distance_to(player.global_position) < reach:
			return true
	for rock in player.get_tree().get_nodes_in_group("Fissures"):
		if rock is Area2D and Fissure.owner_of(rock) != player and rock.global_position.distance_to(player.global_position) < radius():
			return true
	return false
