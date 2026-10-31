extends HBoxContainer

@onready var option_button = $OptionButton as OptionButton
## The resolution option only applies to the windowed modes
signal window_mode_changed

const WINDOW_MODE_ARRAY : Array[String] = [
	"Full-screen",
	"Windowed",
	"Borderless Window",
	"Borderless Full-Screen"
]

func _ready():
#	option_button.item_selected.connect(on_window_mode_selected)
	add_window_mode_items()
	#on_window_mode_selected(1)
	option_button.select(Global.window_mode)
	
func add_window_mode_items():
	for window_mode in WINDOW_MODE_ARRAY:
		option_button.add_item(window_mode)
		
func on_window_mode_selected(index : int):
	Global.window_mode = index
	Global.save_settings()
	Global.apply_window_mode()
	window_mode_changed.emit()
