class_name GameModeRegistry
extends RefCounted

const ModeDef := preload("res://scripts/core/jeffrey/game_mode_definition.gd")

## Availability constants used by modes: AVAIL_PLAYABLE / AVAIL_DEVELOPMENT / AVAIL_LOCKED.

const MODE_SMASH := "smash"
const MODE_RACING := "racing"
const MODE_ZOMBIES := "zombies"

const SMASH_SCENE := "res://scenes/core/M0Playground.tscn"
const RACING_SCENE := "res://scenes/track/TrackMain.tscn"
const RACING_PLACEHOLDER := "res://scenes/modes/racing/HotseatComingSoon.tscn"
const ZOMBIES_SCENE := "res://scenes/zombies/ZombiesMain.tscn"
const ZOMBIES_PLACEHOLDER := "res://scenes/modes/zombies/ZombiesComingSoon.tscn"

var _modes: Dictionary = {}


func _init() -> void:
	register_builtin()


func register_builtin() -> void:
	_modes.clear()
	register_mode(_make(
		MODE_SMASH,
		"Smash Kapes",
		true,
		2,
		4,
		SMASH_SCENE,
		"Mandá volando a tu amigo fuera del Defensores.",
		ModeDef.AVAIL_PLAYABLE,
		Color("#c47a5a"),
		"res://assets/ui/global/mode_cards/smash.png"
	))
	register_mode(_make(
		MODE_RACING,
		"Track",
		true,
		2,
		10,
		RACING_SCENE,
		"Una persona corre por vez. Hasta 10 jugadores, mismo auto.",
		ModeDef.AVAIL_PLAYABLE,
		Color("#5aa8b0"),
		"res://assets/ui/global/mode_cards/hotseat.png"
	))
	register_mode(_make(
		MODE_ZOMBIES,
		"Zombies",
		true,
		1,
		2,
		ZOMBIES_SCENE,
		"1–2 jugadores local. Shopping del Sol.",
		ModeDef.AVAIL_PLAYABLE,
		Color("#7aaf7a"),
		"res://assets/ui/global/mode_cards/zombies.png"
	))


func register_mode(definition) -> void:
	if definition == null or definition.id.is_empty():
		push_error("[GameModeRegistry] refused empty mode definition")
		return
	_modes[definition.id] = definition


func get_mode(mode_id: String):
	return _modes.get(mode_id, null)


func get_all_modes() -> Array:
	var ordered: Array = []
	for mode_id in [MODE_SMASH, MODE_RACING, MODE_ZOMBIES]:
		if _modes.has(mode_id):
			ordered.append(_modes[mode_id])
	for mode_id in _modes.keys():
		if mode_id != MODE_SMASH and mode_id != MODE_RACING and mode_id != MODE_ZOMBIES:
			ordered.append(_modes[mode_id])
	return ordered


func clamp_player_count(mode_id: String, count: int) -> int:
	var mode = get_mode(mode_id)
	if mode == null:
		return 0
	return clampi(count, mode.min_players, mode.max_players)


func _make(
	mode_id: String,
	display_name: String,
	enabled: bool,
	min_players: int,
	max_players: int,
	scene_path: String,
	description: String,
	availability: String,
	accent: Color,
	thumbnail_path: String
):
	var definition = ModeDef.new()
	definition.id = mode_id
	definition.display_name = display_name
	definition.enabled = enabled
	definition.min_players = min_players
	definition.max_players = max_players
	definition.scene_path = scene_path
	definition.description = description
	definition.availability = availability
	definition.accent_color = accent
	definition.thumbnail_path = thumbnail_path
	definition.coming_soon_label = definition.status_label()
	return definition
