class_name TrackGhostPlayer
extends Node3D

const Config := preload("res://scripts/track/track_config.gd")
const VisualScript := preload("res://scripts/track/track_car_visual.gd")

var _samples: Array[Transform3D] = []
var _time: float = 0.0
var playing: bool = false
var profile_id: String = ""


func setup(pid: String, samples: Array) -> void:
	profile_id = pid
	_samples.clear()
	for item in samples:
		if item is Transform3D:
			_samples.append(item)
	_build_visual()
	arm()


func arm() -> void:
	playing = false
	visible = false
	_time = 0.0
	if not _samples.is_empty():
		global_transform = _samples[0]


func begin_playback() -> void:
	playing = not _samples.is_empty()
	visible = playing
	_time = 0.0
	if playing:
		global_transform = _samples[0]


func set_elapsed(time_sec: float) -> void:
	if not playing or _samples.is_empty():
		return
	_time = maxf(time_sec, 0.0)
	global_transform = get_transform_at_time(_time)


func get_transform_at_time(time_sec: float) -> Transform3D:
	if _samples.is_empty():
		return Transform3D.IDENTITY
	if _samples.size() == 1:
		return _samples[0]
	var step := 1.0 / Config.GHOST_HZ
	var max_t: float = step * float(_samples.size() - 1)
	var t := clampf(time_sec, 0.0, max_t)
	if t >= max_t:
		return _samples[_samples.size() - 1]
	var idx := int(t / step)
	idx = clampi(idx, 0, _samples.size() - 2)
	var alpha := (t - float(idx) * step) / step
	return _samples[idx].interpolate_with(_samples[idx + 1], alpha)


func _physics_process(_delta: float) -> void:
	## Playback is driven by race elapsed from TrackMain, not wall-clock.
	pass


func _build_visual() -> void:
	var vis := Node3D.new()
	vis.set_script(VisualScript)
	vis.set("ghost_mode", true)
	vis.set("apply_runtime_transform", true)
	vis.set("show_debug_pivots", false)
	vis.name = "GhostVisual"
	add_child(vis)
