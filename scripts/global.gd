extends Node

var player1Score = 0
var player2Score = 0
var player3Score = 0
var player4Score = 0
var baseSpeed = 150

var player1Left = "A"

var player1Active
var player2Active
var player3Active
var player4Active

var player1Color = Color.BLUE_VIOLET
var player2Color = Color.GREEN
var player3Color = Color.ORANGE_RED
var player4Color = Color.SKY_BLUE

var playerColors = [
	"",
	player1Color,
	player2Color,
	player3Color,
	player4Color
]

var isMultiplayerActive = false

var Players = {}

var multiplayerIds = [0,1,0,0,0]

var musicProgress = 0
var gapSize = 1


