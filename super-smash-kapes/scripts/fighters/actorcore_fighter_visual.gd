class_name ActorCoreFighterVisual
extends "res://scripts/fighters/glb_fighter_visual.gd"

## Generic ActorCore production visual.
## One imported game-ready GLB, baked skeletal clips, no runtime retarget.

const PIPELINE_ID := "ACTORCORE_V4"
const BAKED_IDLE := "idle"

var skeleton: Skeleton3D
var animation_player: AnimationPlayer
var _resolved_clips: Dictionary = {}
var _skeletal_idle_bound: bool = false
var _proxy_idle: bool = true
var _fallback_used: bool = false
var _pipeline_logged: bool = false
var _current_semantic: String = ""
## Presentation-only playback scales. Never changes gameplay frames.
var clip_speed_scale: Dictionary = {}
var clip_blend: Dictionary = {
	"idle": 0.12,
	"run": 0.10,
	"jump": 0.06,
	"attack_neutral": 0.04,
	"hit_light": 0.05,
	"ko": 0.08,
	"victory": 0.12,
}


func play_animation(semantic: String) -> bool:
	if animation_player == null:
		return false
	var clip := _clip_name_for(semantic)
	if clip.is_empty():
		if semantic != "idle" and animation_player.is_playing():
			animation_player.stop()
		return false
	if animation_player.is_playing() and animation_player.current_animation == clip and semantic == _current_semantic:
		return true
	var anim: Animation = animation_player.get_animation(clip)
	if anim != null and semantic == "idle":
		anim.loop_mode = Animation.LOOP_LINEAR
	var blend := float(clip_blend.get(semantic, 0.08))
	var speed := float(clip_speed_scale.get(semantic, 1.0))
	animation_player.play(clip, blend, speed)
	_current_semantic = semantic
	if OS.get_environment("SSK_ANIMATION_AUDIT") == "1":
		print("[ANIMATION_AUDIT] fighter=%s semantic=%s clip=%s speed=%.2f blend=%.2f" % [
			definition.id if definition else "?",
			semantic,
			clip,
			speed,
			blend,
		])
	return true


func _idle_uses_skeletal() -> bool:
	return _skeletal_idle_bound and not _using_fallback


func _ready() -> void:
	super._ready()
	_fallback_used = _using_fallback
	if _using_fallback:
		_emit_pipeline_error("ActorCore production asset failed.")
		return
	skeleton = _find_skeleton(model_instance)
	animation_player = _find_animation_player(model_instance)
	_bind_semantic_clips()
	if _skeletal_idle_bound:
		_proxy_idle = false
		play_animation("idle")
	else:
		_emit_pipeline_error("ActorCore idle clip missing after GLB load.")


func _on_state_changed(_old_state: String, new_state: String) -> void:
	if _using_fallback:
		return
	match new_state:
		"IDLE":
			snap_motion_roots_neutral()
			play_animation("idle")
		"RUN":
			if not play_animation("run"):
				_stop_skeletal_keep_pose()
		"AIR":
			if not play_animation("jump"):
				_stop_skeletal_keep_pose()
		"ATTACK":
			if not play_animation("attack_neutral"):
				_stop_skeletal_keep_pose()
		"HITSTUN":
			if not play_animation("hit_light"):
				_stop_skeletal_keep_pose()
		"KO":
			if not play_animation("ko"):
				_stop_skeletal_keep_pose()
		"VICTORY":
			if not play_animation("victory"):
				play_animation("idle")
		"RESPAWN":
			play_animation("idle")
		_:
			_stop_skeletal_keep_pose()


func _stop_skeletal_keep_pose() -> void:
	if animation_player != null and animation_player.is_playing():
		animation_player.stop()
	_current_semantic = ""


func _bind_semantic_clips() -> void:
	if animation_player == null:
		return
	_resolved_clips.clear()
	for semantic in PackedStringArray(["idle", "run", "jump", "air_attack", "attack_neutral", "attack_heavy", "hit_light", "hit_heavy", "ko", "victory"]):
		var resolved := _resolve_clip(semantic)
		if not resolved.is_empty():
			_resolved_clips[semantic] = resolved
	_skeletal_idle_bound = _resolved_clips.has("idle")


