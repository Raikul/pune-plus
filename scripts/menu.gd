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
var credits_items: Array = []
var btn_volver: Button = null

func _crear_pantalla_creditos() -> void:
	if credits_panel != null:
		credits_panel.visible = false

	# Capa por encima de todo
	credits_layer = CanvasLayer.new()
	credits_layer.layer = 120
	credits_layer.visible = false
	add_child(credits_layer)

	# Fondo oscuro uniforme
	var fondo = ColorRect.new()
	fondo.color = Color(0.04, 0.04, 0.06, 0.95)
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	credits_layer.add_child(fondo)

	# Botón BACK abajo al centro
	btn_volver = Button.new()
	btn_volver.text = "BACK"
	btn_volver.custom_minimum_size = Vector2(180, 45)
	btn_volver.add_theme_font_size_override("font_size", 20)
	btn_volver.pressed.connect(_on_back_credits_button_pressed)
	credits_layer.add_child(btn_volver)

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
# PRESENTACIÓN ELEMENTAL (Versión más lenta y cinematográfica)
# ====================================================================
func _animar_creditos() -> void:
	for item in credits_items:
		if is_instance_valid(item):
			item.queue_free()
	credits_items.clear()

	var screen = get_viewport_rect().size
	var cx = screen.x * 0.5
	var start_y = screen.y * 0.30

	# Botón BACK abajo
	if btn_volver != null:
		btn_volver.position = Vector2(cx - 90, screen.y - 75)

	# Título principal con aparición suave
	var title = Label.new()
	title.text = "DEVELOPMENT TEAM"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	title.position = Vector2(cx - 300, screen.y * 0.16)
	title.custom_minimum_size = Vector2(600, 40)
	title.modulate = Color(0.95, 0.95, 1.0, 0.0)
	credits_layer.add_child(title)
	credits_items.append(title)

	var tw_title = create_tween()
	tw_title.tween_property(title, "modulate:a", 1.0, 0.8)

	await get_tree().create_timer(0.6).timeout

	# -------------------------------------------------------------
	# 1. NICOLAS ALTOMONTE (TIERRA - Sube lento y pesado desde el piso)
	# -------------------------------------------------------------
	var y_nico = start_y
	var lbl_nico = _crear_etiqueta_nombre("Nicolas Altomonte", Color(0.95, 0.75, 0.2), cx, y_nico)
	lbl_nico.position.y = screen.y + 60
	lbl_nico.modulate.a = 0.0

	var tw_nico = create_tween().set_parallel(true)
	tw_nico.tween_property(lbl_nico, "position:y", y_nico, 1.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw_nico.tween_property(lbl_nico, "modulate:a", 1.0, 0.7)

	await get_tree().create_timer(0.75).timeout

	# -------------------------------------------------------------
	# 2. GUSTAVO CHA (AGUA - Se desliza suave como una ola desde el costado)
	# -------------------------------------------------------------
	var y_gustavo = start_y + 65
	var lbl_gustavo = _crear_etiqueta_nombre("Gustavo Cha", Color(0.0, 0.9, 0.6), cx, y_gustavo)
	lbl_gustavo.position.x = -450
	lbl_gustavo.modulate.a = 0.0

	var tw_gustavo = create_tween().set_parallel(true)
	tw_gustavo.tween_property(lbl_gustavo, "position:x", cx - 300, 1.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw_gustavo.tween_property(lbl_gustavo, "modulate:a", 1.0, 0.7)

	await get_tree().create_timer(0.75).timeout

	# -------------------------------------------------------------
	# 3. PORLON(FUEGO - Desciende con impacto de escala)
	# -------------------------------------------------------------
	var y_porlon = start_y + 130
	var lbl_porlon = _crear_etiqueta_nombre("Porlon", Color(1.0, 0.3, 0.1), cx, y_porlon)
	lbl_porlon.scale = Vector2(2.8, 2.8)
	lbl_porlon.pivot_offset = Vector2(300, 19)
	lbl_porlon.modulate.a = 0.0

	var tw_porlon = create_tween().set_parallel(true)
	tw_porlon.tween_property(lbl_porlon, "scale", Vector2.ONE, 0.85).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw_porlon.tween_property(lbl_porlon, "modulate:a", 1.0, 0.5)

	await get_tree().create_timer(0.75).timeout

	# -------------------------------------------------------------
	# 4. IVAN VALENTINI (RAYO - Parpadeos eléctricos bien marcados)
	# -------------------------------------------------------------
	var y_ivan = start_y + 195
	var lbl_ivan = _crear_etiqueta_nombre("Ivan Valentini", Color(0.1, 0.7, 1.0), cx, y_ivan)
	lbl_ivan.modulate.a = 0.0

	var tw_ivan = create_tween()
	for i in range(4):
		tw_ivan.tween_property(lbl_ivan, "modulate:a", 1.0, 0.09)
		tw_ivan.tween_property(lbl_ivan, "modulate:a", 0.0, 0.07)
	tw_ivan.tween_property(lbl_ivan, "modulate:a", 1.0, 0.2)

func _crear_etiqueta_nombre(nombre: String, color: Color, cx: float, cy: float) -> Label:
	var lbl = Label.new()
	lbl.text = nombre
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 26)
	lbl.position = Vector2(cx - 300, cy)
	lbl.custom_minimum_size = Vector2(600, 38)
	lbl.modulate = color
	credits_layer.add_child(lbl)
	credits_items.append(lbl)
	return lbl
	
func _ready():
	_crear_pantalla_creditos()
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
