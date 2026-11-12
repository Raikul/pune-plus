extends Control

var rng = RandomNumberGenerator.new()
var lessonNumber
var lessonText
@onready var winnerTextBox = $DopamineContainer/Dopamine/Winner
@onready var lessonTextBox = $PanelContainer/MarginContainer/LessonTextBox
@onready var dopamineLabel = $DopamineContainer/Dopamine/DopamineLabel

# Win screen: hold any PUNCHI (or Enter) to fill the ring and close it (closed: the
# Playground shows the match stats next; without a listener it goes back to the menu)
const ODIN = preload("res://assets/jorge-resources/Game Selection/Odin Rounded - Bold.otf")
var hold_ring: HoldRing
signal closed

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
	hold_ring.reset()
	set_process(true)
#	$DopamineContainer/Dopamine/Winner
func teach(type):
	randomizeLesson(type)
	showLesson()

func randomizeLesson(type):
	match type:
		"Water":
			lessonNumber = rng.randf_range(0, LessonList.WaterLessons.size())
			lessonText = tr(LessonList.WaterLessons[lessonNumber])

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
	dopamineLabel.anchor_left = 0.1
	dopamineLabel.anchor_right = 0.9
	dopamineLabel.offset_left = 0
	dopamineLabel.offset_right = 0
	dopamineLabel.offset_top = -30
	dopamineLabel.offset_bottom = 130

	var prompt = HBoxContainer.new()
	prompt.alignment = BoxContainer.ALIGNMENT_CENTER
	prompt.add_theme_constant_override("separation", 16)
	prompt.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	prompt.offset_top = -130
	prompt.offset_bottom = -70
	$DopamineContainer/Dopamine.add_child(prompt)
	hold_ring = HoldRing.new()
	hold_ring.back_color = Color(winnerTextBox.get_theme_color("font_outline_color"), 0.35)
	hold_ring.fill_color = winnerTextBox.get_theme_color("font_color")
	prompt.add_child(hold_ring)
	var hint = Label.new()
	hint.text = "HINT_HOLD_PUNCHI"
	hint.add_theme_font_override("font", ODIN)
	hint.add_theme_font_size_override("font_size", 28)
	hint.add_theme_color_override("font_color", Color.WHITE)
	hint.add_theme_constant_override("outline_size", 0)
	hint.add_theme_constant_override("shadow_offset_x", 0)
	hint.add_theme_constant_override("shadow_offset_y", 3)
	hint.add_theme_constant_override("shadow_outline_size", 0)
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	prompt.add_child(hint)

func _process(delta):
	if not visible or not $DopamineContainer.visible:
		return
	if hold_ring.advance(delta, HoldRing.punchi_pressed()):
		set_process(false)
		if closed.get_connections().is_empty():
			get_tree().change_scene_to_file("res://scenes/menu.tscn")
		else:
			closed.emit()

func _input(event: InputEvent) -> void:
	# The win screen only closes by holding (_process)
	if visible and not $DopamineContainer.visible:
		if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel"):
			get_tree().change_scene_to_file("res://scenes/menu.tscn")
		