func _clip_name_for(semantic: String) -> String:
	if _resolved_clips.has(semantic):
		return str(_resolved_clips[semantic])
	return ""


func _resolve_clip(semantic: String) -> String:
	if animation_player == null:
		return ""
	if semantic == "idle" and animation_player.has_animation(BAKED_IDLE):
		return BAKED_IDLE
	for anim_name in animation_player.get_animation_list():
		var lower := anim_name.to_lower()
		if "t-pose" in lower or "tpose" in lower:
			continue
		if lower == semantic or lower.ends_with("/" + semantic) or lower.contains(semantic):
			return anim_name
	return ""


func _bone_track_count() -> int:
	if animation_player == null:
		return 0
	var clip := _clip_name_for("idle")
	if clip.is_empty() or not animation_player.has_animation(clip):
		return 0
	var anim: Animation = animation_player.get_animation(clip)
	if anim == null:
		return 0
	var bones := {}
	for i in anim.get_track_count():
		if anim.track_get_type(i) == Animation.TYPE_ROTATION_3D:
			var path := String(anim.track_get_path(i))
			if ":" in path:
				var parts := path.split(":")
				bones[parts[parts.size() - 1]] = true
	return bones.size()


func _log_pipeline_audit() -> void:
	if OS.get_environment("SSK_FIGHTER_PIPELINE_AUDIT") != "1" and OS.get_environment("SSK_FIGHTER_VISUAL_AUDIT") != "1":
		return
	if _pipeline_logged:
		return
	_pipeline_logged = true
	var player_label := "P?"
	if fighter != null:
		player_label = "P%d" % int(fighter.player_id)
	var fighter_id: String = "?"
	if definition != null:
		fighter_id = str(definition.id)
	var model_name: String = "?"
	if config != null:
		model_name = config.glb_path.get_file()
	var bone_n: int = 0
	if skeleton != null:
		bone_n = skeleton.get_bone_count()
	var height_n: float = 0.0
	if config != null:
		height_n = config.target_visual_height
	print("[FIGHTER_PIPELINE]")
	print("player=%s" % player_label)
	print("fighter=%s" % fighter_id)
	print("pipeline=%s" % pipeline_name())
	print("model=%s" % model_name)
	print("asset=%s" % (config.glb_path if config else "?"))
	print("skeleton_bones=%d" % bone_n)
	print("animation=%s" % _clip_name_for("idle"))
	print("skeletal_tracks=%d" % _bone_track_count())
	print("runtime_retarget=false")
	print("proxy_idle=%s" % str(_proxy_idle))
	print("fallback=%s" % str(_fallback_used))
	print("visual_instances=1")
	print("target_height=%.2f" % height_n)
	if OS.get_environment("SSK_FIGHTER_VISUAL_AUDIT") == "1":
		_log_visual_transform_audit(player_label, fighter_id)


func pipeline_name() -> String:
	return PIPELINE_ID


func _log_visual_transform_audit(player_label: String, fighter_id: String) -> void:
	print("[FIGHTER_VISUAL]")
	print("player=%s" % player_label)
	print("fighter=%s" % fighter_id)
	print("pipeline=%s" % pipeline_name())
	print("asset=%s" % (config.glb_path if config else "?"))
	print("skeleton_bones=%d" % (skeleton.get_bone_count() if skeleton else 0))
	print("animation=%s" % _clip_name_for("idle"))
	print("visual_root_rotation=%s" % str(rotation_degrees))
	print("motion_root_rotation=%s" % str(motion_root.rotation_degrees if motion_root else Vector3.ZERO))
	print("presentation_scale=%s" % str(presentation_root.scale if presentation_root else Vector3.ONE))
	print("facing_root_rotation=%s" % str(facing_root.rotation_degrees if facing_root else Vector3.ZERO))
	print("model_root_rotation=%s" % str(model_root.rotation_degrees if model_root else Vector3.ZERO))
	print("fallback=%s" % str(_fallback_used))


func _emit_pipeline_error(reason: String) -> void:
	push_error("[FIGHTER_PIPELINE][ERROR] ActorCore production asset failed. %s path=%s" % [
		reason,
		config.glb_path if config else "?"
	])


func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node as Skeleton3D
	for child in node.get_children():
		var found := _find_skeleton(child)
		if found:
			return found
	return null


func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found:
			return found
	return null
