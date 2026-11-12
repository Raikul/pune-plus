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
# Rows/toggles taken from the gus_powers_refact console, mapped to main's stats
var label_water_max: Label
var label_void_dur: Label
var label_void_rad: Label
var label_void_uses: Label
var current_water_max: float = 1.0
var current_void_dur: float = 3.0
var current_void_rad: float = 80.0
var current_void_uses: float = 1.0
# stat key -> {button, text, color}: ON/OFF buttons that set a stat to 1 or 0
var toggles: Dictionary = {}

var current_speed: float = 150.0
var current_cooldown: float = 6.0
var current_earth: float = 1.2
var current_earth_scale: float = 1.0
var current_fire_radius: float = 1.0
var current_fire_dur: float = 2.5 # 0 = sin límite
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
	panel.custom_minimum_size = Vector2(430, 640)
	panel.position = Vector2(25, 25)
	add_child(panel)

	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 15)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 15)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)

	# Scrollable: with every power's cards the panel no longer fits the screen
	var scroll = ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_child(scroll)

	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 6)
	scroll.add_child(vbox)

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
		aplicar_stat_directo("water.max_twins", 2.0 if water_triple_enabled else 1.0)
		aplicar_stat_directo("water.twins_per_cast", 2.0 if water_triple_enabled else 1.0)
		actualizar_boton_agua()
	)
	vbox.add_child(btn_water_triple)

	# Fila 6: TIERRA DURACIÓN
	label_earth = crear_fila(vbox, "Tierra Dur: 2.0s", 
		func(): cambiar_stat("earth.duration", -0.5), 
		func(): cambiar_stat("earth.duration", 0.5)
	)

	# Fila 7: TIERRA TAMAÑO COLISIÓN
	label_earth_scale = crear_fila(vbox, "Tierra Rocas: 1.00x", 
		func(): cambiar_stat("earth.scale", -0.25), 
		func(): cambiar_stat("earth.scale", 0.25)
	)

	# Fila 8: FUEGO RADIO
	label_fire_radius = crear_fila(vbox, "Fuego Radio: 1.00x", 
		func(): cambiar_stat("fire.radius", -0.25), 
		func(): cambiar_stat("fire.radius", 0.25)
	)

	# Fila 9: FUEGO DURACIÓN EN EL AIRE
	label_fire_dur = crear_fila(vbox, "Fuego Vuelo: 2.5s", 
		func(): cambiar_stat("fire.duration", -0.5), 
		func(): cambiar_stat("fire.duration", 0.5)
	)

	# --- Extra cards (from gus_powers_refact) ---
	crear_titulo(vbox, "AIRE", Color(0.5, 0.8, 1.0))
	crear_toggle(vbox, "air.shock", "⚡ Descarga Estática", Color(0.3, 0.9, 1.0))
	crear_toggle(vbox, "air.scramble", "🔀 Revoltijo (invierte controles)", Color(0.9, 0.4, 1.0))
	crear_toggle(vbox, "air.storm", "🌩️ Cerca de Tormenta", Color(0.5, 0.7, 1.0))

	crear_titulo(vbox, "AGUA", Color(0.2, 0.8, 1.0))
	label_water_max = crear_fila(vbox, "Agua Máx Gemelos: 1",
		func(): cambiar_stat("water.max_twins", -1.0),
		func(): cambiar_stat("water.max_twins", 1.0)
	)
	crear_toggle(vbox, "water.lasting_twin", "💧 Gemelo Duradero", Color(0.4, 0.9, 1.0))

	crear_titulo(vbox, "FUEGO", Color(1.0, 0.5, 0.1))
	crear_toggle(vbox, "fire.trail", "🔥 Incendio (rastro)", Color(1.0, 0.5, 0.1))
	crear_toggle(vbox, "fire.phoenix", "🦅 Fénix (renacer)", Color(1.0, 0.85, 0.2))

	crear_titulo(vbox, "TIERRA", Color(0.85, 0.65, 0.3))
	crear_toggle(vbox, "earth.border_pass", "⛏️ Excavador (atraviesa muros)", Color(0.85, 0.55, 0.2))
	crear_toggle(vbox, "earth.stone_walk", "🪨 Caminante de Piedra", Color(0.9, 0.8, 0.4))

	crear_titulo(vbox, "VACÍO (VOID)", Color(0.8, 0.4, 1.0))
	label_void_dur = crear_fila(vbox, "Vacío Duración: 3.0s",
		func(): cambiar_stat("void.duration", -0.5),
		func(): cambiar_stat("void.duration", 0.5)
	)
	label_void_rad = crear_fila(vbox, "Vacío Radio: 80px",
		func(): cambiar_stat("void.radius", -15.0),
		func(): cambiar_stat("void.radius", 15.0)
	)
	label_void_uses = crear_fila(vbox, "Usos de poder absorbido: 1",
		func(): cambiar_stat("void.absorb_uses", -1.0),
		func(): cambiar_stat("void.absorb_uses", 1.0)
	)
	crear_toggle(vbox, "void.keep_upgrades", "🔮 Roba con mejoras (Épica)", Color(0.8, 0.4, 1.0))
	crear_toggle(vbox, "void.round_absorbs", "👑 Poderes permanentes en ronda", Color(1.0, 0.85, 0.2))

	var btn_void_all = Button.new()
	btn_void_all.text = "✨ Vacío: ABSORBER TODOS LOS PODERES ✨"
	btn_void_all.modulate = Color(0.9, 0.5, 1.0)
	btn_void_all.pressed.connect(func():
		for player in get_tree().get_nodes_in_group("activePlayers"):
			if player.main_power != null and player.main_power.has_method("absorb"):
				for element in Global.element_ids():
					if element != 5:
						player.main_power.absorb(element, player.playerId)
	)
	vbox.add_child(btn_void_all)

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
		current_earth = 1.2
		current_earth_scale = 1.0
		current_fire_radius = 1.0
		current_fire_dur = 2.5
		current_gap = Global.gap_time()
		air_double_enabled = false
		air_warp_enabled = false
		aplicar_stat_directo("air.wall_warp", 0.0)
		actualizar_boton_warp()
		water_triple_enabled = false
		aplicar_stat_directo("air.recast_window", 0.0)
		aplicar_stat_directo("water.max_twins", 1.0)
		aplicar_stat_directo("water.twins_per_cast", 1.0)
		aplicar_stat_directo("speed", 150.0)
		aplicar_stat_directo("cooldown", 6.0)
		aplicar_stat_directo("earth.duration", 1.2)
		aplicar_stat_directo("earth.scale", 1.0)
		aplicar_stat_directo("fire.radius", 1.0)
		aplicar_stat_directo("fire.duration", 2.5)
		aplicar_stat_directo("gap.time", current_gap)
		current_water_max = 1.0
		current_void_dur = 3.0
		current_void_rad = 80.0
		current_void_uses = 1.0
		aplicar_stat_directo("water.max_twins", 1.0)
		aplicar_stat_directo("void.duration", current_void_dur)
		aplicar_stat_directo("void.radius", current_void_rad)
		aplicar_stat_directo("void.absorb_uses", current_void_uses)
		for key in toggles:
			aplicar_stat_directo(key, 0.0)
		overrides.clear()
		actualizar_toggles()
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

