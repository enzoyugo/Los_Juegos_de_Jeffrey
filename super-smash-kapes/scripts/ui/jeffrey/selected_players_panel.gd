class_name SelectedPlayersPanel
extends Control

const Assets := preload("res://scripts/ui/jeffrey/global_ui_assets.gd")
const Layout := preload("res://scripts/ui/jeffrey/global_ui_layout.gd")
const ThemeRef := preload("res://scripts/ui/jeffrey/global_shell_theme.gd")
const Styles := preload("res://scripts/ui/jeffrey/global_ui_styles.gd")
const RowScript := preload("res://scripts/ui/jeffrey/selected_player_row.gd")
const FitHost := preload("res://scripts/ui/jeffrey/texture_fit_host.gd")

var _count: Label
var _list: VBoxContainer


func _ready() -> void:
	var host = FitHost.new()
	Layout.bind_full(host)
	add_child(host)
	host.set_texture(Assets.texture(Assets.SELECTED_PLAYERS_PANEL))

	var margin := MarginContainer.new()
	Layout.bind_full(margin)
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 36)
	margin.add_theme_constant_override("margin_bottom", 36)
	host.art_space.add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	margin.add_child(root)

	var header := HBoxContainer.new()
	header.name = "HeaderRow"
	header.add_theme_constant_override("separation", 12)
	root.add_child(header)
	var title := Layout.outlined_label("SELECCIONADOS HOY", Styles.SIZE_PANEL_TITLE, ThemeRef.GOLD, HORIZONTAL_ALIGNMENT_LEFT)
	title.name = "HeaderLabel"
	Styles.apply(title, "panel_title")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	_count = Layout.outlined_label("0", Styles.SIZE_COUNTER, ThemeRef.GOLD_HOT, HORIZONTAL_ALIGNMENT_RIGHT)
	_count.name = "SelectedCount"
	Styles.apply(_count, "counter")
	header.add_child(_count)

	var divider := ColorRect.new()
	divider.custom_minimum_size = Vector2(0, 2)
	divider.color = Color(ThemeRef.GOLD.r, ThemeRef.GOLD.g, ThemeRef.GOLD.b, 0.45)
	root.add_child(divider)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	_list = VBoxContainer.new()
	_list.name = "SelectedRowsContainer"
	_list.add_theme_constant_override("separation", 8)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)


func set_profile_ids(ids: Array) -> void:
	if _count != null:
		_count.text = str(ids.size())
	if _list == null:
		return
	for child in _list.get_children():
		child.queue_free()
	_list.add_theme_constant_override("separation", 6 if ids.size() > 6 else 10)
	var index := 0
	for profile_id in ids:
		var profile = JeffreyCore.profiles.get_profile(str(profile_id))
		if profile == null:
			continue
		var row = RowScript.new()
		_list.add_child(row)
		row.setup(profile.display_name, ThemeRef.slot_color(index))
		index += 1
