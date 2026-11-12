extends Control

var rng = RandomNumberGenerator.new()
var lessonNumber
var lessonText
@onready var winnerTextBox = $DopamineContainer/Dopamine/Winner
@onready var lessonTextBox = $PanelContainer/MarginContainer/LessonTextBox
@onready var dopamineLabel = $DopamineContainer/Dopamine/DopamineLabel

# Win screen: hold any PUNCHI (or Enter) to fill the ring and close it (closed: the
# Playground shows the match stats next; without a listener it goes back to the menu)
const ODIN = preload("res://assets/jorge-resources/Game Selection/Odin Rounded - Bold.otf")
var hold_ring: HoldRing
signal closed

# Frases de victoria organizadas por elemento.
# 1 = Fuego, 2 = Tierra, 3 = Aire, 4 = Agua.


const VICTORY_QUOTES = {
	1: [ # FIRE
		"La claridad no siempre llega antes de actuar; a veces es el movimiento el que ilumina el camino.",
		"Comprender el momento oportuno permite actuar antes de perder la ventaja.",
		"La iniciativa no consiste siempre en ser el primero en moverse.",
		"Lo que no ofrece ninguna ventaja puede dejarse pasar; lo que importa exige actuar antes de que ocurra.",
		"Cuando la situación se estanca, abandona tu disposición anterior y comienza de nuevo.",
		"No permitas que una situación difícil te obligue a repetir una respuesta que ya ha fracasado.",
		"No se puede vivir plenamente mientras uno se esconde de la vida.",
		"La peor derrota es perder la esperanza.",
		"La belleza puede ser la primera puerta hacia la sabiduría."
	],

	2: [ # EARTH
		"La fortaleza no consiste en permanecer intacto, sino en conservar la capacidad de volver a florecer.",
		"Quien conoce sus fundamentos puede mantenerse firme incluso cuando todo a su alrededor cambia.",
		"La experiencia y las victorias no garantizan haber comprendido verdaderamente un arte.",
		"Lo profundo se alcanza a través de lo superficial; lo pequeño se comprende a partir de lo grande.",
		"Todo arte tiene su propio ritmo, incluso cuando no podemos percibirlo.",
		"Aprende a distinguir lo que se gana y lo que se pierde en cada cosa.",
		"Contamos historias de héroes para recordar que nosotros también podemos alcanzar la grandeza.",
		"El valor verdadero no necesita recurrir a la crueldad.",
		"Cada día de tu vida existe un juez del que no podés escapar: vos mismo.",
		"La humildad puede enseñarnos aquello que el orgullo nos impide comprender.",
		"La tierra enseña que algunas respuestas llegan con el tiempo y que el silencio también puede ser sabiduría."
	],

	3: [ # AIR
		"No necesitas ver aquello que te transforma para reconocer su presencia.",
		"Para comprender el propio camino también hay que conocer los caminos ajenos.",
		"Sin conocer bien a los demás, difícilmente podrás conocerte a ti mismo.",
		"Aunque practiques tu camino todos los días, puedes estar alejándote de él sin advertirlo.",
		"El exceso puede ser tan perjudicial como la insuficiencia.",
		"La verdadera velocidad no consiste en apresurarse, sino en encontrar el ritmo adecuado.",
		"La verdadera nobleza consiste en superar a la persona que fuiste ayer.",
		"No podés encontrar equilibrio en lo que te rodea si no cultivás equilibrio en tu interior.",
		"La verdadera libertad comienza cuando dejamos de obedecer al miedo.",
		"Un obstáculo debe reconocerse por lo que es, no por lo que aparenta ser."
	],

	4: [ # WATER
		"La verdadera claridad no consiste en encontrar lo que deseas ver, sino en aceptar lo que las aguas revelan.",
		"No confundas la firmeza con la rigidez. El agua conserva su naturaleza sin aferrarse a ninguna forma.",
		"El verdadero aprendizaje exige descubrir los principios por uno mismo, no limitarse a imitarlos.",
		"La mente debe conservar el equilibrio incluso en las situaciones más apremiantes.",
		"Percibir lo importante exige mirar más allá de aquello que atrae inmediatamente nuestra atención.",
		"La rigidez impide responder con libertad.",
		"Cuando todo está en calma, la mente no debe quedarse inmóvil. Cuando todo se acelera, la mente no debe apresurarse.",
		"Fortalece la percepción y no dependas únicamente de lo que ven tus ojos.",
		"No leas las enseñanzas como algo ajeno; descubre sus principios dentro de ti.",
		"El camino de mil leguas se recorre paso a paso.",
		"Hoy debes superar a quien fuiste ayer.",
		"Mil días de práctica forjan; diez mil días de práctica perfeccionan.",
		"La vida es como un río: sus enseñanzas no tienen un principio ni un final.",
		"No podemos dominar las fuerzas de la naturaleza; debemos aprender a movernos en armonía con ellas.",
		"El agua encuentra alegría en la transformación y no teme cambiar de forma."
	],

	5: [ # VOID
		"Nada existe por sí solo. Incluso aquello que parece separado forma parte de una misma totalidad.",
		"No confundas aquello que todavía no comprendes con aquello que no existe.",
		"Ignorar algo no significa que aquello carezca de existencia.",
		"Confundir lo que desconocemos con el vacío es permanecer en la confusión.",
		"El conocimiento requiere despejar las nubes que oscurecen nuestro juicio.",
		"Nadie reconoce su propio error mientras continúe convencido de que su camino es el correcto.",
		"La sabiduría exige pulir tanto el pensamiento como la percepción, hasta que desaparezca la confusión.",
		"Quien busca sabiduría debe aprender primero a encontrarla dentro de sí.",
		"Solo una mente abierta al mundo puede percibirlo verdaderamente.",
		"Aquel que ve enemigos en todas partes puede permanecer ciego ante sí mismo.",
		"El vacío une aquello que parece separado, como el silencio que da forma a cada nota musical."
	]
}


