class_name PlayerStats extends RefCounted

signal stats_changed

var base: Dictionary = {
	"speed": 150.0,
	"cooldown": 6.0,            # Igual que el CooldownTimer de player.tscn
	"earth.duration": 1.2,
	"earth.scale": 1.0,         # Ancho del camino de rocas (1 = normal)
	"earth.stone_walk": 0.0,    # 1 = atraviesa sus propias fisuras sin morir
	"fire.radius": 1.0,
	"fire.duration": 2.5,       # Segundos de vuelo; después se desvanece (0 = sin límite)
	"fire.phoenix": 0.0,        # 1 = renace una vez por ronda
	"air.shock": 0.0,           # 1 = electrocuta a quien atraviesa al teletransportarse
	"air.scramble": 0.0,        # 1 = el choque eléctrico también invierte sus controles
	"gap.time": 0.6,
	"air.recast_window": 0.0,   # Segundos para el segundo salto (0 = sin doble salto)
	"air.wall_warp": 0.0,       # 1 = el teletransporte atraviesa las paredes
	"water.copies": 1.0,        # Gemelos por poder
	"water.lasting_twin": 0.0,  # 1 = la estela del gemelo nunca cambia de color
}
var active_buffs: Dictionary = {}

func _init() -> void:
	# El hueco por defecto sale de la opción Gap Size
	base["gap.time"] = Global.gap_time()

func set_stat(key: String, value: float) -> void:
	base[key] = value
	stats_changed.emit()

func add_buff(b: Buff) -> void:
	if active_buffs.has(b.id):
		if active_buffs[b.id].stacks < b.max_stacks:
			active_buffs[b.id].stacks += 1
	else:
		var behavior_instance: BuffBehavior = null
		if b.behavior_script != null:
			behavior_instance = b.behavior_script.new()
			
		active_buffs[b.id] = {
			"buff": b,
			"stacks": 1,
			"behavior": behavior_instance
		}
	stats_changed.emit()

func get_stack_count(buff_id: StringName) -> int:
	if active_buffs.has(buff_id):
		return active_buffs[buff_id].stacks
	return 0

func get_stat(key: String) -> float:
	var default_val: float = base.get(key, 0.0)
	var add: float = 0.0
	var mult: float = 1.0

	for entry in active_buffs.values():
		var b: Buff = entry.buff
		var stacks: int = entry.stacks
		var mod = b.stat_mods.get(key)
		if mod:
			add += mod.get("add", 0.0) * stacks
			mult *= pow(mod.get("mult", 1.0), stacks)

	return (default_val + add) * mult
