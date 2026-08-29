extends "res://scripts/fighters/glb_fighter_visual.gd"

## Jaguareté rigged visual — prefers offline-baked game-ready GLB.
## Fallback: static v1 GLB -> procedural. No runtime Mixamo retarget in production.

const GAME_READY_GLB := "res://assets/fighters/processed/jaguarete/jaguarete_game_ready_idle.glb"
const FALLBACK_V2_GLB := "res://assets/fighters/models/jaguarete/jaguarete_v2.glb"
const BAKED_IDLE_ANIM := "idle"

var skeleton: Skeleton3D
var animation_player: AnimationPlayer
var _idle_bound: bool = false
var _retarget_mode: String = "off"
var _animation_source: String = "NONE"
var _model_label: String = "V2"
var _fallback_tier: String = "none"
var _resolved_idle_anim: String = ""


func _init() -> void:
	const GLB_FIGHTER_CONFIG := preload("res://scripts/fighters/glb_fighter_config.gd")
	const SIZE := preload("res://scripts/fighters/fighter_size_class.gd")
	var cfg = GLB_FIGHTER_CONFIG.new()
	var use_baked := ResourceLoader.exists(GAME_READY_GLB)
	cfg.glb_path = GAME_READY_GLB if use_baked else FALLBACK_V2_GLB
	_model_label = "GAME_READY_IDLE" if use_baked else "V2"
	cfg.fallback_visual_script = load("res://fighters/jaguarete/jaguarete_glb_visual.gd")
	cfg.size_class = SIZE.TALL
	cfg.target_visual_height = 3.15
	cfg.body_measure_mode = GLB_FIGHTER_CONFIG.BODY_MEASURE_FRACTION
	cfg.body_height_fraction = 0.95
	cfg.fit_ignore_top_ratio = 0.0
	cfg.body_anchor_y_fraction = 0.46
	cfg.horizontal_anchor_fraction = 0.48
	cfg.ground_anchor = 0.0
	cfg.model_yaw_offset = -PI * 0.5
	cfg.shadow_enabled = true
	cfg.shadow_width = 1.55
	cfg.shadow_depth = 0.78
	config = cfg


func _ready() -> void:
	super._ready()
	if _using_fallback:
		_fallback_tier = "static_or_procedural"
		_log_rig("fallback", true)
		return
	skeleton = _find_skeleton(model_instance)
	if _model_label == "GAME_READY_IDLE":
		_bind_baked_idle()
	else:
		push_warning("[JAG_RIG] Baked GLB missing — showing static v2 mesh without idle")
		_retarget_mode = "baked_glb_missing"
	_log_rig("loaded", false)


func bind(fighter_ref, fighter_definition) -> void:
	super.bind(fighter_ref, fighter_definition)
	if _using_fallback and _delegate != null:
		_fallback_tier = "static_or_procedural"


func play_idle(restart: bool = false) -> void:
	if animation_player == null or _resolved_idle_anim.is_empty():
		return
	if not restart and animation_player.is_playing() and animation_player.current_animation == _resolved_idle_anim:
		return
	animation_player.play(_resolved_idle_anim, 0.12, 1.0, false)


func get_skeleton() -> Skeleton3D:
	return skeleton


func get_retarget_mode() -> String:
	return _retarget_mode


func get_animation_source() -> String:
	return _animation_source


func get_model_label() -> String:
	if _using_fallback:
		return "FALLBACK"
	return _model_label


func is_using_fallback() -> bool:
	return _using_fallback


func get_fallback_tier() -> String:
	return _fallback_tier


func _on_state_changed(_old_state: String, new_state: String) -> void:
	if _using_fallback:
		return
	if new_state == "IDLE" and _idle_bound:
		play_idle(false)


func _bind_baked_idle() -> void:
	if skeleton == null:
		push_warning("[JAG_RIG] No Skeleton3D in baked GLB")
		_retarget_mode = "baked_no_skeleton"
		return
	animation_player = _find_animation_player(model_instance)
	if animation_player == null:
		push_warning("[JAG_RIG] No AnimationPlayer in baked GLB")
		_retarget_mode = "baked_no_player"
		return
	_resolved_idle_anim = _resolve_idle_animation_name(animation_player)
	if _resolved_idle_anim.is_empty():
		push_warning("[JAG_RIG] Baked GLB has no idle animation")
		_retarget_mode = "baked_no_idle_clip"
		return
	var anim: Animation = animation_player.get_animation(_resolved_idle_anim)
	if anim != null:
		anim.loop_mode = Animation.LOOP_LINEAR
	_idle_bound = true
	_retarget_mode = "off"
	_animation_source = "BAKED"
	play_idle(true)


func _resolve_idle_animation_name(player: AnimationPlayer) -> String:
	if player.has_animation(BAKED_IDLE_ANIM):
		return BAKED_IDLE_ANIM
	for anim_name in player.get_animation_list():
		var lower := anim_name.to_lower()
		if lower == "idle" or lower.ends_with("/idle") or lower.contains("idle"):
			return anim_name
	var names := player.get_animation_list()
	return names[0] if names.size() > 0 else ""


func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node as Skeleton3D
	for child in node.get_children():
		var found := _find_skeleton(child)
		if found != null:
			return found
	return null


func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found != null:
			return found
	return null


func _log_rig(phase: String, fallback: bool) -> void:
	if OS.get_environment("SSK_ANIMATION_AUDIT") != "1":
		return
	var skel_path := String(skeleton.get_path()) if skeleton != null else "none"
	var bone_count := skeleton.get_bone_count() if skeleton != null else 0
	var mesh_path := "none"
	if model_instance != null:
		for m in _collect_mesh_instances(model_instance):
			mesh_path = String(m.get_path())
			break
	print(
		"[JAG_RIG] phase=%s model=%s skeleton=%s bones=%d mesh=%s anim=%s source=%s runtime_retarget=off fallback=%s tier=%s" % [
			phase,
			_model_label,
			skel_path,
			bone_count,
			mesh_path,
			_resolved_idle_anim if _idle_bound else "none",
			_animation_source,
			str(fallback),
			_fallback_tier
		]
	)
