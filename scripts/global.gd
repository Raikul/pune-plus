extends Node

var scoreToReach = 10
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

var playerColors = [
	"",
	Color.BLUE_VIOLET,
	Color.GREEN,
	Color.ORANGE_RED,
	Color.SKY_BLUE
]

var isMultiplayerActive = false

var Players = {}

#var multiplayerIds = [0,1,0,0,0]

var musicProgress = 0

#Gameplay
var gapSize = 1
var shrooms = true
var lessons = false
