class_name TrackGhostRecorder
extends Node

const Config := preload("res://scripts/track/track_config.gd")

var _samples: Array[Transform3D] = []
var _accum: float = 0.0
var recording: bool = false
var source: Node3D


func start(from: Node3D) -> void:
	source = from
	_samples.clear()
	_accum = 0.0
	recording = true
	if source != null:
		_samples.append(source.global_transform)


func stop() -> Array[Transform3D]:
	recording = false
	return _samples.duplicate()


func _physics_process(delta: float) -> void:
	if not recording or source == null or not is_instance_valid(source):
		return
	_accum += delta
	var step := 1.0 / Config.GHOST_HZ
	if _accum >= step:
		_accum = 0.0
		_samples.append(source.global_transform)
