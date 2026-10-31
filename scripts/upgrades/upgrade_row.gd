extends HBoxContainer
class_name UpgradeRow

# One snake's row in the upgrade screen: its element and keys, its upgrade cards
# and its pick status. Only that snake's own Left/Right/Punchy keys drive it.

signal chosen(player_id, upgrade_id)

const DIRECTION_ICON = preload("res://assets/jorge-resources/Game Selection/direction icon.png")
const PUNCHY_ICON = preload("res://assets/jorge-resources/Game Selection/punchi icon.png")
const MOVE_SOUND = preload("res://assets/sounds/Button.ogg")
const CONFIRM_SOUND = preload("res://assets/sounds/ShroomEaten.ogg")
const AI_STEP_TIME = 0.3

var player_id
var player_color
var is_ai = false
# Which Player{N} keys browse this row (online a machine numbers its own players from 1)
var input_id
# Online: another machine picks for this snake; the row only shows its pick
var is_remote = false
# Online rival: its options, pick and current upgrades stay hidden
var is_hidden = false
var card_box
var cards = []
var focus_index = 0
var has_chosen = false
var status_label
var detail_label
var move_sound_player
var confirm_sound_player
var time = 0.0

# Call after the row is in the tree
func setup(id, options, ai, input = -1, remote = false, hidden = false):
	player_id = id
	is_remote = remote
	is_hidden = hidden
	is_ai = ai and not remote
	input_id = id if input == -1 else input
	player_color = Color(Global.playerColors[id])
	custom_minimum_size.y = 170
	add_theme_constant_override("separation", 24)

	add_child(_build_header())

	card_box = HBoxContainer.new()
	card_box.add_theme_constant_override("separation", 20)
	add_child(card_box)
	if is_hidden:
		card_box.modulate.a = 0.0 # Keeps the layout, shows nothing
	for upgrade in options:
		var card = UpgradeCard.new()
		card.setup(upgrade, player_color)
		card_box.add_child(card)
		cards.append(card)

	add_child(_build_status())

	move_sound_player = _sound_player(MOVE_SOUND, -12.0)
	confirm_sound_player = _sound_player(CONFIRM_SOUND, -4.0)

	_focus(0, false)
	if is_ai:
		_ai_pick()

func _process(delta):
	time += delta
	if not has_chosen:
		status_label.modulate.a = 0.55 + 0.45 * sin(time * 4.0)

func _unhandled_input(event):
	if has_chosen or is_ai or is_remote or input_id == 0:
		return
	var prefix = "Player" + str(input_id)
	if event.is_action_pressed(prefix + "Left"):
		_focus(focus_index - 1)
	elif event.is_action_pressed(prefix + "Right"):
		_focus(focus_index + 1)
	elif event.is_action_pressed(prefix + "Up"):
		confirm()
	else:
		return
	get_viewport().set_input_as_handled()

func _focus(index, play_sound = true):
	focus_index = posmod(index, cards.size())
	for i in cards.size():
		cards[i].set_focused(i == focus_index)
	if play_sound:
		move_sound_player.play()

# Picks the highlighted card. Also called by the screen when time runs out.
# A remote row waits for its machine's pick instead (pick()).
func confirm():
	if is_remote:
		return
	_confirm()

# Shows a pick made elsewhere (online) as if it was confirmed here
func pick(upgrade_id):
	for i in cards.size():
		if cards[i].upgrade.id == StringName(upgrade_id):
			_focus(i, false)
			break
	_confirm()

# The card that would be picked now (the host uses it for players who left)
func highlighted_id():
	return cards[focus_index].upgrade.id

func _confirm():
	if has_chosen:
		return
	has_chosen = true
	var card = cards[focus_index]
	for other in cards:
		if other != card:
			other.set_dimmed(true)
	card.play_chosen()
	confirm_sound_player.play()
	status_label.text = "READY!"
	status_label.modulate.a = 1.0
	status_label.add_theme_color_override("font_color", player_color)
	detail_label.text = "" if is_hidden else card.upgrade.name
	chosen.emit(player_id, card.upgrade.id)

# AI snakes browse a few cards and pick wherever they land
func _ai_pick():
	await _wait(randf_range(0.6, 1.2))
	var steps = randi_range(cards.size(), cards.size() * 2)
	for i in steps:
		if has_chosen:
			return
		_focus(focus_index + 1)
		await _wait(AI_STEP_TIME)
	await _wait(0.4)
	confirm()

# Timer owned by the row, so a pending AI pick dies with the row
func _wait(seconds):
	var timer = Timer.new()
	timer.one_shot = true
	add_child(timer)
	timer.start(seconds)
	await timer.timeout
	timer.queue_free()

func _build_header():
	var panel = PanelContainer.new()
	# Wide enough for the longest header so every row's cards line up
	panel.custom_minimum_size = Vector2(370, 0)
	panel.clip_contents = true
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.16, 0.16, 0.16)
	style.border_color = player_color
	style.border_width_left = 8
	style.set_corner_radius_all(18)
	style.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", style)

	var box = HBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	panel.add_child(box)

	var element = UpgradeCatalog.element_for_player(player_id)
	var symbol = TextureRect.new()
	symbol.texture = UpgradeIcon.FIRE_WATER_SYMBOL if element in ["fire", "water"] else UpgradeIcon.AIR_EARTH_SYMBOL
	symbol.flip_v = element in ["water", "earth"]
	symbol.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	symbol.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	symbol.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	symbol.custom_minimum_size = Vector2(90, 90)
	symbol.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	symbol.modulate = player_color
	box.add_child(symbol)

	var info = VBoxContainer.new()
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.add_theme_constant_override("separation", 6)
	box.add_child(info)
	info.add_child(_label(element.to_upper(), 40, player_color))
	info.add_child(_label("Player " + str(player_id) + ("  (AI)" if is_ai else ""), 22, Color(0.7, 0.7, 0.7)))
	info.add_child(_build_key_hints())
	# What this snake already has (only a count for online rivals)
	var badges = UpgradeBadges.new()
	info.add_child(badges)
	badges.refresh(player_id, is_hidden)
	return panel

func _build_key_hints():
	var hints = HBoxContainer.new()
	hints.add_theme_constant_override("separation", 6)
	if is_remote:
		hints.add_child(_label("Picking online", 20, Color(0.75, 0.75, 0.75)))
		return hints
	var prefix = "Player" + str(input_id)
	for hint in [["Left", DIRECTION_ICON, true], ["Right", DIRECTION_ICON, false], ["Up", PUNCHY_ICON, false]]:
		var hint_icon = TextureRect.new()
		hint_icon.texture = hint[1]
		hint_icon.flip_h = hint[2]
		hint_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		hint_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		hint_icon.custom_minimum_size = Vector2(20, 22)
		hints.add_child(hint_icon)
		hints.add_child(_label(Global.action_key_name(prefix + hint[0]) + " ", 20, Color.WHITE))
	return hints

func _build_status():
	var box = VBoxContainer.new()
	box.custom_minimum_size = Vector2(200, 0)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	status_label = _label("CHOOSING...", 28, Color(0.75, 0.75, 0.75))
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(status_label)
	detail_label = _label("", 22, player_color)
	detail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(detail_label)
	return box


func _sound_player(stream, volume_db):
	var player = AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = volume_db
	add_child(player)
	return player

func _label(text, font_size, font_color):
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", font_color)
	return label
