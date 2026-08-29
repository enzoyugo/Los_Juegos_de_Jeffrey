class_name GlobalUiAssets
extends RefCounted

## Central swap table for Los Juegos de Jeffrey global UI art.
## Screens load through these helpers so missing files never crash.
## Runtime Image load keeps UI lossless even before Godot finishes .import.

const BOOT_BACKGROUND := "res://assets/ui/global/boot/boot_background.png"
const BOOT_LOGO := "res://assets/ui/global/boot/los_juegos_de_jeffrey_logo.png"
const BOOT_PRESS_ENTER := "res://assets/ui/global/boot/boot_press_enter.png"
const BOOT_CONTROLS := "res://assets/ui/global/boot/boot_controls_strip.png"
const BOOT_AMBIENCE := "res://assets/ui/global/boot/boot_ambience_overlay.png"

const PLAYERS_BACKGROUND := "res://assets/ui/global/players_today/players_today_background.png"
const PLAYERS_TITLE := "res://assets/ui/global/players_today/players_today_title.png"
const PLAYER_CARD_SELECTED := "res://assets/ui/global/players_today/player_card_selected.png"
const PLAYER_CARD_UNSELECTED := "res://assets/ui/global/players_today/player_card_unselected.png"
const NEW_PLAYER_CARD := "res://assets/ui/global/players_today/new_player_card.png"
const SELECTED_PLAYERS_PANEL := "res://assets/ui/global/players_today/selected_players_panel.png"
const CONTINUE_BUTTON := "res://assets/ui/global/players_today/continue_button.png"
const BACK_BUTTON := "res://assets/ui/global/players_today/back_button.png"
const PLAYERS_CONTROLS := "res://assets/ui/global/players_today/players_today_controls_strip.png"

const HUB_BACKGROUND := "res://assets/ui/global/hub/hub_background.png"
const HUB_LOGO := "res://assets/ui/global/hub/los_juegos_de_jeffrey_logo.png"
const MODE_SOCO := "res://assets/ui/global/hub/mode_soco.png"
const MODE_TRACK := "res://assets/ui/global/hub/mode_track.png"
const MODE_ZOMBIES := "res://assets/ui/global/hub/mode_zombies.png"
const EDIT_PLAYERS_BUTTON := "res://assets/ui/global/hub/edit_players_button.png"
const ACTIVE_PLAYERS_PANEL := "res://assets/ui/global/hub/active_players_panel.png"
const HUB_CONTROLS := "res://assets/ui/global/hub/hub_controls_strip.png"

const EDIT_BACKGROUND := "res://assets/ui/global/edit_players/edit_players_background.png"
const EDIT_TITLE := "res://assets/ui/global/edit_players/edit_players_title.png"
const EDIT_CARD := "res://assets/ui/global/edit_players/edit_player_card.png"
const EDIT_CARD_ACTIVE := "res://assets/ui/global/edit_players/edit_player_card_active.png"
const EDIT_ADD := "res://assets/ui/global/edit_players/add_player_button.png"
const EDIT_CONTROLS := "res://assets/ui/global/edit_players/edit_players_controls_strip.png"
const EDIT_PANEL := "res://assets/ui/global/edit_players/edit_players_info_panel.png"

const MODE_PLAYERS_BACKGROUND := "res://assets/ui/global/mode_players/mode_players_background.png"
const MODE_PLAYERS_TITLE := "res://assets/ui/global/mode_players/mode_players_title.png"
const MODE_PLAYER_CARD := "res://assets/ui/global/mode_players/mode_player_card.png"
const MODE_PLAYER_CARD_SELECTED := "res://assets/ui/global/mode_players/mode_player_card_selected.png"
const MODE_PLAYERS_SUMMARY := "res://assets/ui/global/mode_players/mode_players_summary_panel.png"
const MODE_PLAYERS_CONTINUE := "res://assets/ui/global/mode_players/continue_button.png"
const MODE_PLAYERS_BACK := "res://assets/ui/global/mode_players/back_button.png"
const MODE_PLAYERS_CONTROLS := "res://assets/ui/global/mode_players/mode_players_controls_strip.png"

