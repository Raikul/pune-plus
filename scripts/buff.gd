class_name Buff extends Resource

enum Rarity { COMMON, RARE, EPIC }

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
@export var rarity: Rarity = Rarity.COMMON
@export var element: int = -1             # -1 = Cualquier serpiente, 1..4 = Solo ese elemento
@export var max_stacks: int = 3
@export var requires: Array[StringName] = []

@export var stat_mods: Dictionary = {}
@export var behavior_script: Script
