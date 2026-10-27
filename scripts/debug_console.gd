extends CanvasLayer

var panel: Panel
var input_line: LineEdit
var log_label: RichTextLabel

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 128
	visible = false
	crear_interfaz()

func crear_interfaz() -> void:
	panel = Panel.new()
	panel.custom_minimum_size = Vector2(700, 220)
	panel.position = Vector2(20, 20)
	add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_child(vbox)

	log_label = RichTextLabel.new()
	log_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_label.scroll_following = true
	log_label.text = "[color=yellow]Consola lista. Escribe 'help' para ver comandos.[/color]\n"
	vbox.add_child(log_label)

	input_line = LineEdit.new()
	input_line.placeholder_text = "Escribe un comando (ej: speed 400, cd 0.1)..."
	input_line.text_submitted.connect(_on_command_submitted)
	vbox.add_child(input_line)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_QUOTELEFT or event.keycode == KEY_ASCIITILDE or event.unicode == 96:
			toggle_console()
			get_viewport().set_input_as_handled()

func toggle_console() -> void:
	visible = !visible
	if visible:
		input_line.clear()
		input_line.grab_focus()

func print_log(msg: String) -> void:
	log_label.append_text(msg + "\n")

func _on_command_submitted(text: String) -> void:
	input_line.clear()
	var raw = text.strip_edges()
	if raw.is_empty():
		return

	print_log("[color=white]> " + raw + "[/color]")
	ejecutar_comando(raw)

func ejecutar_comando(comando: String) -> void:
	var partes = comando.split(" ", false)
	var cmd = partes[0].to_lower()

	match cmd:
		"help":
			print_log("[color=cyan]Comandos:[/color]")
			print_log("  speed <valor> -> Cambia velocidad (ej: speed 400)")
			print_log("  cd <segundos> -> Cambia cooldown (ej: cd 0.1)")
			print_log("  earth_dur <s > -> Invulnerabilidad tierra (ej: earth_dur 5)")
			print_log("  stats         -> Muestra stats de las serpientes")
			print_log("  clear         -> Limpia la consola")

		"clear":
			log_label.clear()

		"speed":
			if partes.size() < 2:
				print_log("[color=red]Uso: speed <valor>[/color]")
				return
			var val = partes[1].to_float()
			aplicar_stat_directo("speed", val)

		"cd", "cooldown":
			if partes.size() < 2:
				print_log("[color=red]Uso: cd <segundos>[/color]")
				return
			var val = partes[1].to_float()
			aplicar_stat_directo("cooldown", val)

		"earth_dur":
			if partes.size() < 2:
				print_log("[color=red]Uso: earth_dur <segundos>[/color]")
				return
			var val = partes[1].to_float()
			aplicar_stat_directo("earth.duration", val)

		"stats":
			var players = get_tree().get_nodes_in_group("activePlayers")
			if players.is_empty():
				print_log("[color=red]No hay serpientes activas.[/color]")
			for p in players:
				print_log("[color=yellow]Player %s:[/color] Speed = %s" % [str(p.playerId), str(p.speed)])

		_:
			print_log("[color=red]Comando desconocido. Escribe 'help'.[/color]")

func aplicar_stat_directo(stat_key: String, valor: float) -> void:
	# 1. Asegurar Global (si era null, lo crea aquí mismo)
	for id in [1, 2, 3, 4]:
		if Global.player_stats.get(id) == null:
			Global.player_stats[id] = PlayerStats.new()
		Global.player_stats[id].set_stat(stat_key, valor)

	# 2. Modificar en vivo y al instante a las serpientes en pantalla
	var serpientes_afectadas = 0
	for player in get_tree().get_nodes_in_group("activePlayers"):
		serpientes_afectadas += 1
		
		# Aplica velocidad al instante
		if stat_key == "speed":
			player.speed = valor
		
		# Aplica cooldown al instante y habilita el poder de inmediato
		if stat_key == "cooldown":
			var timer = player.get_node_or_null("CooldownTimer")
			if timer:
				timer.stop() # Cancela la espera vieja que estuviera corriendo
				timer.wait_time = max(valor, 0.05)
			
			player.powerAvailable = true # Poder listo para usar YA
			if player.has_node("ElementHeadSprite"):
				player.get_node("ElementHeadSprite").modulate = Color.WHITE

		# Si el jugador tiene el objeto stats, lo actualiza también
		if player.stats != null:
			player.stats.set_stat(stat_key, valor)
			player.refresh_stats()

	print_log("[color=green]Fijado '%s' en %s (%d serpientes modificadas).[/color]" % [stat_key, str(valor), serpientes_afectadas])
