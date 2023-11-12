extends CanvasLayer

var label1: Label
var label2: Label
var label3: Label
var label4: Label
#
func _ready():
	label1 = $Player1ScoreLabel
	label2 = $Player2ScoreLabel
	label3 = $Player3ScoreLabel
	label4 = $Player4ScoreLabel
	

func _process(_delta):
	pass
#	if Global.player1Active:
#		label1.text = str(Global.player1Score)
#		$Player1Cooldown.value = $"../Player1/CooldownTimer".time_left
#	if Global.player2Active:	
#		label2.text = str(Global.player2Score)
#		$Player2Cooldown.value = $"../Player2/CooldownTimer".time_left
#	if Global.player3Active:	
#		label3.text = str(Global.player3Score)
#		$Player3Cooldown.value = $"../Player3/CooldownTimer".time_left
#	if Global.player4Active:	
#		label4.text = str(Global.player4Score)
#		$Player4Cooldown.value = $"../Player4/CooldownTimer".time_left
		
		
