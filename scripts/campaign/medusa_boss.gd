extends Node2D
class_name MedusaBoss

# The act's boss (CampaignRules, objective "boss"): a sphere drifting slowly around the
# arena that sends out snakes from its head (MedusaHair). It has HAIR snakes in all; the
# players win by outlasting them (every one spawned and gone). Touching the sphere kills
# like a wall. Now and then it stares: a cone telegraphed from its eye; a snake inside it
# that looks at the Medusa (heading towards it) slows down and, after STARE_TO_STONE
# seconds of it, turns to stone for PETRIFY_TIME seconds (frozen, but it can still be hit).
#
# Online the host runs it (drift, snakes, gaze, defeat) and streams its state (boss_state,
# 15 a second; hair_spawned / hair_gone for its snakes). On the other machines it's a
# `puppet` that follows that state. Every machine applies the gaze to its own snakes only.

const RADIUS = 46.0
const SPEED = 38.0
const HAIR_BASE = 14
const HAIR_PER_PLAYER = 5
const SPAWN_EVERY = 2.0
const ALIVE_BASE = 3
const GAZE_COOLDOWN = Vector2(6.0, 9.0)
const GAZE_CHARGE = 1.0
const GAZE_TIME = 2.6
const GAZE_REACH = 700.0
const GAZE_HALF_ANGLE = 0.49 # 28 degrees
const FACING = 0.2
const STARE_TO_STONE = 1.3
const SLOWEST = 0.3
const PETRIFY_TIME = 2.5
const BODY_COLOR = Color(0.28, 0.55, 0.42)
const GAZE_COLOR = Color(0.95, 0.9, 0.35)

var rules
var active = false
## Online, not the host: it only shows what the host's Medusa does
var puppet = false
const SEND_INTERVAL = 1.0 / 15.0
var send_timer = 0.0
var net_position = Vector2.ZERO
var hairs = {} # Puppet: hair name -> MedusaHair
var stopped = false
var hair_total = HAIR_BASE
var spawned = 0
var alive_hair = 0
var spawn_timer = 1.0
var target = Vector2.ZERO
var time = 0.0
var defeated = false
var arena: Rect2
# Gaze: "idle", "charging", "staring"
var gaze_state = "idle"
var gaze_timer = 4.0
var gaze_dir = Vector2.DOWN
var stares = {} # snake -> seconds stared
var petrified = {} # snake -> seconds of stone left
var body: Area2D

func _ready():
	add_to_group("medusa")
	z_index = 14
	hair_total = HAIR_BASE + HAIR_PER_PLAYER * max(Campaign.human_elements().size() - 1, 0)
	arena = rules.pg._arena_rect()
	target = arena.get_center()
	net_position = global_position
	body = Area2D.new()
	body.add_to_group("limits") # Deadly like a wall; fireballs crash on it
	body.add_to_group("medusa_body")
	body.collision_layer = 1
	body.collision_mask = 0
	var shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = RADIUS
	shape.shape = circle
	body.add_child(shape)
	add_child(body)

func hair_remaining() -> int:
	return hair_total - spawned + alive_hair

# The round is over: everything holds still
func stop():
	stopped = true
	active = false
	for snake in petrified.keys():
		if is_instance_valid(snake):
			snake.modulate = Color.WHITE

func _process(delta):
	time += delta
	queue_redraw()
	if stopped or defeated:
		return
	active = rules.pg.time_flowing
	if not active:
		return
	if puppet:
		if net_position == Vector2.ZERO:
			net_position = global_position
		global_position = global_position.lerp(net_position, clampf(delta * 10.0, 0.0, 1.0))
		if gaze_state == "staring":
			_stare(delta)
		else:
			_relax(delta)
		_update_stone(delta)
		return
	_drift(delta)
	_spawn_hair(delta)
	_gaze(delta)
	_update_stone(delta)
	_send_state(delta)
	if spawned >= hair_total and alive_hair <= 0:
		_defeat()

func _online() -> bool:
	return rules._online()

# --- Online ---

func _send_state(delta):
	if not _online():
		return
	send_timer -= delta
	if send_timer > 0:
		return
	send_timer = SEND_INTERVAL
	var states = []
	for hair in rules.pg.get_tree().get_nodes_in_group("medusa_hair"):
		if not hair.dead:
			states.append([str(hair.name), hair.global_position, hair.heading])
	boss_state.rpc(global_position, gaze_state, gaze_dir, spawned, alive_hair, states)

@rpc("authority", "call_remote", "unreliable_ordered")
func boss_state(at, state, direction, new_spawned, new_alive, hair_states):
	if not puppet:
		return
	net_position = at
	gaze_state = state
	gaze_dir = direction
	spawned = new_spawned
	alive_hair = new_alive
	for entry in hair_states:
		var hair = hairs.get(entry[0])
		if is_instance_valid(hair):
			hair.net_position = entry[1]
			hair.heading = entry[2]