func crear_titulo(parent: Control, texto: String, color: Color) -> void:
	var lbl = Label.new()
	lbl.text = "— %s —" % texto
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.modulate = color
	parent.add_child(lbl)

# ON/OFF button for a 0/1 stat. Its state is read back from the stats (see actualizar_toggles)
func crear_toggle(parent: Control, stat_key: String, texto: String, color: Color) -> void:
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(0, 28)
	btn.pressed.connect(func():
		aplicar_stat_directo(stat_key, 0.0 if _toggle_on(stat_key) else 1.0)
		if stat_key == "fire.phoenix":
			for player in get_tree().get_nodes_in_group("activePlayers"):
				if player.main_power != null and "phoenix_used" in player.main_power:
					player.main_power.phoenix_used = false
		actualizar_toggles()
	)
	parent.add_child(btn)
	toggles[stat_key] = {"button": btn, "text": texto, "color": color}
	actualizar_toggles()

func _toggle_on(stat_key: String) -> bool:
	return overrides.get(stat_key, 0.0) >= 1.0

func actualizar_toggles() -> void:
	for key in toggles:
		var t = toggles[key]
		var on = _toggle_on(key)
		t.button.text = t.text + (": ACTIVADO" if on else ": DESACTIVADO")
		t.button.modulate = t.color if on else Color.WHITE

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
			current_earth_scale = clamp(current_earth_scale + delta, 0.5, 3.0)
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
		"water.max_twins":
			current_water_max = clamp(current_water_max + delta, 1.0, 5.0)
			aplicar_stat_directo("water.max_twins", current_water_max)
		"void.duration":
			current_void_dur = clamp(current_void_dur + delta, 0.5, 10.0)
			aplicar_stat_directo("void.duration", current_void_dur)
		"void.radius":
			current_void_rad = clamp(current_void_rad + delta, 20.0, 300.0)
			aplicar_stat_directo("void.radius", current_void_rad)
		"void.absorb_uses":
			current_void_uses = clamp(current_void_uses + delta, 1.0, 10.0)
			aplicar_stat_directo("void.absorb_uses", current_void_uses)
	actualizar_textos()

func actualizar_textos() -> void:
	if label_speed: label_speed.text = "Velocidad: %d" % int(current_speed)
	if label_cooldown: label_cooldown.text = "Cooldown: %.1fs" % current_cooldown
	if label_earth: label_earth.text = "Tierra Dur: %.1fs" % current_earth
	if label_earth_scale: label_earth_scale.text = "Tierra Rocas: %.2fx" % current_earth_scale
	if label_fire_radius: label_fire_radius.text = "Fuego Radio: %.2fx" % current_fire_radius
	if label_fire_dur: label_fire_dur.text = "Fuego Vuelo: sin límite" if current_fire_dur <= 0 else "Fuego Vuelo: %.1fs" % current_fire_dur
	if label_gap: label_gap.text = "Hueco Estela: %.2fs" % current_gap
	if label_water_max: label_water_max.text = "Agua Máx Gemelos: %d" % int(current_water_max)
	if label_void_dur: label_void_dur.text = "Vacío Duración: %.1fs" % current_void_dur
	if label_void_rad: label_void_rad.text = "Vacío Radio: %dpx" % int(current_void_rad)
	if label_void_uses: label_void_uses.text = "Usos de poder absorbido: %d" % int(current_void_uses)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_QUOTELEFT or event.keycode == KEY_ASCIITILDE or event.unicode == 96 or event.keycode == KEY_INSERT:
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
	for id in Global.element_ids():
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
