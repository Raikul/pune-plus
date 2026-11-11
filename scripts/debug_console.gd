extends CanvasLayer

var panel: Panel
var label_speed: Label
var label_cooldown: Label
var label_earth: Label
var label_earth_scale: Label
var label_fire_radius: Label
var label_fire_dur: Label
var label_gap: Label
var label_water_max: Label

# VACÍO
var label_void_dur: Label
var label_void_rad: Label
var label_void_absorb_time: Label
var btn_void_keep_upgrades: Button
var btn_void_round_absorbs: Button
var btn_void_absorb_all: Button

# BOTONES DE AIRE
var btn_air_double: Button
var btn_air_shock: Button
var btn_air_scramble: Button
var btn_air_storm: Button

# BOTONES DE AGUA
var btn_water_burst: Button
var btn_water_lasting: Button

# BOTONES DE FUEGO
var btn_fire_trail: Button
var btn_fire_phoenix: Button

# BOTONES DE TIERRA
var btn_earth_burrow: Button
var btn_earth_walker: Button

var current_speed: float = 150.0
var current_cooldown: float = 5.0
var current_earth: float = 1.2
var current_earth_scale: float = 1.0
var current_fire_radius: float = 1.0
var current_fire_dur: float = 2.5
var current_gap: float = 0.6
var current_water_max: float = 1.0

# VACÍO STATS
var current_void_dur: float = 2.0
var current_void_rad: float = 60.0
var current_void_absorb_time: float = 4.0
var void_keep_upgrades_enabled: bool = false
var void_round_absorbs_enabled: bool = false

var air_double_enabled: bool = false
var air_shock_enabled: bool = false
var air_scramble_enabled: bool = false
var air_storm_enabled: bool = false

var water_burst_enabled: bool = false
var water_lasting_enabled: bool = false
var fire_trail_enabled: bool = false
var fire_phoenix_enabled: bool = false

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 128
	visible = false
	crear_interfaz_botones()

