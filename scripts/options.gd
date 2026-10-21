extends Control

signal back

func _on_back_pressed():
	emit_signal("back")

func _on_reset_controls_pressed():
	InputMap.load_from_project_settings()

# ---> AGREGAR ESTA FUNCIÓN AQUÍ ABAJO:
func _on_window_mode_item_selected(index: int) -> void:
	match index:
		0: # Full-screen (Exclusivo real)
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		1: # Windowed (Ventana normal con bordes)
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
		2: # Borderless Window (Ventana flotante sin marco)
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
		3: # Borderless Full-Screen (Pantalla completa sin bordes)
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
