extends Node
class_name CampaignRules

# The Playground's rules while a campaign scenario is played (Campaign.playing). The
# Playground asks it whether the round is over and hands it the end of every round; it
# counts the objective, decides when the scenario is won or lost (then back to the
# campaign screen), shows the objective on screen, and runs the scenario's extras: the
# shrooms, the power shrooms and the Medusa (the boss).
#
# Online the host decides (the Playground's deaths and rounds already only happen there):
# it counts, ends rounds and the scenario, spawns the shrooms and runs the Medusa, and
# tells the other machines (the RPCs below; this node has the same path everywhere). A
# shroom is eaten on the machine of the snake that ate it, which tells the others.

const POWER_SHROOM_EVERY = 7.0
const POWER_SHROOMS_MAX = 2
## Seconds the result banner stays before the campaign screen
const RESULT_TIME = 3.0

var pg
var scenario = {}
var objective = ""
var rounds_played = 0
var wins = 0
var kills = 0
var shrooms = 0
var survive_time = 0.0
var ended = false
var boss: MedusaBoss
var boss_beaten = false
var power_shroom_timer = 3.0
var shroom_serial = 0

var hud_layer: CanvasLayer
var hud_label: Label

func setup(playground) -> void:
	pg = playground
	scenario = Campaign.scenario
	objective = scenario.get("objective", "rounds")
	_give_upgrades()
	_build_hud()
	# The scoreboard's "points to win" means nothing here
	var centerfold = pg.get_node_or_null("HUD/Centerfold")
	if centerfold:
		centerfold.hide()
	var hud = pg.get_node_or_null("HUD")
	if hud and hud.get("target_label") != null:
		hud.target_label.hide()

# Offline, or the host online
# The AI goes for the shrooms (Player._ai_seek_shroom) where eating them is the goal
func ai_seeks_shrooms() -> bool:
	return objective == "shrooms"

func _authority() -> bool:
	return pg.net_session == null or multiplayer.is_server()

func _online() -> bool:
	return pg.net_session != null and SteamNet.is_online()

# The players' campaign upgrades (a swapped element and the rivals: the scenario's random
# ones, Campaign.scenario_upgrades)
func _give_upgrades() -> void:
	for element in Campaign.human_elements() + Campaign.enemies:
		var ids = Campaign.upgrades_for(element) if Campaign.is_human(element) else Campaign.scenario_upgrades.get(element, [])
		for upgrade_id in ids:
			var buff = UpgradeCatalog.make_buff(StringName(upgrade_id))
			if buff != null:
				Global.player_stats[element].add_buff(buff)

# --- What the Playground asks ---

# Under the first countdown: the scenario and its goal
func quest_text() -> String:
	return tr("CAMPAIGN_SC_" + str(scenario.id).to_upper()) + "\n" + _goal_text()

func _goal_text() -> String:
	match objective:
		"rounds":
			return tr("CAMPAIGN_GOAL_ROUNDS") % [scenario.need, scenario.rounds]
		"survive":
			return tr("CAMPAIGN_GOAL_SURVIVE") % [scenario.target, scenario.need, scenario.rounds]
		"shrooms":
			return tr("CAMPAIGN_GOAL_SHROOMS") % [scenario.target, scenario.rounds]
		"kills":
			return tr("CAMPAIGN_GOAL_KILLS") % [scenario.target, scenario.rounds]
		"boss":
			return tr("CAMPAIGN_GOAL_BOSS")
	return ""

# A new round is about to start (Playground.setupPlayers, on every machine)
func round_starting() -> void:
	survive_time = 0.0
	boss_beaten = false
	if objective == "boss":
		if is_instance_valid(boss):
			boss.name = "OldMedusa"
			boss.queue_free()
		boss = MedusaBoss.new()
		boss.name = "Medusa" # The same path on every machine (its RPCs)
		boss.rules = self
		boss.puppet = not _authority()
		pg.add_child(boss)
		boss.global_position = pg._arena_rect().get_center()
	_refresh_hud()

func _humans_alive() -> int:
	return pg.get_tree().get_nodes_in_group("alivePlayers").filter(func(p): return Campaign.is_human(p.playerId)).size()

func _enemies_alive() -> int:
	return pg.get_tree().get_nodes_in_group("alivePlayers").filter(func(p): return not Campaign.is_human(p.playerId)).size()

