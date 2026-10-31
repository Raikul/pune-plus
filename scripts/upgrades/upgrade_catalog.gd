extends RefCounted
class_name UpgradeCatalog

# Upgrades offered on the between-rounds screen. A pick becomes a Buff on that
# snake's PlayerStats (Global.player_stats) and lasts for the rest of the match.
# "element" is "generic" (any snake) or the element of the only snake that can pick it.
# "icon" selects the animation drawn by UpgradeIcon.
# "stat_mods" uses PlayerStats keys: {"stat": {"add": x}} or {"stat": {"mult": x}}, per stack.
# "max_stacks" is how many times a snake can take it; at the limit it stops being offered.
# "enabled": false keeps an upgrade out of the rolls until it does something.

const PLAYER_ELEMENTS = {1: "fire", 2: "earth", 3: "air", 4: "water"}

const UPGRADES = [
	{
		"id": &"gap_wider",
		"name": "Wider Gaps",
		"description": "The holes in your trail stay open 30% longer.",
		"element": "generic",
		"icon": "gap_wide",
		"stat_mods": {"gap.time": {"mult": 1.3}},
		"max_stacks": 3,
	},
	{
		"id": &"gap_tighter",
		"name": "Tighter Trail",
		"description": "The holes in your trail close 25% sooner.",
		"element": "generic",
		"icon": "gap_narrow",
		"stat_mods": {"gap.time": {"mult": 0.75}},
		"max_stacks": 3,
	},
	{
		"id": &"speed_up",
		"name": "Swift Snake",
		"description": "Your snake moves 10% faster.",
		"element": "generic",
		"icon": "speed",
		"stat_mods": {"speed": {"add": 15.0}},
		"max_stacks": 3,
	},
	{
		"id": &"cooldown_down",
		"name": "Quick Recharge",
		"description": "Your power recharges 15% faster.",
		"element": "generic",
		"icon": "cooldown",
		"stat_mods": {"cooldown": {"mult": 0.85}},
		"max_stacks": 3,
	},
	{
		"id": &"fire_piercing",
		"name": "Piercing Flame",
		"description": "Your fireball flies 1.5 s longer, burning through more of the trail.",
		"element": "fire",
		"icon": "fireball",
		"stat_mods": {"fire.duration": {"add": 1.5}},
		"max_stacks": 2,
	},
	{
		"id": &"fire_radius",
		"name": "Big Fireball",
		"description": "Your fireball is 30% bigger.",
		"element": "fire",
		"icon": "fireball_big",
		"stat_mods": {"fire.radius": {"add": 0.3}},
		"max_stacks": 3,
	},
	{
		"id": &"air_wall_warp",
		"name": "Wall Warp",
		"description": "Your teleport passes through the arena walls and comes out on the other side.",
		"element": "air",
		"icon": "wall_warp",
		"stat_mods": {"air.wall_warp": {"add": 1.0}},
		"max_stacks": 1,
	},
	{
		"id": &"air_second_wind",
		"name": "Second Wind",
		"description": "After teleporting, teleport once more for free within 1 second.",
		"element": "air",
		"icon": "second_wind",
		"stat_mods": {"air.recast_window": {"add": 1.0}},
		"max_stacks": 1,
	},
	{
		"id": &"earth_wide_body",
		"name": "Tectonic Bulk",
		"description": "Your head grows 25% bigger while your power is active.",
		"element": "earth",
		"icon": "wide_body",
		"stat_mods": {"earth.scale": {"add": 0.5}},
		"max_stacks": 2,
	},
	{
		"id": &"water_extra_copy",
		"name": "Extra Twin",
		"description": "Your power creates one more copy of your snake.",
		"element": "water",
		"icon": "extra_copy",
		"stat_mods": {"water.copies": {"add": 1.0}},
		"max_stacks": 1,
	},
	{
		"id": &"water_lasting_twin",
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
			and stacks_for(player_id, upgrade.id) < upgrade.get("max_stacks", 1))

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
	return options.map(func(upgrade): return _with_level(player_id, upgrade))

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
