class_name Power extends Node

signal activated
signal finished

var player: Node2D   # Referencia al Player
var element: int     # 1: Fuego, 2: Tierra, 3: Aire, 4: Agua

func setup(p: Node2D) -> void:
	player = p

# Lógica pura del poder (NO toca cooldowns del jugador)
func activate() -> void:
	pass

func is_active() -> bool:
	return false

# Lógica para que la IA decida si usarlo
func ai_should_activate(_direction: int) -> bool:
	return false

# Solo para Agua: intercepta la muerte. Devuelve true si salvó al jugador
func try_prevent_death() -> bool:
	return false

func cleanup() -> void:
	pass