@rpc("authority", "call_remote", "reliable")
func hair_spawned(hair_name, at, heading, length):
	if not puppet:
		return
	var hair = MedusaHair.new()
	hair.name = hair_name
	hair.puppet = true
	hair.medusa = self
	hair.arena = arena
	hair.length = length
	hair.heading = heading
	hair.net_position = at
	rules.pg.add_child(hair)
	hair.global_position = at
	hairs[hair_name] = hair
	PowerFx.burst(rules.pg, at, MedusaHair.COLOR)

@rpc("authority", "call_remote", "reliable")
func hair_gone(hair_name, crashed):
	var hair = hairs.get(hair_name)
	hairs.erase(hair_name)
	if is_instance_valid(hair):
		hair.die(crashed)

# A slow drift between random spots, away from the walls
func _drift(delta):
	if global_position.distance_to(target) < 20.0:
		var inner = arena.grow(-RADIUS - 180.0)
		target = Vector2(randf_range(inner.position.x, inner.end.x), randf_range(inner.position.y, inner.end.y))
	global_position = global_position.move_toward(target, SPEED * delta)

func _spawn_hair(delta):
	spawn_timer -= delta
	var limit = ALIVE_BASE + Campaign.human_elements().size()
	if spawn_timer > 0 or spawned >= hair_total or alive_hair >= limit:
		return
	spawn_timer = SPAWN_EVERY
	var aim = Vector2.UP.rotated(randf() * TAU)
	var prey = _nearest_snake()
	if prey != null:
		aim = (prey.global_position - global_position).normalized().rotated(randf_range(-0.8, 0.8))
	var hair = MedusaHair.new()
	hair.name = "MedusaHair%d" % spawned
	hair.medusa = self
	hair.arena = arena
	hair.length = randf_range(120.0, 360.0)
	hair.heading = Vector2.UP.angle_to(aim)
	hair.global_position = global_position + aim * (RADIUS + 14.0)
	var hair_name = str(hair.name)
	hair.died.connect(func(crashed):
		alive_hair -= 1
		if _online():
			hair_gone.rpc(hair_name, crashed))
	rules.pg.add_child(hair)
	if _online():
		hair_spawned.rpc(str(hair.name), hair.global_position, hair.heading, hair.length)
	spawned += 1
	alive_hair += 1
	PowerFx.burst(rules.pg, hair.global_position, MedusaHair.COLOR)

func _nearest_snake():
	var best = null
	var best_distance = INF
	for snake in get_tree().get_nodes_in_group("alivePlayers"):
		var distance = snake.global_position.distance_to(global_position)
		if distance < best_distance:
			best_distance = distance
			best = snake
	return best

# --- The gaze ---

func _gaze(delta):
	gaze_timer -= delta
	match gaze_state:
		"idle":
			if gaze_timer <= 0:
				var prey = _nearest_snake()
				if prey == null:
					gaze_timer = 1.0
					return
				gaze_dir = (prey.global_position - global_position).normalized()
				gaze_state = "charging"
				gaze_timer = GAZE_CHARGE
		"charging":
			if gaze_timer <= 0:
				gaze_state = "staring"
				gaze_timer = GAZE_TIME
		"staring":
			_stare(delta)
			if gaze_timer <= 0:
				gaze_state = "idle"
				gaze_timer = randf_range(GAZE_COOLDOWN.x, GAZE_COOLDOWN.y)
	if gaze_state != "staring":
		_relax(delta)

func in_gaze(snake) -> bool:
	var offset = snake.global_position - global_position
	if offset.length() > GAZE_REACH or absf(gaze_dir.angle_to(offset)) > GAZE_HALF_ANGLE:
		return false
	# Only a snake looking at the Medusa
	var forward = Vector2.UP.rotated(snake.rotation)
	return forward.dot(-offset.normalized()) > FACING

# Only this machine's snakes (online each machine minds its own)
func _stare(delta):
	for snake in get_tree().get_nodes_in_group("alivePlayers"):
		if petrified.has(snake) or snake.reviving or snake.net_remote:
			continue
		if in_gaze(snake):
			stares[snake] = stares.get(snake, 0.0) + delta
			if stares[snake] >= STARE_TO_STONE:
				_petrify(snake)
			else:
				_slow(snake)
		elif stares.has(snake):
			_ease(snake, delta)

func _relax(delta):
	for snake in stares.keys():
		_ease(snake, delta)

# Out of the gaze: the slowness wears off
func _ease(snake, delta):
	if not is_instance_valid(snake):
		stares.erase(snake)
		return
	stares[snake] -= delta * 2.0
	if stares[snake] <= 0:
		stares.erase(snake)
		snake.refresh_stats()
	else:
		_slow(snake)

