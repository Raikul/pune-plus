extends RefCounted
class_name CampaignMap

# The roguelike campaign's act: a map of scenarios, one step after another. Each step
# offers two scenarios to pick from (a normal one, and now and then a hard or a special
# one); the last step is the boss. A scenario is a dictionary (saved as JSON):
#   id         its template (TEMPLATES), also its name: CAMPAIGN_SC_<ID>
#   kind       "normal", "hard" (stronger rivals, better upgrade cards), "special" (you play
#              another element with random upgrades), "boss"
#   level      the arena (res://levels/...; "" = the empty classic one)
#   objective  "rounds" (win `need` of `rounds` rounds: your team the last one standing),
#              "survive" (stay alive `target` seconds, `need` of `rounds` rounds),
#              "shrooms" (eat `target` shrooms between you, within `rounds` rounds),
#              "kills" (`target` rival snakes die, within `rounds` rounds),
#              "boss" (outlast the Medusa)
#   enemies    how many AI rivals (the elements nobody plays; at most 4 snakes in all)
#   enemy_upgrades  random upgrades each rival starts with
#   shrooms    score shrooms show up (only the "shrooms" objective has them, Campaign.shrooms); power_shrooms: shrooms with a temporary power too
#   swap       special: every player plays another element, with random upgrades

const STEPS = 8 # Steps before the boss (9 scenarios in all)

const TEMPLATES = [
	{"id": "skirmish", "objective": "rounds", "level": "", "rounds": 3, "need": 2},
	{"id": "pillars", "objective": "kills", "level": "res://levels/pillars.tscn", "target": 3, "rounds": 4},
	{"id": "harvest", "objective": "shrooms", "level": "res://levels/crossroads.tscn", "target": 5, "rounds": 3, "shrooms": true},
	{"id": "siege", "objective": "survive", "level": "res://levels/lens.tscn", "target": 25, "rounds": 3, "need": 2, "extra_enemies": 1},
	{"id": "fungal", "objective": "rounds", "level": "res://levels/windmill.tscn", "rounds": 3, "need": 2, "power_shrooms": true},
	{"id": "maze", "objective": "rounds", "level": "res://levels/zigzag.tscn", "rounds": 3, "need": 2},
	{"id": "serpent", "objective": "kills", "level": "res://levels/serpent.tscn", "target": 4, "rounds": 4},
	{"id": "chevrons", "objective": "survive", "level": "res://levels/chevrons.tscn", "target": 30, "rounds": 3, "need": 2},
	{"id": "parallels", "objective": "shrooms", "level": "res://levels/parallels.tscn", "target": 6, "rounds": 3, "shrooms": true, "power_shrooms": true},
	{"id": "gauntlet", "kind": "hard", "objective": "kills", "level": "res://levels/funnels.tscn", "target": 5, "rounds": 4, "extra_enemies": 1},
	{"id": "arena", "kind": "hard", "objective": "rounds", "level": "res://levels/twin_blocks.tscn", "rounds": 3, "need": 2},
	{"id": "mirror", "kind": "special", "objective": "rounds", "level": "", "rounds": 3, "need": 2, "swap": true},
	{"id": "stranger", "kind": "special", "objective": "survive", "level": "res://levels/crossroads.tscn", "target": 25, "rounds": 3, "need": 2, "swap": true, "power_shrooms": true},
]

const BOSS = {"id": "medusa", "kind": "boss", "objective": "boss", "level": "", "rounds": 1, "need": 1, "power_shrooms": true}

static func template(id) -> Dictionary:
	for entry in TEMPLATES:
		if entry.id == id:
			return entry
	return BOSS if id == BOSS.id else {}

# The act for a new campaign: STEPS steps of two scenarios, then the boss. humans: how
# many players (fewer rivals fit with more players).
static func generate(rng_seed: int, humans: int) -> Array:
	var rng = RandomNumberGenerator.new()
	rng.seed = rng_seed
	var normal = TEMPLATES.filter(func(t): return t.get("kind", "normal") == "normal")
	var harder = TEMPLATES.filter(func(t): return t.get("kind", "normal") != "normal")
	var steps = []
	for step in STEPS:
		var options = []
		# Steps 3 and 6 (and the second half now and then) offer a hard or special path
		var spicy = step == 2 or step == 5 or (step >= 4 and rng.randf() < 0.35)
		var used = []
		for i in 2:
			var pool = harder if (spicy and i == 1) else normal
			var choice = _pick(rng, pool, used + _recent(steps))
			used.append(choice.id)
			options.append(_scenario(choice, step, humans, rng))
		steps.append(options)
	steps.append([_scenario(BOSS, STEPS, humans, rng)])
	return steps

# Ids of the last step's scenarios (so the next step offers something else)
static func _recent(steps) -> Array:
	return steps.back().map(func(s): return s.id) if not steps.is_empty() else []

static func _pick(rng, pool, avoid) -> Dictionary:
	var fresh = pool.filter(func(t): return not t.id in avoid)
	if fresh.is_empty():
		fresh = pool
	return fresh[rng.randi_range(0, fresh.size() - 1)]

# A scenario from its template, tuned to how far into the act it is
static func _scenario(base: Dictionary, step: int, humans: int, rng) -> Dictionary:
	var scenario = base.duplicate(true)
	scenario.kind = base.get("kind", "normal")
	scenario.step = step
	var room = Global.MAX_SNAKES - humans
	if scenario.kind == "boss":
		scenario.enemies = 0
	else:
		var enemies = 1 + int(step >= 2) + int(step >= 5) + base.get("extra_enemies", 0)
		scenario.enemies = clampi(enemies, 1, max(room, 1))
	var upgrades = int(step / 2)
	if scenario.kind == "hard":
		upgrades += 2
	scenario.enemy_upgrades = upgrades
	# Targets grow a little through the act
	if scenario.objective == "kills" or scenario.objective == "shrooms":
		scenario.target = base.target + int(step / 3)
	elif scenario.objective == "survive":
		scenario.target = base.target + 5 * int(step / 3)
	for key in ["shrooms", "power_shrooms", "swap"]:
		scenario[key] = base.get(key, false)
	scenario.need = base.get("need", 1)
	scenario.erase("extra_enemies")
	return scenario
