class_name TrackUiAssets
extends RefCounted

## Track Menu V1 — approved UI pack under assets/ui/track/menu_v1/

const ROOT := "res://assets/ui/track/menu_v1/"

const BG := ROOT + "backgrounds/track_menu_costanera_bg.png"
const HEADER := ROOT + "header/track_menu_header.png"
const PLAYERS_PANEL := ROOT + "players/track_active_players_panel.png"
const LENGTH_SELECTOR := ROOT + "selectors/track_length_selector.png"
const DIFFICULTY_SELECTOR := ROOT + "selectors/track_difficulty_selector.png"
const BTN_START := ROOT + "buttons/track_start_button.png"
const BTN_BACK := ROOT + "buttons/track_back_button.png"
const HINTS := ROOT + "hints/track_controls_hint.png"

## UI labels ↔ TrackConfig authority
const LENGTH_IDS := ["corta", "media", "larga"]
const LENGTH_LABELS := ["CORTA", "MEDIA", "LARGA"]
const DIFF_IDS := ["tranqui", "picante", "demente"]
const DIFF_LABELS := ["FÁCIL", "NORMAL", "DIFÍCIL"]

const ACCENT := Color("#c084fc")
const GOLD := Color("#f5c542")


static func texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		var loaded = load(path)
		if loaded is Texture2D:
			return loaded
	if FileAccess.file_exists(path):
		var img := Image.new()
		if img.load(path) == OK:
			return ImageTexture.create_from_image(img)
	return null


static func all_paths() -> PackedStringArray:
	return PackedStringArray([
		BG, HEADER, PLAYERS_PANEL, LENGTH_SELECTOR, DIFFICULTY_SELECTOR, BTN_START, BTN_BACK, HINTS,
	])
