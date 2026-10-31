extends VBoxContainer

# "AI PLAYER" badge over the bottom of the card while the AI plays this snake
var ai_badge

func _ready():
	# AI on: the button turns into a light rounded pill (was a square salmon block)
	var ai_button = $"VBoxContainer/Enable AI"
	var on_style = StyleBoxFlat.new()
	on_style.bg_color = Color(0.9, 0.9, 0.9)
	on_style.set_corner_radius_all(15)
	for state in ["pressed", "hover_pressed"]:
		ai_button.add_theme_stylebox_override(state, on_style)
	for color_name in ["font_pressed_color", "font_hover_pressed_color"]:
		ai_button.add_theme_color_override(color_name, Color(0.1, 0.1, 0.1))

func set_ai_status(status):
	$"VBoxContainer/Enable AI".button_pressed = status
	_on_enable_ai_toggled(status)

func _on_enable_ai_toggled(button_pressed):

	if button_pressed:
		$"VBoxContainer/Enable AI".text = "Disable AI"
	else:
		$"VBoxContainer/Enable AI".text = "Enable AI"
	_get_ai_badge().visible = button_pressed
	pass # Replace with function body.

func _get_ai_badge():
	if ai_badge != null:
		return ai_badge
	# Stacked over the card's contents (PanelContainer2), at the bottom, centered
	var holder = MarginContainer.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_theme_constant_override("margin_bottom", 16)
	ai_badge = PanelContainer.new()
	ai_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ai_badge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ai_badge.size_flags_vertical = Control.SIZE_SHRINK_END
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.08, 0.9)
	style.border_color = Color(1, 1, 1, 0.85)
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	ai_badge.add_theme_stylebox_override("panel", style)
	var label = Label.new()
	label.text = "AI PLAYER"
	label.add_theme_font_size_override("font_size", 30)
	label.add_theme_color_override("font_color", Color.WHITE)
	ai_badge.add_child(label)
	holder.add_child(ai_badge)
	$PanelContainer2.add_child(holder)
	return ai_badge
