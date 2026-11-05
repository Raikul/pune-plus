extends Node
class_name ReplayRecorder

# Keeps the last CLIP_SECONDS of play as a small video and picks the "play of the game"
# shown after the win screen (scripts/replay/replay_screen.gd).
#
# Recording: while a round runs, FPS times a second the screen is scaled down on the GPU
# (a SubViewport showing the window's texture), read back and compressed to JPG on a
# worker thread. The frames go into a ring that only holds the last CLIP_SECONDS.
#
# Picking: something worth seeing (Global.note_highlight: kills, Phoenix rising, a twin
# saving the water snake...) schedules a look at the ring AFTER_EVENT seconds later, so
# the clip shows what followed too. The ring then gets a score (the highlights in it, more
# for several kills in a row by the same snake) and, if it beats the best clip so far, it
# becomes the play of the game. Keeping a clip costs nothing: the frames are shared.
#
# Each machine records its own screen (online too); nothing is sent over the network.

const FPS = 20.0
const CLIP_SECONDS = 10.0
const AFTER_EVENT = 2.0
const SIZE = Vector2i(960, 540)
const JPG_QUALITY = 0.8
## Seconds between two kills of the same snake for a multi-kill
const MULTI_KILL_WINDOW = 3.5
const MULTI_KILL_BONUS = 4.0

var playground: Node
var enabled = true
var viewport: SubViewport
var clock = 0.0          # Seconds of recorded play (stops between rounds)
var next_capture = 0.0
var waiting_frame = null # A frame asked of the SubViewport, read on the next process
var frames = []          # [{"t", "jpg", "heads": {id: Vector2}}], oldest first
var events = []          # [{"t", "player", "kind", "weight", "victim"}]
var pending = []         # Clock times when the ring gets scored
var best_score = 0.0
var best = {}            # {"frames", "player", "score", "kills", "caption"}
var was_flowing = false
var mutex = Mutex.new()
var tasks = []

func _ready():
	process_mode = Node.PROCESS_MODE_PAUSABLE
	# Nothing to record without a screen (headless runs, the dedicated test scripts)
	enabled = DisplayServer.get_name() != "headless"
	if not enabled:
		return
	viewport = SubViewport.new()
	viewport.size = SIZE
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	viewport.transparent_bg = false
	var view = TextureRect.new()
	view.texture = get_tree().root.get_texture()
	view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	view.stretch_mode = TextureRect.STRETCH_SCALE
	# Averaged, not every other pixel (the project's default filter is Nearest): thin
	# trails and text stay whole instead of breaking into jagged steps
	view.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	view.size = SIZE
	viewport.add_child(view)
	add_child(viewport)
	Global.highlight.connect(_on_highlight)

func _exit_tree():
	for task in tasks:
		WorkerThreadPool.wait_for_task_completion(task)
	tasks.clear()

func _process(delta):
	if not enabled:
		return
	var flowing = playground.time_flowing and not playground.gameEnded
	if flowing and not was_flowing:
		# A new round: the ring only ever holds one round
		frames = []
		events = []
		pending = []
		next_capture = clock
	if not flowing and was_flowing:
		# The round ended: whatever was waiting to be scored is scored now
		_score_pending(true)
	was_flowing = flowing
	_collect_frame()
	if not flowing:
		return
	clock += delta
	if clock >= next_capture:
		next_capture = max(next_capture + 1.0 / FPS, clock)
		_request_frame()
	_score_pending(false)

func _request_frame():
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	var heads = {}
	for snake in get_tree().get_nodes_in_group("activePlayers"):
		if snake.is_in_group("alivePlayers") and not snake.reviving:
			heads[snake.playerId] = snake.global_position / get_viewport().get_visible_rect().size
	waiting_frame = {"t": clock, "jpg": PackedByteArray(), "heads": heads}

# The SubViewport drew the frame asked for last time: read it and compress it off the main thread
func _collect_frame():
	if waiting_frame == null:
		return
	var frame = waiting_frame
	waiting_frame = null
	var image = viewport.get_texture().get_image()
	if image == null or image.is_empty():
		return
	frames.append(frame)
	tasks.append(WorkerThreadPool.add_task(_encode.bind(frame, image)))
	_prune_tasks()
	while not frames.is_empty() and frames[0].t < clock - CLIP_SECONDS:
		frames.pop_front()

