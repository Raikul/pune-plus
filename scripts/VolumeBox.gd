extends HBoxContainer

var master = AudioServer.get_bus_index("Master")

func _ready():
	$HSlider.set_value_no_signal(db_to_linear(AudioServer.get_bus_volume_db(master)))

func _on_volume_slider_value_changed(value):
	AudioServer.set_bus_volume_db(master, linear_to_db(value))
