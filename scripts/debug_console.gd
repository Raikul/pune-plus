extends CanvasLayer

var panel: Panel
var label_speed: Label
var label_cooldown: Label
var label_earth: Label
var label_earth_scale: Label
var label_fire_radius: Label
var label_fire_dur: Label
var label_gap: Label
var btn_air_double: Button
var btn_water_triple: Button
var btn_air_warp: Button

var current_speed: float = 150.0
var current_cooldown: float = 6.0
var current_earth: float = 2.0
var current_earth_scale: float = 2.0
var current_fire_radius: float = 1.0
var current_fire_dur: float = 4.0 # 0 = sin límite
var current_gap: float = 0.7
var air_double_enabled: bool = false
var air_warp_enabled: bool = false
var water_triple_enabled: bool = false
# Stats changed from the console. Each match starts with fresh stats, so they are applied again
var overrides: Dictionary = {}

func _ready():
	# Corregido: la consola es solo para pruebas, no viene en el juego exportado
	if not OS.is_debug_build():
		queue_free()
		return
	current_gap = Global.gap_time()
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 128
	visible = false
	crear_interfaz_botones()
	Global.player_stats_reset.connect(_reaplicar_cambios)

func crear_interfaz_botones() -> void:
	panel = Panel.new()
	panel.custom_minimum_size = Vector2(390, 580)
	panel.position = Vector2(25, 25)
	add_child(panel)

	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 15)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 15)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)

	var title = Label.new()
	title.text = "⚡ PANEL DE CONTROL [ ` ] ⚡"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	# Fila 1: VELOCIDAD
	label_speed = crear_fila(vbox, "Velocidad: 150", 
		func(): cambiar_stat("speed", -50.0), 
		func(): cambiar_stat("speed", 50.0)
	)

	# Fila 2: COOLDOWN
	label_cooldown = crear_fila(vbox, "Cooldown: 6.0s", 
		func(): cambiar_stat("cooldown", -0.5), 
		func(): cambiar_stat("cooldown", 0.5)
	)

	# Fila 3: HUECO DE ESTELA (GAP)
	label_gap = crear_fila(vbox, "Hueco Estela: %.2fs" % current_gap, 
		func(): cambiar_stat("gap.time", -0.15), 
		func(): cambiar_stat("gap.time", 0.15)
	)

	# Fila 4: BOTÓN ON/OFF PARA DOBLE SALTO DE AIRE
	btn_air_double = Button.new()
	btn_air_double.custom_minimum_size = Vector2(0, 28)
	actualizar_boton_aire()
	btn_air_double.pressed.connect(func():
		air_double_enabled = !air_double_enabled
		aplicar_stat_directo("air.recast_window", 1.0 if air_double_enabled else 0.0)
		actualizar_boton_aire()
	)
	vbox.add_child(btn_air_double)

	# BOTÓN ON/OFF PARA ATRAVESAR PAREDES CON AIRE (mejora Wall Warp)
	btn_air_warp = Button.new()
	btn_air_warp.custom_minimum_size = Vector2(0, 28)
	actualizar_boton_warp()
	btn_air_warp.pressed.connect(func():
		air_warp_enabled = !air_warp_enabled
		aplicar_stat_directo("air.wall_warp", 1.0 if air_warp_enabled else 0.0)
		actualizar_boton_warp()
	)
	vbox.add_child(btn_air_warp)

	# Fila 5: BOTÓN 2 / 3 CABEZAS DE AGUA
	btn_water_triple = Button.new()
	btn_water_triple.custom_minimum_size = Vector2(0, 28)
	actualizar_boton_agua()
	btn_water_triple.pressed.connect(func():
		water_triple_enabled = !water_triple_enabled
		aplicar_stat_directo("water.copies", 2.0 if water_triple_enabled else 1.0)
		actualizar_boton_agua()
	)
	vbox.add_child(btn_water_triple)

	# Fila 6: TIERRA DURACIÓN
	label_earth = crear_fila(vbox, "Tierra Dur: 2.0s", 
		func(): cambiar_stat("earth.duration", -0.5), 
		func(): cambiar_stat("earth.duration", 0.5)
	)

	# Fila 7: TIERRA TAMAÑO COLISIÓN
	label_earth_scale = crear_fila(vbox, "Tierra Tamaño: 2.00x", 
		func(): cambiar_stat("earth.scale", -0.5), 
		func(): cambiar_stat("earth.scale", 0.5)
	)

	# Fila 8: FUEGO RADIO
	label_fire_radius = crear_fila(vbox, "Fuego Radio: 1.00x", 
		func(): cambiar_stat("fire.radius", -0.25), 
		func(): cambiar_stat("fire.radius", 0.25)
	)

	# Fila 9: FUEGO DURACIÓN EN EL AIRE
	label_fire_dur = crear_fila(vbox, "Fuego Vuelo: 4.0s", 
		func(): cambiar_stat("fire.duration", -0.5), 
		func(): cambiar_stat("fire.duration", 0.5)
	)

	# ACCIONES RÁPIDAS
	var hbox_acciones = HBoxContainer.new()
	hbox_acciones.add_theme_constant_override("separation", 8)
	vbox.add_child(hbox_acciones)

	var btn_infinito = Button.new()
	btn_infinito.text = "Cooldown 0.1s"
	btn_infinito.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_infinito.pressed.connect(func():
		current_cooldown = 0.1
		aplicar_stat_directo("cooldown", 0.1)
		actualizar_textos()
	)
	hbox_acciones.add_child(btn_infinito)

	var btn_reset = Button.new()
	btn_reset.text = "Reset Normal"
	btn_reset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_reset.pressed.connect(func():
		current_speed = 150.0
		current_cooldown = 6.0
		current_earth = 2.0
		current_earth_scale = 2.0
		current_fire_radius = 1.0
		current_fire_dur = 4.0
		current_gap = Global.gap_time()
		air_double_enabled = false
		air_warp_enabled = false
		aplicar_stat_directo("air.wall_warp", 0.0)
		actualizar_boton_warp()
		water_triple_enabled = false
		aplicar_stat_directo("air.recast_window", 0.0)
		aplicar_stat_directo("water.copies", 1.0)
		aplicar_stat_directo("speed", 150.0)
		aplicar_stat_directo("cooldown", 6.0)
		aplicar_stat_directo("earth.duration", 2.0)
		aplicar_stat_directo("earth.scale", 2.0)
		aplicar_stat_directo("fire.radius", 1.0)
		aplicar_stat_directo("fire.duration", 4.0)
		aplicar_stat_directo("gap.time", current_gap)
		overrides.clear()
		actualizar_boton_aire()
		actualizar_boton_agua()
		actualizar_textos()
	)
	hbox_acciones.add_child(btn_reset)

