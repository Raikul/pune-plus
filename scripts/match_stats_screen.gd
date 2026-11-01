extends Control
class_name MatchStatsScreen

# End of the match, after the win screen: one column per snake with what it did
# (Global.match_stats) and its choice for what's next, REMATCH or QUIT. Each player picks
# with their own Left/Right (or the mouse); AI snakes always want a rematch. Holding
# PUNCHI for 2 s confirms: everyone on REMATCH plays again, anything else goes back to
# the lobby (Playground decides; online the host waits for every machine).

signal choice_changed(player_id, rematch)
signal confirmed(choices) # {player_id: rematch}

const ODIN = preload("res://assets/jorge-resources/Game Selection/Odin Rounded - Bold.otf")
const HOLD_TIME = 2.0
const ELEMENT_NAMES = ["", "FIRE", "EARTH", "AIR", "WATER"]
const GENERIC_STATS = [["length", "Trail length"], ["dead_time", "Time dead"], ["powers", "Powers used"]]
const ELEMENT_STATS = {
	1: [["fire_kills", "Fireball kills"]],
	2: [["earth_blocked", "Fireballs & twins blocked"]],
	3: [["air_warps", "Warps through the edge"], ["air_shocks", "Enemies electrocuted"], ["air_scramble_kills", "Kills on scrambled foes"]],
	4: [["water_twins", "Twins summoned"], ["water_saves", "Lives saved by a twin"]],
}
## Shown only when it happened at all (Air without Wall Warp never warps)
const HIDE_WHEN_ZERO = ["air_warps"]
const GOLD = Color(1.0, 0.82, 0.3)
const DIM = Color(0.75, 0.75, 0.8)
const PIXELS_PER_METER = 10.0

var ids = []
var info = {} # player_id -> {"name", "input_id" (0 = can't choose here), "ai"}
var choices = {}
var columns = {} # player_id -> {"values": {stat: Label}, "rematch": Button, "quit": Button}
var hold_ring: HoldRing
var hint: Label
var waiting = false

# ids: snakes in column order; winners: their columns get the crown; totals: summed stats
func setup(column_ids: Array, winners: Array, totals: Dictionary, player_info: Dictionary):
	ids = column_ids
	info = player_info
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var backdrop = ColorRect.new()
	backdrop.color = Color(0.06, 0.05, 0.09, 0.94)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)

	var layout = VBoxContainer.new()
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layout.offset_left = 60
	layout.offset_right = -60
	layout.offset_top = 50
	layout.offset_bottom = -40
	layout.add_theme_constant_override("separation", 30)
	add_child(layout)
	layout.add_child(_label("MATCH STATS", 64, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER))

	var row = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 28)
	layout.add_child(row)
	for id in ids:
		choices[id] = true
		row.add_child(_column(id, winners.has(id)))

	var footer = HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	footer.add_theme_constant_override("separation", 16)
	layout.add_child(footer)
	hold_ring = HoldRing.new()
	hold_ring.hold_time = HOLD_TIME
	hold_ring.fill_color = GOLD
	footer.add_child(hold_ring)
	hint = _label("", 28, Color.WHITE)
	footer.add_child(hint)
	_refresh_hint()
	set_totals(totals)
	for id in ids:
		_show_choice(id)

