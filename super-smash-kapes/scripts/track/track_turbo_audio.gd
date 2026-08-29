class_name TrackTurboAudio
extends Node

## Speed-feel hooks. No systemic music. WASAPI device invalidation is external.

signal hook(name: String, intensity: float)

var _engine: AudioStreamPlayer
var _wind: AudioStreamPlayer
var _squeal: AudioStreamPlayer
var _boost: AudioStreamPlayer


func _ready() -> void:
	_engine = _player("Engine")
	_wind = _player("Wind")
	_squeal = _player("Squeal")
	_boost = _player("Boost")


func _player(pname: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.name = pname
	p.bus = "Master"
	add_child(p)
	return p


func tick(speed: float, max_speed: float, slip: float, airborne: bool, surface: String) -> void:
	if _engine == null:
		return
	var t := clampf(speed / maxf(max_speed, 0.001), 0.0, 1.0)
	_engine.pitch_scale = lerpf(0.82, 1.35, t)
	_engine.volume_db = lerpf(-18.0, -6.0, t)
	_wind.volume_db = lerpf(-28.0, -8.0, t * t)
	var sq := clampf(absf(slip) * 1.6, 0.0, 1.0)
	_squeal.volume_db = lerpf(-40.0, -4.0, sq)
	if airborne:
		_engine.volume_db -= 3.0
	hook.emit("engine", t)
	hook.emit("wind", t * t)
	hook.emit("squeal", sq)
	hook.emit("surface", 1.0 if surface == "ROAD" else 0.4)


func play_boost() -> void:
	hook.emit("boost", 1.0)
	print("[TRACK_AUDIO] boost")


func play_countdown(n: int) -> void:
	print("[TRACK_AUDIO] countdown %d" % n)
	hook.emit("countdown", float(n))


func play_dale() -> void:
	print("[TRACK_AUDIO] dale")
	hook.emit("generation", 0.0)


func play_finish() -> void:
	print("[TRACK_AUDIO] finish")
	hook.emit("finish", 1.0)


func play_ultima() -> void:
	print("[TRACK_AUDIO] ultima")
	hook.emit("final_chance", 1.0)


func play_landing(vy: float) -> void:
	print("[TRACK_AUDIO] landing vy=%.2f" % vy)
	hook.emit("landing", clampf(absf(vy) / 12.0, 0.0, 1.0))
