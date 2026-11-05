extends Node

var scoreToReach = 10
var player1Score = 0
var player2Score = 0
var player3Score = 0
var player4Score = 0
var player5Score = 0
var baseSpeed = 150

var player1Left = "A"

var player1Active
var player2Active
var player3Active
var player4Active
var player5Active = false

var player1AIEnabled = false
var player2AIEnabled = false
var player3AIEnabled = false
var player4AIEnabled = false

var AI_Enabled = {
	1: false,
	2: false,
	3: false,
	4: false,
	5: false,
}

# --- Elements by id: 1 Fire, 2 Earth, 3 Air, 4 Water, 5 Void (EXPERIMENTAL, offline only).
# Only MAX_SNAKES of them play at once: the scoreboard, stats and upgrade screens have room
# for four, so with Void in, one element sits out and Void takes its seat (seat_of).
const VOID_ID = 5
const MAX_SNAKES = 4
## Void's own color is nearly white; where white wouldn't show (a selected card's tint),
## the purple of its void is used
const VOID_ACCENT = Color(0.62, 0.36, 1.0)
## Void's Punchi cooldown (the others: PlayerStats "cooldown", 6 s)
const VOID_COOLDOWN = 10.0

# Every element that can play: online stays with the classic four
func element_ids() -> Array:
	return [1, 2, 3, 4] if isMultiplayerActive else [1, 2, 3, 4, 5]

# The elements playing this match
func active_ids() -> Array:
	return element_ids().filter(func(id): return get("player%dActive" % id))

## Where a snake sits on four-seat screens (scoreboard card, corner spawn): the classic four
## sit in their own seat, Void in the seat of the element that sits out
func seat_of(player_id) -> int:
	if player_id != VOID_ID:
		return player_id
	for id in [1, 2, 3, 4]:
		if not get("player%dActive" % id):
			return id
	return 4

## Each element's symbol (white art, tinted with the element's color)
const SYMBOL_PATHS = ["", "res://assets/jorge-resources/Game Selection/Fire-Water symbol.png",
	"res://assets/jorge-resources/Game Selection/Air-Earth symbol rot.png",
	"res://assets/jorge-resources/Game Selection/Air-Earth symbol.png",
	"res://assets/jorge-resources/Game Selection/Fire-Water symbol rot.png",
	"res://assets/images/void_symbol.png"]

func element_symbol(player_id) -> Texture2D:
	return load(SYMBOL_PATHS[player_id]) if player_id > 0 and player_id < SYMBOL_PATHS.size() else null

# Each element's color (by player id). Filled from ELEMENT_COLORS or, with the colorblind
# mode on, COLORBLIND_COLORS (apply_colors).
var playerColors = [
	"",
	"ff401a",
	"e6bf00",
	"1ab2ff",
	"00e699"
]
const ELEMENT_COLORS = ["", "ff401a", "e6bf00", "1ab2ff", "00e699", "e4dcff"]
## Colorblind mode (Options > Accessibility): fire red, earth green, air yellow, water blue,
## from the Okabe-Ito palette, which stays distinct with every kind of color blindness
## (they also differ in brightness: yellow lightest, then green, blue and red)
## (Void is white in both: no color blindness mixes it up with the others)
const COLORBLIND_COLORS = ["", "e0491c", "00b386", "f0e442", "3a86ff", "ffffff"]
var colorblind = false

# The colors of the current mode into playerColors. Called at startup, by Options outside
# a match and when a match starts (a match keeps the colors it started with).
func apply_colors() -> void:
	var colors = COLORBLIND_COLORS if colorblind else ELEMENT_COLORS
	while playerColors.size() < colors.size():
		playerColors.append("")
	for id in range(1, colors.size()):
		playerColors[id] = colors[id]

## The water twins' see-through color: aqua, or a light blue in the colorblind mode (aqua
## is too close to its green earth)
func twin_color() -> Color:
	return Color("9cc4ff") if colorblind else Color.AQUA

var isMultiplayerActive = false

var Players = {}

var multiplayerIds = [0,1,0,0,0]

var musicProgress = 0

#Gameplay
var gapSize = 1
var shrooms = false
var upgrades = true
var lessons = false

var player_stats: Dictionary = {
	1: null,
	2: null,
	3: null,
	4: null,
	5: null,
}

