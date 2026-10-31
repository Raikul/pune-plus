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
		options_panel.back.connect(_on_options_back_pressed)
	# Deferred: Options builds its theme in its own _ready, which runs after this one
	_add_volume_sliders.call_deferred()

	# Conectar botones del menú
	if resume_button: resume_button.pressed.connect(_on_resume_pressed)
	if simulate_button: simulate_button.pressed.connect(_on_simulate_pressed)  # <--- Conectado aquí
	# Simulating a round only works locally
	if simulate_button and Global.isMultiplayerActive: simulate_button.hide()
	if options_button: options_button.pressed.connect(_on_options_pressed)
	if instructions_button: instructions_button.pressed.connect(_on_instructions_pressed)
	if quit_button: quit_button.pressed.connect(_on_quit_pressed)

# Volume right in the pause menu (same look and settings as Options > Audio)
var volume_sliders = {}
func _add_volume_sliders():
	var list = resume_button.get_parent()
	var box = PanelContainer.new()
	if options_panel:
		box.theme = options_panel.theme
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.35)
	style.set_corner_radius_all(14)
	style.set_content_margin_all(18)
	box.add_theme_stylebox_override("panel", style)
	box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.custom_minimum_size.x = 720
	var grid = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 14)
	box.add_child(grid)
	for bus in ["Master", "Music", "Effects"]:
		var name_label = Label.new()
		name_label.text = bus
		name_label.custom_minimum_size.x = 150
		var slider = HSlider.new()
		slider.min_value = 0.0
		slider.max_value = 1.0
		slider.step = 0.05
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var percent = Label.new()
		percent.custom_minimum_size.x = 80
		percent.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		slider.value_changed.connect(func(value):
			Global.volumes[bus] = value
			Global.apply_volumes()
			percent.text = "%d%%" % round(value * 100))
		slider.drag_ended.connect(func(_changed): Global.save_settings())
		slider.focus_exited.connect(Global.save_settings)
		grid.add_child(name_label)
		grid.add_child(slider)
		grid.add_child(percent)
		volume_sliders[bus] = slider
	# Between the buttons and Quit
	list.add_child(box)
	list.move_child(box, quit_button.get_index())
	_refresh_volume_sliders()

func _refresh_volume_sliders():
	for bus in volume_sliders:
		volume_sliders[bus].value = Global.volumes[bus]
		volume_sliders[bus].value_changed.emit(Global.volumes[bus])

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
	if visible:
		hide()
		if options_panel: options_panel.hide()
		if instructions_panel: instructions_panel.hide()
		get_tree().paused = false
	else:
		show()
		_refresh_volume_sliders()
		# Online the match keeps running for everyone else
		get_tree().paused = not Global.isMultiplayerActive

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
		options_panel.refresh_volumes()
		options_panel.show()

func _on_options_back_pressed():
	if options_panel:
		options_panel.hide()
	show()
	_refresh_volume_sliders()

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
