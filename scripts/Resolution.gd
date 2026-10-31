extends HBoxContainer

# Window size for the windowed modes (Global.RESOLUTIONS). In the fullscreen modes the
# game always fills the screen, so the option is greyed out there.

@onready var option_button = $OptionButton as OptionButton

func _ready():
	for size in Global.RESOLUTIONS:
		option_button.add_item("%d x %d" % [size.x, size.y])
	option_button.select(Global.resolution)
	option_button.item_selected.connect(on_resolution_selected)
	var window_mode = get_node_or_null("../WindowMode")
	if window_mode:
		window_mode.window_mode_changed.connect(_update_enabled)
	_update_enabled()

func on_resolution_selected(index : int):
	Global.resolution = index
	Global.save_settings()
	Global.apply_window_size()

func _update_enabled():
	option_button.disabled = not Global.is_windowed()
	option_button.tooltip_text = "" if Global.is_windowed() else "Only for Windowed and Borderless Window"
