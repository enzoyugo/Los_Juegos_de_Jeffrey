extends Node3D

## Standalone Terere Idle Pose Redesign V1 lab.
## STATIC POSES ONLY. Keys 1–4 switch candidates. Camera is scene-authored and frozen.
## Does not extend actorcore / production / semantic solver labs.

const PIPELINE := "TERERE_IDLE_POSE_REDESIGN_V1"
const FORBIDDEN := [
	"game_ready_v4",
	"game_ready_v3",
	"semantic_solver_v2",
	"solver_v1",
	"actorcore_benchmark",
	"source_rigged",
	"native_skin_audit",
]
const CANDIDATES := ["BASELINE", "POSE_A", "POSE_B", "POSE_C"]
const TITLES := {
	"BASELINE": "BASELINE",
	"POSE_A": "RELAXED COMPACT",
	"POSE_B": "GAME READY",
	"POSE_C": "CARTOON FIGHTER",
}

@export var fighter_id: String = "terere"
@export var pipeline_id: String = PIPELINE
@export var baseline_glb: String = "res://assets/fighters/processed/idle_benchmark_v1/terere/terere_idle_semantic_clean_v1.glb"
@export var pose_a_glb: String = "res://assets/fighters/processed/idle_pose_redesign_v1/terere/terere_idle_pose_redesign_v1_a.glb"
@export var pose_b_glb: String = "res://assets/fighters/processed/idle_pose_redesign_v1/terere/terere_idle_pose_redesign_v1_b.glb"
@export var pose_c_glb: String = "res://assets/fighters/processed/idle_pose_redesign_v1/terere/terere_idle_pose_redesign_v1_c.glb"

var _slot: Node3D
var _camera: Camera3D
var _overlay: Label
var _paths: Dictionary = {}
var _active_id: String = "BASELINE"
var _current: Node3D
var _load_ok := false
var _fail_reason := ""
var _handled_frame := -1
var _camera_xform := Transform3D.IDENTITY


func _ready() -> void:
	set_process_input(true)
	set_process_unhandled_input(true)
	_paths = {
		"BASELINE": baseline_glb,
		"POSE_A": pose_a_glb,
		"POSE_B": pose_b_glb,
		"POSE_C": pose_c_glb,
	}
	_slot = get_node_or_null("ModelSlot") as Node3D
	_camera = get_node_or_null("Camera3D") as Camera3D
	_overlay = get_node_or_null("CanvasLayer/Overlay") as Label
	if _camera:
		_camera.current = true
		_camera_xform = _camera.transform
	_bind_paths()
	if _load_ok:
		_show("BASELINE")
		_self_check_switches()
	_refresh_overlay()


func _bind_paths() -> void:
	if pipeline_id != PIPELINE:
		_fail("pipeline_id must be %s" % PIPELINE)
		return
	if _slot == null:
		_fail("missing ModelSlot")
		return
	if _camera == null:
		_fail("missing Camera3D")
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
	push_error("[POSE_REDESIGN_V1_LAB] FAIL %s" % reason)


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
		_show("BASELINE")
		handled = true
	elif ident == KEY_2 or ident == KEY_KP_2:
		_show("POSE_A")
		handled = true
	elif ident == KEY_3 or ident == KEY_KP_3:
		_show("POSE_B")
		handled = true
	elif ident == KEY_4 or ident == KEY_KP_4:
		_show("POSE_C")
		handled = true
	if handled:
		_handled_frame = Engine.get_process_frames()
		_restore_camera()
	return handled


func _show(cand_id: String) -> void:
	if not _load_ok:
		_refresh_overlay()
		return
	_active_id = cand_id
	if _current:
		_slot.remove_child(_current)
		_current.free()
		_current = null
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
	_hold_static_pose(_current)
	_restore_camera()
	_refresh_overlay()


func _hold_static_pose(node: Node) -> void:
	var player := _find_player(node)
	if player == null:
		return
	player.active = true
	player.speed_scale = 0.0
	var pose_name := _static_pose_name(player)
	if pose_name.is_empty():
		player.stop()
		player.active = false
		return
	var anim: Animation = player.get_animation(pose_name)
	if anim:
		anim.loop_mode = Animation.LOOP_NONE
	# Apply frame 0 only. Do not loop or let Mixamo/runtime play.
	player.play(pose_name)
	player.seek(0.0, true)
	player.pause()


func _static_pose_name(player: AnimationPlayer) -> String:
	var names := player.get_animation_list()
	for n in names:
		var lower := String(n).to_lower()
		if lower.contains("canonical") or lower.contains("pose") or lower.contains("idle"):
			return n
	return names[0] if names.size() > 0 else ""


func _restore_camera() -> void:
	if _camera == null:
		return
	_camera.transform = _camera_xform
	_camera.current = true


func _self_check_switches() -> void:
	if DisplayServer.get_name() != "headless":
		return
	var start := _camera.transform if _camera else Transform3D.IDENTITY
	for id in CANDIDATES:
		_show(id)
		if _camera and _camera.transform != start:
			push_error("[POSE_REDESIGN_V1_LAB] FAIL camera moved while switching %s" % id)
			return
		var player := _find_player(_current)
		if player and player.is_playing() and player.speed_scale != 0.0:
			push_error("[POSE_REDESIGN_V1_LAB] FAIL animation playing on %s" % id)
			return
	_show("BASELINE")
	print("POSE_LAB_SWITCH_OK")


func _refresh_overlay() -> void:
	if _overlay == null:
		return
	if not _load_ok:
		_overlay.text = "POSE REDESIGN LAB FAILED | %s" % _fail_reason
		return
	_overlay.text = (
		"TERERÉ IDLE POSE REDESIGN\n\n1 BASELINE\n2 RELAXED COMPACT\n3 GAME READY\n4 CARTOON FIGHTER\n\nNOW: %s\nSTATIC — no animation\nCamera frozen"
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
		"fallback": false,
		"fail_reason": _fail_reason,
		"animation_playing": false,
		"inherited_actorcore_lab": false,
		"baseline_glb": baseline_glb,
		"pose_a_glb": pose_a_glb,
		"pose_b_glb": pose_b_glb,
		"pose_c_glb": pose_c_glb,
		"battle_hud_instanced": false,
	}
