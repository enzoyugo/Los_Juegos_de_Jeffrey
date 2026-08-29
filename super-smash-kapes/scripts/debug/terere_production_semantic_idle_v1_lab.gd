extends Node3D

## Terere Production Semantic Idle V1 comparison lab.
## 1 = POSE B STATIC  2 = OLD SEMANTIC BASELINE IDLE  3 = PRODUCTION SEMANTIC IDLE V1
## Standalone. Does not extend actorcore / production / semantic solver labs.

const PIPELINE := "TERERE_PRODUCTION_SEMANTIC_IDLE_V1"
const FORBIDDEN := [
	"game_ready_v4",
	"game_ready_v3",
	"semantic_solver_v2",
	"solver_v1",
	"actorcore_benchmark",
	"source_rigged",
	"native_skin_audit",
]
const CANDIDATES := ["POSE_B", "OLD_SEMANTIC", "PRODUCTION"]
const TITLES := {
	"POSE_B": "POSE B STATIC",
	"OLD_SEMANTIC": "OLD SEMANTIC IDLE",
	"PRODUCTION": "PRODUCTION SEMANTIC IDLE V1",
}

@export var fighter_id: String = "terere"
@export var pipeline_id: String = PIPELINE
@export var pose_b_glb: String = "res://assets/fighters/processed/idle_pose_redesign_v1/terere/terere_idle_pose_redesign_v1_b.glb"
@export var old_semantic_glb: String = "res://assets/fighters/processed/idle_benchmark_v1/terere/terere_idle_semantic_clean_v1.glb"
@export var production_glb: String = "res://assets/fighters/processed/production_semantic_idle_v1/terere/terere_production_semantic_idle_v1.glb"

var _slot: Node3D
var _camera: Camera3D
var _overlay: Label
var _paths: Dictionary = {}
var _active_id: String = "POSE_B"
var _current: Node3D
var _player: AnimationPlayer
var _load_ok := false
var _fail_reason := ""
var _handled_frame := -1
var _camera_xform := Transform3D.IDENTITY
var _shared_time := 0.0


func _ready() -> void:
	set_process_input(true)
	set_process_unhandled_input(true)
	set_process(true)
	_paths = {
		"POSE_B": pose_b_glb,
		"OLD_SEMANTIC": old_semantic_glb,
		"PRODUCTION": production_glb,
	}
	_slot = get_node_or_null("ModelSlot") as Node3D
	_camera = get_node_or_null("Camera3D") as Camera3D
	_overlay = get_node_or_null("CanvasLayer/Overlay") as Label
	if _camera:
		_camera.current = true
		_camera_xform = _camera.transform
	_bind_paths()
	if _load_ok:
		_show("POSE_B")
	_refresh_overlay()


func _bind_paths() -> void:
	if pipeline_id != PIPELINE:
		_fail("pipeline_id must be %s" % PIPELINE)
		return
	if _slot == null or _camera == null:
		_fail("missing ModelSlot or Camera3D")
		return
	for id in CANDIDATES:
		var path: String = String(_paths[id])
		for token in FORBIDDEN:
			if path.find(token) != -1:
				_fail("refused non-lab asset %s" % path)
				return
		if not ResourceLoader.exists(path):
			_fail("missing packed scene %s" % path)
			return
	_load_ok = true


func _fail(reason: String) -> void:
	_load_ok = false
	_fail_reason = reason
	push_error("[PROD_SEMANTIC_IDLE_V1_LAB] FAIL %s" % reason)


func _input(event: InputEvent) -> void:
	if _handle(event):
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if _handle(event):
		get_viewport().set_input_as_handled()


