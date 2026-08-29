class_name ZombiesUiAssets
extends RefCounted

## Final 2D Zombies menu/loading art. Visual authority lives in these PNGs.

const MENU_BG := "res://assets/ui/zombies/backgrounds/zombies_menu_bg.png"
const LOADING_BG := "res://assets/ui/zombies/backgrounds/zombies_loading_bg.png"
const TITLE := "res://assets/ui/zombies/branding/zombies_title.png"
const BTN_PLAY := "res://assets/ui/zombies/buttons/btn_play.png"
const BTN_CHARACTERS := "res://assets/ui/zombies/buttons/btn_characters.png"
const BTN_MAP := "res://assets/ui/zombies/buttons/btn_map.png"
const BTN_OPTIONS := "res://assets/ui/zombies/buttons/btn_options.png"
const BTN_BACK := "res://assets/ui/zombies/buttons/btn_back.png"
const LOADING_BAR := "res://assets/ui/zombies/loading/loading_bar.png"

const FLAVOR := "Llegá al estacionamiento del Shopping del Sol y encontrá la última muestra de la cura."
const LOADING_COPY := "CARGANDO..."
const MAP_COPY := "MAPA ACTUAL: SHOPPING DEL SOL"
const SLIME := Color("#c6ff3a")
const SLIME_DIM := Color("#9ad42e")
const FOCUS_GREEN := Color(0.55, 1.0, 0.38, 1.0)


static func expected_paths() -> PackedStringArray:
	return PackedStringArray([
		MENU_BG, LOADING_BG, TITLE,
		BTN_PLAY, BTN_CHARACTERS, BTN_MAP, BTN_OPTIONS, BTN_BACK,
		LOADING_BAR,
	])
