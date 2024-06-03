extends HBoxContainer

var effects = AudioServer.get_bus_index("Effects")

func _ready():
	$HSlider.set_value_no_signal(db_to_linear(AudioServer.get_bus_volume_db(effects)))

func _on_volume_slider_value_changed(value):
	AudioServer.set_bus_volume_db(effects, linear_to_db(value))
