extends Node3D

## Visual ranking board for last-place Hotseat. Keys simulate finishes.

const Hotseat := preload("res://scripts/track/track_hotseat_v2.gd")
const HudScript := preload("res://scripts/track/track_turbo_hud.gd")

var _hs
var _hud
var _fake := 22.0


func _ready() -> void:
	_hs = Hotseat.new()
	_hs.setup([
		{"id": "enzo", "name": "Enzo", "color": Color("#e8c04a")},
		{"id": "juan", "name": "Juan", "color": Color("#4aa8e8")},
		{"id": "santi", "name": "Santi", "color": Color("#e87a4a")},
		{"id": "tomi", "name": "Tomi", "color": Color("#7ad07a")},
	], 24.0)
	_hud = HudScript.new()
	add_child(_hud)
	_refresh()
	print("[TRACK_HOTSEAT_LAB] SPACE finish current  VISUAL_REVIEW_PENDING")


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if event.keycode == KEY_SPACE:
		_hs.begin_run()
		_hs.record_finish(_fake)
		_fake += 0.7
		_refresh()


func _refresh() -> void:
	_hud.set_ranking(_hs.ranking(), _hs.current_id)
	var p: Dictionary = _hs.current()
	_hud.set_player(str(p.get("name", "")), p.get("color", Color.WHITE))
	_hud.set_banner("%s  TE TOCA\nSPACE simula finish" % str(p.get("name", "")), true)
