class_name Powers

const FIRE_SCENE = preload("res://scenes/firepower.tscn")

static func create(element_id: int) -> Power:
	match element_id:
		1:
			var p = FIRE_SCENE.instantiate()
			p.element = 1
			return p
		_:
			# Por ahora para los demás elementos devolvemos null o un Power genérico
			return null
