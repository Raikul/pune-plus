extends HBoxContainer

var music = AudioServer.get_bus_index("Music")
# Called when the node enters the scene tree for the first time.
func _ready():
	$HSlider.set_value_no_signal(db_to_linear(AudioServer.get_bus_volume_db(music)))
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	pass


func _on_music_slider_value_changed(value):
	AudioServer.set_bus_volume_db(music, linear_to_db(value))
	pass # Replace with function body.
