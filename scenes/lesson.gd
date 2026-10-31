extends Control

var rng = RandomNumberGenerator.new()
var lessonNumber
var lessonText
@onready var winnerTextBox = $DopamineContainer/Dopamine/Winner
@onready var lessonTextBox = $PanelContainer/MarginContainer/LessonTextBox
@onready var dopamineLabel = $DopamineContainer/Dopamine/DopamineLabel

# Win screen: hold any PUNCHI (or Enter) to fill the ring and go back to the menu
const ODIN = preload("res://assets/jorge-resources/Game Selection/Odin Rounded - Bold.otf")
const HOLD_TIME = 1.2
const RING_RADIUS = 22.0
var hold = 0.0
var armed = false # Keys held when the game ended must be released first
var hold_ring

func _ready():
	_style_dopamine()
#	var my_random_number = rng.randf_range(-10.0, 10.0)

# area: the screen rectangle it covers (Playground: the whole arena, under the scoreboard);
# empty = its own size, centered on the screen
func improvise(improvisedText, area = Rect2()):
	winnerTextBox.set_text(improvisedText)
	$DopamineContainer.show()
	# Above trails, heads and power effects
	z_index = 60
	if area.has_area():
		$DopamineContainer.global_position = area.position
		$DopamineContainer.size = area.size
	else:
		$DopamineContainer.global_position = (get_viewport_rect().size - $DopamineContainer.size) / 2
	hold = 0.0
	armed = false
#	$DopamineContainer/Dopamine/Winner
func teach(type):
	randomizeLesson(type)
	showLesson()

func randomizeLesson(type):
	match type:
		"Water":
			lessonNumber = rng.randf_range(0, LessonList.WaterLessons.size())
			lessonText = LessonList.WaterLessons[lessonNumber]

func showLesson():
	lessonTextBox.set_text(lessonText)
	lessonTextBox.show()
	
func hideLesson():
	lessonTextBox.hide()
	
# Same colors as the theme, rounder font and a softer shadow
func _style_dopamine():
	for label in [winnerTextBox, dopamineLabel]:
		label.add_theme_font_override("font", ODIN)
		label.add_theme_constant_override("outline_size", 12)
		label.add_theme_constant_override("shadow_offset_x", 0)
		label.add_theme_constant_override("shadow_offset_y", 6)
		label.add_theme_constant_override("shadow_outline_size", 12)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.set_anchors_preset(Control.PRESET_HCENTER_WIDE)
		label.offset_left = 40
		label.offset_right = -40
	# Offsets from the middle of the box, whatever its size
	winnerTextBox.add_theme_font_size_override("font_size", 120)
	winnerTextBox.offset_top = -230
	winnerTextBox.offset_bottom = -50
	dopamineLabel.add_theme_font_size_override("font_size", 56)
	dopamineLabel.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dopamineLabel.offset_top = -30
	dopamineLabel.offset_bottom = 130

	var prompt = HBoxContainer.new()
	prompt.alignment = BoxContainer.ALIGNMENT_CENTER
	prompt.add_theme_constant_override("separation", 16)
	prompt.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	prompt.offset_top = -130
	prompt.offset_bottom = -70
	$DopamineContainer/Dopamine.add_child(prompt)
	hold_ring = Control.new()
	hold_ring.custom_minimum_size = Vector2.ONE * (RING_RADIUS * 2 + 8)
	hold_ring.draw.connect(_draw_ring)
	prompt.add_child(hold_ring)
	var hint = Label.new()
	hint.text = "HOLD PUNCHI TO CONTINUE"
	hint.add_theme_font_override("font", ODIN)
	hint.add_theme_font_size_override("font_size", 28)
	hint.add_theme_color_override("font_color", Color.WHITE)
	hint.add_theme_constant_override("outline_size", 0)
	hint.add_theme_constant_override("shadow_offset_x", 0)
	hint.add_theme_constant_override("shadow_offset_y", 3)
	hint.add_theme_constant_override("shadow_outline_size", 0)
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	prompt.add_child(hint)

func _draw_ring():
	var center = hold_ring.size / 2
	var outline = winnerTextBox.get_theme_color("font_outline_color")
	var fill = winnerTextBox.get_theme_color("font_color")
	hold_ring.draw_circle(center, RING_RADIUS, Color(outline, 0.35))
	hold_ring.draw_arc(center, RING_RADIUS, 0, TAU, 48, Color(1, 1, 1, 0.6), 3.0, true)
	if hold > 0:
		var t = hold / HOLD_TIME
		hold_ring.draw_arc(center, RING_RADIUS, -PI / 2, -PI / 2 + TAU * t, 48, fill, 7.0, true)
		hold_ring.draw_circle(center, RING_RADIUS * 0.45 * t, fill)

func _hold_pressed() -> bool:
	if Input.is_action_pressed("ui_accept"):
		return true
	for id in range(1, 5):
		if Input.is_action_pressed("Player%dUp" % id):
			return true
	return false

func _process(delta):
	if not visible or not $DopamineContainer.visible:
		return
	var pressed = _hold_pressed()
	if not armed:
		armed = not pressed
		return
	if pressed:
		hold = min(hold + delta, HOLD_TIME)
	else:
		hold = max(hold - delta * 2.0, 0.0)
	hold_ring.queue_redraw()
	if hold >= HOLD_TIME:
		set_process(false)
		get_tree().change_scene_to_file("res://scenes/menu.tscn")

func _input(event: InputEvent) -> void:
	# The win screen only closes by holding (_process)
	if visible and not $DopamineContainer.visible:
		if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel"):
			get_tree().change_scene_to_file("res://scenes/menu.tscn")
		