func round_is_over() -> bool:
	if _humans_alive() == 0:
		return true
	match objective:
		"boss":
			return boss_beaten
		"survive":
			return _enemies_alive() == 0 or survive_time >= scenario.target
		"kills":
			return _enemies_alive() == 0 or kills >= scenario.target
		"shrooms":
			return _enemies_alive() == 0 or shrooms >= scenario.target
	return _enemies_alive() == 0

# A snake died (Playground.playerDead: offline, or the host)
func on_snake_dead(player) -> void:
	if not Campaign.is_human(player.playerId):
		kills += 1
	_share_state()

# A snake of this machine ate a shroom (Playground.shroom_eaten)
func shroom_eaten(element, shroom_name = "") -> void:
	if _online():
		shroom_taken.rpc(element, str(shroom_name))
	_count_shroom(element)

# Online: another machine's snake ate this shroom (it's gone there; here too)
@rpc("any_peer", "call_remote", "reliable")
func shroom_taken(element, shroom_name):
	var shroom = pg.get_node_or_null("Events/" + shroom_name)
	if shroom:
		shroom.queue_free()
	_count_shroom(element)

func _count_shroom(element) -> void:
	if not _authority() or not Campaign.is_human(element):
		return
	shrooms += 1
	_share_state()
	if objective == "shrooms" and shrooms >= scenario.target:
		_end_round_now()

func boss_defeated() -> void:
	boss_beaten = true
	_end_round_now()

# Something besides a death ended the round (time survived, the goal reached)
func _end_round_now() -> void:
	if not _authority() or not pg.time_flowing or pg.gameEnded or ended:
		return
	if pg.net_session:
		pg.net_session.host_round_over()
	pg.restart()

func _process(delta):
	if pg == null or not pg.time_flowing or ended:
		return
	if objective == "survive":
		survive_time += delta
		if survive_time >= scenario.target:
			_end_round_now()
		_refresh_hud()
	if scenario.get("power_shrooms", false) and _authority():
		power_shroom_timer -= delta
		if power_shroom_timer <= 0:
			power_shroom_timer = POWER_SHROOM_EVERY
			_spawn_power_shroom()

# --- Shrooms ---

func _spawn_power_shroom() -> void:
	if pg.get_tree().get_nodes_in_group("power_shrooms").size() >= POWER_SHROOMS_MAX:
		return
	var point = pg.get_node("Events")._shroom_point()
	if point == null:
		return
	place_shroom(point, true)

# A shroom on the arena (also the plain ones, Events); online the host's, shown everywhere
func place_shroom(point: Vector2, power: bool) -> Node2D:
	shroom_serial += 1
	var shroom_name = "CampaignShroom%d" % shroom_serial
	if _online():
		shared_shroom.rpc(shroom_name, point, power)
	return _add_shroom(shroom_name, point, power)

@rpc("authority", "call_remote", "reliable")
func shared_shroom(shroom_name, point, power):
	_add_shroom(shroom_name, point, power)

func _add_shroom(shroom_name, point, power) -> Node2D:
	var shroom = PowerShroom.create() if power else pg.get_node("Events").shroomScene.instantiate()
	shroom.name = shroom_name
	shroom.set_as_top_level(true)
	shroom.add_to_group("Shrooms")
	pg.get_node("Events").add_child(shroom)
	shroom.global_position = point
	return shroom

# --- The end of a round (Playground.restart): next round, or the scenario is decided ---

func round_ended(delay) -> void:
	if ended:
		return
	if is_instance_valid(boss):
		boss.stop()
	# Online the host decides and tells the others (sync_state, scenario_end, start_round)
	if not _authority():
		return
	rounds_played += 1
	var won_round = _humans_alive() > 0
	if objective == "boss":
		won_round = won_round and boss_beaten
	if won_round and objective in ["rounds", "survive", "boss"]:
		wins += 1
	_share_state()
	var verdict = _verdict()
	if verdict != "":
		if _online():
			scenario_end.rpc(verdict == "won")
		else:
			_end_scenario(verdict == "won")
		return
	await pg.get_tree().create_timer(delay).timeout
	if not pg.is_inside_tree():
		return
	if pg.net_session:
		pg.net_session.host_start_round()
		return
	pg.clear_round()
	pg.use_level(Campaign.level_path())
	pg.call_deferred("setupPlayers")

