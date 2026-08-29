extends "res://scripts/debug/production_animation_lab.gd"

## Isolated rest-axis solver V1 lab. Not wired into battle.
## 1 REST  2 solver_v1 Idle  3 skeleton  4 bbox

@export var metrics_json: String = ""
@export var solver_version: String = "solver_v1"

var _metrics: Dictionary = {}
var _volume_ratio: float = 0.0
var _pose_class: String = "UNKNOWN"


func _ready() -> void:
	pipeline_id = "ACTORCORE_SOLVER_V1"
	if production_glb != "":
		benchmark_glb = production_glb
	_load_metrics()
	super._ready()
	if _animation_player:
		_animation_player.stop()
	if _skeleton:
		_skeleton.reset_bone_poses()
	_refresh_status()


func _load_metrics() -> void:
	if metrics_json.is_empty():
		return
	var abs_path := ProjectSettings.globalize_path(metrics_json)
	if not FileAccess.file_exists(abs_path):
		return
	var fh := FileAccess.open(abs_path, FileAccess.READ)
	if fh == null:
		return
	var parsed: Variant = JSON.parse_string(fh.get_as_text())
	if parsed is Dictionary:
		_metrics = parsed
		_volume_ratio = float(_metrics.get("max_volume_ratio", 0.0))
		_pose_class = str(_metrics.get("idle_pose_classification", "UNKNOWN"))


func _handle_lab_key(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match (event as InputEventKey).keycode:
		KEY_1:
			if _animation_player:
				_animation_player.stop()
			if _skeleton:
				_skeleton.reset_bone_poses()
		KEY_2:
			if _animation_player and not _resolved_idle.is_empty():
				_animation_player.play(_resolved_idle, 0.1)
		KEY_3:
			_skel_overlay = not _skel_overlay
			_apply_skeleton_overlay()
		KEY_4:
			_bbox_debug = not _bbox_debug
			_apply_bbox_debug()
	_refresh_status()


func _refresh_status() -> void:
	if _status == null:
		return
	var bones := _skeleton.get_bone_count() if _skeleton else 0
	var anim := "REST"
	if _animation_player and _animation_player.is_playing():
		anim = _resolved_idle if not _resolved_idle.is_empty() else "NONE"
	_status.text = (
		"FIGHTER %s | SOLVER %s | BONES %d | ANIMATION %s | VOLUME_RATIO %.3f | POSE %s | [1] REST [2] IDLE [3] SKEL %s [4] BBOX %s | BATTLE OFF"
		% [
			fighter_id,
			solver_version,
			bones,
			anim,
			_volume_ratio,
			_pose_class,
			"ON" if _skel_overlay else "off",
			"ON" if _bbox_debug else "off",
		]
	)