# Duración de los huecos de la estela según la opción Gap Size (Options > Gameplay)
func gap_time() -> float:
	match gapSize:
		0: return 0.4
		2: return 1.0
		_: return 0.7

## Fresh stats for every snake (every match starts without upgrades)
signal player_stats_reset

func reset_all_player_stats() -> void:
	for id in [1, 2, 3, 4, 5]:
		player_stats[id] = PlayerStats.new()
	# Void absorbs powers and recharges by absorbing: its own recharge is slower
	player_stats[VOID_ID].set_stat("cooldown", VOID_COOLDOWN)
	player_stats_reset.emit()

## What each snake did this match, for the end screen (scripts/match_stats_screen.gd):
## {player_id: {stat: amount}}. Online every machine only counts what it decides (its own
## snakes, deaths it sees first) and the machines add theirs up at the end
## (NetSession.send_stats), so nothing is counted twice.
var match_stats = {}

func reset_match_stats() -> void:
	match_stats = {1: {}, 2: {}, 3: {}, 4: {}, 5: {}}

func add_stat(player_id, stat, amount = 1) -> void:
	if not match_stats.has(player_id):
		match_stats[player_id] = {}
	match_stats[player_id][stat] = match_stats[player_id].get(stat, 0) + amount
	if HIGHLIGHT_STATS.has(stat):
		note_highlight(player_id, HIGHLIGHT_STATS[stat][0], HIGHLIGHT_STATS[stat][1])

# For stats that only count the best (the longest single life)
func max_stat(player_id, stat, amount) -> void:
	if not match_stats.has(player_id):
		match_stats[player_id] = {}
	match_stats[player_id][stat] = max(match_stats[player_id].get(stat, 0), amount)

## Something worth a replay happened (the play of the game, scripts/replay/replay_recorder.gd).
## player_id: whose moment it is; kind: what (its caption); weight: how good;
## victim_id: who it happened to (a kill's victim)
signal highlight(player_id, kind, weight, victim_id)
## Stats that are a moment of their own: [kind, weight]
const HIGHLIGHT_STATS = {
	"fire_revives": ["phoenix", 3.0],
	"water_saves": ["save", 3.0],
	"earth_blocked": ["block", 2.0],
	"air_shocks": ["shock", 1.5],
}

func note_highlight(player_id, kind, weight, victim_id = 0) -> void:
	highlight.emit(player_id, kind, weight, victim_id)

# Several machines' match_stats added up
static func sum_stats(sources: Array) -> Dictionary:
	var total = {}
	for source in sources:
		for player_id in source:
			if not total.has(player_id):
				total[player_id] = {}
			for stat in source[player_id]:
				total[player_id][stat] = total[player_id].get(stat, 0) + source[player_id][stat]
	return total

## Leaving a match's end screen with "Quit" opens the menu right at player setup
var open_player_setup = false

# Window mode chosen in Options (index of WindowMode.WINDOW_MODE_ARRAY) and the window
# size for the windowed modes (index of RESOLUTIONS). Saved in the settings file.
var window_mode = 3 # Borderless Full-Screen
var resolution = 3  # 1920 x 1080
var window_mode_applied = false
const RESOLUTIONS = [Vector2i(1152, 648), Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080)]

func apply_window_mode() -> void:
	window_mode_applied = true
	match window_mode:
		0: # Full-screen
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
		1: # Windowed
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
		2: # Borderless Window
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
		3: # Borderless Full-Screen
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
	if is_windowed():
		# The OS finishes leaving fullscreen first, otherwise the new size can be ignored
		await get_tree().process_frame
		apply_window_size()

func is_windowed() -> bool:
	return window_mode == 1 or window_mode == 2

# The chosen size, shrunk to fit the screen's usable area (taskbar and Windows scaling
# included): a 1920 x 1080 window on a 1080p screen would cover it like fullscreen.
func apply_window_size() -> void:
	if not is_windowed():
		return
	var screen = DisplayServer.window_get_current_screen()
	var usable = DisplayServer.screen_get_usable_rect(screen)
	var wanted = RESOLUTIONS[clampi(resolution, 0, RESOLUTIONS.size() - 1)]
	var size = wanted
	# Keep 16:9 and leave room for the title bar
	var max_size = Vector2(usable.size) - Vector2(0, 40 if window_mode == 1 else 0)
	var fit = min(1.0, min(max_size.x / size.x, max_size.y / size.y))
	size = Vector2i(Vector2(size) * fit)
	DisplayServer.window_set_size(size)
	DisplayServer.window_set_position(usable.position + (usable.size - size) / 2)