# Finished compressions are waited on (which frees them)
func _prune_tasks():
	var running = []
	for task in tasks:
		if WorkerThreadPool.is_task_completed(task):
			WorkerThreadPool.wait_for_task_completion(task)
		else:
			running.append(task)
	tasks = running

func _encode(frame, image):
	image.convert(Image.FORMAT_RGB8)
	var jpg = image.save_jpg_to_buffer(JPG_QUALITY)
	mutex.lock()
	frame.jpg = jpg
	mutex.unlock()

func _on_highlight(player_id, kind, weight, victim_id):
	# was_flowing: the round may have ended this very frame (the last crash)
	if not enabled or not (playground.time_flowing or was_flowing):
		return
	events.append({"t": clock, "player": player_id, "kind": kind, "weight": weight, "victim": victim_id})
	pending.append(clock + AFTER_EVENT)

func _score_pending(now):
	var due = pending.filter(func(t): return now or clock >= t)
	if due.is_empty():
		return
	pending = pending.filter(func(t): return not due.has(t))
	_score_ring()

# How good the ring is as a clip right now
func _score_ring():
	if frames.size() < FPS:
		return
	var start = frames[0].t
	var by_player = {}
	var kills = {}
	var biggest = {} # Each snake's biggest moment in the clip
	var score = 0.0
	for event in events:
		if event.t < start:
			continue
		score += event.weight
		by_player[event.player] = by_player.get(event.player, 0.0) + event.weight
		if not biggest.has(event.player) or event.weight > biggest[event.player].weight:
			biggest[event.player] = event
		if event.kind == "kill":
			if not kills.has(event.player):
				kills[event.player] = []
			kills[event.player].append(event.t)
	# Several kills close together by the same snake
	var streaks = {}
	for player in kills:
		var times = kills[player]
		var streak = 1
		var longest = 1
		for i in range(1, times.size()):
			streak = streak + 1 if times[i] - times[i - 1] <= MULTI_KILL_WINDOW else 1
			longest = max(longest, streak)
		streaks[player] = longest
		if longest >= 2:
			score += MULTI_KILL_BONUS * (longest - 1)
			by_player[player] = by_player.get(player, 0.0) + MULTI_KILL_BONUS * (longest - 1)
	if score <= best_score:
		return
	var star = 0
	for player in by_player:
		if star == 0 or by_player[player] > by_player[star]:
			star = player
	best_score = score
	best = {"frames": frames.duplicate(), "player": star, "score": score, "caption": _caption(streaks.get(star, 0), biggest.get(star, {}).get("kind", ""))}

# Translation keys (the replay screen shows them with tr())
const CAPTIONS = {
	"kill": "REPLAY_TAKEDOWN",
	"phoenix": "REPLAY_PHOENIX",
	"save": "REPLAY_SAVE",
	"block": "REPLAY_BLOCK",
	"shock": "REPLAY_SHOCK",
	"round": "REPLAY_LAST_STANDING",
	"crash": "REPLAY_WIPEOUT",
	"absorb": "REPLAY_ABSORB",
}

func _caption(streak, kind) -> String:
	match streak:
		2: return "REPLAY_DOUBLE_KILL"
		3: return "REPLAY_TRIPLE_KILL"
		4: return "REPLAY_QUAD_KILL"
	if streak > 4:
		return "REPLAY_UNSTOPPABLE"
	return CAPTIONS.get(kind, "REPLAY_WHAT_A_MOMENT")

# The play of the game, or the last seconds of the match if nothing stood out
func play_of_the_game() -> Dictionary:
	_score_pending(true)
	for task in tasks:
		WorkerThreadPool.wait_for_task_completion(task)
	tasks.clear()
	if best.is_empty() and frames.size() >= FPS:
		var last = playground.winners[0] if not playground.winners.is_empty() else 0
		best = {"frames": frames.duplicate(), "player": last, "score": 0.0, "caption": "REPLAY_FINAL_MOMENTS"}
	return best
