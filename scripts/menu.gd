extends Control

var Options 
@onready var shrooms_button =  $CanvasLayer/Modifiers/PanelContainer/ShroomsContainer/ShroomsButton
@onready var upgrades_button = $CanvasLayer/Modifiers/UpgradesPanel/UpgradesContainer/UpgradesButton
@onready var play_button = $CanvasLayer/TopMenu/VBoxContainer/PanelContainer/MarginContainer/VBoxContainer/Play
@onready var version_button = $CanvasLayer/ChangeLog/VBoxContainer/MarginContainer/ChangeLogButton
var patch_notes_scene = preload("res://scenes/patch_notes.tscn")

func _ready():
	# Back from a campaign scenario: the hotseat setup finds its players as they were
	Campaign.restore_match_globals()
	Options = $CanvasLayer/Options
	Options.hide()
	# Play opens Online / Hotseat / Roguelike (the old Multiplayer button went in there)
	$CanvasLayer/TopMenu/VBoxContainer/PanelContainer/MarginContainer/VBoxContainer/Multiplayer.hide()
	_build_play_menu()
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
		_open_hotseat()

# A new language (Options): the version label is built in code
func _notification(what):
	if what == NOTIFICATION_TRANSLATION_CHANGED and version_button != null:
		version_button.text = PatchNotes.version_label()

# Play: how to play (Online, Hotseat, Roguelike)
func _on_play_pressed():
	$CanvasLayer/TopMenu.hide()
	play_menu.show()
	play_menu_first.grab_focus.call_deferred()

var play_menu: Control
var play_menu_first: Button

func _build_play_menu():
	play_menu = CenterContainer.new()
	play_menu.name = "PlayMenu"
	play_menu.theme = $CanvasLayer/TopMenu.theme
	play_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	play_menu.hide()
	$CanvasLayer.add_child(play_menu)
	$CanvasLayer.move_child(play_menu, $CanvasLayer/TopMenu.get_index() + 1)
	var panel = PanelContainer.new()
	play_menu.add_child(panel)
	var margin = MarginContainer.new()
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 15)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 3)
	panel.add_child(margin)
	var box = VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(box)
	for entry in [["MENU_ONLINE", _on_multiplayer_pressed], ["MENU_HOTSEAT", _open_hotseat],
			["MENU_ROGUELIKE", _open_roguelike], ["UI_BACK", _close_play_menu]]:
		var button = Button.new()
		button.text = entry[0]
		button.pressed.connect(entry[1])
		box.add_child(button)
		if play_menu_first == null:
			play_menu_first = button

func _close_play_menu():
	play_menu.hide()
	$CanvasLayer/TopMenu.show()
	$CanvasLayer/ChangeLog.show()
	play_button.grab_focus.call_deferred()

func _unhandled_input(event):
	if play_menu != null and play_menu.visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close_play_menu()

# Hotseat: the local match setup
func _open_hotseat():
	play_menu.hide()
	$CanvasLayer/PlayerSetup.show()
	$CanvasLayer/TopMenu.hide()
	$CanvasLayer/ChangeLog.hide()
	$CanvasLayer/PlayerSetup/PanelContainer/PlayerSetup.recalculate_all_labels()

# Roguelike: the campaign's screen (save slots, the act's map)
func _open_roguelike():
	Campaign.slot = -1
	get_tree().change_scene_to_file(Campaign.SCREEN)

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
	$CanvasLayer/Modifiers.hide()
	$CanvasLayer/ChangeLog.show()
	play_menu.show()
	play_menu_first.grab_focus.call_deferred()

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