func crear_fila(parent: Control, texto_inicial: String, on_minus: Callable, on_plus: Callable) -> Label:
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	parent.add_child(hbox)

	var btn_minus = Button.new()
	btn_minus.text = "  -  "
	btn_minus.custom_minimum_size = Vector2(40, 26)
	btn_minus.pressed.connect(on_minus)
	hbox.add_child(btn_minus)

	var lbl = Label.new()
	lbl.text = texto_inicial
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(lbl)

	var btn_plus = Button.new()
	btn_plus.text = "  +  "
	btn_plus.custom_minimum_size = Vector2(40, 26)
	btn_plus.pressed.connect(on_plus)
	hbox.add_child(btn_plus)

	return lbl

func actualizar_boton_warp() -> void:
	if btn_air_warp:
		btn_air_warp.text = "🧱 Aire atraviesa paredes: " + ("ACTIVADO" if air_warp_enabled else "DESACTIVADO")
		btn_air_warp.modulate = Color(0.3, 1.0, 0.4) if air_warp_enabled else Color.WHITE

func actualizar_boton_aire() -> void:
	if btn_air_double:
		if air_double_enabled:
			btn_air_double.text = "🌀 Doble Salto Aire: ACTIVADO (1s)"
			btn_air_double.modulate = Color(0.3, 1.0, 0.4)
		else:
			btn_air_double.text = "🌀 Doble Salto Aire: DESACTIVADO"
			btn_air_double.modulate = Color(1.0, 1.0, 1.0)

