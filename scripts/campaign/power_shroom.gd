extends Node2D
class_name PowerShroom

# Campaign: a shroom that also gives whoever eats it something for a while (it still counts
# as a shroom: a point, and the "eat shrooms" objective). It's an ordinary shroom
# (shroom.tscn) in the "power_shrooms" group with this glow on it; Player (and a water twin,
# for its snake) calls PowerShroom.apply when eating one. One of:
# - borrow: like Void, the next Punchi also casts another element's power (once)
# - upgrade: a random upgrade of its own for UPGRADE_TIME seconds
# - haste: faster for a few seconds
# - shield: nothing can kill it for a few seconds (like a Phoenix rising)
# - recharge: Punchi ready right away

const SHROOM_SCENE = preload("res://scenes/shroom.tscn")
const UPGRADE_TIME = 15.0
const HASTE_TIME = 6.0
const HASTE_SPEED = 1.35
const SHIELD_TIME = 4.0
const EFFECTS = ["borrow", "upgrade", "haste", "shield", "recharge"]
const ELEMENT_KEYS = {1: "ELEMENT_FIRE_UPPER", 2: "ELEMENT_EARTH_UPPER", 3: "ELEMENT_AIR_UPPER", 4: "ELEMENT_WATER_UPPER"}

var time = 0.0

static func create() -> Node2D:
	var shroom = SHROOM_SCENE.instantiate()
	shroom.add_to_group("Shrooms")
	shroom.add_to_group("power_shrooms")
	shroom.add_child(PowerShroom.new())
	return shroom

func _ready():
	z_index = -1
	var glow = CanvasItemMaterial.new()
	glow.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = glow

func _process(delta):
	time += delta
	queue_redraw()

# A rainbow ring turning around it, so it reads as something more than a shroom
func _draw():
	var radius = 22.0 + 2.0 * sin(time * 5.0)
	for i in 6:
		var start = time * 2.0 + TAU * i / 6.0
		var hue = fposmod(i / 6.0 + time * 0.2, 1.0)
		draw_arc(Vector2.ZERO, radius / max(global_scale.x, 0.001), start, start + 0.8, 10, Color.from_hsv(hue, 0.7, 1.0, 0.9), 3.0 / max(global_scale.x, 0.001), true)

# The snake that ate it gets one of the effects
# (effect: one of EFFECTS; random when empty)
static func apply(snake: Node2D, effect = "") -> void:
	if snake == null or not is_instance_valid(snake) or not "playerId" in snake:
		return
	if effect == "":
		# Online a borrowed power would only go off on this machine
		var choices = EFFECTS.filter(func(e): return e != "borrow" or not Global.isMultiplayerActive)
		effect = choices.pick_random()
	var text = ""
	match effect:
		"borrow":
			var element = [1, 2, 3, 4].filter(func(e): return e != snake.playerId).pick_random()
			var power = Powers.create(element)
			snake.add_child(power)
			power.setup(snake)
			# It stays with the snake (Earth's armor ends with its timer); it's cast once
			var cast = func(_recast, _hold):
				if is_instance_valid(power) and is_instance_valid(snake) and snake.is_processing():
					power.activate()
			snake.power_used.connect(cast, CONNECT_ONE_SHOT)
			text = TranslationServer.translate("CAMPAIGN_FX_BORROW") % TranslationServer.translate(ELEMENT_KEYS[element])
		"upgrade":
			var options = UpgradeCatalog.roll_options(snake.playerId, 1)
			if options.is_empty() or str(options[0].id) == "skip":
				snake.reset_cooldown()
				text = TranslationServer.translate("CAMPAIGN_FX_RECHARGE")
			else:
				var buff = UpgradeCatalog.make_buff(options[0].id)
				_lend(snake, buff, UPGRADE_TIME)
				text = TranslationServer.translate(options[0].name)
		"haste":
			var buff = Buff.new()
			buff.id = &"campaign_haste"
			buff.max_stacks = 3
			buff.stat_mods = {"speed": {"mult": HASTE_SPEED}}
			_lend(snake, buff, HASTE_TIME)
			text = TranslationServer.translate("CAMPAIGN_FX_HASTE")
		"shield":
			snake.phoenix_grace = max(snake.phoenix_grace, SHIELD_TIME)
			text = TranslationServer.translate("CAMPAIGN_FX_SHIELD")
		"recharge":
			snake.reset_cooldown()
			text = TranslationServer.translate("CAMPAIGN_FX_RECHARGE")
	PowerFx.score(snake.get_parent(), snake.global_position, Color(Global.playerColors[snake.playerId]).lightened(0.3), text)

# A buff for a while (the stats outlive the round, so it always runs out)
static func _lend(snake, buff: Buff, seconds: float) -> void:
	var stats = Global.player_stats.get(snake.playerId)
	if stats == null or buff == null:
		return
	stats.add_buff(buff)
	var id = buff.id
	snake.get_tree().create_timer(seconds, false).timeout.connect(func(): stats.remove_buff(id))