# Shrooms and upgrades online: shrooms aren't synced yet, upgrades follow the host's toggle
var online_upgrades = false

# --- Match rules: 2v2 teams and points to win (saved). Online the host's copies are used.
# Team mode: two teams share their score and earn one point per enemy snake that dies.
var teams = false
var player_team = {1: 0, 2: 1, 3: 0, 4: 1, 5: 1} # 0 = Team A, 1 = Team B
## 0 = automatic: (players - 1) x 10 in free for all, 10 with teams
var points_to_win = 0
const POINTS_TO_WIN_OPTIONS = [0, 5, 10, 15, 20, 30, 50]
const TEAM_NAMES = ["TEAM_A", "TEAM_B"] # Translation keys (team_name)
const TEAM_COLORS = [Color(1.0, 0.55, 0.15), Color(0.45, 0.6, 1.0)]
var online_teams = false
var online_player_team = {1: 0, 2: 1, 3: 0, 4: 1}
var online_points_to_win = 0
# Random starting spots each round (spread out, away from walls, facing inwards)
var random_spawns = false
var online_random_spawns = false

# "3, 2, 1, GO!" before every round (the first one always has it)
var round_countdown = true
var online_round_countdown = true

func round_countdown_enabled() -> bool:
	return online_round_countdown if isMultiplayerActive else round_countdown

# Arena: a level scene with walls (res://levels, see docs/levels.md); "" = the empty classic arena
var level = ""
var online_level = ""
const LEVELS_DIR = "res://levels/"

# A level scene run on its own from the editor (Level._playtest) plays on itself
var test_level = ""

func level_path() -> String:
	if test_level != "":
		return test_level
	return online_level if isMultiplayerActive else level

## Arena rotation: the levels a match picks from, a random one every round ("" = the empty
## classic arena). Chosen in Match settings > Arena rotation (scripts/level_rotation_menu.gd).
var level_rotation = [""]
var online_level_rotation = [""]

# The rotation this match plays (only levels this build has; never empty)
func level_rotation_setting() -> Array:
	if test_level != "":
		return [test_level]
	var rotation = online_level_rotation if isMultiplayerActive else level_rotation
	rotation = rotation.filter(func(path): return path == "" or ResourceLoader.exists(path))
	return rotation if not rotation.is_empty() else [""]

# A random level of the rotation, a different one than `previous` when there's a choice
func pick_level(previous = null) -> String:
	var choices = level_rotation_setting()
	if choices.size() > 1 and previous != null:
		choices = choices.filter(func(path): return path != previous)
	return choices[randi() % choices.size()]

# "Classic", "Lens", "3 arenas", "All 10 arenas"
func level_rotation_text(rotation: Array) -> String:
	if rotation.size() == 1:
		return level_name(rotation[0])
	if rotation.size() == level_paths().size() + 1:
		return tr("ARENAS_ALL") % rotation.size()
	return tr("ARENAS_COUNT") % rotation.size()

# Every level scene in LEVELS_DIR (exports list them too)
func level_paths() -> Array:
	var paths = []
	if DirAccess.dir_exists_absolute(LEVELS_DIR):
		for file in ResourceLoader.list_directory(LEVELS_DIR):
			if file.ends_with(".tscn") and not file.begins_with("_"):
				paths.append(LEVELS_DIR + file)
	paths.sort()
	return paths

# Translated: key LEVEL_<FILE NAME> (e.g. LEVEL_TWIN_BLOCKS); a level without one in
# translations/strings.csv shows its file name
func level_name(path) -> String:
	if path == "":
		return tr("LEVEL_CLASSIC")
	var base = path.get_file().get_basename()
	var key = "LEVEL_" + base.to_upper()
	var name = tr(key)
	return base.capitalize() if name == key else name

# Names of the people at the keyboard, by the element they play (player setup). They move
# with their keys when they drag their name to another element.
# "" = the default "Player N", in the current language
var player_names = {1: "", 2: "", 3: "", 4: "", 5: ""}

func team_name(team) -> String:
	return tr(TEAM_NAMES[team])

