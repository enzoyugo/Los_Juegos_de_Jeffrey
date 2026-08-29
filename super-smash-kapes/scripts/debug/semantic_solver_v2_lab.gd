extends "res://scripts/debug/production_animation_lab.gd"

## Isolated semantic Idle solver V2 lab. Not wired into battle.
## 1 REST  2 CANONICAL STANDING  3 IDLE  4 SKELETON  5 BBOX

@export var metrics_json: String = ""
@export var solver_version: String = "semantic_idle_solver_v2"
@export var idle_source: String = "assets/fighters/animations/Idle.fbx"

var _metrics: Dictionary = {}
var _volume_ratio: float = 0.0
var _pose_class: String = "UNKNOWN"
var _root_xz: float = 0.0
var _resolved_rest: String = ""
var _resolved_standing: String = ""
var _clip_label: String = "REST"


func _ready() -> void:
	pipeline_id = "ACTORCORE_SEMANTIC_SOLVER_V2"
	if production_glb != "":
		benchmark_glb = production_glb
	_load_metrics()
	super._ready()
	_resolved_rest = _resolve_named(["rest"])
	_resolved_standing = _resolve_named(["canonical_standing", "standing"])
	if _resolved_idle.is_empty():
		_resolved_idle = _resolve_named(["idle"])
	if _animation_player:
		_animation_player.stop()
		_loop_clip(_resolved_idle, true)
		_loop_clip(_resolved_rest, false)
		_loop_clip(_resolved_standing, false)
	if _skeleton:
		_skeleton.reset_bone_poses()
	_clip_label = "REST"
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
		_root_xz = float(_metrics.get("max_root_xz", 0.0))


func _resolve_named(tokens: Array) -> String:
	if _animation_player == null:
		return ""
	for name in _animation_player.get_animation_list():
		var lower := name.to_lower()
		for token in tokens:
			if lower.contains(str(token).to_lower()):
				return name
	return ""


func _loop_clip(clip_name: String, loop: bool) -> void:
	if clip_name.is_empty() or _animation_player == null:
		return
	if not _animation_player.has_animation(clip_name):
		return
	var anim: Animation = _animation_player.get_animation(clip_name)
	if anim:
		anim.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE


func _handle_lab_key(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match (event as InputEventKey).keycode:
		KEY_1:
			if _animation_player:
				_animation_player.stop()
			if _skeleton:
				_skeleton.reset_bone_poses()
			_clip_label = "REST"
		KEY_2:
			if _animation_player and not _resolved_standing.is_empty():
				_animation_player.play(_resolved_standing, 0.1)
				_clip_label = "CANONICAL_STANDING"
		KEY_3:
			if _animation_player and not _resolved_idle.is_empty():
				_animation_player.play(_resolved_idle, 0.1)
				_clip_label = "IDLE"
		KEY_4:
			_skel_overlay = not _skel_overlay
			_apply_skeleton_overlay()
		KEY_5:
			_bbox_debug = not _bbox_debug
			_apply_bbox_debug()
	_refresh_status()


func _refresh_status() -> void:
	if _status == null:
		return
	var bones := _skeleton.get_bone_count() if _skeleton else 0
	_status.text = (
		"FIGHTER %s | SOLVER %s ARM-CHAIN | VOLUME_RATIO %.3f | POSE %s | BONES %d | IDLE_SOURCE %s | ROOT_XZ %.4f | CLIP %s | [1] REST [2] CANONICAL STANDING [3] IDLE [4] SKEL %s [5] BBOX %s | BATTLE OFF"
		% [
			fighter_id,
			solver_version,
			_volume_ratio,
			_pose_class,
			bones,
			idle_source,
			_root_xz,
			_clip_label,
			"ON" if _skel_overlay else "off",
			"ON" if _bbox_debug else "off",
		]
	)
