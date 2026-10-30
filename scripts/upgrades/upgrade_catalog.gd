extends RefCounted
class_name UpgradeCatalog

# Placeholder upgrade pool for the between-rounds upgrade screen.
# "element" is "generic" (any snake) or the element of the only snake that can pick it.
# "icon" selects the animation drawn by UpgradeIcon.

const PLAYER_ELEMENTS = {1: "fire", 2: "earth", 3: "air", 4: "water"}

const UPGRADES = [
	{
		"id": &"gap_wider",
		"name": "Wider Gaps",
		"description": "The holes in your trail stay open longer.",
		"element": "generic",
		"icon": "gap_wide",
	},
	{
		"id": &"gap_tighter",
		"name": "Tighter Trail",
		"description": "The holes in your trail close sooner.",
		"element": "generic",
		"icon": "gap_narrow",
	},
	{
		"id": &"speed_up",
		"name": "Swift Snake",
		"description": "Your snake moves faster.",
		"element": "generic",
		"icon": "speed",
	},
	{
		"id": &"cooldown_down",
		"name": "Quick Recharge",
		"description": "Your power is ready again sooner.",
		"element": "generic",
		"icon": "cooldown",
	},
	{
		"id": &"fire_piercing",
		"name": "Piercing Flame",
		"description": "Your fireball burns through more of the trail.",
		"element": "fire",
		"icon": "fireball",
	},
	{
		"id": &"fire_radius",
		"name": "Big Fireball",
		"description": "Increases the radius of your fireball.",
		"element": "fire",
		"icon": "fireball_big",
	},
	{
		"id": &"air_wall_warp",
		"name": "Wall Warp",
		"description": "Your teleport can pass through the arena walls.",
		"element": "air",
		"icon": "wall_warp",
	},
	{
		"id": &"air_second_wind",
		"name": "Second Wind",
		"description": "After teleporting, teleport once more within 1 second.",
		"element": "air",
		"icon": "second_wind",
	},
	{
		"id": &"earth_wide_body",
		"name": "Tectonic Bulk",
		"description": "Your collision gets wider while your power is active.",
		"element": "earth",
		"icon": "wide_body",
	},
	{
		"id": &"water_extra_copy",
		"name": "Extra Twin",
		"description": "Your power creates one more copy of your snake.",
		"element": "water",
		"icon": "extra_copy",
	},
	{
		"id": &"water_lasting_twin",
		"name": "Lasting Twin",
		"description": "Your twin's trail never sheds: it stays aqua and never blocks you.",
		"element": "water",
		"icon": "lasting_twin",
	},
]

static func get_upgrade(upgrade_id) -> Dictionary:
	for upgrade in UPGRADES:
		if upgrade.id == upgrade_id:
			return upgrade
	return {}

static func element_for_player(player_id) -> String:
	return PLAYER_ELEMENTS.get(player_id, "generic")

static func pool_for_player(player_id) -> Array:
	var element = element_for_player(player_id)
	return UPGRADES.filter(func(upgrade): return upgrade.element == "generic" or upgrade.element == element)

# Random options for one snake, always including at least one upgrade of its own element.
static func roll_options(player_id, count = 3) -> Array:
	var element = element_for_player(player_id)
	var pool = pool_for_player(player_id)
	pool.shuffle()
	var options = []
	for upgrade in pool:
		if upgrade.element == element:
			options.append(upgrade)
			break
	for upgrade in pool:
		if options.size() >= count:
			break
		if not options.has(upgrade):
			options.append(upgrade)
	options.shuffle()
	return options
