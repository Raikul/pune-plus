extends Control

var Options 
@onready var shrooms_button = $CanvasLayer/Modifiers/PanelContainer/ShroomsContainer/ShroomsButton
@onready var upgrades_button = $CanvasLayer/Modifiers/UpgradesPanel/UpgradesContainer/UpgradesButton
@onready var play_button = $CanvasLayer/TopMenu/VBoxContainer/PanelContainer/MarginContainer/VBoxContainer/Play
@onready var version_button = $CanvasLayer/ChangeLog/VBoxContainer/MarginContainer/ChangeLogButton
var patch_notes_scene = preload("res://scenes/patch_notes.tscn")

@onready var main_menu = $CanvasLayer/TopMenu
@onready var credits_panel = $CreditsPanel

var credits_layer: CanvasLayer = null
var credits_root: Control = null
var credits_items: Array = []
var btn_volver: Button = null

var menu_font: Font = null
var menu_theme: Theme = null



func _detectar_estilo_menu() -> void:
	if play_button != null:
		# Extrae la fuente exacta que usa el botón Play del menú
		menu_font = play_button.get_theme_font("font")
		# Busca si algún padre tiene un Theme asignado para heredarlo completo
		var nodo: Node = play_button
		while nodo != null:
			if nodo is Control and nodo.theme != null:
				menu_theme = nodo.theme
				break
			nodo = nodo.get_parent()

func _crear_pantalla_creditos() -> void:
	if credits_panel != null:
		credits_panel.visible = false

	credits_layer = CanvasLayer.new()
	credits_layer.layer = 120
	credits_layer.visible = false
	add_child(credits_layer)

	# Contenedor raíz Control con el tema heredado del menú
	credits_root = Control.new()
	credits_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	if menu_theme != null:
		credits_root.theme = menu_theme
	credits_layer.add_child(credits_root)

	# Fondo oscuro
	var fondo = ColorRect.new()
	fondo.color = Color(0.03, 0.03, 0.05, 0.96)
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	credits_root.add_child(fondo)

	# Botón BACK con el mismo estilo del menú
	btn_volver = Button.new()
	btn_volver.text = "BACK"
	btn_volver.custom_minimum_size = Vector2(200, 48)
	if play_button != null:
		btn_volver.flat = play_button.flat
		btn_volver.theme_type_variation = play_button.theme_type_variation
	if menu_font != null:
		btn_volver.add_theme_font_override("font", menu_font)
	btn_volver.add_theme_font_size_override("font_size", 26)
	btn_volver.pressed.connect(_on_back_credits_button_pressed)
	credits_root.add_child(btn_volver)

func _on_credits_button_pressed() -> void:
	if main_menu != null:
		main_menu.hide()
	if credits_layer != null:
		credits_layer.show()
		_animar_creditos()

func _on_back_credits_button_pressed() -> void:
	if credits_layer != null:
		credits_layer.hide()
	if main_menu != null:
		main_menu.show()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and credits_layer != null and credits_layer.visible:
		_on_back_credits_button_pressed()
		get_viewport().set_input_as_handled()

