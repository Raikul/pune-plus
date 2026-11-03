@tool
extends Node2D
class_name Level

# An arena layout: walls inside the playground (LevelWall children) and, optionally, where
# each snake starts. Levels are scenes in res://levels/ (see docs/levels.md) and are picked
# with the Arena match setting; Playground adds the chosen one on top of the empty arena.
#
# In the editor the play area is drawn as a guide, so walls can be placed where snakes
# actually move. Run the level scene on its own (F6) to playtest it: the game starts with
# player 1 on its usual keys against three AIs.
#
# Starting spots: Marker2D children named Spawn1..Spawn4 (position, and rotation for the
# heading; 0 = facing up). Without them the usual fixed spots are used, moved off any wall.

## The play area in the playground (inside the purple border), for the editor guide
const ARENA = Rect2(1, 135, 1918, 939)

## Shown in the Arena setting; empty = the scene's file name
@export var display_name = ""

# Seconds since the level started, the clock moving walls follow. Online every machine
# uses the shared network clock instead, so the walls are in the same place everywhere.
static var elapsed = 0.0

static func now() -> float:
	if Global.isMultiplayerActive:
		return SteamNet.net_time()
	return elapsed

func _ready():
	if Engine.is_editor_hint():
		return
	elapsed = 0.0
	# Played on its own (F6): start a test match on this level
	if get_tree().current_scene == self:
		_playtest.call_deferred()

func _physics_process(delta):
	if not Engine.is_editor_hint():
		elapsed += delta

func _playtest():
	Global.test_level = scene_file_path
	for id in [1, 2, 3, 4]:
		Global.set("player%dActive" % id, true)
		Global.AI_Enabled[id] = id != 1
	Global.reset_score()
	get_tree().change_scene_to_file("res://scenes/Playground.tscn")

func walls() -> Array:
	return find_children("*", "LevelWall", true, false)

# [x, y, rotation] from a SpawnN marker, or [] if the level has none for this snake
func spawn_for(player_id) -> Array:
	var marker = get_node_or_null("Spawn%d" % player_id)
	if marker is Node2D:
		return [marker.global_position.x, marker.global_position.y, marker.global_rotation]
	return []

# No wall within margin pixels of this point (walls where they are right now)
func is_clear(point: Vector2, margin: float) -> bool:
	for wall in walls():
		var shape = wall.global_polygon()
		if shape.size() < 3:
			continue
		if Geometry2D.is_point_in_polygon(point, shape):
			return false
		for i in shape.size():
			var closest = Geometry2D.get_closest_point_to_segment(point, shape[i], shape[(i + 1) % shape.size()])
			if closest.distance_to(point) < margin:
				return false
	return true

func _draw():
	if not Engine.is_editor_hint():
		return
	# The play area and the four usual starting corners
	draw_rect(ARENA, Color(0.62, 0.36, 1.0, 0.08))
	draw_rect(ARENA, Color(0.62, 0.36, 1.0, 0.9), false, 3.0)
	draw_rect(Rect2(ARENA.position.x, 0, ARENA.size.x, ARENA.position.y), Color(0, 0, 0, 0.35))
	var font = ThemeDB.fallback_font
	draw_string(font, Vector2(ARENA.position.x + 12, ARENA.position.y - 14), "Scoreboard (not playable)", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1, 1, 1, 0.5))
	var corners = [Vector2(300, 300), Vector2(300, 900), Vector2(1400, 900), Vector2(1400, 300)]
	for i in corners.size():
		if get_node_or_null("Spawn%d" % (i + 1)) == null:
			draw_circle(corners[i], 150, Color(1, 1, 1, 0.05))
			draw_string(font, corners[i] + Vector2(-60, 6), "Player %d start" % (i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1, 1, 1, 0.35))
