extends RefCounted
class_name PatchNotes

# Patch notes shown from the version button in the main menu, newest first.
#
# Version numbers are MAJOR.MINOR.PATCH (0.x while in development):
# - MINOR for a content update (new modes, powers, screens),
# - PATCH for fixes and small tweaks on top of it.
# The current one lives in Project Settings > Application > Config > Version
# (application/config/version); add a release here whenever it changes.

const STAGE = "Alpha"

const RELEASES = [
	{
		"version": "0.4.1",
		"name": "Teams & Real Upgrades",
		"date": "2026-10-31",
		"sections": [
			["2v2 and match options", [
				"New 2v2 Teams mode, offline in player setup and online in the host's lobby. Teammates share one score, and a team scores a point each time an enemy snake dies. The round ends when only one team is left.",
				"Choose how many points win the match: Auto, 5, 10, 15, 20, 30 or 50. Auto keeps the old rule.",
				"Mode, teams, points to win, Shrooms, Upgrades, Gap Size and the window settings are remembered between runs.",
			]],
			["Upgrades", [
				"Upgrades now really change your snake for the rest of the match: gaps, speed, recharge, fireball size and flight time, Air's jumps, Earth's size and Water's twins. Maxed upgrades stop showing up, and cards show their level (\"Swift Snake 2/3\").",
				"Upgrades work online: everyone sees the same options and every pick is applied on every screen.",
				"Your current upgrades are shown next to your score and on the upgrade screen. Online you only see your own and your teammates'; rivals show how many they have.",
				"New Earth upgrade, Stone Walker: walk through your own stone walls.",
			]],
			["Powers", [
				"Each power was rebuilt as its own piece, ready for upgrades (thanks Gus!).",
				"Fire: the fireball flies 2.5 seconds, then quickly fades away. Hitting a wall, a snake or Earth's stone stops it on the spot.",
				"Earth: the stone left by its power is now solid. Any snake that touches it dies, Earth included (unless it has Stone Walker).",
				"Air: no double jump and no going through walls by default; jumps stop short of the wall. Second Wind and Wall Warp bring them back as upgrades. A lightning bolt shows the jump, and the landing spot is now a small sparkle.",
				"Water: a splash shows where Water was when it takes its twin's place.",
				"The symbol on your snake's head is white when the power is ready and dark while it recharges.",
				"Smarter AI: Air jumps away from danger to a free spot and uses its upgrades, and Water's twin no longer circles into its own trail.",
			]],
			["Fixes", [
				"Earth's trail turned invisible while its power was on but still killed: it's visible now.",
				"Earth could get out of the arena and stay alive off screen.",
				"The scoreboard froze one point short when a round or match ended.",
				"Windowed mode and resolution now work, and the window fits your screen.",
				"Water's twin no longer causes an error at the start of a round.",
				"Gamepad buttons have short names (\"Pad A\") instead of stretching the setup and upgrade screens.",
				"Redefining keys asks for Left, Right and PUNCHI, and the keys you press no longer move the menu.",
			]],
			["Also new", [
				"Dead snakes get a red cross on the scoreboard.",
				"A new mouse pointer in the colors of the four elements.",
				"New sound for Air's teleport.",
			]],
			["Known issues (online)", [
				"Fireballs can break slightly different trail pieces on each screen, and Earth's stone can be laid slightly differently.",
				"Mushrooms are turned off online, and pausing doesn't stop an online match.",
			]],
		],
	},
	{
		"version": "0.4.0",
		"name": "Online & Upgrades",
		"date": "2026-10-30",
		"sections": [
			["Online multiplayer (Steam, early version)", [
				"Host a friends-only or public lobby, browse open lobbies, invite friends with the Steam overlay or join from your friends list. No port forwarding needed.",
				"Pick your element: click any open slot to move there, add another player on your keyboard or add your own AI. Two PCs can fill a four-snake match.",
				"See every local player's keys in the lobby and rebind them with the Keys button.",
				"Built for latency: your snake reacts instantly, everyone else's movement is predicted and trails are exact copies on every screen.",
				"Players leaving a match no longer cause errors; if the host leaves, everyone returns to the lobby.",
			]],
			["Upgrades", [
				"New upgrade screen between rounds, turned on with \"Upgrades?\" in the main menu. Each snake picks one of three upgrades with its own keys within 10 seconds.",
				"Placeholder upgrades for now (picks don't change the game yet): wider or tighter gaps, speed, quicker recharge, piercing and bigger fireballs, wall warp, second wind, tectonic bulk, extra twin and lasting twin.",
			]],
			["Water", [
				"The twin is now steered by its own AI after splitting away from your snake, instead of mirroring your keys.",
				"The twin's trail sheds its skin: after 5 seconds each segment fades from aqua to Water's color, tail first, and from then on it blocks the Water snake like its own trail.",
				"When Water takes its twin's place, the twin's trail now stays on the field.",
			]],
			["Fixes", [
				"Water now wins when it reaches the score limit.",
				"AI Air could teleport off the map at the start of a round and keep flying where nobody could see it.",
				"Earth's fissure is drawn above every trail instead of under some of them.",
				"The game failed to start on Linux.",
				"The fireball no longer floods the log with errors.",
			]],
			["Also new", [
				"Version number in the main menu and these patch notes.",
			]],
			["Known issues (online)", [
				"Fireballs can break slightly different trail pieces on each screen.",
				"Mushrooms and upgrades are turned off online, and pausing doesn't stop an online match.",
			]],
		],
	},
	{
		"version": "0.3.2",
		"name": "Air & Instructions",
		"date": "2026-10-28",
		"note": "Reconstructed from the project history.",
		"sections": [
			["New", [
				"Air's power teleports the snake ahead of itself, shown by an indicator in front of its head.",
				"Instructions screen.",
				"New fireball sprite.",
				"Debug: \"Simulate round\" in the pause menu.",
			]],
			["Engine", [
				"Updated to Godot 4.3, then 4.5.",
			]],
		],
	},
	{
		"version": "0.3.1",
		"name": "Expo Patch",
		"date": "2024-09-14",
		"note": "Reconstructed from the project history.",
		"sections": [
			["New", [
				"Full keyboard navigation in the menus.",
				"Music and effects volume settings.",
				"Lessons: a quote shows up between rounds.",
			]],
			["Changes", [
				"Player setup and HUD tweaks for the expo.",
			]],
		],
	},
	{
		"version": "0.3.0",
		"name": "Bots & Fissures",
		"date": "2024-03-24",
		"note": "Reconstructed from the project history.",
		"sections": [
			["New", [
				"AI bots: any snake can be played by the computer, chosen in player setup.",
				"Earth's power opens a fissure that crawls ahead of the snake.",
				"Pause and exit buttons during a match.",
				"New fireball.",
			]],
			["Changes", [
				"Major rework and optimization of the game code.",
				"Updated to Godot 4.2.",
			]],
		],
	},
	{
		"version": "0.2.2",
		"name": "New Look",
		"date": "2023-11-30",
		"note": "From the in-game changelog of the time.",
		"sections": [
			["Changes", [
				"Upgraded Water Punchy.",
				"Added a visual for Punchy ready.",
				"New logo, fonts and menu art.",
			]],
		],
	},
	{
		"version": "0.2.0",
		"name": "Shrooms",
		"date": "2023-11-13",
		"note": "From the in-game changelog of the time.",
		"sections": [
			["New", [
				"Shrooms.",
				"Redefine keys.",
				"Win condition and main menu.",
				"Lessons (coded but not shown yet).",
				"LAN multiplayer (coded but not shown yet).",
			]],
		],
	},
	{
		"version": "0.1.7",
		"name": "First Slither",
		"date": "2023-11-09",
		"note": "From the in-game changelog of the time.",
		"sections": [
			["New", [
				"Audio settings: master, music and effects.",
				"Gap size setting.",
				"Full Fire: the fireball breaks everything it passes through.",
			]],
		],
	},
]

static func current_version() -> String:
	return ProjectSettings.get_setting("application/config/version", "0.0.0")

# "Version 0.4.1 (Alpha)"
static func version_label() -> String:
	return "Version %s (%s)" % [current_version(), STAGE]

const MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

# "2026-10-30" -> "Oct 30, 2026"
static func format_date(date: String) -> String:
	var parts = date.split("-")
	if parts.size() != 3:
		return date
	return "%s %d, %s" % [MONTHS[int(parts[1]) - 1], int(parts[2]), parts[0]]