func _slow(snake):
	var base = snake.stats.get_stat("speed") if snake.stats != null else snake.speed
	snake.speed = base * lerpf(1.0, SLOWEST, clampf(stares.get(snake, 0.0) / STARE_TO_STONE, 0.0, 1.0))

func _petrify(snake):
	stares.erase(snake)
	petrified[snake] = PETRIFY_TIME
	snake.cancel_hold()
	snake.set_frozen(true)
	snake.modulate = Color(0.55, 0.55, 0.5)
	PowerFx.burst(rules.pg, snake.global_position, Color(0.7, 0.7, 0.65))

func _update_stone(delta):
	for snake in petrified.keys():
		if not is_instance_valid(snake):
			petrified.erase(snake)
			continue
		petrified[snake] -= delta
		if petrified[snake] <= 0:
			petrified.erase(snake)
			snake.modulate = Color.WHITE
			snake.refresh_stats()
			if snake.is_in_group("alivePlayers") and rules.pg.time_flowing:
				snake.set_frozen(false)

# --- Beaten ---

func _defeat():
	defeated = true
	for snake in petrified.keys():
		if is_instance_valid(snake):
			snake.modulate = Color.WHITE
			if snake.is_in_group("alivePlayers"):
				snake.set_frozen(false)
	petrified.clear()
	body.set_deferred("monitorable", false)
	PowerFx.explosion(rules.pg, global_position, BODY_COLOR, RADIUS * 3.0)
	var tween = create_tween().set_parallel()
	tween.tween_property(self, "scale", Vector2.ONE * 0.2, 0.8)
	tween.tween_property(self, "modulate:a", 0.0, 0.8)
	rules.boss_defeated()

# --- Look: a sphere with an eye looking where it stares, and hair while it has some ---

func _draw():
	# The gaze cone
	if gaze_state != "idle" and not stopped:
		var alpha = 0.12 + 0.1 * sin(time * 18.0) if gaze_state == "staring" else 0.06 * (1.0 - gaze_timer / GAZE_CHARGE)
		var points = PackedVector2Array([Vector2.ZERO])
		for i in 9:
			points.append(gaze_dir.rotated(lerpf(-GAZE_HALF_ANGLE, GAZE_HALF_ANGLE, i / 8.0)) * GAZE_REACH)
		draw_colored_polygon(points, Color(GAZE_COLOR, max(alpha, 0.03)))
		var edge = Color(GAZE_COLOR, 0.8 if gaze_state == "staring" else 0.4)
		draw_line(Vector2.ZERO, points[1], edge, 2.0, true)
		draw_line(Vector2.ZERO, points[points.size() - 1], edge, 2.0, true)
	# Hair still to come: writhing strands around the top
	var strands = mini(hair_total - spawned, 12)
	for i in strands:
		var angle = -PI / 2 + lerpf(-1.3, 1.3, (i + 0.5) / 12.0)
		var root = Vector2.from_angle(angle) * RADIUS * 0.9
		var points = PackedVector2Array()
		for k in 6:
			var reach = RADIUS * 0.9 + k * 7.0
			var sway = sin(time * 4.0 + i + k * 0.7) * k * 1.6
			points.append(Vector2.from_angle(angle) * reach + Vector2.from_angle(angle + PI / 2) * sway)
		draw_polyline(points, MedusaHair.COLOR.darkened(0.15), 4.0, true)
		draw_circle(points[points.size() - 1], 3.5, MedusaHair.COLOR, true, -1.0, true)
	# The sphere, lit from the top left
	draw_circle(Vector2.ZERO, RADIUS + 3.0, BODY_COLOR.darkened(0.55), true, -1.0, true)
	draw_circle(Vector2.ZERO, RADIUS, BODY_COLOR, true, -1.0, true)
	draw_circle(Vector2(-12, -14), RADIUS * 0.55, BODY_COLOR.lightened(0.18), true, -1.0, true)
	draw_circle(Vector2(-18, -20), RADIUS * 0.18, BODY_COLOR.lightened(0.5), true, -1.0, true)
	# The eye
	var look = gaze_dir if gaze_state != "idle" else Vector2.from_angle(time * 0.7)
	var glowing = gaze_state != "idle" and not stopped
	var eye = look * 12.0
	draw_circle(eye, 15.0, Color(1, 1, 0.85) if not glowing else GAZE_COLOR.lightened(0.3), true, -1.0, true)
	draw_set_transform(eye + look * 4.0, look.angle(), Vector2(0.35, 1.0))
	draw_circle(Vector2.ZERO, 9.0, Color(0.1, 0.05, 0.05), true, -1.0, true)
	draw_set_transform(Vector2.ZERO)
