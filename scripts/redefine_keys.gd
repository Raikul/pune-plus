extends Control

var actionsToRedefine = []
@onready var keyNumber = 0
@onready var keyToPress = $PanelContainer/HBoxContainer/Key as Label
var currentPlayerId
signal recalculateLabels
func _ready():
	set_process_input(false)
	
func redefinePlayer(playerId):
	var stringId = str(playerId)
	set_process_input(true)
	currentPlayerId = playerId
	actionsToRedefine = ["Player"+stringId+"Left", "Player"+stringId+"Right", "Player"+stringId+"Up"]
	keyToPress.set_text(actionsToRedefine[keyNumber])

func _input(event):
	if not event is InputEventMouseMotion and not event is InputEventJoypadMotion:
		if event.is_pressed():
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
		
		
		
	
