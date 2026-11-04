extends Control

var actionsToRedefine = []
@onready var keyNumber = 0
@onready var keyToPress = $PanelContainer/HBoxContainer/Key as Label
var currentPlayerId
signal recalculateLabels
const ACTION_NAMES = ["KEY_LEFT_UPPER", "KEY_RIGHT_UPPER", "KEY_PUNCHI_UPPER"] # Translation keys
func _ready():
	set_process_input(false)
	
func redefinePlayer(playerId):
	var stringId = str(playerId)
	set_process_input(true)
	currentPlayerId = playerId
	actionsToRedefine = ["Player"+stringId+"Left", "Player"+stringId+"Right", "Player"+stringId+"Up"]
	$PanelContainer/HBoxContainer/PlayerName.set_text("%s (%s)" % [tr("PLAYER_N") % playerId, tr(Global.ELEMENT_KEYS[playerId] + "_UPPER")])
	keyToPress.set_text(ACTION_NAMES[keyNumber])

func _input(event):
	# The keys pressed here are for the snake: they must not also move the menu focus
	get_viewport().set_input_as_handled()
	if not event is InputEventMouseMotion and not event is InputEventJoypadMotion:
		if event.is_pressed() and not event.is_echo():
			InputMap.action_erase_events(actionsToRedefine[keyNumber])
			InputMap.action_add_event(actionsToRedefine[keyNumber],event)
			keyNumber += 1	
			
			if keyNumber == 3:
				set_process_input(false)
				keyNumber = 0
				emit_signal("recalculateLabels", currentPlayerId)
				hide()
			else:
				keyToPress.set_text(ACTION_NAMES[keyNumber])
		
		
		
	
