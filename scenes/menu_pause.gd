extends Control

# Botones de MenuPause
@onready var resume_button = $PanelContainer/MarginContainer/VBoxContainer/Resume
@onready var simulate_button = $PanelContainer/MarginContainer/VBoxContainer/Simulate  # <--- Botón de simular
@onready var options_button = $PanelContainer/MarginContainer/VBoxContainer/Options
@onready var instructions_button = $PanelContainer/MarginContainer/VBoxContainer/Instructions
@onready var quit_button = $PanelContainer/MarginContainer/VBoxContainer/Quit

# Paneles hermanos
@onready var instructions_panel = get_node_or_null("../Instrucciones")
@onready var options_panel = get_node_or_null("../Options")

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	
	# Asegurar que los paneles no se congelen durante la pausa
	if instructions_panel:
		instructions_panel.process_mode = Node.PROCESS_MODE_ALWAYS
		instructions_panel.hide()
		_conectar_botones_cerrar(instructions_panel, _on_instructions_back_pressed)

	if options_panel:
		options_panel.process_mode = Node.PROCESS_MODE_ALWAYS
		options_panel.hide()
		_conectar_botones_cerrar(options_panel, _on_options_back_pressed)

	# Conectar botones del menú
	if resume_button: resume_button.pressed.connect(_on_resume_pressed)
	if simulate_button: simulate_button.pressed.connect(_on_simulate_pressed)  # <--- Conectado aquí
	if options_button: options_button.pressed.connect(_on_options_pressed)
	if instructions_button: instructions_button.pressed.connect(_on_instructions_pressed)
	if quit_button: quit_button.pressed.connect(_on_quit_pressed)

func _conectar_botones_cerrar(nodo: Node, metodo_destino: Callable):
	for hijo in nodo.get_children():
		if hijo is Button:
			var nombre = hijo.name.to_lower()
			if "back" in nombre or "close" in nombre or "volver" in nombre or nombre == "button":
				if not hijo.pressed.is_connected(metodo_destino):
					hijo.pressed.connect(metodo_destino)
		_conectar_botones_cerrar(hijo, metodo_destino)

func _unhandled_input(event):
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			if options_panel and options_panel.visible:
				_on_options_back_pressed()
			elif instructions_panel and instructions_panel.visible:
				_on_instructions_back_pressed()
			else:
				toggle_pause()

func toggle_pause():
	if get_tree().paused:
		hide()
		if options_panel: options_panel.hide()
		if instructions_panel: instructions_panel.hide()
		get_tree().paused = false
	else:
		show()
		get_tree().paused = true

func _on_resume_pressed():
	toggle_pause()


func _on_simulate_pressed():
	toggle_pause()
	var playground = get_tree().current_scene
	if playground and playground.has_method("simulate_round"):
		playground.simulate_round()

func _on_options_pressed():
	hide()
	if options_panel:
		options_panel.show()

func _on_options_back_pressed():
	if options_panel:
		options_panel.hide()
	show()

func _on_instructions_pressed():
	hide()
	if instructions_panel:
		instructions_panel.show()

func _on_instructions_back_pressed():
	if instructions_panel:
		instructions_panel.hide()
	show()

func _on_quit_pressed():
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/menu.tscn")
