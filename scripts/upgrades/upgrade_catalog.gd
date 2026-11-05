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
# "name" and "description" (and the rarities' names) are translation keys: UPG_<ID> and
# UPG_<ID>_DESC in translations/strings.csv. Show them with tr().

const PLAYER_ELEMENTS = {1: "fire", 2: "earth", 3: "air", 4: "water"}

# weight: how likely an upgrade of that rarity is to be offered, relative to the others
const RARITIES = {
	"common": {"name": "RARITY_COMMON", "color": Color(0.72, 0.72, 0.72), "weight": 40.0},
	"uncommon": {"name": "RARITY_UNCOMMON", "color": Color(0.35, 0.85, 0.35), "weight": 26.0},
	"rare": {"name": "RARITY_RARE", "color": Color(0.3, 0.6, 1.0), "weight": 18.0},
	"epic": {"name": "RARITY_EPIC", "color": Color(0.7, 0.35, 0.95), "weight": 9.0},
	"legendary": {"name": "RARITY_LEGENDARY", "color": Color(1.0, 0.6, 0.1), "weight": 4.0},
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
		"name": "UPG_GAP_TIGHTER",
		"description": "UPG_GAP_TIGHTER_DESC",
		"element": "generic",
		"icon": "gap_narrow",
		"stat_mods": {"gap.time": {"mult": 0.75}},
		"max_stacks": 3,
	},
	{
		"id": &"speed_up",
		"rarity": "common",
		"name": "UPG_SPEED_UP",
		"description": "UPG_SPEED_UP_DESC",
		"element": "generic",
		"icon": "speed",
		"stat_mods": {"speed": {"add": 15.0}},
		"max_stacks": 3,
	},
	{
		"id": &"cooldown_down",
		"rarity": "uncommon",
		"name": "UPG_COOLDOWN_DOWN",
		"description": "UPG_COOLDOWN_DOWN_DESC",
		"element": "generic",
		"icon": "cooldown",
		"stat_mods": {"cooldown": {"mult": 0.85}},
		"max_stacks": 3,
	},
	{
		"id": &"fire_piercing",
		"rarity": "rare",
		"name": "UPG_FIRE_PIERCING",
		"description": "UPG_FIRE_PIERCING_DESC",
		"element": "fire",
		"icon": "fireball",
		"stat_mods": {"fire.duration": {"add": 1.5}},
		"max_stacks": 2,
	},
	{
		"id": &"fire_radius",
		"rarity": "rare",
		"name": "UPG_FIRE_RADIUS",
		"description": "UPG_FIRE_RADIUS_DESC",
		"element": "fire",
		"icon": "fireball_big",
		"stat_mods": {"fire.radius": {"add": 0.3}},
		"max_stacks": 2,
	},
	{
		"id": &"fire_wildfire",
		"rarity": "epic",
		"name": "UPG_FIRE_WILDFIRE",
		"description": "UPG_FIRE_WILDFIRE_DESC",
		"element": "fire",
		"icon": "wildfire",
		"stat_mods": {"fire.trail": {"add": 1.0}},
		"max_stacks": 1,
	},
	{
		"id": &"fire_phoenix",
		"rarity": "legendary",
		"name": "UPG_FIRE_PHOENIX",
		"description": "UPG_FIRE_PHOENIX_DESC",
		"element": "fire",
		"icon": "phoenix",
		"stat_mods": {"fire.phoenix": {"add": 1.0}},
		"max_stacks": 1,
	},
	{
		"id": &"air_wall_warp",
		"rarity": "rare",
		"name": "UPG_AIR_WALL_WARP",
		"description": "UPG_AIR_WALL_WARP_DESC",
		"element": "air",
		"icon": "wall_warp",
		"stat_mods": {"air.wall_warp": {"add": 1.0}},
		"max_stacks": 1,
	},
	{
		"id": &"air_second_wind",
		"rarity": "rare",
		"name": "UPG_AIR_SECOND_WIND",
		"description": "UPG_AIR_SECOND_WIND_DESC",
		"element": "air",
		"icon": "second_wind",
		"stat_mods": {"air.recast_window": {"add": 1.0}},
		"max_stacks": 1,
	},
	{
		"id": &"air_shock",
		"rarity": "epic",
		"name": "UPG_AIR_SHOCK",
		"description": "UPG_AIR_SHOCK_DESC",
		"element": "air",
		"icon": "shock",
		"stat_mods": {"air.shock": {"add": 1.0}},
		"max_stacks": 1,
	},
	{
		"id": &"air_scramble",
		"rarity": "legendary",
		"name": "UPG_AIR_SCRAMBLE",
		"description": "UPG_AIR_SCRAMBLE_DESC",
		"element": "air",
		"icon": "scramble",
		"stat_mods": {"air.scramble": {"add": 1.0}},
		"max_stacks": 1,
		"requires": &"air_shock",
	},
	{
		"id": &"air_storm_fence",
		"rarity": "legendary",
		"name": "UPG_AIR_STORM_FENCE",
		"description": "UPG_AIR_STORM_FENCE_DESC",
		"element": "air",
		"icon": "storm_fence",
		"stat_mods": {"air.storm": {"add": 1.0}},
		"max_stacks": 1,
	},
	{
		"id": &"earth_wide_body",
		"rarity": "epic",
		"name": "UPG_EARTH_WIDE_BODY",
		"description": "UPG_EARTH_WIDE_BODY_DESC",
		"element": "earth",
		"icon": "wide_body",
		"stat_mods": {"earth.scale": {"add": 0.3}},
		"max_stacks": 2,
	},
	{
		"id": &"earth_stone_walk",
		"rarity": "legendary",
		"name": "UPG_EARTH_STONE_WALK",
		"description": "UPG_EARTH_STONE_WALK_DESC",
		"element": "earth",
		"icon": "stone_walk",
		"stat_mods": {"earth.stone_walk": {"add": 1.0}},
		"max_stacks": 1,
	},
	{
		"id": &"earth_burrower",
		"rarity": "rare",
		"name": "UPG_EARTH_BURROWER",
		"description": "UPG_EARTH_BURROWER_DESC",
		"element": "earth",
		"icon": "burrower",
		"stat_mods": {"earth.border_pass": {"add": 1.0}},
		"max_stacks": 1,
	},
	{
		"id": &"earth_bedrock",
		"rarity": "rare",
		"name": "UPG_EARTH_BEDROCK",
		"description": "UPG_EARTH_BEDROCK_DESC",
		"element": "earth",
		"icon": "bedrock",
		"stat_mods": {"earth.duration": {"add": 0.25}},
		"max_stacks": 2,
	},
	{
		"id": &"water_extra_copy",
		"rarity": "rare",
		"name": "UPG_WATER_EXTRA_COPY",
		"description": "UPG_WATER_EXTRA_COPY_DESC",
		"element": "water",
		"icon": "extra_copy",
		"stat_mods": {"water.max_twins": {"add": 1.0}},
		"max_stacks": 1,
	},
	{
		"id": &"water_twin_burst",
		"rarity": "epic",
		"name": "UPG_WATER_TWIN_BURST",
		"description": "UPG_WATER_TWIN_BURST_DESC",
		"element": "water",
		"icon": "twin_burst",
		"stat_mods": {"water.twins_per_cast": {"add": 1.0}},
		"max_stacks": 1,
		"requires": &"water_extra_copy",
	},
	{
		"id": &"water_third_twin",
		"rarity": "legendary",
		"name": "UPG_WATER_THIRD_TWIN",
		"description": "UPG_WATER_THIRD_TWIN_DESC",
		"element": "water",
		"icon": "third_twin",
		"stat_mods": {"water.max_twins": {"add": 1.0}},
		"max_stacks": 1,
		"requires": &"water_twin_burst",
	},
	{
		"id": &"water_lasting_twin",
		"rarity": "rare",
		"name": "UPG_WATER_LASTING_TWIN",
		"description": "UPG_WATER_LASTING_TWIN_DESC",
		"element": "water",
		"icon": "lasting_twin",
		"stat_mods": {"water.lasting_twin": {"add": 1.0}},
		"max_stacks": 1,
	},
]

# Offered as an extra card when a snake has fewer than 3 upgrades left: take nothing
const SKIP = {
	"id": &"skip",
	"rarity": "common",
	"name": "UPG_SKIP",
	"description": "UPG_SKIP_DESC",
	"element": "generic",
	"icon": "skip",
}

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
			and stacks_for(player_id, upgrade.id) < upgrade.get("max_stacks", 1) \
			and (not upgrade.has("requires") or stacks_for(player_id, upgrade.requires) > 0))

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
	buff.display_name = TranslationServer.translate(upgrade.name)
	buff.description = TranslationServer.translate(upgrade.description)
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
	shown.name = "%s %d/%d" % [TranslationServer.translate(upgrade.name), stacks_for(player_id, upgrade.id) + 1, max_stacks]
	return shown