func crear_interfaz_botones() -> void:
	panel = Panel.new()
	panel.custom_minimum_size = Vector2(430, 640)
	panel.position = Vector2(20, 20)
	add_child(panel)

	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)

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

	# Fila: VELOCIDAD
	label_speed = crear_fila(vbox, "Velocidad: 150", 
		func(): cambiar_stat("speed", -50.0), 
		func(): cambiar_stat("speed", 50.0)
	)

	# Fila: COOLDOWN
	label_cooldown = crear_fila(vbox, "Cooldown: 5.0s", 
		func(): cambiar_stat("cooldown", -0.5), 
		func(): cambiar_stat("cooldown", 0.5)
	)

	# Fila: HUECO DE ESTELA (GAP)
	label_gap = crear_fila(vbox, "Hueco Estela: 0.60s", 
		func(): cambiar_stat("gap.time", -0.15), 
		func(): cambiar_stat("gap.time", 0.15)
	)

	# --- VACÍO (VOID - ELEMENTO 5) ---
	var void_title = Label.new()
	void_title.text = "🔮 ELEMENTO VACÍO (VOID) 🔮"
	void_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	void_title.modulate = Color(0.8, 0.4, 1.0)
	vbox.add_child(void_title)

	label_void_dur = crear_fila(vbox, "Vacío Duración: 2.0s",
		func(): cambiar_stat("void.duration", -0.5),
		func(): cambiar_stat("void.duration", 0.5)
	)

	label_void_rad = crear_fila(vbox, "Vacío Radio: 60px",
		func(): cambiar_stat("void.radius", -15.0),
		func(): cambiar_stat("void.radius", 15.0)
	)

	label_void_absorb_time = crear_fila(vbox, "Tiempo Retención: 4.0s",
		func(): cambiar_stat("void.absorb_time", -1.0),
		func(): cambiar_stat("void.absorb_time", 1.0)
	)

	btn_void_keep_upgrades = Button.new()
	btn_void_keep_upgrades.custom_minimum_size = Vector2(0, 28)
	actualizar_boton_void_upgrades()
	btn_void_keep_upgrades.pressed.connect(func():
		void_keep_upgrades_enabled = !void_keep_upgrades_enabled
		aplicar_stat_directo("void.keep_upgrades", 1.0 if void_keep_upgrades_enabled else 0.0)
		actualizar_boton_void_upgrades()
	)
	vbox.add_child(btn_void_keep_upgrades)

	btn_void_round_absorbs = Button.new()
	btn_void_round_absorbs.custom_minimum_size = Vector2(0, 28)
	actualizar_boton_void_round()
	btn_void_round_absorbs.pressed.connect(func():
		void_round_absorbs_enabled = !void_round_absorbs_enabled
		aplicar_stat_directo("void.round_absorbs", 1.0 if void_round_absorbs_enabled else 0.0)
		actualizar_boton_void_round()
	)
	vbox.add_child(btn_void_round_absorbs)

	btn_void_absorb_all = Button.new()
	btn_void_absorb_all.text = "✨ Vacío: ABSORBER TODOS LOS PODERES (Combo) ✨"
	btn_void_absorb_all.modulate = Color(0.9, 0.5, 1.0)
	btn_void_absorb_all.pressed.connect(func():
		for player in get_tree().get_nodes_in_group("activePlayers"):
			if player.main_power != null and player.main_power.has_method("absorb"):
				player.main_power.absorb(1, player.playerId)
				player.main_power.absorb(2, player.playerId)
				player.main_power.absorb(3, player.playerId)
				player.main_power.absorb(4, player.playerId)
	)
	vbox.add_child(btn_void_absorb_all)

	# --- CARTAS DE AIRE ---
	btn_air_double = Button.new()
	btn_air_double.custom_minimum_size = Vector2(0, 28)
	actualizar_boton_aire_doble()
	btn_air_double.pressed.connect(func():
		air_double_enabled = !air_double_enabled
		aplicar_stat_directo("air.recast_window", 1.0 if air_double_enabled else 0.0)
		actualizar_boton_aire_doble()
	)
	vbox.add_child(btn_air_double)

	btn_air_shock = Button.new()
	btn_air_shock.custom_minimum_size = Vector2(0, 28)
	actualizar_boton_aire_shock()
	btn_air_shock.pressed.connect(func():
		air_shock_enabled = !air_shock_enabled
		aplicar_stat_directo("air.shock", 1.0 if air_shock_enabled else 0.0)
		actualizar_boton_aire_shock()
	)
	vbox.add_child(btn_air_shock)

	btn_air_scramble = Button.new()
	btn_air_scramble.custom_minimum_size = Vector2(0, 28)
	actualizar_boton_aire_scramble()
	btn_air_scramble.pressed.connect(func():
		air_scramble_enabled = !air_scramble_enabled
		aplicar_stat_directo("air.scramble", 1.0 if air_scramble_enabled else 0.0)
		actualizar_boton_aire_scramble()
	)
	vbox.add_child(btn_air_scramble)

	btn_air_storm = Button.new()
	btn_air_storm.custom_minimum_size = Vector2(0, 28)
	actualizar_boton_aire_storm()
	btn_air_storm.pressed.connect(func():
		air_storm_enabled = !air_storm_enabled
		aplicar_stat_directo("air.storm", 1.0 if air_storm_enabled else 0.0)
		actualizar_boton_aire_storm()
	)
	vbox.add_child(btn_air_storm)

	# --- CARTAS DE AGUA ---
	label_water_max = crear_fila(vbox, "Agua Máx Gemelos: 1", 
		func(): cambiar_stat("water.max_twins", -1.0), 
		func(): cambiar_stat("water.max_twins", 1.0)
	)

	btn_water_burst = Button.new()
	btn_water_burst.custom_minimum_size = Vector2(0, 28)
	actualizar_boton_rafaga()
	btn_water_burst.pressed.connect(func():
		water_burst_enabled = !water_burst_enabled
		aplicar_stat_directo("water.twins_per_cast", 2.0 if water_burst_enabled else 1.0)
		actualizar_boton_rafaga()
	)
	vbox.add_child(btn_water_burst)

	btn_water_lasting = Button.new()
	btn_water_lasting.custom_minimum_size = Vector2(0, 28)
	actualizar_boton_duradero()
	btn_water_lasting.pressed.connect(func():
		water_lasting_enabled = !water_lasting_enabled
		aplicar_stat_directo("water.lasting_twin", 1.0 if water_lasting_enabled else 0.0)
		actualizar_boton_duradero()
	)
	vbox.add_child(btn_water_lasting)

	# --- CARTAS DE FUEGO ---
	btn_fire_trail = Button.new()
	btn_fire_trail.custom_minimum_size = Vector2(0, 28)
	actualizar_boton_incendio()
	btn_fire_trail.pressed.connect(func():
		fire_trail_enabled = !fire_trail_enabled
		aplicar_stat_directo("fire.trail", 1.0 if fire_trail_enabled else 0.0)
		actualizar_boton_incendio()
	)
	vbox.add_child(btn_fire_trail)

	btn_fire_phoenix = Button.new()
	btn_fire_phoenix.custom_minimum_size = Vector2(0, 28)
	actualizar_boton_fenix()
	btn_fire_phoenix.pressed.connect(func():
		fire_phoenix_enabled = !fire_phoenix_enabled
		aplicar_stat_directo("fire.phoenix", 1.0 if fire_phoenix_enabled else 0.0)
		for player in get_tree().get_nodes_in_group("activePlayers"):
			if player.main_power != null and "phoenix_used" in player.main_power:
				player.main_power.phoenix_used = false
		actualizar_boton_fenix()
	)
	vbox.add_child(btn_fire_phoenix)

	# --- CARTAS DE TIERRA ---
	btn_earth_burrow = Button.new()
	btn_earth_burrow.custom_minimum_size = Vector2(0, 28)
	actualizar_boton_excavador()
	btn_earth_burrow.pressed.connect(func():
		Global.debug_burrow = !Global.debug_burrow
		actualizar_boton_excavador()
	)
	vbox.add_child(btn_earth_burrow)

	btn_earth_walker = Button.new()
	btn_earth_walker.custom_minimum_size = Vector2(0, 28)
	actualizar_boton_caminante()
	btn_earth_walker.pressed.connect(func():
		Global.debug_walker = !Global.debug_walker
		actualizar_boton_caminante()
	)
	vbox.add_child(btn_earth_walker)

	label_earth = crear_fila(vbox, "Tierra Dur: 1.20s", 
		func(): cambiar_stat("earth.duration", -0.25), 
		func(): cambiar_stat("earth.duration", 0.25)
	)

	label_earth_scale = crear_fila(vbox, "Tierra Ancho: 1.00x", 
		func(): cambiar_stat("earth.scale", -0.30), 
		func(): cambiar_stat("earth.scale", 0.30)
	)

	label_fire_radius = crear_fila(vbox, "Fuego Radio: 1.00x", 
		func(): cambiar_stat("fire.radius", -0.25), 
		func(): cambiar_stat("fire.radius", 0.25)
	)

	label_fire_dur = crear_fila(vbox, "Fuego Vuelo: 2.5s", 
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
		current_cooldown = 5.0
		current_earth = 1.2
		current_earth_scale = 1.0
		current_fire_radius = 1.0
		current_fire_dur = 2.5
		current_gap = 0.6
		current_water_max = 1.0

		current_void_dur = 2.0
		current_void_rad = 60.0
		current_void_absorb_time = 4.0
		void_keep_upgrades_enabled = false
		void_round_absorbs_enabled = false

		air_double_enabled = false
		air_shock_enabled = false
		air_scramble_enabled = false
		air_storm_enabled = false

		water_burst_enabled = false
		water_lasting_enabled = false
		fire_trail_enabled = false
		fire_phoenix_enabled = false
		Global.debug_burrow = false
		Global.debug_walker = false

		aplicar_stat_directo("speed", 150.0)
		aplicar_stat_directo("cooldown", 5.0)
		aplicar_stat_directo("earth.duration", 1.2)
		aplicar_stat_directo("earth.scale", 1.0)
		aplicar_stat_directo("fire.radius", 1.0)
		aplicar_stat_directo("fire.duration", 2.5)
		aplicar_stat_directo("fire.trail", 0.0)
		aplicar_stat_directo("fire.phoenix", 0.0)
		aplicar_stat_directo("gap.time", 0.6)
		aplicar_stat_directo("air.recast_window", 0.0)
		aplicar_stat_directo("air.shock", 0.0)
		aplicar_stat_directo("air.scramble", 0.0)
		aplicar_stat_directo("air.storm", 0.0)
		aplicar_stat_directo("water.max_twins", 1.0)
		aplicar_stat_directo("water.twins_per_cast", 1.0)
		aplicar_stat_directo("water.lasting_twin", 0.0)
		aplicar_stat_directo("void.duration", 2.0)
		aplicar_stat_directo("void.radius", 60.0)
		aplicar_stat_directo("void.absorb_time", 4.0)
		aplicar_stat_directo("void.keep_upgrades", 0.0)
		aplicar_stat_directo("void.round_absorbs", 0.0)

		actualizar_boton_void_upgrades()
		actualizar_boton_void_round()
		actualizar_boton_aire_doble()
		actualizar_boton_aire_shock()
		actualizar_boton_aire_scramble()
		actualizar_boton_aire_storm()
		actualizar_boton_rafaga()
		actualizar_boton_duradero()
		actualizar_boton_incendio()
		actualizar_boton_fenix()
		actualizar_boton_excavador()
		actualizar_boton_caminante()
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

func actualizar_boton_void_upgrades() -> void:
	if btn_void_keep_upgrades:
		if void_keep_upgrades_enabled:
			btn_void_keep_upgrades.text = "🔮 Vacío: ROBA CON MEJORAS (Épica)"
			btn_void_keep_upgrades.modulate = Color(0.8, 0.4, 1.0)
		else:
			btn_void_keep_upgrades.text = "🔮 Vacío: Roba Base (Sin mejoras del rival)"
			btn_void_keep_upgrades.modulate = Color(1.0, 1.0, 1.0)

func actualizar_boton_void_round() -> void:
	if btn_void_round_absorbs:
		if void_round_absorbs_enabled:
			btn_void_round_absorbs.text = "👑 Vacío: PODERES PERMANENTES EN RONDA"
			btn_void_round_absorbs.modulate = Color(1.0, 0.85, 0.2)
		else:
			btn_void_round_absorbs.text = "👑 Vacío: Poderes Temporales (4s)"
			btn_void_round_absorbs.modulate = Color(1.0, 1.0, 1.0)

func actualizar_boton_aire_doble() -> void:
	if btn_air_double:
		if air_double_enabled:
			btn_air_double.text = "🌀 Segundo Aliento: ACTIVADO (Doble salto)"
			btn_air_double.modulate = Color(0.3, 1.0, 0.4)
		else:
			btn_air_double.text = "🌀 Segundo Aliento: DESACTIVADO"
			btn_air_double.modulate = Color(1.0, 1.0, 1.0)

func actualizar_boton_aire_shock() -> void:
	if btn_air_shock:
		if air_shock_enabled:
			btn_air_shock.text = "⚡ Descarga Estática: ACTIVADO (Sin poder 5s)"
			btn_air_shock.modulate = Color(0.3, 0.9, 1.0)
		else:
			btn_air_shock.text = "⚡ Descarga Estática: DESACTIVADO"
			btn_air_shock.modulate = Color(1.0, 1.0, 1.0)

func actualizar_boton_aire_scramble() -> void:
	if btn_air_scramble:
		if air_scramble_enabled:
			btn_air_scramble.text = "🔀 Revoltijo: ACTIVADO (Invierte izq/der 3s)"
			btn_air_scramble.modulate = Color(0.9, 0.4, 1.0)
		else:
			btn_air_scramble.text = "🔀 Revoltijo: DESACTIVADO"
			btn_air_scramble.modulate = Color(1.0, 1.0, 1.0)

func actualizar_boton_aire_storm() -> void:
	if btn_air_storm:
		if air_storm_enabled:
			btn_air_storm.text = "🌩️ Cerca de Tormenta: ACTIVADO (Rayos en huecos)"
			btn_air_storm.modulate = Color(0.5, 0.7, 1.0)
		else:
			btn_air_storm.text = "🌩️ Cerca de Tormenta: DESACTIVADO"
			btn_air_storm.modulate = Color(1.0, 1.0, 1.0)

func actualizar_boton_rafaga() -> void:
	if btn_water_burst:
		if water_burst_enabled:
			btn_water_burst.text = "🌊 Ráfaga Gemela: ACTIVADO (2 por cast)"
			btn_water_burst.modulate = Color(0.2, 0.8, 1.0)
		else:
			btn_water_burst.text = "🌊 Ráfaga Gemela: DESACTIVADO"
			btn_water_burst.modulate = Color(1.0, 1.0, 1.0)

func actualizar_boton_duradero() -> void:
	if btn_water_lasting:
		if water_lasting_enabled:
			btn_water_lasting.text = "💧 Gemelo Duradero: ACTIVADO (Estela libre)"
			btn_water_lasting.modulate = Color(0.4, 0.9, 1.0)
		else:
			btn_water_lasting.text = "💧 Gemelo Duradero: DESACTIVADO"
			btn_water_lasting.modulate = Color(1.0, 1.0, 1.0)

func actualizar_boton_incendio() -> void:
	if btn_fire_trail:
		if fire_trail_enabled:
			btn_fire_trail.text = "🔥 Fuego Incendio: ACTIVADO (Rastro)"
			btn_fire_trail.modulate = Color(1.0, 0.5, 0.1)
		else:
			btn_fire_trail.text = "🔥 Fuego Incendio: DESACTIVADO"
			btn_fire_trail.modulate = Color(1.0, 1.0, 1.0)

func actualizar_boton_fenix() -> void:
	if btn_fire_phoenix:
		if fire_phoenix_enabled:
			btn_fire_phoenix.text = "🦅 Fénix: ACTIVADO (Renacer)"
			btn_fire_phoenix.modulate = Color(1.0, 0.85, 0.2)
		else:
			btn_fire_phoenix.text = "🦅 Fénix: DESACTIVADO"
			btn_fire_phoenix.modulate = Color(1.0, 1.0, 1.0)

func actualizar_boton_excavador() -> void:
	if btn_earth_burrow:
		if Global.debug_burrow:
			btn_earth_burrow.text = "⛏️ Tierra Excavador: ACTIVADO"
			btn_earth_burrow.modulate = Color(0.85, 0.55, 0.2)
		else:
			btn_earth_burrow.text = "⛏️ Tierra Excavador: DESACTIVADO"
			btn_earth_burrow.modulate = Color(1.0, 1.0, 1.0)

func actualizar_boton_caminante() -> void:
	if btn_earth_walker:
		if Global.debug_walker:
			btn_earth_walker.text = "🪨 Caminante de Piedra: ACTIVADO"
			btn_earth_walker.modulate = Color(0.9, 0.8, 0.4)
		else:
			btn_earth_walker.text = "🪨 Caminante de Piedra: DESACTIVADO"
			btn_earth_walker.modulate = Color(1.0, 1.0, 1.0)

func cambiar_stat(tipo: String, delta: float) -> void:
	match tipo:
		"speed":
			current_speed = clamp(current_speed + delta, 50.0, 1000.0)
			aplicar_stat_directo("speed", current_speed)
		"cooldown":
			current_cooldown = clamp(current_cooldown + delta, 0.1, 15.0)
			aplicar_stat_directo("cooldown", current_cooldown)
		"earth.duration":
			current_earth = clamp(current_earth + delta, 0.25, 15.0)
			aplicar_stat_directo("earth.duration", current_earth)
		"earth.scale":
			current_earth_scale = clamp(current_earth_scale + delta, 0.5, 4.0)
			aplicar_stat_directo("earth.scale", current_earth_scale)
		"fire.radius":
			current_fire_radius = clamp(current_fire_radius + delta, 0.25, 4.0)
			aplicar_stat_directo("fire.radius", current_fire_radius)
		"fire.duration":
			current_fire_dur = clamp(current_fire_dur + delta, 0.5, 10.0)
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
		"void.absorb_time":
			current_void_absorb_time = clamp(current_void_absorb_time + delta, 1.0, 30.0)
			aplicar_stat_directo("void.absorb_time", current_void_absorb_time)
	actualizar_textos()

func actualizar_textos() -> void:
	if label_speed: label_speed.text = "Velocidad: %d" % int(current_speed)
	if label_cooldown: label_cooldown.text = "Cooldown: %.1fs" % current_cooldown
	if label_earth: label_earth.text = "Tierra Dur: %.2fs" % current_earth
	if label_earth_scale: label_earth_scale.text = "Tierra Ancho: %.2fx" % current_earth_scale
	if label_fire_radius: label_fire_radius.text = "Fuego Radio: %.2fx" % current_fire_radius
	if label_fire_dur: label_fire_dur.text = "Fuego Vuelo: %.1fs" % current_fire_dur
	if label_gap: label_gap.text = "Hueco Estela: %.2fs" % current_gap
	if label_water_max: label_water_max.text = "Agua Máx Gemelos: %d" % int(current_water_max)
	if label_void_dur: label_void_dur.text = "Vacío Duración: %.1fs" % current_void_dur
	if label_void_rad: label_void_rad.text = "Vacío Radio: %dpx" % int(current_void_rad)
	if label_void_absorb_time: label_void_absorb_time.text = "Tiempo Retención: %.1fs" % current_void_absorb_time

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_QUOTELEFT or event.keycode == KEY_ASCIITILDE or event.unicode == 96:
			visible = !visible
			get_viewport().set_input_as_handled()

func aplicar_stat_directo(stat_key: String, valor: float) -> void:
	for id in [1, 2, 3, 4, 5]:
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
			player.powerAvailable = true
			if player.has_node("ElementHeadSprite"):
				player.get_node("ElementHeadSprite").modulate = Color.WHITE

		if player.stats != null:
			player.stats.set_stat(stat_key, valor)
			player.refresh_stats()