func player_name(player_id) -> String:
	if isMultiplayerActive:
		var entry = SteamNet.roster.get(player_id, {})
		if not entry.is_empty():
			return entry.name
	if AI_Enabled.get(player_id, false):
		return ai_match_names.get(player_id, tr("AI_FALLBACK_NAME") % tr(ELEMENT_KEYS[player_id]))
	var name = str(player_names.get(player_id, ""))
	return name if name.strip_edges() != "" else tr("PLAYER_N") % player_id

## Translation keys of the elements' names (Title case: "Fire"; ELEMENT_*_UPPER: "FIRE")
const ELEMENT_KEYS = ["", "ELEMENT_FIRE", "ELEMENT_EARTH", "ELEMENT_AIR", "ELEMENT_WATER", "ELEMENT_VOID"]

## AI snakes' names (translation keys): every match each AI gets a random one of its element's
const AI_NAMES = {
	1: ["AI_BLAZE", "AI_CINDER", "AI_SCORCH", "AI_EMBER", "AI_INFERNO"],
	2: ["AI_BOULDER", "AI_GRANITE", "AI_TREMOR", "AI_PEBBLE", "AI_QUAKE"],
	3: ["AI_GALE", "AI_ZEPHYR", "AI_CYCLONE", "AI_BREEZE", "AI_TEMPEST"],
	4: ["AI_TIDE", "AI_RIPPLE", "AI_TORRENT", "AI_DRIZZLE", "AI_RIPTIDE"],
	5: ["AI_ABYSS", "AI_ECHO", "AI_HOLLOW", "AI_NULL", "AI_ECLIPSE"],
}
var ai_match_names = {}

# New names for the AIs, at the start of a match
func roll_ai_names() -> void:
	for id in AI_NAMES:
		ai_match_names[id] = random_ai_name(id)

static func random_ai_name(element) -> String:
	return TranslationServer.translate(AI_NAMES[element].pick_random())

## The names this machine's players go by online, by key set (Player{N} keys: 1 is the
## first person at the keyboard). Empty = the Steam name (and "#2"... for the others).
var online_names = {}

# What each element's power does, in two words (player setup and online lobby; translation keys)
const POWER_TAGLINES = ["", "POWER_FIRE", "POWER_EARTH", "POWER_AIR", "POWER_WATER", "POWER_VOID"]

# --- Accessibility (Options), off by default ---
var nameplates = false   # Each snake's name under its head
var snake_eyes = false   # Eyes on the heads, looking at the nearest snake
var direction_arrow = false # A small arrow in front of each head

# A match is being played (the Playground scene is on)
func in_match() -> bool:
	var scene = get_tree().current_scene
	return scene != null and scene.scene_file_path == "res://scenes/Playground.tscn"

func random_spawns_enabled() -> bool:
	return online_random_spawns if isMultiplayerActive else random_spawns

func teams_enabled() -> bool:
	return online_teams if isMultiplayerActive else teams

func team_of(player_id) -> int:
	return (online_player_team if isMultiplayerActive else player_team).get(player_id, 0)

func points_to_win_setting() -> int:
	return online_points_to_win if isMultiplayerActive else points_to_win

func points_to_win_text(points) -> String:
	return tr("VALUE_AUTO") if points <= 0 else str(points)

## On / Off in the current language
func on_off(on) -> String:
	return tr("VALUE_ON") if on else tr("VALUE_OFF")

# The options a host plays an online match with
func match_options() -> Dictionary:
	return {"upgrades": upgrades, "teams": teams, "player_team": player_team.duplicate(), "points_to_win": points_to_win,
		"upgrade_time": online_upgrade_time, "random_spawns": random_spawns, "round_countdown": round_countdown,
		"levels": level_rotation.duplicate()}

func shrooms_enabled() -> bool:
	return shrooms and not isMultiplayerActive

func upgrades_enabled() -> bool:
	return online_upgrades if isMultiplayerActive else upgrades

# --- Short names for bound keys and gamepad buttons (setup screen, lobby, upgrade screen) ---
# Godot's own names are too long for the UI ("Joypad Button 0 (Bottom Action, Sony Cross...")
const PAD_BUTTON_NAMES = ["A", "B", "X", "Y", "Back", "Home", "Start", "LS", "RS", "LB", "RB",
	"Up", "Down", "Left", "Right"]
const PAD_AXIS_NAMES = ["LX", "LY", "RX", "RY", "LT", "RT"]
const MAX_KEY_NAME = 10

