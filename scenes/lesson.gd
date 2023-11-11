extends Control

var rng = RandomNumberGenerator.new()
var lessonNumber
var lessonText
@onready var winnerTextBox = $DopamineContainer/Dopamine/Winner
@onready var lessonTextBox = $PanelContainer/MarginContainer/LessonTextBox

func _ready():
	pass
#	var my_random_number = rng.randf_range(-10.0, 10.0)

func improvise(improvisedText):
	winnerTextBox.set_text(improvisedText)
	$DopamineContainer.show()
	$DopamineContainer/Dopamine/Winner
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
