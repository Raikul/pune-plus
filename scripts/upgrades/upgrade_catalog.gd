extends RefCounted
class_name UpgradeCatalog

# Upgrades offered on the between-rounds screen. A pick becomes a Buff on that
# snake's PlayerStats (Global.player_stats) and lasts for the rest of the match.
# "element" is "generic" (any snake) or the element of the only snake that can pick it.
# "icon" selects the animation drawn by UpgradeIcon.
# "stat_mods" uses PlayerStats keys: {"stat": {"add": x}} or {"stat": {"mult": x}}, per stack.
# "max_stacks" is how many times a snake can take it; at the limit it stops being offered.
# "enabled": false keeps an upgrade out of the rolls until it does something.
# "rarity" (RARITIES) sets how often it is offered and its color on the card.
# "requires": the id of an upgrade the snake must already have.

const PLAYER_ELEMENTS = {1: "fire", 2: "earth", 3: "air", 4: "water"}

# weight: how likely an upgrade of that rarity is to be offered, relative to the others
const RARITIES = {
	"common": {"name": "Common", "color": Color(0.72, 0.72, 0.72), "weight": 40.0},
	"uncommon": {"name": "Uncommon", "color": Color(0.35, 0.85, 0.35), "weight": 26.0},
	"rare": {"name": "Rare", "color": Color(0.3, 0.6, 1.0), "weight": 18.0},
	"epic": {"name": "Epic", "color": Color(0.7, 0.35, 0.95), "weight": 9.0},
	"legendary": {"name": "Legendary", "color": Color(1.0, 0.6, 0.1), "weight": 4.0},
}

static func rarity_of(upgrade) -> Dictionary:
	return RARITIES.get(upgrade.get("rarity", "common"), RARITIES.common)

const UPGRADES = [
	# Wider Gaps: of no real use, kept out of the game for now
#	{
#		"id": &"gap_wider",
#		"name": "Wider Gaps",
#		"description": "The holes in your trail stay open 30% longer.",
#		"element": "generic",
#		"icon": "gap_wide",
#		"stat_mods": {"gap.time": {"mult": 1.3}},
#		"max_stacks": 3,
#	},
	{
		"id": &"gap_tighter",
		"rarity": "common",
		"name": "Tighter Trail",
		"description": "The holes in your trail close 25% sooner.",
		"element": "generic",
		"icon": "gap_narrow",
		"stat_mods": {"gap.time": {"mult": 0.75}},
		"max_stacks": 3,
	},
	{
		"id": &"speed_up",
		"rarity": "common",
		"name": "Swift Snake",
		"description": "Your snake moves 10% faster.",
		"element": "generic",
		"icon": "speed",
		"stat_mods": {"speed": {"add": 15.0}},
		"max_stacks": 3,
	},
	{
		"id": &"cooldown_down",
		"rarity": "uncommon",
		"name": "Quick Recharge",
		"description": "Your power recharges 15% faster.",
		"element": "generic",
		"icon": "cooldown",
		"stat_mods": {"cooldown": {"mult": 0.85}},
		"max_stacks": 3,
	},
	{
		"id": &"fire_piercing",
		"rarity": "rare",
		"name": "Piercing Flame",
		"description": "Your fireball flies 1.5 s longer, burning through more of the trail.",
		"element": "fire",
		"icon": "fireball",
		"stat_mods": {"fire.duration": {"add": 1.5}},
		"max_stacks": 2,
	},
	{
		"id": &"fire_radius",
		"rarity": "rare",
		"name": "Big Fireball",
		"description": "Your fireball is 30% bigger.",
		"element": "fire",
		"icon": "fireball_big",
		"stat_mods": {"fire.radius": {"add": 0.3}},
		"max_stacks": 3,
	},
	{
		"id": &"fire_phoenix",
		"rarity": "legendary",
		"name": "Phoenix",
		"description": "Once per round, rise from your ashes 10 s after dying, in a burst that clears the trails around you. Aim with Left/Right.",
		"element": "fire",
		"icon": "phoenix",
		"stat_mods": {"fire.phoenix": {"add": 1.0}},
		"max_stacks": 1,
	},
	{
		"id": &"air_wall_warp",
		"rarity": "rare",
		"name": "Wall Warp",
		"description": "Your teleport passes through the arena walls and comes out on the other side.",
		"element": "air",
		"icon": "wall_warp",
		"stat_mods": {"air.wall_warp": {"add": 1.0}},
		"max_stacks": 1,
	},
	{
		"id": &"air_second_wind",
		"rarity": "rare",
		"name": "Second Wind",
		"description": "After teleporting, teleport once more for free within 1 second.",
		"element": "air",
		"icon": "second_wind",
		"stat_mods": {"air.recast_window": {"add": 1.0}},
		"max_stacks": 1,
	},
	{
		"id": &"air_shock",
		"rarity": "rare",
		"name": "Static Shock",
		"description": "Snakes whose heads you teleport through are electrocuted: no power for 5 s.",
		"element": "air",
		"icon": "shock",
		"stat_mods": {"air.shock": {"add": 1.0}},
		"max_stacks": 1,
	},
	{
		"id": &"air_scramble",
		"rarity": "epic",
		"name": "Scrambler",
		"description": "Your shock also swaps their left and right for 3 s.",
		"element": "air",
		"icon": "scramble",
		"stat_mods": {"air.scramble": {"add": 1.0}},
		"max_stacks": 1,
		"requires": &"air_shock",
	},
	{
		"id": &"earth_wide_body",
		"rarity": "rare",
		"name": "Tectonic Bulk",
		"description": "Your rocky path is 30% wider: more ground for you, more wall for them.",
		"element": "earth",
		"icon": "wide_body",
		"stat_mods": {"earth.scale": {"add": 0.3}},
		"max_stacks": 2,
	},
	{
		"id": &"earth_stone_walk",
		"rarity": "rare",
		"name": "Stone Walker",
		"description": "You walk through your own stone walls. They still stop everyone else.",
		"element": "earth",
		"icon": "stone_walk",
		"stat_mods": {"earth.stone_walk": {"add": 1.0}},
		"max_stacks": 1,
	},
	{
		"id": &"water_extra_copy",
		"rarity": "rare",
		"name": "Extra Twin",
		"description": "Your power creates one more copy of your snake.",
		"element": "water",
		"icon": "extra_copy",
		"stat_mods": {"water.copies": {"add": 1.0}},
		"max_stacks": 1,
	},
	{
		"id": &"water_lasting_twin",
		"rarity": "rare",
		"name": "Lasting Twin",
		"description": "Your twin's trail never sheds: it stays aqua and never blocks you.",
		"element": "water",
		"icon": "lasting_twin",
		"stat_mods": {"water.lasting_twin": {"add": 1.0}},
		"max_stacks": 1,
	},
]