func input_event_name(event) -> String:
	var text = ""
	if event is InputEventKey:
		var code = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		text = OS.get_keycode_string(code)
	elif event is InputEventJoypadButton:
		var index = event.button_index
		text = tr("KEY_PAD") + " " + (PAD_BUTTON_NAMES[index] if index >= 0 and index < PAD_BUTTON_NAMES.size() else str(index))
	elif event is InputEventJoypadMotion:
		var axis = event.axis
		text = tr("KEY_PAD") + " " + (PAD_AXIS_NAMES[axis] if axis >= 0 and axis < PAD_AXIS_NAMES.size() else str(axis)) 			+ ("+" if event.axis_value > 0 else "-")
	elif event is InputEventMouseButton:
		text = tr("KEY_MOUSE") + " " + str(event.button_index)
	else:
		text = event.as_text()
	return text if text.length() <= MAX_KEY_NAME else text.substr(0, MAX_KEY_NAME - 1) + "."

# The first event bound to an input action, by its short name
func action_key_name(action) -> String:
	var events = InputMap.action_get_events(action)
	return "?" if events.is_empty() else input_event_name(events[0])

# --- Settings remembered between runs (user://settings.cfg) ---
const SETTINGS_PATH = "user://settings.cfg"

func _ready():
	load_settings()
	apply_language()
	apply_colors()
	apply_volumes()
	apply_video_settings()
	_set_cursors()

# Same look as the arrow (project setting mouse_cursor/custom_image): an I-beam over text
# fields and a four-way arrow over things that can be dragged (player names in setup)
func _set_cursors():
	var center = Vector2(24, 24)
	Input.set_custom_mouse_cursor(load("res://assets/images/ui/cursor_text.png"), Input.CURSOR_IBEAM, center)
	var move = load("res://assets/images/ui/cursor_move.png")
	for shape in [Input.CURSOR_MOVE, Input.CURSOR_DRAG, Input.CURSOR_CAN_DROP]:
		Input.set_custom_mouse_cursor(move, shape, center)

func load_settings() -> void:
	var config = ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return
	shrooms = config.get_value("game", "shrooms", shrooms)
	upgrades = config.get_value("game", "upgrades", upgrades)
	gapSize = config.get_value("game", "gap_size", gapSize)
	window_mode = config.get_value("video", "window_mode", window_mode)
	resolution = config.get_value("video", "resolution", resolution)
	teams = config.get_value("match", "teams", teams)
	player_team = config.get_value("match", "player_team", player_team)
	points_to_win = config.get_value("match", "points_to_win", points_to_win)
	random_spawns = config.get_value("match", "random_spawns", random_spawns)
	round_countdown = config.get_value("match", "round_countdown", round_countdown)
	level = config.get_value("match", "level", level)
	if level != "" and not ResourceLoader.exists(level):
		level = ""
	# Before rotations there was a single arena setting: it becomes a rotation of one
	level_rotation = config.get_value("match", "level_rotation", [level])
	level_rotation = level_rotation.filter(func(path): return path == "" or ResourceLoader.exists(path))
	if level_rotation.is_empty():
		level_rotation = [""]
	player_names = config.get_value("game", "player_names", player_names)
	# Names saved before translations: the old defaults go back to "" (translated "Player N")
	for id in player_names:
		if str(player_names[id]) == "Player %d" % id:
			player_names[id] = ""
	# Settings saved before Void had a seat
	for id in [1, 2, 3, 4, 5]:
		if not player_names.has(id):
			player_names[id] = ""
		if not player_team.has(id):
			player_team[id] = 1
	language = config.get_value("game", "language", language)
	online_names = config.get_value("game", "online_names", online_names)
	nameplates = config.get_value("accessibility", "nameplates", nameplates)
	snake_eyes = config.get_value("accessibility", "snake_eyes", snake_eyes)
	direction_arrow = config.get_value("accessibility", "direction_arrow", direction_arrow)
	colorblind = config.get_value("accessibility", "colorblind", colorblind)
	vsync = config.get_value("video", "vsync", vsync)
	max_fps = config.get_value("video", "max_fps", max_fps)
	show_fps = config.get_value("video", "show_fps", show_fps)
	for bus in volumes:
		volumes[bus] = config.get_value("audio", bus.to_lower(), volumes[bus])
	# Own key for the offline limit, so it starts Off even where the old shared one was saved
	upgrade_time = config.get_value("game", "offline_upgrade_time", upgrade_time)
	online_upgrade_time = config.get_value("game", "upgrade_time", online_upgrade_time)
	show_quotes = config.get_value("game", "show_quotes", show_quotes)

