extends Node2D

func _ready():
	top_level = true # No se ve afectado por la rotación de la serpiente
	z_index = 20     # Se dibuja por encima del fondo y los cuerpos

func _draw():
	# Círculo celeste semitransparente (estilo aire)
	draw_circle(Vector2.ZERO, 12, Color(0.3, 0.8, 1.0, 0.45))
	# Borde blanco circular
	draw_arc(Vector2.ZERO, 12, 0, TAU, 32, Color.WHITE, 2.0)
	# Punto blanco en el centro
	draw_circle(Vector2.ZERO, 3, Color.WHITE)
