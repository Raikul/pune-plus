extends VBoxContainer


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	
	$Hosting.set_text(str("1: " , str(Global.multiplayerIds[1]) , " 2: " , (Global.multiplayerIds[2])))
	$PlayerConnected.text = str(multiplayer.get_peers())
	pass
