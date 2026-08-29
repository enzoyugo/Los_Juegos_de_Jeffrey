class_name GameModeDefinition
extends RefCounted

const AVAIL_PLAYABLE := "playable"
const AVAIL_DEVELOPMENT := "development"
const AVAIL_LOCKED := "locked"

var id: String = ""
var display_name: String = ""
var enabled: bool = false
var min_players: int = 1
var max_players: int = 1
var scene_path: String = ""
var description: String = ""
var coming_soon_label: String = "PRÓXIMAMENTE"
var availability: String = AVAIL_LOCKED
var accent_color: Color = Color("#9eb4c9")
var thumbnail_path: String = ""
var art_background_path: String = ""


func status_label() -> String:
	match availability:
		AVAIL_PLAYABLE:
			return "JUGAR"
		AVAIL_DEVELOPMENT:
			return "EN DESARROLLO"
		_:
			return "PRÓXIMAMENTE"


func is_playable() -> bool:
	return availability == AVAIL_PLAYABLE and enabled and not scene_path.is_empty() and ResourceLoader.exists(scene_path)
