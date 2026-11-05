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
# Each element's symbol, as on the scoreboard (tinted with the snake's color)
const SYMBOLS_PATH = "res://assets/jorge-resources/Game Selection/"
const SYMBOLS = ["", "Fire-Water symbol.png", "Air-Earth symbol rot.png", "Air-Earth symbol.png", "Fire-Water symbol rot.png"]
## [stat, its name in English]; shown translated by the key STAT_<STAT> (translations/strings.csv)
const GENERIC_STATS = [["kills", "Kills"], ["length", "Trail length"], ["dead_time", "Time dead"], ["powers", "Powers used"]]
const ELEMENT_STATS = {
	1: [["fire_kills", "Fireball kills"], ["fire_revives", "Times revived"]],
	2: [["earth_blocked", "Fireballs & twins blocked"], ["earth_own_trail", "Own trail crossed"]],
	3: [["air_warps", "Warps through the edge"], ["air_shocks", "Enemies electrocuted"], ["air_scramble_kills", "Kills on scrambled foes"]],
	4: [["water_twins", "Twins summoned"], ["water_saves", "Lives saved by a twin"]],
}
## Shown only when it happened at all (Air without Wall Warp never warps)
const HIDE_WHEN_ZERO = ["air_warps"]
## Awards: [title, stat, "max" or "min", what it's for]. Shown translated by the keys
## AWARD_<TITLE> and AWARD_<TITLE>_DESC (spaces as underscores: AWARD_FIRST_OUT). A snake gets it for the most (or
## least) of the stat in the match; ties share it; nobody gets it if everyone is level, or
## if the most is zero. A column shows its first MAX_AWARDS.
const AWARDS = [
	["HUNTER", "kills", "max", "Most kills"],
	["SURVIVOR", "round_wins", "max", "Most rounds survived to the end"],
	["LONGEST TRAIL", "length", "max", "Longest trail in the match"],
	["UNTOUCHABLE", "dead_time", "min", "Least time dead"],
	["MARATHON", "best_life", "max", "Longest single life"],
	["POWER HUNGRY", "powers", "max", "Most powers used"],
	["GHOST", "dead_time", "max", "Most time dead"],
	["FIRST OUT", "first_out", "max", "First to crash, most often"],
]
const MAX_AWARDS = 3
const AWARD_INK = Color(0.16, 0.1, 0.02)
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
	layout.add_child(_label(tr("STATS_TITLE"), 64, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER))

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
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)

	box.add_child(_label(tr("STATS_WINNER") if winner else " ", 26, GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	var symbol = TextureRect.new()
	symbol.texture = load(SYMBOLS_PATH + SYMBOLS[id])
	symbol.modulate = color
	symbol.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	symbol.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	symbol.custom_minimum_size = Vector2(0, 72)
	box.add_child(symbol)
	# Laurels in the corners and dragons around the symbol (scripts/winner_flair.gd)
	if winner:
		var flair = WinnerFlair.new()
		flair.accent = color
		flair.header_top = 34.0
		flair.header_height = 72.0
		panel.add_child(flair)
	var name_label = _label(info[id].name, 26, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	box.add_child(name_label)
	if Global.teams_enabled():
		var team = Global.team_of(id)
		box.add_child(_label(Global.team_name(team), 22, Global.TEAM_COLORS[team], HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(_label(str(Global.get("player%dScore" % id)), 72, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(_separator(color))

	var values = {}
	for stat in GENERIC_STATS + [null] + ELEMENT_STATS.get(id, []):
		if stat == null:
			box.add_child(_separator(color))
			continue
		var line = HBoxContainer.new()
		line.add_child(_label(tr("STAT_" + stat[0].to_upper()), 22, DIM))
		var spacer = Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(spacer)
		var value = _label("0", 26, Color.WHITE)
		line.add_child(value)
		box.add_child(line)
		values[stat[0]] = value

	# Awards (filled by set_totals)
	var award_gap = Control.new()
	award_gap.custom_minimum_size.y = 8
	box.add_child(award_gap)
	# One award per line: the badge, and what it's for to its right (the badges share a width)
	var awards = GridContainer.new()
	awards.columns = 2
	awards.add_theme_constant_override("h_separation", 10)
	awards.add_theme_constant_override("v_separation", 6)
	box.add_child(awards)

	var filler = Control.new()
	filler.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(filler)
	var pick = HBoxContainer.new()
	pick.add_theme_constant_override("separation", 12)
	box.add_child(pick)
	var rematch = _choice_button(tr("STATS_REMATCH"), id, true)
	var quit = _choice_button(tr("STATS_QUIT"), id, false)
	pick.add_child(rematch)
	pick.add_child(quit)
	var how = tr("STATS_AI_CHOICE") if info[id].ai else (tr("STATS_HOW_CHOOSE") if _can_choose(id) else tr("STATS_REMOTE_CHOICE"))
	box.add_child(_label(how, 20, DIM, HORIZONTAL_ALIGNMENT_CENTER))
	columns[id] = {"values": values, "rematch": rematch, "quit": quit, "color": color, "awards": awards}
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
	for stat in ["kills", "length", "powers"]:
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
	_show_awards(totals)

# Who gets which award: {player_id: [award, ...]} in AWARDS order
func awards_for(totals: Dictionary) -> Dictionary:
	var given = {}
	for id in ids:
		given[id] = []
	if ids.size() < 2:
		return given
	for award in AWARDS:
		var amounts = {}
		for id in ids:
			amounts[id] = totals.get(id, {}).get(award[1], 0)
		var values = amounts.values()
		var top = values.max() if award[2] == "max" else values.min()
		if values.min() == values.max() or (award[2] == "max" and top <= 0):
			continue
		for id in ids:
			if amounts[id] == top:
				given[id].append(award)
	return given

func _show_awards(totals):
	var given = awards_for(totals)
	for id in ids:
		var list = columns[id].awards
		for child in list.get_children():
			child.queue_free()
		for award in given[id].slice(0, MAX_AWARDS):
			list.add_child(_award_chip(award))
			var description = _label(tr(_award_key(award) + "_DESC"), 16, DIM)
			description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			description.add_theme_constant_override("line_spacing", -3)
			description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			list.add_child(description)

func _award_chip(award) -> Control:
	var chip = PanelContainer.new()
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var style = StyleBoxFlat.new()
	style.bg_color = GOLD
	style.border_color = GOLD.lightened(0.4)
	style.set_border_width_all(2)
	style.set_corner_radius_all(14)
	style.content_margin_left = 8
	style.content_margin_right = 10
	style.content_margin_top = 3
	style.content_margin_bottom = 3
	chip.add_theme_stylebox_override("panel", style)
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	chip.add_child(row)
	var icon = AwardIcon.new()
	icon.award = award[0]
	icon.custom_minimum_size = Vector2(24, 24)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)
	row.add_child(_label(tr(_award_key(award)), 16, AWARD_INK))
	return chip

# AWARD_LONGEST_TRAIL...
func _award_key(award) -> String:
	return "AWARD_" + award[0].replace(" ", "_")

func _format(stat, amount) -> String:
	match stat:
		"length":
			return tr("METERS_N") % roundi(amount / PIXELS_PER_METER)
		"dead_time":
			if amount >= 60:
				return "%d:%02d" % [int(amount) / 60, int(amount) % 60]
			return tr("SECONDS_DECIMAL") % amount
	return str(int(amount))

# Online: this machine confirmed, the host waits for the others
func show_waiting():
	waiting = true
	for id in ids:
		_show_choice(id)
	_refresh_hint()

func _refresh_hint():
	if waiting:
		hint.text = tr("STATS_WAITING")
		hold_ring.hide()
	else:
		hint.text = tr("HINT_HOLD_PUNCHI")

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

# The symbol on an award ribbon, drawn in the ribbon's dark ink
class AwardIcon extends Control:
	var award = ""

	func _draw():
		var c = size / 2
		var ink = MatchStatsScreen.AWARD_INK
		var gold = MatchStatsScreen.GOLD
		match award:
			"HUNTER": # Crosshair
				draw_arc(c, 8.0, 0, TAU, 24, ink, 2.2, true)
				for direction in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
					draw_line(c + direction * 5.0, c + direction * 11.5, ink, 2.2, true)
				draw_circle(c, 2.0, ink)
			"SURVIVOR": # Shield
				var shield = PackedVector2Array([c + Vector2(-8, -9), c + Vector2(8, -9), c + Vector2(8, 0), c + Vector2(0, 10), c + Vector2(-8, 0)])
				draw_colored_polygon(shield, ink)
				draw_line(c + Vector2(0, -6), c + Vector2(0, 6), gold, 2.0, true)
			"LONGEST TRAIL": # A long winding trail
				var points = PackedVector2Array()
				for i in 13:
					var t = i / 12.0
					points.append(c + Vector2(-11 + 20 * t, sin(t * TAU * 1.2) * 5.0))
				draw_polyline(points, ink, 2.6, true)
				draw_circle(points[points.size() - 1], 3.2, ink)
			"UNTOUCHABLE": # A sparkle
				var star = PackedVector2Array()
				for i in 8:
					var radius = 11.0 if i % 2 == 0 else 3.5
					star.append(c + Vector2.UP.rotated(i * TAU / 8.0) * radius)
				draw_colored_polygon(star, ink)
			"MARATHON": # Stopwatch
				draw_arc(c + Vector2(0, 2), 8.5, 0, TAU, 24, ink, 2.2, true)
				draw_line(c + Vector2(0, -9), c + Vector2(0, -6.5), ink, 3.0)
				draw_line(c + Vector2(-3, -10.5), c + Vector2(3, -10.5), ink, 2.2)
				draw_line(c + Vector2(0, 2), c + Vector2(4, -2), ink, 2.2, true)
			"POWER HUNGRY": # Lightning bolt
				draw_colored_polygon(PackedVector2Array([c + Vector2(2, -11), c + Vector2(-7, 2), c + Vector2(-1, 2), c + Vector2(-3, 11), c + Vector2(7, -3), c + Vector2(1, -3)]), ink)
			"GHOST": # A ghost with a wavy hem
				var body = PackedVector2Array()
				for i in 9:
					body.append(c + Vector2(0, -2) + Vector2.LEFT.rotated(i * PI / 8.0) * 8.0)
				for i in 5:
					var x = 8.0 - i * 4.0
					body.append(c + Vector2(x, 9.0 if i % 2 == 0 else 6.0))
				draw_colored_polygon(body, ink)
				draw_circle(c + Vector2(-3, -2), 1.8, gold)
				draw_circle(c + Vector2(3, -2), 1.8, gold)
			"FIRST OUT": # Skull
				draw_circle(c + Vector2(0, -2), 8.0, ink)
				draw_rect(Rect2(c + Vector2(-4.5, 3), Vector2(9, 6)), ink)
				draw_circle(c + Vector2(-3, -2), 2.3, gold)
				draw_circle(c + Vector2(3, -2), 2.3, gold)
				for x in [-2.2, 0.0, 2.2]:
					draw_line(c + Vector2(x, 5), c + Vector2(x, 9), gold, 1.0)
