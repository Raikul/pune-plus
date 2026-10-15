class_name Powers

const FIRE_SCENE = preload("res://scenes/firepower.tscn")
const EARTH_SCENE = preload("res://scenes/earthpower.tscn")
const AIR_SCENE = preload("res://scenes/airpower.tscn")
const WATER_SCENE = preload("res://scenes/waterpower.tscn")

static func create(element_id: int) -> Power:
	match element_id:
		1:
			var p = FIRE_SCENE.instantiate()
			p.element = 1
			return p
		2:
			var p = EARTH_SCENE.instantiate()
			p.element = 2
			return p
		3:
			var p = AIR_SCENE.instantiate()
			p.element = 3
			return p
		4:
			var p = WATER_SCENE.instantiate()
			p.element = 4
			return p
		_:
			return null
