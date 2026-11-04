extends Node2D
class_name AiTakeover

# 2v2: a human whose snake died can take over its AI teammate for the rest of the round
# by holding its PUNCHI key. A faint ghostly ring around the AI snake fills while it holds.
# Online it only works when both snakes are played on this machine.

const HOLD_TIME = 1.0
const RING_RADIUS = 26.0
const FLASH_TIME = 0.45

var playground
# Dead human snake -> {"hold": seconds held, "armed": released PUNCHI since dying, "mate": AI snake}
var holders = {}
# [snake, color, time left] rings that burst when a takeover completes
var flashes = []
var time = 0.0

func _ready():
	z_index = 20
	var glow = CanvasItemMaterial.new()
	glow.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = glow

func _process(delta):
	time += delta
	_update_holders(delta)
	for flash in flashes:
		flash[2] -= delta
	flashes = flashes.filter(func(flash): return flash[2] > 0 and is_instance_valid(flash[0]))
	queue_redraw()

func _update_holders(delta):
	if playground == null or not playground.teams_mode or playground.gameEnded or not playground.time_flowing:
		holders.clear()
		return
	var still_dead = {}
	for human in get_tree().get_nodes_in_group("activePlayers"):
		if not _can_take_over(human):
			continue
		var mate = _ai_teammate(human)
		if mate == null:
			continue
		still_dead[human] = true
		var state = holders.get(human, {"hold": 0.0, "armed": false})
		state.mate = mate
		var pressed = Input.is_action_pressed("Player%dUp" % human.input_id)
		# Dying with PUNCHI held (using the power) doesn't count: it has to be pressed again
		if not pressed:
			state.armed = true
		if pressed and state.armed:
			state.hold += delta
		else:
			state.hold = max(state.hold - delta * 2.0, 0.0)
		holders[human] = state
		if state.hold >= HOLD_TIME:
			mate.take_control(human.input_id)
			flashes.append([mate, Color(Global.playerColors[human.playerId]), FLASH_TIME])
			still_dead.erase(human)
	for human in holders.keys():
		if not still_dead.has(human):
			holders.erase(human)

# A human snake that died for good this round (not a Phoenix waiting to rise), played here
func _can_take_over(human) -> bool:
	return is_instance_valid(human) and not human.net_remote and human.input_id != 0 \
		and not Global.AI_Enabled.get(human.playerId, false) \
		and not human.is_in_group("alivePlayers") and not human.reviving

func _ai_teammate(human):
	for mate in get_tree().get_nodes_in_group("alivePlayers"):
		if mate != human and mate.ai_enabled and not mate.net_remote \
				and Global.team_of(mate.playerId) == Global.team_of(human.playerId):
			return mate
	return null

func _draw():
	for human in holders:
		var state = holders[human]
		if state.hold <= 0 or not is_instance_valid(state.mate):
			continue
		var t = state.hold / HOLD_TIME
		var color = Color(Global.playerColors[human.playerId]).lightened(0.3)
		var center = state.mate.global_position
		# See-through: a faint wash and thin rings, so the snake and what's ahead stay visible
		var wobble = 1.5 * sin(time * 9.0)
		draw_circle(center, RING_RADIUS + wobble, Color(color, 0.06 + 0.08 * t))
		draw_arc(center, RING_RADIUS + wobble, 0, TAU, 40, Color(color, 0.18), 1.5, true)
		draw_arc(center, RING_RADIUS + wobble, -PI / 2, -PI / 2 + TAU * t, 40, Color(color, 0.6), 3.0, true)
	for flash in flashes:
		var t = 1.0 - flash[2] / FLASH_TIME
		draw_arc(flash[0].global_position, RING_RADIUS * (1.0 + 0.8 * t), 0, TAU, 40, Color(flash[1], 0.7 * (1.0 - t)), 3.0, true)