# ====================================================================
# PRESENTACIÓN ELEMENTAL CON EFECTOS GRÁFICOS
# ====================================================================
func _animar_creditos() -> void:
	for item in credits_items:
		if is_instance_valid(item):
			item.queue_free()
	credits_items.clear()

	var screen = get_viewport_rect().size
	var cx = screen.x * 0.5
	var start_y = screen.y * 0.30

	if btn_volver != null:
		btn_volver.position = Vector2(cx - 100, screen.y - 80)

	# Título principal con la fuente del menú
	var title = Label.new()
	title.text = "DEVELOPMENT TEAM"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if menu_font != null:
		title.add_theme_font_override("font", menu_font)
	title.add_theme_font_size_override("font_size", 38)
	title.position = Vector2(cx - 300, screen.y * 0.16)
	title.custom_minimum_size = Vector2(600, 45)
	title.modulate = Color(0.95, 0.95, 1.0, 0.0)
	credits_root.add_child(title)
	credits_items.append(title)

	var tw_title = create_tween()
	tw_title.tween_property(title, "modulate:a", 1.0, 0.8)
	await get_tree().create_timer(0.6).timeout

	# -------------------------------------------------------------
	# 1. NICOLAS ALTOMONTE (TIERRA - Grieta solo al principio y polvo)
	# -------------------------------------------------------------
	var y_nico = start_y
	var lbl_nico = _crear_etiqueta_nombre("Nicolas Altomonte", Color(0.95, 0.75, 0.2), cx, y_nico)
	lbl_nico.position.y = screen.y + 60
	lbl_nico.modulate.a = 0.0

	var tw_nico = create_tween().set_parallel(true)
	tw_nico.tween_property(lbl_nico, "position:y", y_nico, 1.0).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw_nico.tween_property(lbl_nico, "modulate:a", 1.0, 0.6)

	await get_tree().create_timer(0.85).timeout
	_efecto_tierra(Vector2(cx, y_nico + 34))
	await get_tree().create_timer(0.5).timeout

	# -------------------------------------------------------------
	# 2. GUSTAVO CHA (AGUA - Corriente ondulante y gotas)
	# -------------------------------------------------------------
	var y_gustavo = start_y + 65
	var lbl_gustavo = _crear_etiqueta_nombre("Gustavo Cha", Color(0.0, 0.9, 0.6), cx, y_gustavo)
	lbl_gustavo.position.x = -450
	lbl_gustavo.modulate.a = 0.0

	_efecto_agua(Vector2(cx - 350, y_gustavo + 20), Vector2(cx + 350, y_gustavo + 20))

	var tw_gustavo = create_tween().set_parallel(true)
	tw_gustavo.tween_property(lbl_gustavo, "position:x", cx - 300, 1.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw_gustavo.tween_property(lbl_gustavo, "modulate:a", 1.0, 0.6)

	await get_tree().create_timer(0.9).timeout

	# -------------------------------------------------------------
	# 3. PORLON (FUEGO - Llamarada y chispas ascendentes)
	# -------------------------------------------------------------
	var y_porlon = start_y + 130
	var lbl_porlon = _crear_etiqueta_nombre("Andres Alvarez Godeken", Color(1.0, 0.35, 0.1), cx, y_porlon)
	lbl_porlon.scale = Vector2(2.6, 2.6)
	lbl_porlon.pivot_offset = Vector2(300, 20)
	lbl_porlon.modulate.a = 0.0

	var tw_porlon = create_tween().set_parallel(true)
	tw_porlon.tween_property(lbl_porlon, "scale", Vector2.ONE, 0.8).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw_porlon.tween_property(lbl_porlon, "modulate:a", 1.0, 0.45)

	await get_tree().create_timer(0.55).timeout
	_efecto_fuego(Vector2(cx, y_porlon + 20))
	await get_tree().create_timer(0.6).timeout

	# -------------------------------------------------------------
	# 4. IVAN VALENTINI (RAYO - Arco de relámpago y chispas eléctricas)
	# -------------------------------------------------------------
	var y_ivan = start_y + 195
	var lbl_ivan = _crear_etiqueta_nombre("Ivan Valentini", Color(0.2, 0.75, 1.0), cx, y_ivan)
	lbl_ivan.modulate.a = 0.0

	_efecto_rayo(Vector2(cx, y_ivan - 120), Vector2(cx, y_ivan + 15))

	var tw_ivan = create_tween()
	for i in range(4):
		tw_ivan.tween_property(lbl_ivan, "modulate:a", 1.0, 0.08)
		tw_ivan.tween_property(lbl_ivan, "modulate:a", 0.1, 0.06)
	tw_ivan.tween_property(lbl_ivan, "modulate:a", 1.0, 0.2)

# ====================================================================
# EFECTOS GRÁFICOS ELEMENTALES
# ====================================================================

# Tierra: Grieta temporal (solo al principio) y polvo de roca
func _efecto_tierra(pos: Vector2) -> void:
	var crack = Line2D.new()
	crack.width = 4.0
	crack.default_color = Color(0.9, 0.7, 0.2, 0.85)
	var pts: Array[Vector2] = []
	for i in range(-12, 13):
		var px = pos.x + (i * 20)
		var py = pos.y + (randf_range(-4, 4) if abs(i) < 10 else 0)
		pts.append(Vector2(px, py))
	crack.points = PackedVector2Array(pts)
	credits_layer.add_child(crack)
	credits_items.append(crack)

	# La grieta aparece en el impacto inicial y luego desaparece suavemente
	var tw_crack = create_tween()
	tw_crack.tween_interval(0.3)
	tw_crack.tween_property(crack, "modulate:a", 0.0, 0.5)
	tw_crack.tween_callback(crack.queue_free)

	var p = CPUParticles2D.new()
	p.position = pos
	p.amount = 35
	p.lifetime = 0.9
	p.one_shot = true
	p.explosiveness = 0.85
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(180, 4)
	p.direction = Vector2(0, -1)
	p.spread = 50.0
	p.gravity = Vector2(0, 350)
	p.initial_velocity_min = 90.0
	p.initial_velocity_max = 180.0
	p.scale_amount_min = 3.0
	p.scale_amount_max = 7.0
	p.color = Color(0.95, 0.75, 0.25)
	credits_layer.add_child(p)
	credits_items.append(p)
	p.emitting = true

# Agua: Corriente fluida y salpicaduras
func _efecto_agua(from_pos: Vector2, to_pos: Vector2) -> void:
	var wave = Line2D.new()
	wave.width = 5.0
	wave.default_color = Color(0.0, 0.9, 0.65, 0.75)
	var pts: Array[Vector2] = []
	var steps = 24
	for i in range(steps + 1):
		var t = float(i) / steps
		var x = lerp(from_pos.x, to_pos.x, t)
		var y = from_pos.y + sin(t * TAU * 2.5) * 12.0
		pts.append(Vector2(x, y))
	wave.points = PackedVector2Array(pts)
	credits_layer.add_child(wave)
	credits_items.append(wave)

	var tw = create_tween()
	tw.tween_property(wave, "modulate:a", 0.0, 1.4)

	var p = CPUParticles2D.new()
	p.position = Vector2((from_pos.x + to_pos.x) * 0.5, from_pos.y)
	p.amount = 40
	p.lifetime = 1.0
	p.one_shot = true
	p.explosiveness = 0.7
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(240, 8)
	p.direction = Vector2(1, -0.4)
	p.spread = 60.0
	p.gravity = Vector2(0, 200)
	p.initial_velocity_min = 70.0
	p.initial_velocity_max = 150.0
	p.scale_amount_min = 2.5
	p.scale_amount_max = 5.5
	p.color = Color(0.1, 0.85, 0.7)
	credits_layer.add_child(p)
	credits_items.append(p)
	p.emitting = true

# Fuego: Llamarada ardiente que sube
func _efecto_fuego(pos: Vector2) -> void:
	var p = CPUParticles2D.new()
	p.position = pos
	p.amount = 60
	p.lifetime = 1.1
	p.one_shot = true
	p.explosiveness = 0.6
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(160, 6)
	p.direction = Vector2(0, -1)
	p.spread = 35.0
	p.gravity = Vector2(0, -180)
	p.initial_velocity_min = 100.0
	p.initial_velocity_max = 220.0
	p.scale_amount_min = 4.0
	p.scale_amount_max = 9.0
	p.color = Color(1.0, 0.35, 0.1)
	credits_layer.add_child(p)
	credits_items.append(p)
	p.emitting = true

# Rayo: Relámpago en zigzag y chispas eléctricas
func _efecto_rayo(from_pos: Vector2, to_pos: Vector2) -> void:
	var bolt = Line2D.new()
	bolt.width = 4.0
	bolt.default_color = Color(0.7, 0.9, 1.0)
	var pts: Array[Vector2] = []
	var segments = 7
	for i in range(segments + 1):
		var t = float(i) / segments
		var p = from_pos.lerp(to_pos, t)
		if i > 0 and i < segments:
			p.x += randf_range(-22, 22)
		pts.append(p)
	bolt.points = PackedVector2Array(pts)
	credits_layer.add_child(bolt)
	credits_items.append(bolt)

	var tw = create_tween()
	tw.tween_property(bolt, "modulate:a", 0.0, 0.3)

	var p = CPUParticles2D.new()
	p.position = to_pos
	p.amount = 35
	p.lifetime = 0.5
	p.one_shot = true
	p.explosiveness = 0.9
	p.spread = 180.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 120.0
	p.initial_velocity_max = 240.0
	p.scale_amount_min = 2.5
	p.scale_amount_max = 5.0
	p.color = Color(0.3, 0.85, 1.0)
	credits_layer.add_child(p)
	credits_items.append(p)
	p.emitting = true

func _crear_etiqueta_nombre(nombre: String, color: Color, cx: float, cy: float) -> Label:
	var lbl = Label.new()
	lbl.text = nombre
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if menu_font != null:
		lbl.add_theme_font_override("font", menu_font)
	lbl.add_theme_font_size_override("font_size", 30)
	lbl.position = Vector2(cx - 300, cy)
	lbl.custom_minimum_size = Vector2(600, 42)
	lbl.modulate = color
	credits_root.add_child(lbl)
	credits_items.append(lbl)
	return lbl
func _ready():
	_crear_pantalla_creditos()
	_detectar_estilo_menu()
	Options = $CanvasLayer/Options
	Options.hide()
	# The teams picked in setup again (Random teams only dealt them for that match)
	Global.match_teams = {}
	# Shrooms and upgrades moved to player setup's match settings
	$CanvasLayer/Modifiers.hide()
	# Back from an online match
	if SteamNet.is_online():
		SteamNet.leave()
	# Local play: Steam stops, so friends don't see the game as running
	SteamNet.stop_steam()
	# The version (Project Settings > Application > Config > Version) opens the patch notes
	version_button.text = PatchNotes.version_label()
	# The menu's display font has no digits (demo font), so the version uses Odin
	version_button.add_theme_font_override("font", preload("res://assets/jorge-resources/Game Selection/Odin Rounded - Bold.otf"))
	version_button.tooltip_text = "MENU_PATCH_NOTES"
	shrooms_button.button_pressed = Global.shrooms
	upgrades_button.button_pressed = Global.upgrades
	# Only when the game starts: afterwards the mode chosen in Options stays
	if not Global.window_mode_applied:
		Global.apply_window_mode()
	get_tree().paused = false
	play_button.grab_focus.call_deferred()
	# "Quit" on a match's end screen: back to player setup, ready for another one
	if Global.open_player_setup:
		Global.open_player_setup = false
		_on_play_pressed()

# A new language (Options): the version label is built in code
func _notification(what):
	if what == NOTIFICATION_TRANSLATION_CHANGED and version_button != null:
		version_button.text = PatchNotes.version_label()

func _on_play_pressed():
	$CanvasLayer/PlayerSetup.show()
	$CanvasLayer/TopMenu.hide()
	$CanvasLayer/ChangeLog.hide()
	$CanvasLayer/PlayerSetup/PanelContainer/PlayerSetup.recalculate_all_labels()

func _on_options_pressed():
	Options.show()
	$CanvasLayer/TopMenu.hide()
	$CanvasLayer/ChangeLog.hide()
	Options.focus_first()

func _on_quit_pressed():
	get_tree().quit()

func _on_options_back_button_pressed():
	Options.hide()
	$CanvasLayer/TopMenu.show()
	$CanvasLayer/ChangeLog.show()
	play_button.grab_focus.call_deferred()

func _on_player_setup_go():
	get_tree().change_scene_to_file("res://scenes/Playground.tscn")

func _on_player_setup_back():
	$CanvasLayer/PlayerSetup.hide()
	$CanvasLayer/TopMenu.show()
	$CanvasLayer/ChangeLog.show()
	$CanvasLayer/Modifiers.hide()
	play_button.grab_focus.call_deferred()

func _on_change_log_button_pressed():
	var patch_notes = patch_notes_scene.instantiate()
	# Above the menu's CanvasLayer
	var layer = CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	layer.add_child(patch_notes)
	patch_notes.closed.connect(func():
		layer.queue_free()
		version_button.grab_focus.call_deferred())

func _on_shrooms_button_toggled(button_pressed):
	Global.shrooms = button_pressed
	Global.save_settings()

func _on_upgrades_button_toggled(button_pressed):
	Global.upgrades = button_pressed
	Global.save_settings()

#Region Multiplayer
func _on_multiplayer_pressed():
	get_tree().change_scene_to_file("res://scenes/net/online_lobby.tscn")


# Like Options: the menu steps aside while it's open
func _on_instructions_pressed() -> void:
	$CanvasLayer/TopMenu.hide()
	$CanvasLayer/ChangeLog.hide()
	%Instrucciones.show()
	if not %Instrucciones.closed.is_connected(_on_instructions_closed):
		%Instrucciones.closed.connect(_on_instructions_closed)

func _on_instructions_closed() -> void:
	$CanvasLayer/TopMenu.show()
	$CanvasLayer/ChangeLog.show()
	play_button.grab_focus.call_deferred()
	pass
