extends HBoxContainer

@onready var option_button = $OptionButton as OptionButton
# Called when the node enters the scene tree for the first time.

const RESOLUTION_DICTIONARY : Dictionary = {
	"1152 x 648" : Vector2(1152,648),
	"1288 x 720" : Vector2(1288,720),
	"1680 x 1050" : Vector2(1680,1050),
	"1920 x 1080" : Vector2(1920,1080)
}


func _ready():
	add_resolution_items()
	on_resolution_selected(3)
	#option_button.select(2)
#	print(RESOLUTION_DICTIONARY.values())
#	print(DisplayServer.window_get_size())
#	print(RESOLUTION_DICTIONARY.values().find(DisplayServer.window_get_size()))
#	option_button._select_int(RESOLUTION_DICTIONARY.values().find(DisplayServer.window_get_size()))
	option_button.item_selected.connect(on_resolution_selected)
	
	
	pass # Replace with function body.

func add_resolution_items():
	for resolution_size_text in RESOLUTION_DICTIONARY:
		option_button.add_item(resolution_size_text)

func on_resolution_selected(index : int):
	DisplayServer.window_set_size(RESOLUTION_DICTIONARY.values()[index])