func _column(id, winner):
	var color = Color(Global.playerColors[id])
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(400, 0)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(color.darkened(0.82), 0.95)
	style.border_color = color if not winner else GOLD
	style.set_border_width_all(6 if winner else 3)
	style.set_corner_radius_all(22)
	style.set_content_margin_all(26)
	panel.add_theme_stylebox_override("panel", style)
	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)

	box.add_child(_label("WINNER" if winner else " ", 26, GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(_label(ELEMENT_NAMES[id], 52, color, HORIZONTAL_ALIGNMENT_CENTER))
	var name_label = _label(info[id].name, 26, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	box.add_child(name_label)
	if Global.teams_enabled():
		var team = Global.team_of(id)
		box.add_child(_label(Global.TEAM_NAMES[team], 22, Global.TEAM_COLORS[team], HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(_label(str(Global.get("player%dScore" % id)), 84, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(_separator(color))

	var values = {}
	for stat in GENERIC_STATS + [null] + ELEMENT_STATS.get(id, []):
		if stat == null:
			box.add_child(_separator(color))
			continue
		var line = HBoxContainer.new()
		line.add_child(_label(stat[1], 24, DIM))
		var spacer = Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(spacer)
		var value = _label("0", 28, Color.WHITE)
		line.add_child(value)
		box.add_child(line)
		values[stat[0]] = value

	var filler = Control.new()
	filler.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(filler)
	var pick = HBoxContainer.new()
	pick.add_theme_constant_override("separation", 12)
	box.add_child(pick)
	var rematch = _choice_button("REMATCH", id, true)
	var quit = _choice_button("QUIT", id, false)
	pick.add_child(rematch)
	pick.add_child(quit)
	var how = "AI: always up for more" if info[id].ai else ("Left / Right to choose" if _can_choose(id) else "Choosing on their machine")
	box.add_child(_label(how, 20, DIM, HORIZONTAL_ALIGNMENT_CENTER))
	columns[id] = {"values": values, "rematch": rematch, "quit": quit, "color": color}
	return panel

func _choice_button(text, id, rematch):
	var button = Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size.y = 58
	button.add_theme_font_override("font", ODIN)
	button.add_theme_font_size_override("font_size", 26)
	button.pressed.connect(func(): _choose(id, rematch))
	return button

func _can_choose(id) -> bool:
	return not waiting and not info[id].ai and info[id].input_id != 0

func _choose(id, rematch):
	if not _can_choose(id) or choices[id] == rematch:
		return
	choices[id] = rematch
	_show_choice(id)
	choice_changed.emit(id, rematch)

# Online: another machine's player changed their pick
func set_choice(id, rematch):
	if choices.has(id):
		choices[id] = rematch
		_show_choice(id)

func _show_choice(id):
	var column = columns[id]
	for button in [column.rematch, column.quit]:
		var selected = (button == column.rematch) == choices[id]
		var style = StyleBoxFlat.new()
		style.set_corner_radius_all(16)
		style.bg_color = column.color if selected else Color(0, 0, 0, 0.35)
		style.border_color = column.color
		style.set_border_width_all(0 if selected else 2)
		for state in ["normal", "hover", "pressed", "disabled"]:
			button.add_theme_stylebox_override(state, style)
		var text_color = Color.BLACK if selected else Color(1, 1, 1, 0.6)
		for state in ["font_color", "font_hover_color", "font_pressed_color", "font_disabled_color"]:
			button.add_theme_color_override(state, text_color)
		button.disabled = not _can_choose(id)

func set_totals(totals: Dictionary):
	var best = {}
	for stat in ["length", "powers"]:
		best[stat] = 0
		for id in ids:
			best[stat] = max(best[stat], totals.get(id, {}).get(stat, 0))
	for id in ids:
		var stats = totals.get(id, {})
		for stat in columns[id].values:
			var label = columns[id].values[stat]
			var amount = stats.get(stat, 0)
			label.text = _format(stat, amount)
			label.get_parent().visible = not (HIDE_WHEN_ZERO.has(stat) and amount == 0)
			# The most of it in the match, if more than one snake is on screen
			var leader = best.has(stat) and amount > 0 and amount == best[stat] and ids.size() > 1
			label.add_theme_color_override("font_color", GOLD if leader else Color.WHITE)

func _format(stat, amount) -> String:
	match stat:
		"length":
			return "%d m" % roundi(amount / PIXELS_PER_METER)
		"dead_time":
			if amount >= 60:
				return "%d:%02d" % [int(amount) / 60, int(amount) % 60]
			return "%.1f s" % amount
	return str(int(amount))

# Online: this machine confirmed, the host waits for the others
func show_waiting():
	waiting = true
	for id in ids:
		_show_choice(id)
	_refresh_hint()

func _refresh_hint():
	if waiting:
		hint.text = "WAITING FOR THE OTHER PLAYERS..."
		hold_ring.hide()
	else:
		hint.text = "HOLD PUNCHI TO CONTINUE"

func _input(event):
	if waiting:
		return
	for id in ids:
		var keys = info[id].input_id
		if keys == 0:
			continue
		if event.is_action_pressed("Player%dLeft" % keys):
			_choose(id, true)
		elif event.is_action_pressed("Player%dRight" % keys):
			_choose(id, false)

func _process(delta):
	if waiting:
		return
	if hold_ring.advance(delta, HoldRing.punchi_pressed()):
		set_process(false)
		confirmed.emit(choices.duplicate())

func _label(text, font_size, color, align = HORIZONTAL_ALIGNMENT_LEFT):
	var label = Label.new()
	label.text = text
	label.horizontal_alignment = align
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", ODIN)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

func _separator(color):
	var line = ColorRect.new()
	line.color = Color(color, 0.35)
	line.custom_minimum_size = Vector2(0, 2)
	return line