func _handle(event: InputEvent) -> bool:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return false
	var key_event := event as InputEventKey
	if Engine.get_process_frames() == _handled_frame:
		return true
	var ident := key_event.keycode if key_event.keycode != KEY_NONE else key_event.physical_keycode
	var handled := false
	if ident == KEY_1 or ident == KEY_KP_1:
		_show("POSE_B")
		handled = true
	elif ident == KEY_2 or ident == KEY_KP_2:
		_show("OLD_SEMANTIC")
		handled = true
	elif ident == KEY_3 or ident == KEY_KP_3:
		_show("PRODUCTION")
		handled = true
	if handled:
		_handled_frame = Engine.get_process_frames()
		_restore_camera()
	return handled


func _process(_delta: float) -> void:
	if _player and _player.is_playing() and _player.speed_scale != 0.0:
		_shared_time = _player.current_animation_position
	_refresh_overlay()


func _show(cand_id: String) -> void:
	if not _load_ok:
		_refresh_overlay()
		return
	if _player and _player.is_playing() and _player.speed_scale != 0.0:
		_shared_time = _player.current_animation_position
	_active_id = cand_id
	if _current:
		_slot.remove_child(_current)
		_current.free()
		_current = null
		_player = null
	var packed: PackedScene = load(String(_paths[cand_id])) as PackedScene
	if packed == null:
		_fail("failed to load %s" % String(_paths[cand_id]))
		_refresh_overlay()
		return
	var inst := packed.instantiate()
	if not (inst is Node3D):
		inst.free()
		_fail("candidate is not Node3D")
		_refresh_overlay()
		return
	_current = inst as Node3D
	_slot.add_child(_current)
	_player = _find_player(_current)
	if cand_id == "POSE_B":
		_hold_static(_player)
	else:
		_play_idle(_player)
	_restore_camera()
	_refresh_overlay()


func _idle_name(player: AnimationPlayer) -> String:
	var names := player.get_animation_list()
	for n in names:
		var lower := String(n).to_lower()
		if lower.contains("idle") or lower.contains("canonical") or lower.contains("pose"):
			return n
	return names[0] if names.size() > 0 else ""


func _hold_static(player: AnimationPlayer) -> void:
	if player == null:
		return
	player.active = true
	player.speed_scale = 0.0
	var pose_name := _idle_name(player)
	if pose_name.is_empty():
		player.stop()
		return
	var anim: Animation = player.get_animation(pose_name)
	if anim:
		anim.loop_mode = Animation.LOOP_NONE
	player.play(pose_name)
	player.seek(0.0, true)
	player.pause()


func _play_idle(player: AnimationPlayer) -> void:
	if player == null:
		return
	player.active = true
	player.speed_scale = 1.0
	var idle := _idle_name(player)
	if idle.is_empty():
		return
	var anim: Animation = player.get_animation(idle)
	if anim:
		anim.loop_mode = Animation.LOOP_LINEAR
	player.play(idle)
	if _shared_time > 0.0 and player.current_animation != "":
		player.seek(_shared_time, true)


func _restore_camera() -> void:
	if _camera == null:
		return
	_camera.transform = _camera_xform
	_camera.current = true


func _refresh_overlay() -> void:
	if _overlay == null:
		return
	if not _load_ok:
		_overlay.text = "PRODUCTION SEMANTIC IDLE LAB FAILED | %s" % _fail_reason
		return
	_overlay.text = (
		"TERERÉ IDLE FINAL\n\n1 POSE B STATIC\n2 OLD SEMANTIC IDLE\n3 PRODUCTION SEMANTIC IDLE V1\n\nNOW: %s\nCamera frozen"
		% String(TITLES.get(_active_id, _active_id))
	)


func _find_player(node: Node) -> AnimationPlayer:
	if node == null:
		return null
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var found := _find_player(child)
		if found:
			return found
	return null


func collect_dump() -> Dictionary:
	return {
		"fighter": fighter_id,
		"pipeline": pipeline_id,
		"method": _active_id,
		"load_ok": _load_ok,
		"fail_reason": _fail_reason,
		"wired_into_battle": false,
		"inherited_actorcore_lab": false,
		"pose_b_glb": pose_b_glb,
		"old_semantic_glb": old_semantic_glb,
		"production_glb": production_glb,
	}
