extends HBoxContainer

var effects = AudioServer.get_bus_index("Effects")
# Called when the node enters the scene tree for the first time.
func _ready():
	$HSlider.set_value_no_signal(db_to_linear(AudioServer.get_bus_volume_db(effects)))
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	pass


func _on_volume_slider_value_changed(value):
	AudioServer.set_bus_volume_db(effects, linear_to_db(value))
	pass # Replace with function body.
