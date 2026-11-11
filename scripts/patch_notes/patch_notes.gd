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
		"version": "0.7.0",
		"name": "The Void",
		"date": "2026-11-05",
		"sections": [
			["Void (EXPERIMENTAL)", [
				"A fifth snake, Void, white, with its own symbol: a snake shaped like an hourglass. Only four snakes play at once, so picking Void means one element sits out; Void takes its seat on the scoreboard and its corner. Offline only for now. Default keys: F / H / T.",
				"Its Punchi opens a wiggling void around its head for 3 seconds. A rival's fireball, rock or twin head it touches gives it that power, and so does lightning that strikes it (the shock does nothing). A snake that crashes into Void's trail meanwhile gives up its power for the whole round.",
				"Its Punchi takes 10 seconds to recharge, but absorbing recharges it. An absorbed power lasts 4 seconds and is cast on the next press, together with everything else it holds (and the void opens again); powers kept for the round are cast on every press. Holding Water, its twins copy the rest: they shoot fireballs, wear stone armor with a rocky path and jump.",
				"Upgrades: Lingering Void (+1 s, common), Wide Void (30% wider, uncommon), Long Memory (absorbs last 8 s, uncommon), Perfect Mimic (absorbs come with their owner's upgrades, epic) and Event Horizon (every absorb lasts the whole round, legendary).",
			]],
			["Fire", [
				"The fireball no longer crashes on the arena's edge: it flies out one side and comes back in on the other, so it can be used close to the edge.",
				"New uncommon upgrade, Hearth: a circle of fire burns where you start each round, for the whole round. It kills other snakes, never you. With Phoenix, rising lights another one.",
				"New epic upgrade, Pyre (needs Hearth): your fireball's kills leave a circle of fire where they fell.",
			]],
			["Water", [
				"New legendary upgrade, Black Ice: the gaps in your trail freeze over for 10 seconds. Other snakes on the ice slide: they turn slower and keep drifting the way they were going.",
			]],
			["Earth", [
				"New legendary upgrade, Strangling Roots: roots grow in the gaps of your trail for 10 seconds, and other snakes crawl through them at a third of their speed.",
			]],
		],
	},
	{
		"version": "0.6.2",
		"name": "Languages",
		"date": "2026-11-04",
		"sections": [
			["Menus", [
				"New Language option (Options > Gameplay): English, Español and 简体中文 (Simplified Chinese). Every menu, screen, upgrade and quote is translated; the patch notes stay in English.",
				"Match stats: the awards are a list, each with what it's for written next to it.",
				"Upgrade cards: the animated icons draw their trails as smooth strokes like the snakes' own, with soft edges everywhere.",
				"The play of the game replay is smooth instead of blocky.",
				"Instructions and the pause menu redone in the look of Options: a card per element in its color (colorblind mode included), how points work, and a dimmed game behind a rounded panel.",
				"New colorblind mode (Options > Accessibility): fire red, earth green, air yellow and water blue, colors that stay distinct with any kind of color blindness. Water's twins turn light blue.",
			]],
		],
	},
	{
		"version": "0.6.1",
		"name": "Faces & Arenas",
		"date": "2026-11-03",
		"sections": [
			["Snakes", [
				"AI snakes get a name of their element every match, picked at random from five each (Fire: Blaze, Cinder, Scorch, Ember, Inferno; Earth: Boulder, Granite, Tremor, Pebble, Quake; Air: Gale, Zephyr, Cyclone, Breeze, Tempest; Water: Tide, Ripple, Torrent, Drizzle, Riptide). Online too.",
				"Water's \"power ready\" pulse only shows when the power will really make a twin: not while every twin is out, and it comes as soon as a twin is lost if the power was already recharged.",
				"In 2v2 the AI never fires at its teammate (Fire), doesn't jump through it with Static Shock unless it's that or crashing, doesn't aim Static Shock or Storm Fence at it, and drifts away from a teammate up ahead so they don't run into each other.",
"Water's power no longer pulls the snake to the side: only the twins veer off, and you keep steering.",
				"A soft pulse in the snake's color when its power finishes recharging.",
				"Water casting its power makes a small ripple. Crashing makes a burst of shards, and every point gained pops a +1 over the snake.",
			]],
			["Fire", [
				"Phoenix is untouchable for a moment after rising, so it can't die on the spot next to a wall, and it never rises inside a level's wall.",
				"Phoenix no longer triggers in a duel: with a single rival left, the round just ends.",
				"New epic upgrade, Wildfire: the fireball leaves a trail of flames that burns for 2 seconds. It kills other snakes, never you.",
				"Big Fireball now stacks twice instead of three times.",
				"A fireball that hits something bursts into sparks; one whose flight runs out slows down and fizzles away instead, so it no longer looks like it crashed into nothing.",
			]],
			["Earth", [
				"New rare upgrade, Burrower: while the armor lasts, Earth digs through every wall, the level's obstacles and the arena's edges. Be out in the open when it wears off, or you're crushed. An arrow on the edge of the screen shows where you are while you're off the map.",
				"New rare upgrade, Bedrock: the armor and rocky path last 0.25 seconds longer (stacks twice).",
				"Tectonic Bulk is now Epic and Stone Walker Legendary.",
			]],
			["Air", [
				"Static Shock is now Epic and Scrambler Legendary.",
				"New legendary upgrade, Storm Fence: when Air teleports, lightning crackles across every gap in its trail for 1 second (gaps a fireball burnt open don't count). Snakes caught in a gap are electrocuted like by Static Shock: no power for 5 seconds, and with Scrambler their left and right swap for 3 seconds. The AI jumps when an enemy is about to cross one.",
			]],
			["Upgrades", [
				"With fewer than three upgrades left to offer, a Skip card lets you take nothing that round.",
				"The upgrade badges on the scoreboard are sorted by rarity, rarest first, each framed in its rarity's color.",
			]],
			["Instructions", [
				"Power gallery: every base power and upgrade on one screen, a column per element and a row per rarity, with open slots and totals (upgrades and picks, counting stacks) to see where each element stands.",
			]],
			["AI", [
				"The AI sees spinning and sliding walls coming and steers out of their way.",
			]],
			["Player setup", [
				"Match settings moved to the top left corner: Mode and Points to win always in view, everything else under Match settings: Arena, Upgrades, Upgrade pick time, Shrooms, Spawns and Countdown. The online lobby folds them the same way.",
				"Shrooms and Upgrades left the main menu for Match settings. New players start with Upgrades on and Shrooms off.",
				"Player names are editable on each card. Drag a name onto another card to swap elements: the name, keys, AI and selection move together.",
				"Each element shows what its power does in two words, offline and online.",
				"The mouse pointer turns into a text cursor over the name boxes and a move cursor over what can be dragged.",
				"Gamepad keys no longer stretch the player boxes on the upgrade screen.",
			]],
			["Match flow", [
				"There's a countdown before every round, for every mode. Turn it off with the Countdown match setting (the first round always counts down).",
				"The first countdown shows the match's goal, like FREE FOR ALL - FIRST TO 30 - DODGE EVERYTHING.",
				"During the countdown a ring in each snake's color closes in on its head every second, so you know where you start.",
				"Snakes start facing open ground (no wall or level obstacle right ahead, moving walls included) and farther apart.",
				"After a match, the players who picked REMATCH go back to the lobby when not everyone did; the ones who picked QUIT leave (online they leave the session).",
				"The win and stats screens use the players' names.",
				"New stats: Fire's times revived and Earth's crossings of its own trail.",
			]],
			["Play of the game", [
				"The game keeps a short video of the last 10 seconds of play and picks the best moment of the match: kills (more for fireballs and flames), double and triple kills, a Phoenix rising, a twin saving the water snake, Earth's rock stopping a fireball...",
				"After the win screen the play of the game loops, with a ring on the snake it's about, until someone presses PUNCHI (or Enter or a click). Then the match stats.",
			]],
			["Match stats", [
				"Awards: Hunter (most kills), Survivor (most rounds lasted to the end), Longest Trail, Untouchable (least time dead), Marathon (longest single life), Power Hungry, Ghost (most time dead) and First Out. Ties share them.",
				"New Kills line for every snake: crashes into your trail, rocks, fireballs or flames, and kills on snakes you scrambled.",
				"The winner's column gets golden laurels around the corners of its border and two dragons around its symbol.",
				"Each award ribbon has its own symbol (crosshair, shield, trail, sparkle, stopwatch, bolt, ghost, skull), with more room between them.",
			]],
			["Arenas", [
				"Arena rotation: in Match settings, pick which arenas are in the match (a card with a small map of each, click to check it in or out; All and Classic only buttons). Every round plays a random arena from the rotation, never the same one twice in a row, and the countdown names it. Online the host's rotation is used.",
				"Eight new arenas from Jorge's sketches: Crossroads, Twin Blocks, Zigzag, Serpent, Chevrons, Lens, Funnels and Parallels.",
				"Arenas can have shroom spots: in Shroom mode the shrooms only appear there (the new arenas have them). On arenas without spots, shrooms no longer appear inside walls.",
				"Level walls are drawn over the snakes and their trails, so an obstacle always looks solid (Burrower's Earth disappears under them).",
				"New Arena setting with two layouts besides the classic empty arena: Pillars and Windmill, whose walls spin and slide.",
				"Levels are made in the Godot editor: draw walls as polygons, give them a slide or a spin, place starting spots and playtest with F6 (docs/levels.md).",
			]],
			["Menus", [
				"The main menu buttons have the same space above and below their text.",
			]],
			["Online", [
				"Steam only starts when you open Multiplayer and stops when you're back in the main menu, so your friends only see you in-game on Steam while you're playing online.",
				"In the lobby, each of your players has a name box: type the name you go by (up to 16 characters). It's remembered for next time, per key set.",
			]],
			["Accessibility", [
				"New Accessibility tab in Options, all off by default: nameplates under the snakes, a small arrow showing where each snake is heading, and snake eyes that look at the nearest snake (with a forked tongue now and then).",
			]],
		],
	},
	{
		"version": "0.6.0",
		"name": "Victory Lap",
		"date": "2026-11-01",
		"sections": [
			["Win screen", [
				"The winner takes a victory lap behind the win screen: steer your snake with Left and Right, it can't crash and wraps around the edges. In 2v2 the whole winning team gets a lap.",
				"Each element shows off on the lap: Fire throws fireballs four ways every 2 seconds, Earth stays in rocky mode, Air zaps ahead every 1.5 seconds, and Water splits into three twins every 3 seconds, up to nine.",
			]],
			["Match stats", [
				"After the win screen, a stats screen shows a column per snake: trail length, time spent dead and powers used.",
				"Plus a stat or two per element: Fire's fireball kills, fireballs and twins stopped by Earth's rocks, Air's warps through the edge, enemies electrocuted and kills on scrambled foes, and Water's twins summoned and lives saved by a twin.",
				"Each player picks REMATCH or QUIT with their own Left and Right (or the mouse); hold PUNCHI for 2 seconds to go on. If everyone wants a rematch, a new match starts right away with the same snakes and rules; otherwise it's back to the lobby.",
				"Online the stats of every machine are added up, everyone sees the others' picks, and QUIT takes everyone back to the online lobby, still together.",
			]],
		],
	},
	{
		"version": "0.5.1",
		"name": "Twins & Takeovers",
		"date": "2026-10-31",
		"sections": [
			["Water", [
				"Water's twins were rebalanced. You start with one twin at a time: while it lives, the power can't be cast and doesn't go on cooldown.",
				"Extra Twin now lets you keep up to 2 twins, summoned one per cast: cast, wait for the recharge, cast again.",
				"New Epic upgrade, Twin Burst (needs Extra Twin): your power summons twins two at a time, up to your maximum.",
				"New Legendary upgrade, Triplets (needs Twin Burst): keep up to 3 twins alive.",
			]],
			["2v2", [
				"Died while your AI teammate is still alive? Hold PUNCHI for 1 second to take it over for the rest of the round. A faint ring around it fills while you hold.",
				"The scoreboard groups each team into one card: both symbols side by side and a single team score.",
			]],
			["Look", [
				"Trails are now smooth lines instead of a row of stamped dots, and they look the same at any speed: a faster snake no longer leaves a beaded, gappy trail.",
				"Holes burned by a fireball end in clean rounded tips.",
				"Upgrade icons are smaller and wrap into two rows on the scoreboard, so a late-game pile of upgrades no longer pushes the scoreboard or the upgrade screen off screen. If the upgrade screen still doesn't fit, it shrinks to fit.",
				"The mouse pointer fades out after 2 seconds without moving during a match, and comes back as soon as you move it or pause.",
			]],
			["Match flow", [
				"The first round starts with a 3, 2, 1 countdown, with every snake waiting in place.",
				"When the match is won, the final moment stays on screen for 2 seconds before the win screen.",
				"Online, the host can set the upgrade pick time in the lobby (10 seconds by default). Offline it now has its own setting in Options, with a new Off choice that is the default: no countdown, take your time.",
				"New Spawns option (player setup and online lobby): Random puts the snakes anywhere in the arena each round, well apart from each other and the walls and facing roughly inwards. Every round then starts with a 2 second countdown so you can find yourself.",
				"A bit more room between \"First to\" and the arena.",
				"Punchi is now spelled with an \"i\" everywhere.",
			]],
			["Fixes", [
				"The upgrade screen no longer breaks when a snake has no upgrades left to pick; its row shows \"Maxed out\".",
				"Online, the \"+ Upgrade\" text no longer gives away the pick of a rival whose cards are hidden.",
				"Online, another player's Air landing marker could appear frozen after a teleport. It now stays hidden.",
				"Rows with fewer than three cards keep their status lined up with the others.",
				"Online lobby: long player names and key lists no longer push the Keys, Team and Remove buttons off screen.",
			]],
		],
	},
	{
		"version": "0.5.0",
		"name": "Rarities & Wisdom",
		"date": "2026-10-31",
		"sections": [
			["Upgrades", [
				"Upgrades now have a rarity, shown in its color on each card: Common, Uncommon, Rare, Epic and Legendary. Rarer upgrades show up less often.",
				"Some upgrades need another one first (Scrambler needs Static Shock).",
				"New Legendary Fire upgrade, Phoenix: once per round, you rise from your ashes 10 seconds after dying, in a burst that clears the trails and rocks around you. Aim where you'll fly off with Left/Right while you wait.",
				"New Rare Air upgrade, Static Shock: snakes whose heads you teleport through get electrocuted and can't use their power for 5 seconds.",
				"New Epic Air upgrade, Scrambler: your shock also swaps their left and right for 3 seconds.",
				"Tectonic Bulk now makes Earth's rocky path 30% wider.",
				"Wider Gaps is gone.",
				"A quote for the element that won the last round now opens the upgrade screen.",
			]],
			["Powers", [
				"Earth: the rocky path and the invincibility now last the same time, 1.2 seconds. The head no longer grows; it hides while the rocks are laid, and no trail is left on top of them.",
				"Earth: with Stone Walker, your snake is drawn on top of your rocks when you cross them, so you can see where you've already been.",
				"Air: a short grace after teleporting, so you no longer die on the spot you jumped from or landed on.",
				"Air: the landing marker shines when you can jump (power ready or a free second jump) and turns small and faint while it recharges.",
				"Water: the twin now looks like a ghost: see-through aqua with a shimmer running along it. Its trail turns solid after 7 seconds instead of 5, and a glow and a flash show the part that's turning solid.",
				"AI: Air with Static Shock jumps through enemy heads on purpose, and an AI that gets scrambled finds its grip again after 1.5 seconds.",
			]],
			["Online", [
				"Lobbies are public by default. The host can make one private, which hides it from the lobby list and friends lists.",
				"Every lobby has a 6-character code. Copy it from the lobby and share it; others can type it in to join, even if the lobby isn't in the list.",
				"The lobby list scrolls when there are many lobbies.",
			]],
			["Options", [
				"New Options screen with Video, Audio, Gameplay and Controls tabs, usable with keyboard or gamepad.",
				"New settings: VSync, max FPS, an FPS counter, separate Master, Music and Effects volume (now saved), upgrade pick time, the upgrade-screen quotes on or off, and a button to reset all keys.",
				"Volume sliders right in the pause menu.",
			]],
			["Look", [
				"New scoreboard with a card per snake and a \"First to\" target.",
				"New win screen that fills the arena. Hold PUNCHI to go back to the menu.",
				"The arena border is one thin line that marks exactly where snakes die.",
				"Player setup polish: centered element names, bigger Mode and Points buttons, a lighter tint and a glowing border on selected players, and an \"AI player\" badge.",
			]],
			["Fixes", [
				"A fireball hitting Water's twin made the twin's whole trail disappear.",
				"Air's landing marker stayed on screen after Air died.",
				"A dead Water twin kept laying hidden trail under its head.",
				"Powers could still be used, sound included, on the win screen.",
				"Long upgrade descriptions no longer overflow their card.",
			]],
			["Known issues (online)", [
				"While a Phoenix waits to rise, other players see its starting direction, not the one being aimed.",
				"Fireballs can break slightly different trail pieces on each screen, and Earth's stone can be laid slightly differently.",
				"Mushrooms are turned off online, and pausing doesn't stop an online match.",
			]],
		],
	},
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
				"Upgraded Water Punchi.",
				"Added a visual for Punchi ready.",
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
	return TranslationServer.translate("VERSION_LABEL") % [current_version(), TranslationServer.translate("STAGE_" + STAGE.to_upper())]

const MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

# "2026-10-30" -> "Oct 30, 2026"
static func format_date(date: String) -> String:
	var parts = date.split("-")
	if parts.size() != 3:
		return date
	return "%s %d, %s" % [MONTHS[int(parts[1]) - 1], int(parts[2]), parts[0]]