func _ready():
	_style_dopamine()
#	var my_random_number = rng.randf_range(-10.0, 10.0)

# area: the screen rectangle it covers (Playground: the whole arena, under the scoreboard);
# empty = its own size, centered on the screen
func improvise(improvisedText, area = Rect2(), winner_id: int = 0):
	print("IMPROVISE EJECUTADO")
	print("Ganador recibido: ", winner_id)
	print("Texto recibido: ", improvisedText)
	winnerTextBox.set_text(improvisedText)
	show_victory_quote(winner_id)
	$DopamineContainer.show()
	# Above trails, heads and power effects
	z_index = 60
	if area.has_area():
		$DopamineContainer.global_position = area.position
		$DopamineContainer.size = area.size
	else:
		$DopamineContainer.global_position = (get_viewport_rect().size - $DopamineContainer.size) / 2
	hold_ring.reset()
	set_process(true)
#	$DopamineContainer/Dopamine/Winner
func teach(type):
	randomizeLesson(type)
	showLesson()

func randomizeLesson(type):
	match type:
		"Water":
			lessonNumber = rng.randf_range(0, LessonList.WaterLessons.size())
			lessonText = tr(LessonList.WaterLessons[lessonNumber])

func showLesson():
	lessonTextBox.set_text(lessonText)
	lessonTextBox.show()
	
func hideLesson():
	lessonTextBox.hide()
	
# Same colors as the theme, rounder font and a softer shadow
func _style_dopamine():
	for label in [winnerTextBox, dopamineLabel]:
		label.add_theme_font_override("font", ODIN)
		label.add_theme_constant_override("outline_size", 12)
		label.add_theme_constant_override("shadow_offset_x", 0)
		label.add_theme_constant_override("shadow_offset_y", 6)
		label.add_theme_constant_override("shadow_outline_size", 12)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.set_anchors_preset(Control.PRESET_HCENTER_WIDE)
		label.offset_left = 40
		label.offset_right = -40
	# Offsets from the middle of the box, whatever its size
	winnerTextBox.add_theme_font_size_override("font_size", 120)
	winnerTextBox.offset_top = -230
	winnerTextBox.offset_bottom = -50
	dopamineLabel.add_theme_font_size_override("font_size", 56)
	dopamineLabel.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dopamineLabel.anchor_left = 0.1
	dopamineLabel.anchor_right = 0.9
	dopamineLabel.offset_left = 0
	dopamineLabel.offset_right = 0
	dopamineLabel.offset_top = -30
	dopamineLabel.offset_bottom = 130

	var prompt = HBoxContainer.new()
	prompt.alignment = BoxContainer.ALIGNMENT_CENTER
	prompt.add_theme_constant_override("separation", 16)
	prompt.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	prompt.offset_top = -130
	prompt.offset_bottom = -70
	$DopamineContainer/Dopamine.add_child(prompt)
	hold_ring = HoldRing.new()
	hold_ring.back_color = Color(winnerTextBox.get_theme_color("font_outline_color"), 0.35)
	hold_ring.fill_color = winnerTextBox.get_theme_color("font_color")
	prompt.add_child(hold_ring)
	var hint = Label.new()
	hint.text = "HINT_HOLD_PUNCHI"
	hint.add_theme_font_override("font", ODIN)
	hint.add_theme_font_size_override("font_size", 28)
	hint.add_theme_color_override("font_color", Color.WHITE)
	hint.add_theme_constant_override("outline_size", 0)
	hint.add_theme_constant_override("shadow_offset_x", 0)
	hint.add_theme_constant_override("shadow_offset_y", 3)
	hint.add_theme_constant_override("shadow_outline_size", 0)
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	prompt.add_child(hint)

func _process(delta):
	if not visible or not $DopamineContainer.visible:
		return
	if hold_ring.advance(delta, HoldRing.punchi_pressed()):
		set_process(false)
		if closed.get_connections().is_empty():
			get_tree().change_scene_to_file("res://scenes/menu.tscn")
		else:
			closed.emit()

func _input(event: InputEvent) -> void:
	# The win screen only closes by holding (_process)
	if visible and not $DopamineContainer.visible:
		if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel"):
			get_tree().change_scene_to_file("res://scenes/menu.tscn")
		
func show_victory_quote(player_id: int):
	if VICTORY_QUOTES.has(player_id):
		var quotes = VICTORY_QUOTES[player_id]
		dopamineLabel.text = quotes.pick_random()
	else:
		dopamineLabel.text = "DISFRUTA TU DOPAMINA"
