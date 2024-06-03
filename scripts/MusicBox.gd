extends HBoxContainer

var music = AudioServer.get_bus_index("Music")

func _ready():
	$HSlider.set_value_no_signal(db_to_linear(AudioServer.get_bus_volume_db(music)))

func _on_music_slider_value_changed(value):
	AudioServer.set_bus_volume_db(music, linear_to_db(value))