const CHAR_BACKGROUND := "res://assets/ui/global/character_select/character_select_background.png"
const CHAR_TITLE := "res://assets/ui/global/character_select/character_select_title.png"
const CHAR_CARD := "res://assets/ui/global/character_select/character_card.png"
const CHAR_CARD_SELECTED := "res://assets/ui/global/character_select/character_card_selected.png"
const CHAR_RANDOM := "res://assets/ui/global/character_select/character_random_card.png"
const CHAR_PLAYERS_PANEL := "res://assets/ui/global/character_select/character_players_panel.png"
const CHAR_CONTINUE := "res://assets/ui/global/character_select/continue_button.png"
const CHAR_BACK := "res://assets/ui/global/character_select/back_button.png"
const CHAR_CONTROLS := "res://assets/ui/global/character_select/character_select_controls_strip.png"

const SOCO_BG := "res://assets/ui/global/transitions/soco/soco_transition_background.png"
const SOCO_TITLE := "res://assets/ui/global/transitions/soco/soco_title.png"
const SOCO_BANNER := "res://assets/ui/global/transitions/soco/soco_mode_banner.png"
const SOCO_HEADER := "res://assets/ui/global/transitions/soco/soco_global_header.png"
const SOCO_FIST := "res://assets/ui/global/transitions/soco/soco_fist_emblem.png"
const SOCO_PROGRESS := "res://assets/ui/global/transitions/soco/soco_progress_bar.png"
const SOCO_CONTROLS := "res://assets/ui/global/transitions/soco/soco_controls_strip.png"
const SOCO_FX := "res://assets/ui/global/transitions/soco/soco_fx_overlay.png"

const TRACK_BG := "res://assets/ui/global/transitions/track/track_transition_background.png"
const TRACK_TITLE := "res://assets/ui/global/transitions/track/track_title.png"
const TRACK_BANNER := "res://assets/ui/global/transitions/track/track_mode_banner.png"
const TRACK_HEADER := "res://assets/ui/global/transitions/track/track_global_header.png"
const TRACK_GEN := "res://assets/ui/global/transitions/track/track_generation_panel.png"
const TRACK_PROGRESS := "res://assets/ui/global/transitions/track/track_progress_bar.png"
const TRACK_CONTROLS := "res://assets/ui/global/transitions/track/track_controls_strip.png"
const TRACK_TIP := "res://assets/ui/global/transitions/track/track_tip_panel.png"
const TRACK_FX := "res://assets/ui/global/transitions/track/track_fx_overlay.png"

const ZOMBIES_BG := "res://assets/ui/global/transitions/zombies/zombies_transition_background.png"
const ZOMBIES_TITLE := "res://assets/ui/global/transitions/zombies/zombies_title.png"
const ZOMBIES_BANNER := "res://assets/ui/global/transitions/zombies/zombies_mode_banner.png"
const ZOMBIES_HEADER := "res://assets/ui/global/transitions/zombies/zombies_global_header.png"
const ZOMBIES_LOADING := "res://assets/ui/global/transitions/zombies/zombies_loading_panel.png"
const ZOMBIES_PROGRESS := "res://assets/ui/global/transitions/zombies/zombies_progress_bar.png"
const ZOMBIES_CONTROLS := "res://assets/ui/global/transitions/zombies/zombies_controls_strip.png"
const ZOMBIES_PLAYERS := "res://assets/ui/global/transitions/zombies/zombies_player_panel.png"
const ZOMBIES_FX := "res://assets/ui/global/transitions/zombies/zombies_fx_overlay.png"

const ZOMBIES_MENU_BG := "res://assets/ui/zombies/backgrounds/zombies_menu_bg.png"
const ZOMBIES_LOADING_BG := "res://assets/ui/zombies/backgrounds/zombies_loading_bg.png"
const ZOMBIES_BRAND_TITLE := "res://assets/ui/zombies/branding/zombies_title.png"
const ZOMBIES_BTN_PLAY := "res://assets/ui/zombies/buttons/btn_play.png"
const ZOMBIES_BTN_CHARACTERS := "res://assets/ui/zombies/buttons/btn_characters.png"
const ZOMBIES_BTN_MAP := "res://assets/ui/zombies/buttons/btn_map.png"
const ZOMBIES_BTN_OPTIONS := "res://assets/ui/zombies/buttons/btn_options.png"
const ZOMBIES_BTN_BACK := "res://assets/ui/zombies/buttons/btn_back.png"
const ZOMBIES_LOADING_BAR := "res://assets/ui/zombies/loading/loading_bar.png"

const RANDOM_CHARACTER_ID := "__random__"

