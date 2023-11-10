extends Control

var actionsToRedefine = []
@onready var keyNumber = 0
@onready var keyToPress = $PanelContainer/HBoxContainer/Key as Label
var currentPlayerId
signal recalculateLabels
func _ready():
	set_process_input(false)
	
func redefinePlayer(playerId):
	set_process_input(true)
	currentPlayerId = playerId
	match playerId:
		1:
			actionsToRedefine = ["Player1Left", "Player1Right", "Player1Up"]
	keyToPress.set_text(actionsToRedefine[keyNumber])

func _input(event):
	
	if not event is InputEventMouseMotion:
		if event.is_pressed():
#		if event is InputEventJoypadMotion:
#			event.axis_value
#		print(event.as_text())
			InputMap.action_erase_events(actionsToRedefine[keyNumber])
			InputMap.action_add_event(actionsToRedefine[keyNumber],event)
			keyNumber += 1	
			
			if keyNumber == 3:
				set_process_input(false)
				keyNumber = 0
				emit_signal("recalculateLabels", currentPlayerId)
				hide()
			else:
				keyToPress.set_text(actionsToRedefine[keyNumber])
		
		
		
	