# "won", "lost", or "" (more rounds to go)
func _verdict() -> String:
	var rounds = int(scenario.get("rounds", 1))
	match objective:
		"kills":
			if kills >= scenario.target:
				return "won"
			return "lost" if rounds_played >= rounds else ""
		"shrooms":
			if shrooms >= scenario.target:
				return "won"
			return "lost" if rounds_played >= rounds else ""
	var need = int(scenario.get("need", 1))
	if wins >= need:
		return "won"
	# Not enough rounds left to make it
	if wins + (rounds - rounds_played) < need:
		return "lost"
	return ""

@rpc("authority", "call_local", "reliable")
func scenario_end(won):
	_end_scenario(won)

func _end_scenario(won: bool) -> void:
	if ended:
		return
	ended = true
	pg.stopTime()
	if is_instance_valid(boss):
		boss.stop()
	var banner = Label.new()
	banner.text = tr("CAMPAIGN_SCENARIO_WON") if won else tr("CAMPAIGN_SCENARIO_LOST")
	banner.add_theme_font_override("font", preload("res://assets/jorge-resources/Game Selection/Odin Rounded - Bold.otf"))
	banner.add_theme_font_size_override("font_size", 110)
	banner.add_theme_color_override("font_color", Color(1, 0.85, 0.35) if won else Color(1, 0.4, 0.35))
	banner.add_theme_constant_override("outline_size", 22)
	banner.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	banner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.modulate.a = 0.0
	hud_layer.add_child(banner)
	banner.create_tween().tween_property(banner, "modulate:a", 1.0, 0.4)
	await pg.get_tree().create_timer(RESULT_TIME, false).timeout
	if not pg.is_inside_tree():
		return
	Campaign.finish_scenario(won)

# --- The counts, for every machine's display ---

func _share_state() -> void:
	_refresh_hud()
	if _online() and multiplayer.is_server():
		sync_state.rpc(rounds_played, wins, kills, shrooms)

@rpc("authority", "call_remote", "reliable")
func sync_state(new_rounds, new_wins, new_kills, new_shrooms):
	rounds_played = new_rounds
	wins = new_wins
	kills = new_kills
	shrooms = new_shrooms
	_refresh_hud()

# --- On screen: the scenario, its goal so far, the round and the lives ---

func _build_hud() -> void:
	hud_layer = CanvasLayer.new()
	hud_layer.layer = 4
	add_child(hud_layer)
	hud_label = Label.new()
	hud_label.add_theme_font_override("font", preload("res://assets/jorge-resources/Game Selection/Odin Rounded - Bold.otf"))
	hud_label.add_theme_font_size_override("font_size", 26)
	hud_label.add_theme_color_override("font_color", Color(1, 0.92, 0.7))
	hud_label.add_theme_constant_override("outline_size", 8)
	hud_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	hud_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud_label.anchor_right = 1.0
	hud_label.offset_top = 142
	hud_label.offset_bottom = 180
	hud_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_layer.add_child(hud_label)
	_refresh_hud()

func _refresh_hud() -> void:
	if hud_label == null:
		return
	var parts = [tr("CAMPAIGN_SC_" + str(scenario.id).to_upper())]
	match objective:
		"rounds":
			parts.append(tr("CAMPAIGN_HUD_WINS") % [wins, scenario.need])
		"survive":
			parts.append(tr("CAMPAIGN_HUD_SURVIVE") % [maxi(ceili(scenario.target - survive_time), 0)])
			parts.append(tr("CAMPAIGN_HUD_WINS") % [wins, scenario.need])
		"shrooms":
			parts.append(tr("CAMPAIGN_HUD_SHROOMS") % [shrooms, scenario.target])
		"kills":
			parts.append(tr("CAMPAIGN_HUD_KILLS") % [kills, scenario.target])
		"boss":
			if is_instance_valid(boss):
				parts.append(tr("CAMPAIGN_HUD_HAIR") % boss.hair_remaining())
	if objective != "boss":
		parts.append(tr("CAMPAIGN_HUD_ROUND") % [mini(rounds_played + 1, int(scenario.rounds)), scenario.rounds])
	parts.append(tr("CAMPAIGN_HUD_LIVES") % Campaign.data.get("lives", 0))
	hud_label.text = "  ·  ".join(parts)
