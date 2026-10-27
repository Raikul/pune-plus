class_name BuffBehavior extends RefCounted

func on_power_activated(_player, _stacks: int) -> void:
	pass

func on_death(_player, _stacks: int) -> bool:
	return false
