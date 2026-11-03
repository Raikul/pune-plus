extends Node

var scoreToReach = 10
var player1Score = 0
var player2Score = 0
var player3Score = 0
var player4Score = 0
var baseSpeed = 150

var player1Left = "A"

var player1Active
var player2Active
var player3Active
var player4Active

var player1AIEnabled = false
var player2AIEnabled = false
var player3AIEnabled = false
var player4AIEnabled = false

var AI_Enabled = {
	1: false,
	2: false,
	3: false,
	4: false
}

var playerColors = [
	"",
	"ff401a",
	"e6bf00",
	"1ab2ff",
	"00e699"
]

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
	4: null
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
	for id in [1, 2, 3, 4]:
		player_stats[id] = PlayerStats.new()
	player_stats_reset.emit()

## What each snake did this match, for the end screen (scripts/match_stats_screen.gd):
## {player_id: {stat: amount}}. Online every machine only counts what it decides (its own
## snakes, deaths it sees first) and the machines add theirs up at the end
## (NetSession.send_stats), so nothing is counted twice.
var match_stats = {}

func reset_match_stats() -> void:
	match_stats = {1: {}, 2: {}, 3: {}, 4: {}}

func add_stat(player_id, stat, amount = 1) -> void:
	if not match_stats.has(player_id):
		match_stats[player_id] = {}
	match_stats[player_id][stat] = match_stats[player_id].get(stat, 0) + amount

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
var player_team = {1: 0, 2: 1, 3: 0, 4: 1} # 0 = Team A, 1 = Team B
## 0 = automatic: (players - 1) x 10 in free for all, 10 with teams
var points_to_win = 0
const POINTS_TO_WIN_OPTIONS = [0, 5, 10, 15, 20, 30, 50]
const TEAM_NAMES = ["Team A", "Team B"]
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

# Every level scene in LEVELS_DIR (exports list them too)
func level_paths() -> Array:
	var paths = []
	if DirAccess.dir_exists_absolute(LEVELS_DIR):
		for file in ResourceLoader.list_directory(LEVELS_DIR):
			if file.ends_with(".tscn") and not file.begins_with("_"):
				paths.append(LEVELS_DIR + file)
	paths.sort()
	return paths

func level_name(path) -> String:
	if path == "":
		return "Classic"
	return path.get_file().get_basename().capitalize()

# Names of the people at the keyboard, by the element they play (player setup). They move
# with their keys when they drag their name to another element.
var player_names = {1: "Player 1", 2: "Player 2", 3: "Player 3", 4: "Player 4"}

func player_name(player_id) -> String:
	if isMultiplayerActive:
		var entry = SteamNet.roster.get(player_id, {})
		if not entry.is_empty():
			return entry.name
	if AI_Enabled.get(player_id, false):
		return ["", "Fire", "Earth", "Air", "Water"][player_id] + " AI"
	var name = str(player_names.get(player_id, ""))
	return name if name.strip_edges() != "" else "Player %d" % player_id

# What each element's power does, in two words (player setup and online lobby)
const POWER_TAGLINES = ["", "Burning Shot", "Rock Armor", "Lightning Jump", "Twin Split"]

# --- Accessibility (Options), off by default ---
var nameplates = false   # Each snake's name under its head
var snake_eyes = false   # Eyes on the heads, looking at the nearest snake
var direction_arrow = false # A small arrow in front of each head

func random_spawns_enabled() -> bool:
	return online_random_spawns if isMultiplayerActive else random_spawns

func teams_enabled() -> bool:
	return online_teams if isMultiplayerActive else teams

func team_of(player_id) -> int:
	return (online_player_team if isMultiplayerActive else player_team).get(player_id, 0)

func points_to_win_setting() -> int:
	return online_points_to_win if isMultiplayerActive else points_to_win

func points_to_win_text(points) -> String:
	return "Auto" if points <= 0 else str(points)

# The options a host plays an online match with
func match_options() -> Dictionary:
	return {"upgrades": upgrades, "teams": teams, "player_team": player_team.duplicate(), "points_to_win": points_to_win,
		"upgrade_time": online_upgrade_time, "random_spawns": random_spawns, "round_countdown": round_countdown,
		"level": level}

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
		text = "Pad " + (PAD_BUTTON_NAMES[index] if index >= 0 and index < PAD_BUTTON_NAMES.size() else str(index))
	elif event is InputEventJoypadMotion:
		var axis = event.axis
		text = "Pad " + (PAD_AXIS_NAMES[axis] if axis >= 0 and axis < PAD_AXIS_NAMES.size() else str(axis)) 			+ ("+" if event.axis_value > 0 else "-")
	elif event is InputEventMouseButton:
		text = "Mouse " + str(event.button_index)
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
	player_names = config.get_value("game", "player_names", player_names)
	nameplates = config.get_value("accessibility", "nameplates", nameplates)
	snake_eyes = config.get_value("accessibility", "snake_eyes", snake_eyes)
	direction_arrow = config.get_value("accessibility", "direction_arrow", direction_arrow)
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
	config.set_value("game", "player_names", player_names)
	config.set_value("accessibility", "nameplates", nameplates)
	config.set_value("accessibility", "snake_eyes", snake_eyes)
	config.set_value("accessibility", "direction_arrow", direction_arrow)
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
	return "Off" if seconds <= 0 else "%d s" % seconds
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
	
