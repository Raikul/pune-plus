extends Node2D

# Where Air's teleport lands: a small twinkling sparkle (additive, so it shines over
# trails without hiding them)

const COLOR = Color(0.55, 0.9, 1.0)
const RAY_LENGTH = 7.0
const RAY_WIDTH = 1.4
var time = 0.0
# Player sets it every frame: true when Air can jump now (power ready, or its free second
# jump). Ready = bigger and shinier; recharging = small and faint.
var can_jump = true
var shine = 1.0 # Eases towards 1 (ready) or 0 (recharging)

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
	shine = move_toward(shine, 1.0 if can_jump else 0.0, delta * 5.0)
	queue_redraw()

func _draw():
	var pulse = 0.5 + 0.5 * sin(time * 6.0)
	var spin = time * (0.8 + 1.4 * shine)
	var size = lerp(0.65, 1.3, shine)
	var alpha = lerp(0.3, 1.0, shine)
	# Halo: a faint dot while recharging, a wider pulsing glow when ready
	draw_circle(Vector2.ZERO, (4.0 + pulse) * size, Color(COLOR, 0.12 * alpha))
	if shine > 0:
		draw_circle(Vector2.ZERO, (9.0 + 3.0 * pulse) * size, Color(COLOR, 0.07 * shine))
	# Long thin rays and short diagonal ones, like a star glint
	_draw_rays(spin, RAY_LENGTH * size * (0.75 + 0.35 * pulse * shine), Color(COLOR.lerp(Color.WHITE, 0.35 * shine), 0.85 * alpha))
	_draw_rays(spin + PI / 4, RAY_LENGTH * size * 0.45, Color(COLOR, 0.5 * alpha))
	draw_circle(Vector2.ZERO, 1.2 * size, Color(1, 1, 1, 0.95 * alpha))

func _draw_rays(angle, length, color):
	for i in 4:
		var dir = Vector2.RIGHT.rotated(angle + i * PI / 2)
		var side = dir.orthogonal() * RAY_WIDTH
		draw_colored_polygon(PackedVector2Array([side, dir * length, -side]), color)
