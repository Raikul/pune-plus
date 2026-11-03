extends Control

func _ready() -> void:
	# Power gallery: every power and upgrade by snake and rarity
	var gallery_button = Button.new()
	gallery_button.text = "POWER GALLERY"
	gallery_button.position = Vector2(1050, 587)
	gallery_button.size = Vector2(220, 43)
	gallery_button.pressed.connect(_open_gallery)
	add_child(gallery_button)

func _open_gallery() -> void:
	add_child(PowerGallery.new())

func _on_button_pressed() -> void:
	hide()
	pass # Replace with function body.
