extends CanvasLayer
class_name RoundQuote

# The wisdom quote between rounds (scripts/upgrades/wisdom.gd: the round winner's element).
# One quote travels through the whole break, so it stays in view:
#  1. pop(): it pops up big over the arena when the round is won,
#  2. move_to(): it glides into the upgrade screen's quote spot while snakes pick,
#  3. to_countdown(): it glides under the next round's countdown,
#  4. vanish(): it fades out at GO.
# Above the upgrade screen (layer 5), below the pause menu.

const ODIN = preload("res://assets/jorge-resources/Game Selection/Odin Rounded - Bold.otf")
const FONT_SIZE = 46
const WIDTH = 1500.0
const MOVE_TIME = 0.6
## Where it waits during the countdown: under the "3, 2, 1" and the match's goal
const COUNTDOWN_CENTER = Vector2(960, 950)
const COUNTDOWN_SCALE = 0.62

var quote = {}
var winner_id = 0
var holder: Control
var tween: Tween

static func create(parent: Node, winner: int) -> RoundQuote:
	var round_quote = RoundQuote.new()
	round_quote.winner_id = winner
	round_quote.quote = Wisdom.for_winner(winner)
	parent.add_child(round_quote)
	return round_quote

func _ready():
	layer = 6
	holder = Control.new()
	holder.size = Vector2(WIDTH, 220)
	holder.pivot_offset = holder.size / 2
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.modulate.a = 0.0
	add_child(holder)
	var box = VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 8)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(box)
	var color = Color(Global.playerColors[winner_id]).lightened(0.25) if winner_id in [1, 2, 3, 4, 5] else Color(0.9, 0.9, 0.9)
	box.add_child(_label(tr("WISDOM_QUOTE") % tr(quote.text), FONT_SIZE, color))
	box.add_child(_label("— " + tr(quote.source), 26, Color(0.75, 0.75, 0.75)))

func _label(text, font_size, color) -> Label:
	var label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_override("font", ODIN)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	label.add_theme_constant_override("outline_size", 12)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _new_tween() -> Tween:
	if tween != null and tween.is_valid():
		tween.kill()
	# Keeps moving while the game is paused, like the screens it travels between
	tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel()
	return tween

# Pops up big at `center` (screen position)
func pop(center: Vector2):
	holder.position = center - holder.size / 2
	holder.scale = Vector2(0.6, 0.6)
	var t = _new_tween()
	t.tween_property(holder, "modulate:a", 1.0, 0.25)
	t.tween_property(holder, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

# Glides to `center`, shrinking (or growing) to `target_scale`
func move_to(center: Vector2, target_scale: float):
	var t = _new_tween()
	t.tween_property(holder, "modulate:a", 1.0, 0.2)
	t.tween_property(holder, "position", center - holder.size / 2, MOVE_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(holder, "scale", Vector2(target_scale, target_scale), MOVE_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)

func to_countdown():
	move_to(COUNTDOWN_CENTER, COUNTDOWN_SCALE)

func vanish():
	var t = _new_tween()
	t.tween_property(holder, "modulate:a", 0.0, 0.5)
	t.chain().tween_callback(queue_free)