func save_settings() -> void:
	var config = ConfigFile.new()
	config.set_value("game", "shrooms", shrooms)
	config.set_value("game", "upgrades", upgrades)
	config.set_value("game", "gap_size", gapSize)
	config.set_value("video", "window_mode", window_mode)
	config.set_value("video", "resolution", resolution)
	config.set_value("match", "teams", teams)
	config.set_value("match", "player_team", player_team)
	config.set_value("match", "points_to_win", points_to_win)
	config.set_value("match", "random_spawns", random_spawns)
	config.set_value("match", "round_countdown", round_countdown)
	config.set_value("match", "level", level)
	config.set_value("match", "level_rotation", level_rotation)
	config.set_value("game", "player_names", player_names)
	config.set_value("game", "language", language)
	config.set_value("game", "online_names", online_names)
	config.set_value("accessibility", "nameplates", nameplates)
	config.set_value("accessibility", "snake_eyes", snake_eyes)
	config.set_value("accessibility", "direction_arrow", direction_arrow)
	config.set_value("accessibility", "colorblind", colorblind)
	config.set_value("video", "vsync", vsync)
	config.set_value("video", "max_fps", max_fps)
	config.set_value("video", "show_fps", show_fps)
	for bus in volumes:
		config.set_value("audio", bus.to_lower(), volumes[bus])
	config.set_value("game", "offline_upgrade_time", upgrade_time)
	config.set_value("game", "upgrade_time", online_upgrade_time)
	config.set_value("game", "show_quotes", show_quotes)
	config.save(SETTINGS_PATH)

# --- Options screen settings (scripts/options.gd) ---
var vsync = true
var max_fps = 0 # 0 = no limit
const MAX_FPS_OPTIONS = [0, 60, 120, 144, 240]
var show_fps = false
# Linear volume (0-1) per audio bus
var volumes = {"Master": 0.75, "Music": 0.68, "Effects": 1.0}

# Seconds to pick an upgrade. Offline it can be off (0 = no limit, the default);
# online the host always sets a limit, so nobody waits forever on a rival
var upgrade_time = 0.0
const UPGRADE_TIME_OPTIONS = [0.0, 5.0, 10.0, 15.0, 20.0, 30.0]
var online_upgrade_time = 10.0
const ONLINE_UPGRADE_TIME_OPTIONS = [5.0, 10.0, 15.0, 20.0, 30.0]

func upgrade_time_text(seconds) -> String:
	return tr("UPGRADE_TIME_OFF") if seconds <= 0 else tr("SECONDS_N") % seconds

# --- Language (Options > Gameplay). Texts are translation keys (translations/strings.csv);
# English is the default and the fallback for anything missing
const LANGUAGES = [["en", "English"], ["es", "Español"], ["zh_CN", "简体中文"]]
var language = "en"

func apply_language() -> void:
	if not LANGUAGES.any(func(entry): return entry[0] == language):
		language = "en"
	TranslationServer.set_locale(language)
# Wise quote at the top of the upgrade screen
var show_quotes = true
var fps_label: Label

func apply_video_settings() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = max_fps
	if show_fps and fps_label == null:
		var layer = CanvasLayer.new()
		layer.layer = 100
		fps_label = Label.new()
		fps_label.position = Vector2(12, 8)
		fps_label.add_theme_font_size_override("font_size", 22)
		fps_label.add_theme_color_override("font_outline_color", Color.BLACK)
		fps_label.add_theme_constant_override("outline_size", 6)
		layer.add_child(fps_label)
		add_child(layer)
	if fps_label:
		fps_label.get_parent().visible = show_fps

func apply_volumes() -> void:
	for bus in volumes:
		var index = AudioServer.get_bus_index(bus)
		if index >= 0:
			AudioServer.set_bus_volume_db(index, linear_to_db(volumes[bus]))
			AudioServer.set_bus_mute(index, volumes[bus] <= 0.001)

func _process(_delta):
	if fps_label and show_fps:
		fps_label.text = "%d FPS" % Engine.get_frames_per_second()

func reset_score():
	player1Score = 0
	player2Score = 0
	player3Score = 0
	player4Score = 0
	player5Score = 0
	
