extends Control

var Options 
@onready var shrooms_button =  $CanvasLayer/Modifiers/PanelContainer/ShroomsContainer/ShroomsButton
@onready var upgrades_button = $CanvasLayer/Modifiers/UpgradesPanel/UpgradesContainer/UpgradesButton
@onready var play_button = $CanvasLayer/TopMenu/VBoxContainer/PanelContainer/MarginContainer/VBoxContainer/Play
@onready var version_button = $CanvasLayer/ChangeLog/VBoxContainer/MarginContainer/ChangeLogButton
var patch_notes_scene = preload("res://scenes/patch_notes.tscn")

func _ready():
	Options = $CanvasLayer/Options
	Options.hide()
	# Back from an online match
	if SteamNet.is_online():
		SteamNet.leave()
	# The version (Project Settings > Application > Config > Version) opens the patch notes
	version_button.text = PatchNotes.version_label()
	# The menu's display font has no digits (demo font), so the version uses Odin
	version_button.add_theme_font_override("font", preload("res://assets/jorge-resources/Game Selection/Odin Rounded - Bold.otf"))
	version_button.tooltip_text = "Patch notes"
	shrooms_button.button_pressed = Global.shrooms
	upgrades_button.button_pressed = Global.upgrades
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
	get_tree().paused = false
	play_button.grab_focus.call_deferred()
	pass

func _on_play_pressed():
	$CanvasLayer/PlayerSetup.show()
	$CanvasLayer/TopMenu.hide()
	$CanvasLayer/ChangeLog.hide()
	$CanvasLayer/Modifiers.show()
	$CanvasLayer/PlayerSetup/PanelContainer/PlayerSetup.recalculate_all_labels()

func _on_options_pressed():
	Options.show()
	$CanvasLayer/TopMenu.hide()
	$CanvasLayer/ChangeLog.hide()
	$CanvasLayer/Options/CenterContainer/PanelContainer/MarginContainer/TabContainer/Video/WindowMode/OptionButton.grab_focus.call_deferred()

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

func _on_upgrades_button_toggled(button_pressed):
	Global.upgrades = button_pressed

#Region Multiplayer
func _on_multiplayer_pressed():
	get_tree().change_scene_to_file("res://scenes/net/online_lobby.tscn")


func _on_instructions_pressed() -> void:
	%Instrucciones.show()
	pass