func actualizar_boton_agua() -> void:
	if btn_water_triple:
		if water_triple_enabled:
			btn_water_triple.text = "🌊 Agua: 3 CABEZAS (2 clones)"
			btn_water_triple.modulate = Color(0.2, 0.8, 1.0)
		else:
			btn_water_triple.text = "🌊 Agua: 2 CABEZAS (Normal)"
			btn_water_triple.modulate = Color(1.0, 1.0, 1.0)

func cambiar_stat(tipo: String, delta: float) -> void:
	match tipo:
		"speed":
			current_speed = clamp(current_speed + delta, 50.0, 1000.0)
			aplicar_stat_directo("speed", current_speed)
		"cooldown":
			current_cooldown = clamp(current_cooldown + delta, 0.1, 15.0)
			aplicar_stat_directo("cooldown", current_cooldown)
		"earth.duration":
			current_earth = clamp(current_earth + delta, 0.5, 15.0)
			aplicar_stat_directo("earth.duration", current_earth)
		"earth.scale":
			current_earth_scale = clamp(current_earth_scale + delta, 1.0, 5.0)
			aplicar_stat_directo("earth.scale", current_earth_scale)
		"fire.radius":
			current_fire_radius = clamp(current_fire_radius + delta, 0.25, 4.0)
			aplicar_stat_directo("fire.radius", current_fire_radius)
		"fire.duration":
			current_fire_dur = clamp(current_fire_dur + delta, 0.0, 10.0)
			aplicar_stat_directo("fire.duration", current_fire_dur)
		"gap.time":
			current_gap = clamp(current_gap + delta, 0.1, 2.0)
			aplicar_stat_directo("gap.time", current_gap)
	actualizar_textos()

func actualizar_textos() -> void:
	if label_speed: label_speed.text = "Velocidad: %d" % int(current_speed)
	if label_cooldown: label_cooldown.text = "Cooldown: %.1fs" % current_cooldown
	if label_earth: label_earth.text = "Tierra Dur: %.1fs" % current_earth
	if label_earth_scale: label_earth_scale.text = "Tierra Tamaño: %.2fx" % current_earth_scale
	if label_fire_radius: label_fire_radius.text = "Fuego Radio: %.2fx" % current_fire_radius
	if label_fire_dur: label_fire_dur.text = "Fuego Vuelo: sin límite" if current_fire_dur <= 0 else "Fuego Vuelo: %.1fs" % current_fire_dur
	if label_gap: label_gap.text = "Hueco Estela: %.2fs" % current_gap

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_QUOTELEFT or event.keycode == KEY_ASCIITILDE or event.unicode == 96:
			# Corregido: en online cada máquina tendría reglas distintas, así que no se abre
			if Global.isMultiplayerActive:
				return
			visible = !visible
			get_viewport().set_input_as_handled()

# Una partida nueva arranca con stats nuevos: se vuelven a aplicar los cambios de la consola
func _reaplicar_cambios() -> void:
	for stat_key in overrides:
		aplicar_stat_directo(stat_key, overrides[stat_key])

func aplicar_stat_directo(stat_key: String, valor: float) -> void:
	overrides[stat_key] = valor
	for id in [1, 2, 3, 4]:
		if Global.player_stats.get(id) == null:
			Global.player_stats[id] = PlayerStats.new()
		Global.player_stats[id].set_stat(stat_key, valor)

	for player in get_tree().get_nodes_in_group("activePlayers"):
		if stat_key == "speed":
			player.speed = valor
		
		if stat_key == "cooldown":
			var timer = player.get_node_or_null("CooldownTimer")
			if timer:
				timer.stop()
				timer.wait_time = max(valor, 0.05)
			player.powerReady()

		if player.stats != null:
			player.stats.set_stat(stat_key, valor)
			player.refresh_stats()