static func get_upgrade(upgrade_id) -> Dictionary:
	for upgrade in UPGRADES:
		if upgrade.id == upgrade_id:
			return upgrade
	return {}

static func element_for_player(player_id) -> String:
	return PLAYER_ELEMENTS.get(player_id, "generic")

# Upgrades this snake can still take: its element or generic, enabled, and below max_stacks
static func pool_for_player(player_id) -> Array:
	var element = element_for_player(player_id)
	return UPGRADES.filter(func(upgrade):
		return (upgrade.element == "generic" or upgrade.element == element) \
			and upgrade.get("enabled", true) \
			and stacks_for(player_id, upgrade.id) < upgrade.get("max_stacks", 1) 			and (not upgrade.has("requires") or stacks_for(player_id, upgrade.requires) > 0))

static func stacks_for(player_id, upgrade_id) -> int:
	var stats = Global.player_stats.get(player_id)
	return stats.get_stack_count(upgrade_id) if stats != null else 0

# The Buff a pick adds to the snake's PlayerStats
static func make_buff(upgrade_id) -> Buff:
	var upgrade = get_upgrade(upgrade_id)
	if upgrade.is_empty():
		return null
	var buff = Buff.new()
	buff.id = upgrade.id
	buff.display_name = upgrade.name
	buff.description = upgrade.description
	buff.element = PLAYER_ELEMENTS.find_key(upgrade.element) if upgrade.element != "generic" else -1
	buff.max_stacks = upgrade.get("max_stacks", 1)
	buff.stat_mods = upgrade.get("stat_mods", {})
	return buff

# Random options for one snake, always including at least one upgrade of its own element.
# Rarer upgrades are less likely to come up (RARITIES weight).
static func roll_options(player_id, count = 3) -> Array:
	var element = element_for_player(player_id)
	var pool = pool_for_player(player_id)
	var options = []
	var own = pool.filter(func(upgrade): return upgrade.element == element)
	if not own.is_empty():
		var first = _weighted_pick(own)
		options.append(first)
		pool.erase(first)
	while options.size() < count and not pool.is_empty():
		var upgrade = _weighted_pick(pool)
		options.append(upgrade)
		pool.erase(upgrade)
	options.shuffle()
	return options.map(func(upgrade): return _with_level(player_id, upgrade))

static func _weighted_pick(upgrades: Array) -> Dictionary:
	var total = 0.0
	for upgrade in upgrades:
		total += rarity_of(upgrade).weight
	var roll = randf() * total
	for upgrade in upgrades:
		roll -= rarity_of(upgrade).weight
		if roll <= 0.0:
			return upgrade
	return upgrades.back()

# Online: the options the host rolled, by id
static func options_from_ids(player_id, ids: Array) -> Array:
	var options = []
	for upgrade_id in ids:
		var upgrade = get_upgrade(StringName(upgrade_id))
		if not upgrade.is_empty():
			options.append(_with_level(player_id, upgrade))
	return options

# Shows the level of upgrades that stack, e.g. "Swift Snake 2/3"
static func _with_level(player_id, upgrade) -> Dictionary:
	var max_stacks = upgrade.get("max_stacks", 1)
	if max_stacks <= 1:
		return upgrade
	var shown = upgrade.duplicate()
	shown.name = "%s %d/%d" % [upgrade.name, stacks_for(player_id, upgrade.id) + 1, max_stacks]
	return shown
