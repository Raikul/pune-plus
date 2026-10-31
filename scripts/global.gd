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
var shrooms = true
var upgrades = false
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

func shrooms_enabled() -> bool:
	return shrooms and not isMultiplayerActive

func upgrades_enabled() -> bool:
	return online_upgrades if isMultiplayerActive else upgrades

# --- Settings remembered between runs (user://settings.cfg) ---
const SETTINGS_PATH = "user://settings.cfg"

func _ready():
	load_settings()

func load_settings() -> void:
	var config = ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return
	shrooms = config.get_value("game", "shrooms", shrooms)
	upgrades = config.get_value("game", "upgrades", upgrades)
	gapSize = config.get_value("game", "gap_size", gapSize)
	window_mode = config.get_value("video", "window_mode", window_mode)
	resolution = config.get_value("video", "resolution", resolution)

func save_settings() -> void:
	var config = ConfigFile.new()
	config.set_value("game", "shrooms", shrooms)
	config.set_value("game", "upgrades", upgrades)
	config.set_value("game", "gap_size", gapSize)
	config.set_value("video", "window_mode", window_mode)
	config.set_value("video", "resolution", resolution)
	config.save(SETTINGS_PATH)

func reset_score():
	player1Score = 0
	player2Score = 0
	player3Score = 0
	player4Score = 0
	
