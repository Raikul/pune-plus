extends PanelContainer
class_name UpgradeCard

# One selectable upgrade inside an UpgradeRow: icon, name, element tag and description.

const NORMAL_BG = Color(0.2, 0.2, 0.2)
const FOCUSED_BG = Color(0.27, 0.27, 0.27)
const NORMAL_BORDER = Color(0.33, 0.33, 0.33)
const FOCUS_SCALE = Vector2(1.06, 1.06)

var upgrade = {}
var player_color = Color.WHITE
var icon
var style
var flash
var tag_label
var scale_tween

func setup(upgrade_data, color):
	upgrade = upgrade_data
	player_color = color
	custom_minimum_size = Vector2(390, 0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	style = StyleBoxFlat.new()
	style.set_corner_radius_all(18)
	style.set_content_margin_all(16)
	add_theme_stylebox_override("panel", style)

	var content = HBoxContainer.new()
	content.add_theme_constant_override("separation", 14)
	add_child(content)

	icon = UpgradeIcon.new()
	icon.kind = upgrade.icon
	icon.color = player_color
	icon.custom_minimum_size = Vector2(120, 120)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	content.add_child(icon)

	var text_box = VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.alignment = BoxContainer.ALIGNMENT_CENTER
	text_box.add_theme_constant_override("separation", 4)
	content.add_child(text_box)

	text_box.add_child(_label(upgrade.name, 28, Color.WHITE))
	if upgrade.element == "generic":
		tag_label = _label("ANY SNAKE", 16, Color(0.6, 0.6, 0.6))
	else:
		tag_label = _label(upgrade.element.to_upper() + " POWER", 16, player_color)
	text_box.add_child(tag_label)
	text_box.add_child(_label(upgrade.description, 19, Color(0.82, 0.82, 0.82)))

	# White overlay flashed when the card is chosen
	flash = Panel.new()
	var flash_style = StyleBoxFlat.new()
	flash_style.bg_color = Color.WHITE
	flash_style.set_corner_radius_all(18)
	flash.add_theme_stylebox_override("panel", flash_style)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.modulate.a = 0
	add_child(flash)

	resized.connect(func(): pivot_offset = size / 2)
	set_focused(false)

func set_focused(focused):
	style.bg_color = FOCUSED_BG if focused else NORMAL_BG
	style.border_color = player_color if focused else NORMAL_BORDER
	style.set_border_width_all(6 if focused else 3)
	style.shadow_color = Color(player_color, 0.45) if focused else Color.TRANSPARENT
	style.shadow_size = 14 if focused else 0
	icon.speed_scale = 1.8 if focused else 1.0
	_tween_scale(FOCUS_SCALE if focused else Vector2.ONE, 0.12)

func set_dimmed(dimmed):
	create_tween().tween_property(self, "modulate", Color(1, 1, 1, 0.35 if dimmed else 1.0), 0.25)

func play_chosen():
	style.bg_color = player_color.darkened(0.55)
	style.border_color = player_color.lightened(0.3)
	style.shadow_color = Color(player_color, 0.75)
	style.shadow_size = 26
	tag_label.text = "CHOSEN!"
	tag_label.add_theme_color_override("font_color", Color.WHITE)

	flash.modulate.a = 0.85
	create_tween().tween_property(flash, "modulate:a", 0.0, 0.45)
	scale = Vector2(1.2, 1.2)
	_tween_scale(FOCUS_SCALE, 0.6).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_float_text("+ " + upgrade.name)

# Text that rises from the card and fades out as pick confirmation
func _float_text(text):
	var label = _label(text, 36, player_color)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_constant_override("outline_size", 10)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.top_level = true
	label.z_index = 10
	add_child(label)
	label.size = Vector2(size.x, 50)
	label.global_position = global_position + Vector2(0, -20)
	var tween = create_tween().set_parallel()
	tween.tween_property(label, "position:y", label.position.y - 90, 1.3).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.6).set_delay(0.7)
	tween.chain().tween_callback(label.queue_free)

func _tween_scale(target, duration):
	if scale_tween:
		scale_tween.kill()
	scale_tween = create_tween()
	return scale_tween.tween_property(self, "scale", target, duration)

func _label(text, font_size, font_color):
	var label = Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", font_color)
	return label
