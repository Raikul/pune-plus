extends Node2D
class_name Fissure

var texture_path = "res://assets/jorge-resources/Powers/Earth/"
@onready var fissure_rect: TextureRect = $FissureBody
var _fissure_step: = 1
var delta_sum : float = 0
var next_created := false
var fissure_gap := 0.1
var maximum_step_number := 8
var available_bodies : Array
var available_ends : Array
signal fissure_ready(step)

# The stone is solid like a trail: snakes that touch it die (Earth too, unless it has
# the Stone Walker upgrade) and the fireball crashes on it. Only the drawn rock collides,
# not the transparent gaps between the rocks.
static var _outlines = {} # texture path -> rock outlines in texture pixels

func _ready() -> void:
	_add_wall.call_deferred()

func _add_wall() -> void:
	var texture = fissure_rect.texture
	var area = Area2D.new()
	area.collision_mask = 0
	area.add_to_group("Fissures")
	var pixel_scale = fissure_rect.size * fissure_rect.scale / Vector2(texture.get_size())
	for outline in _rock_outlines(texture):
		var points = PackedVector2Array()
		for point in outline:
			if fissure_rect.flip_h:
				point.x = texture.get_width() - point.x
			if fissure_rect.flip_v:
				point.y = texture.get_height() - point.y
			points.append(fissure_rect.position + point * pixel_scale)
		var shape = CollisionPolygon2D.new()
		shape.polygon = points
		area.add_child(shape)
	add_child(area)

static func _rock_outlines(texture) -> Array:
	if _outlines.has(texture.resource_path):
		return _outlines[texture.resource_path]
	var image = texture.get_image()
	if image.is_compressed():
		image.decompress()
	var bitmap = BitMap.new()
	bitmap.create_from_image_alpha(image, 0.5)
	var outlines = []
	for outline in bitmap.opaque_to_polygons(Rect2i(Vector2i.ZERO, image.get_size()), 2.0):
		# A little inside the art, so grazing the jagged edges doesn't kill
		for shrunk in Geometry2D.offset_polygon(outline, -4.0):
			if shrunk.size() >= 3:
				outlines.append(shrunk)
	_outlines[texture.resource_path] = outlines
	return outlines


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta: float) -> void:
	delta_sum += delta
	if delta_sum >= fissure_gap and !next_created:
		next_created = true
		emit_signal("fissure_ready", _fissure_step + 1)

func set_body(fissure_step: int, body_list = []) -> Array:
	if fissure_step == 1:
		var index = 1
		while index < maximum_step_number:
			available_bodies.append(index)
			index += 1
		#index = 0
		#while index < 4:
			#available_ends.append(index)
			#index += 1
		
	if body_list!=[]:
		available_bodies = body_list
	_fissure_step = fissure_step
	#var random_end = available_ends[randi_range(0,available_ends.size())]
	var random_end = randi_range(1,4)
	if fissure_step == 1 or fissure_step == maximum_step_number:
		$FissureBody.texture = load(texture_path + "inicio_" + str(random_end) + ".png")
		#available_ends.erase(random_end)
		if fissure_step == 1:
			$FissureBody.set_flip_v(true)
	else: 
		var random_body = available_bodies[randi_range(0,available_bodies.size() - 1)]
		available_bodies.erase(random_body)
		$FissureBody.texture = load(texture_path + "cuerpo_" + str(random_body) + ".png")
		var random_flip = randi_range(0,1)
		if random_flip:
			$FissureBody.set_flip_h(true)
	
	return available_bodies
