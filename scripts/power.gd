class_name Power extends Node

signal activated
signal finished

var player: Node2D   # Referencia al Player
var element: int     # 1: Fuego, 2: Tierra, 3: Aire, 4: Agua, 5: Vacío
## Whose upgrades this power uses: its snake's (null), or, for a power Void absorbed with
## its Epic upgrade, the snake it came from
var stats_source: PlayerStats = null

func _stats() -> PlayerStats:
	return stats_source if stats_source != null else player.stats

# A stat of the upgrades this power uses (see _stats)
func stat(key: String) -> float:
	var s = _stats()
	return s.get_stat(key) if s != null else 0.0

func setup(p: Node2D) -> void:
	player = p

# Lógica pura del poder (NO toca cooldowns del jugador)
func activate() -> void:
	pass

func is_active() -> bool:
	return false

# False blocks the cast before it starts, so it doesn't go on cooldown either
func can_activate() -> bool:
	return true

# Lógica para que la IA decida si usarlo
func ai_should_activate(_direction: int) -> bool:
	return false

# IA: usar una segunda vez gratis (doble salto de Aire)
func ai_should_recast(_direction: int) -> bool:
	return false

# Solo para Agua: intercepta la muerte. Devuelve true si salvó al jugador
func try_prevent_death() -> bool:
	return false
func should_ignore_collision(_area: Area2D) -> bool:
	return false
# Whether the "power ready" pulse makes sense when the cooldown ends (Water: not with
# every twin already out, since the power can't make another)
func should_pulse_ready() -> bool:
	return true

func cleanup() -> void:
	pass