const MODE_ART := {
	"smash": MODE_SOCO,
	"racing": MODE_TRACK,
	"zombies": MODE_ZOMBIES,
}

const MODE_FALLBACK_LABEL := {
	"smash": "SOCO",
	"racing": "TRACK",
	"zombies": "ZOMBIES",
}

static var _missing_logged: Dictionary = {}
static var _cache: Dictionary = {}


static func expected_paths() -> PackedStringArray:
	return PackedStringArray([
		BOOT_BACKGROUND, BOOT_LOGO, BOOT_PRESS_ENTER, BOOT_CONTROLS, BOOT_AMBIENCE,
		PLAYERS_BACKGROUND, PLAYERS_TITLE, PLAYER_CARD_SELECTED, PLAYER_CARD_UNSELECTED,
		NEW_PLAYER_CARD, SELECTED_PLAYERS_PANEL, CONTINUE_BUTTON, BACK_BUTTON, PLAYERS_CONTROLS,
		HUB_BACKGROUND, HUB_LOGO, MODE_SOCO, MODE_TRACK, MODE_ZOMBIES,
		EDIT_PLAYERS_BUTTON, ACTIVE_PLAYERS_PANEL, HUB_CONTROLS,
		EDIT_BACKGROUND, EDIT_TITLE, EDIT_CARD, EDIT_CARD_ACTIVE, EDIT_ADD, EDIT_CONTROLS, EDIT_PANEL,
		MODE_PLAYERS_BACKGROUND, MODE_PLAYERS_TITLE, MODE_PLAYER_CARD, MODE_PLAYER_CARD_SELECTED,
		MODE_PLAYERS_SUMMARY, MODE_PLAYERS_CONTINUE, MODE_PLAYERS_BACK, MODE_PLAYERS_CONTROLS,
		CHAR_BACKGROUND, CHAR_TITLE, CHAR_CARD, CHAR_CARD_SELECTED, CHAR_RANDOM, CHAR_PLAYERS_PANEL,
		CHAR_CONTINUE, CHAR_BACK, CHAR_CONTROLS,
		SOCO_BG, SOCO_TITLE, SOCO_BANNER, SOCO_HEADER, SOCO_FIST, SOCO_PROGRESS, SOCO_CONTROLS, SOCO_FX,
		TRACK_BG, TRACK_TITLE, TRACK_BANNER, TRACK_HEADER, TRACK_GEN, TRACK_PROGRESS, TRACK_CONTROLS, TRACK_TIP, TRACK_FX,
		ZOMBIES_BG, ZOMBIES_TITLE, ZOMBIES_BANNER, ZOMBIES_HEADER, ZOMBIES_LOADING, ZOMBIES_PROGRESS, ZOMBIES_CONTROLS, ZOMBIES_PLAYERS, ZOMBIES_FX,
		ZOMBIES_MENU_BG, ZOMBIES_LOADING_BG, ZOMBIES_BRAND_TITLE, ZOMBIES_BTN_PLAY, ZOMBIES_BTN_CHARACTERS,
		ZOMBIES_BTN_MAP, ZOMBIES_BTN_OPTIONS, ZOMBIES_BTN_BACK, ZOMBIES_LOADING_BAR,
	])


static func file_present(path: String) -> bool:
	return ResourceLoader.exists(path) or FileAccess.file_exists(path)


static func texture(path: String) -> Texture2D:
	if path.is_empty():
		return null
	if _cache.has(path):
		return _cache[path]
	var loaded: Texture2D = null
	if ResourceLoader.exists(path):
		var resource: Resource = load(path)
		if resource is Texture2D:
			loaded = resource
	if loaded == null and FileAccess.file_exists(path):
		var image := Image.new()
		if image.load(path) == OK:
			loaded = ImageTexture.create_from_image(image)
	if loaded == null:
		_log_missing(path)
		return null
	_cache[path] = loaded
	return loaded


static func mode_art(mode_id: String) -> Texture2D:
	return texture(str(MODE_ART.get(mode_id, "")))


static func mode_fallback_label(mode_id: String) -> String:
	return str(MODE_FALLBACK_LABEL.get(mode_id, mode_id.to_upper()))


static func hub_mode_order() -> PackedStringArray:
	return PackedStringArray(["smash", "racing", "zombies"])


static func _log_missing(path: String) -> void:
	if _missing_logged.has(path):
		return
	_missing_logged[path] = true
	push_warning("MISSING_FINAL_ASSET %s" % path)
