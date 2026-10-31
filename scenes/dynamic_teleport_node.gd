extends Node2D

# Where Air's teleport lands: a small twinkling sparkle (additive, so it shines over
# trails without hiding them)

const COLOR = Color(0.55, 0.9, 1.0)
const RAY_LENGTH = 7.0
const RAY_WIDTH = 1.4
var time = 0.0

func _ready():
	top_level = true # No se ve afectado por la rotación de la serpiente
	z_index = 20     # Se dibuja por encima del fondo y los cuerpos
	var glow = CanvasItemMaterial.new()
	glow.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = glow

func _process(delta):
	if not visible:
		return
	time += delta
	queue_redraw()

func _draw():
	var pulse = 0.5 + 0.5 * sin(time * 6.0)
	var spin = time * 1.5
	# Faint halo
	draw_circle(Vector2.ZERO, 4.0 + pulse, Color(COLOR, 0.12))
	# Long thin rays and short diagonal ones, like a star glint
	_draw_rays(spin, RAY_LENGTH * (0.75 + 0.35 * pulse), Color(COLOR, 0.85))
	_draw_rays(spin + PI / 4, RAY_LENGTH * 0.45, Color(COLOR, 0.5))
	draw_circle(Vector2.ZERO, 1.2, Color(1, 1, 1, 0.95))

func _draw_rays(angle, length, color):
	for i in 4:
		var dir = Vector2.RIGHT.rotated(angle + i * PI / 2)
		var side = dir.orthogonal() * RAY_WIDTH
		draw_colored_polygon(PackedVector2Array([side, dir * length, -side]), color)
