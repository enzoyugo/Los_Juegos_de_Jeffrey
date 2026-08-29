class_name JeffreyScoreRow
extends Control

const Layout := preload("res://scripts/ui/jeffrey/global_ui_layout.gd")
const ThemeRef := preload("res://scripts/ui/jeffrey/system/jeffrey_theme.gd")
const Motion := preload("res://scripts/ui/jeffrey/system/jeffrey_ui_motion.gd")
const Chip := preload("res://scripts/ui/jeffrey/components/jeffrey_player_chip.gd")

var _points_label: Label


func configure(rank: int, display_name: String, points: int, total: int = -1, leader: bool = false, profile_id: String = "") -> void:
	for child in get_children():
		child.queue_free()
	custom_minimum_size = Vector2(0, 42)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	Layout.bind_full(row)
	add_child(row)
	var rank_color := ThemeRef.Base.GOLD if leader else ThemeRef.Base.MUTED
	var rank_label := Layout.outlined_label("%d" % rank if rank > 0 else "—", 18, rank_color, HORIZONTAL_ALIGNMENT_CENTER)
	rank_label.custom_minimum_size = Vector2(36, 0)
	row.add_child(rank_label)
	if not profile_id.is_empty():
		var chip = Chip.new()
		chip.configure(profile_id, display_name, rank - 1)
		chip.custom_minimum_size = Vector2(180, 32)
		row.add_child(chip)
	else:
		var name_label := Layout.outlined_label(display_name.to_upper(), 18, ThemeRef.Base.TEXT, HORIZONTAL_ALIGNMENT_LEFT)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)
	_points_label = Layout.outlined_label("", 20, ThemeRef.Base.GOLD_HOT if points > 0 else ThemeRef.Base.MUTED, HORIZONTAL_ALIGNMENT_RIGHT)
	if total < 0:
		_points_label.text = str(points)
	else:
		_points_label.text = "+%d" % points if points > 0 else "+0"
	_points_label.custom_minimum_size = Vector2(52, 0)
	row.add_child(_points_label)
	if total >= 0:
		var total_label := Layout.outlined_label("TOTAL %d" % total, 16, ThemeRef.Base.MUTED, HORIZONTAL_ALIGNMENT_RIGHT)
		total_label.custom_minimum_size = Vector2(96, 0)
		row.add_child(total_label)
	if leader:
		var crown := Layout.outlined_label("★", 18, ThemeRef.Base.GOLD_HOT, HORIZONTAL_ALIGNMENT_CENTER)
		row.add_child(crown)


func emphasize_points() -> void:
	if _points_label != null:
		Motion.emphasize_points(_points_label)
