class_name ActivePlayersPanel
extends Control

const Assets := preload("res://scripts/ui/jeffrey/global_ui_assets.gd")
const Layout := preload("res://scripts/ui/jeffrey/global_ui_layout.gd")
const ThemeRef := preload("res://scripts/ui/jeffrey/global_shell_theme.gd")
const Styles := preload("res://scripts/ui/jeffrey/global_ui_styles.gd")
const RowScript := preload("res://scripts/ui/jeffrey/active_player_row.gd")
const FitHost := preload("res://scripts/ui/jeffrey/texture_fit_host.gd")


func _ready() -> void:
	var host = FitHost.new()
	Layout.bind_full(host)
	add_child(host)
	host.set_texture(Assets.texture(Assets.ACTIVE_PLAYERS_PANEL))
	var rows := Control.new()
	rows.name = "PlayerRowsContainer"
	Layout.bind_full(rows)
	host.art_space.add_child(rows)
	_fill(rows)


func _fill(rows: Control) -> void:
	var index := 0
	for profile_id in JeffreyCore.session.active_player_ids:
		if index >= Styles.HUB_ROW_COUNT:
			break
		var profile = JeffreyCore.profiles.get_profile(profile_id)
		if profile == null:
			continue
		var row = RowScript.new()
		rows.add_child(row)
		Layout.bind_frac_rect(row, 0.0, Styles.hub_row_top(index), 1.0, Styles.hub_row_bottom(index))
		row.setup(profile.display_name, index, profile.portrait_path)
		index += 1
	if index == 0:
		var empty := Layout.outlined_label("NADIE EN LA SESIÓN", Styles.SIZE_HELPER, ThemeRef.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
		Styles.apply(empty, "small_helper")
		rows.add_child(empty)
		Layout.bind_frac_rect(empty, 0.12, 0.45, 0.88, 0.55)
