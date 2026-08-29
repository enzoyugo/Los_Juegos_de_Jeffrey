class_name ModeTransitionDefinition
extends RefCounted

const Assets := preload("res://scripts/ui/jeffrey/global_ui_assets.gd")
const ModeRegistry := preload("res://scripts/core/jeffrey/game_mode_registry.gd")
const ThemeRef := preload("res://scripts/ui/jeffrey/global_shell_theme.gd")

var mode_id: String = ""
var background_texture: String = ""
var title_texture: String = ""
var mode_banner_texture: String = ""
var global_header_texture: String = ""
var main_panel_texture: String = ""
var progress_texture: String = ""
var controls_texture: String = ""
var secondary_panel_texture: String = ""
var fx_overlay_texture: String = ""
var emblem_texture: String = ""
var accent: Color = ThemeRef.GOLD
var duration_min: float = 1.1
var target_scene: String = ""
var status_copy: String = ""


func configure(p_mode_id: String) -> void:
	mode_id = p_mode_id
	var mode = JeffreyCore.modes.get_mode(p_mode_id)
	if mode != null:
		target_scene = mode.scene_path
		accent = mode.accent_color
	match p_mode_id:
		ModeRegistry.MODE_SMASH:
			background_texture = Assets.SOCO_BG
			title_texture = Assets.SOCO_TITLE
			mode_banner_texture = Assets.SOCO_BANNER
			global_header_texture = Assets.SOCO_HEADER
			emblem_texture = Assets.SOCO_FIST
			progress_texture = Assets.SOCO_PROGRESS
			controls_texture = Assets.SOCO_CONTROLS
			fx_overlay_texture = Assets.SOCO_FX
			duration_min = 0.48
			status_copy = "ENTRANDO A LA BATALLA..."
		ModeRegistry.MODE_RACING:
			background_texture = Assets.TRACK_BG
			title_texture = Assets.TRACK_TITLE
			mode_banner_texture = Assets.TRACK_BANNER
			global_header_texture = Assets.TRACK_HEADER
			main_panel_texture = Assets.TRACK_GEN
			progress_texture = Assets.TRACK_PROGRESS
			controls_texture = Assets.TRACK_CONTROLS
			secondary_panel_texture = Assets.TRACK_TIP
			fx_overlay_texture = Assets.TRACK_FX
			duration_min = 0.52
			status_copy = "PREPARANDO TRACK..."
		ModeRegistry.MODE_ZOMBIES:
			background_texture = Assets.ZOMBIES_BG
			title_texture = Assets.ZOMBIES_TITLE
			mode_banner_texture = Assets.ZOMBIES_BANNER
			global_header_texture = Assets.ZOMBIES_HEADER
			main_panel_texture = Assets.ZOMBIES_LOADING
			progress_texture = Assets.ZOMBIES_PROGRESS
			controls_texture = Assets.ZOMBIES_CONTROLS
			secondary_panel_texture = Assets.ZOMBIES_PLAYERS
			fx_overlay_texture = Assets.ZOMBIES_FX
			duration_min = 0.55
			status_copy = "PREPARANDO MODO..."
		_:
			status_copy = "PREPARANDO..."
			duration_min = 0.50
