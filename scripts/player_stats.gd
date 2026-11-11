class_name PlayerStats extends RefCounted

signal stats_changed

var base: Dictionary = {
	"speed": 150.0,
	"cooldown": 5.0,
	"gap.time": 0.6,
	# --- AIRE ---
	"air.recast_window": 0.0,
	"air.shock": 0.0,
	"air.scramble": 0.0,
	"air.storm": 0.0,
	# --- TIERRA ---
	"earth.duration": 1.2,
	"earth.scale": 1.0,
	"earth.burrow": 0.0,
	"earth.walker": 0.0,
	# --- FUEGO ---
	"fire.radius": 1.0,
	"fire.duration": 2.5,
	"fire.trail": 0.0,
	"fire.phoenix": 0.0,
	# --- AGUA ---
	"water.max_twins": 1.0,
	"water.twins_per_cast": 1.0,
	"water.lasting_twin": 0.0,
	# --- VACÍO (VOID - ELEMENTO 5) ---
	"void.duration": 2.0,        # Duración del campo de succión
	"void.radius": 60.0,         # Radio del campo en píxeles
	"void.absorb_time": 4.0,     # Segundos que guarda el poder robado
	"void.keep_upgrades": 0.0,   # Épica: roba con mejoras del rival
	"void.round_absorbs": 0.0,   # Legendaria: poderes duran toda la ronda
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
