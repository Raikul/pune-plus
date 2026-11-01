extends GridContainer
class_name UpgradeBadges

# A snake's current upgrades as small animated icons (with "x2" when stacked), for the
# scoreboard and the upgrade screen. Online, rivals' upgrades are hidden: only how many.
# A grid, so a late-game pile of upgrades wraps into rows instead of running off screen.

const MAX_SHOWN = 8
## Size of each icon; set before refresh()
var icon_size = 46.0
const ODIN_FONT = preload("res://assets/jorge-resources/Game Selection/Odin Rounded - Bold.otf")

var player_id = 0
var color = Color.WHITE

func _init():
	columns = MAX_SHOWN
	add_theme_constant_override("h_separation", 3)
	add_theme_constant_override("v_separation", 3)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

# hidden: show only how many upgrades the snake has
func refresh(id, hidden = false):
	player_id = id
	color = Color(Global.playerColors[id])
	for child in get_children():
		child.queue_free()
	var stats = Global.player_stats.get(id)
	if stats == null or stats.active_buffs.is_empty():
		return
	if hidden:
		var count = 0
		for entry in stats.active_buffs.values():
			count += entry.stacks
		add_child(_label("? x%d" % count, 22, Color(0.7, 0.7, 0.7)))
		return
	var shown = 0
	for buff_id in stats.active_buffs:
		if shown >= MAX_SHOWN:
			add_child(_label("...", 22, Color.WHITE))
			break
		shown += 1
		var upgrade = UpgradeCatalog.get_upgrade(buff_id)
		if upgrade.is_empty():
			continue
		add_child(_badge(upgrade, stats.active_buffs[buff_id].stacks))

func _badge(upgrade, stacks):
	var holder = Control.new()
	holder.custom_minimum_size = Vector2(icon_size, icon_size)
	holder.tooltip_text = upgrade.name + ("  x%d" % stacks if stacks > 1 else "")
	holder.mouse_filter = Control.MOUSE_FILTER_PASS
	holder.clip_contents = true
	var backing = Panel.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.35)
	style.set_corner_radius_all(int(icon_size * 0.22))
	backing.add_theme_stylebox_override("panel", style)
	backing.size = Vector2(icon_size, icon_size)
	backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(backing)
	# Drawn at card size and scaled down, so the icon art keeps its proportions
	var icon = UpgradeIcon.new()
	icon.kind = upgrade.icon
	icon.color = color
	icon.size = Vector2(120, 120)
	icon.scale = Vector2.ONE * (icon_size / 120.0)
	holder.add_child(icon)
	if stacks > 1:
		var count = _label("x%d" % stacks, int(icon_size * 0.36), Color.WHITE)
		count.position = icon_size * Vector2(0.52, 0.56)
		count.add_theme_constant_override("outline_size", 4)
		count.add_theme_color_override("font_outline_color", Color.BLACK)
		holder.add_child(count)
	return holder

func _label(text, font_size, font_color):
	var label = Label.new()
	label.text = text
	label.add_theme_font_override("font", ODIN_FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", font_color)
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return label
