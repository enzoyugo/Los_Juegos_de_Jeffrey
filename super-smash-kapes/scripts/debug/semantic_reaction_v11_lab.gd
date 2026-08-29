extends Node3D

## Semantic Reaction V1.1 comparison lab.
## 1 APPROVED IDLE  2 ORIGINAL REACTION V1  3 LIGHT  4 MEDIUM  5 STRONG  6 reset camera
## Single-trigger only: idle -> selected reaction once -> idle.
## No skeleton/bbox debug. Does not extend other labs. No battle / HUD.

const PIPELINE := "SEMANTIC_REACTION_V11"
const FORBIDDEN := [
	"game_ready_v4",
	"game_ready_v3",
	"semantic_solver_v2",
	"solver_v1",
	"actorcore_benchmark",
	"source_rigged",
	"native_skin_audit",
]
const REACTION_KEYS := ["V1", "A", "B", "C"]
const TITLES := {
	"IDLE": "APPROVED IDLE",
	"V1": "ORIGINAL REACTION V1",
	"A": "V1.1 LIGHT",
	"B": "V1.1 MEDIUM",
	"C": "V1.1 STRONG",
}

@export var fighter_id: String = "terere"
@export var pipeline_id: String = PIPELINE
@export var idle_glb: String = ""
@export var v1_glb: String = ""
@export var light_glb: String = ""
@export var medium_glb: String = ""
@export var strong_glb: String = ""

var _camera: Camera3D
var _overlay: Label
var _roots: Dictionary = {}
var _nodes: Dictionary = {}
var _players: Dictionary = {}
var _mode := "IDLE"
var _pending := ""
var _load_ok := false
var _fail_reason := ""
var _handled_frame := -1
var _camera_xform := Transform3D.IDENTITY
var _once := false
var _switching := false


func _ready() -> void:
	set_process_input(true)
	set_process_unhandled_input(true)
	set_process(true)
	_camera = get_node_or_null("Camera3D") as Camera3D
	_overlay = get_node_or_null("CanvasLayer/Overlay") as Label
	_roots = {
		"IDLE": get_node_or_null("IdleRoot"),
		"V1": get_node_or_null("V1Root"),
		"A": get_node_or_null("LightRoot"),
		"B": get_node_or_null("MediumRoot"),
		"C": get_node_or_null("StrongRoot"),
	}
	if _camera:
		_camera.current = true
		_camera_xform = _camera.transform
	_bind()
	if _load_ok:
		_show_idle()
	_refresh_overlay()


func _live(node: Node) -> bool:
	return (
		node != null
		and is_instance_valid(node)
		and not node.is_queued_for_deletion()
		and node.is_inside_tree()
	)


func _bind() -> void:
	if pipeline_id != PIPELINE:
		_fail("pipeline_id must be %s" % PIPELINE)
		return
	var paths := {
		"IDLE": idle_glb,
		"V1": v1_glb,
		"A": light_glb,
		"B": medium_glb,
		"C": strong_glb,
	}
	for id in paths.keys():
		var path: String = String(paths[id])
		for token in FORBIDDEN:
			if path.find(token) != -1:
				_fail("refused non-lab asset %s" % path)
				return
		if not ResourceLoader.exists(path):
			_fail("missing %s" % path)
			return
		var root: Node3D = _roots[id] as Node3D
		var inst := _instantiate(path, root)
		if inst == null:
			_fail("failed to instance %s" % id)
			return
		_nodes[id] = inst
		var player := _find_player(inst)
		_players[id] = player
		if id != "IDLE" and _live(player):
			player.animation_finished.connect(_on_reaction_finished.bind(id))
	_load_ok = true


func _instantiate(path: String, parent: Node3D) -> Node3D:
	if parent == null:
		return null
	var packed: PackedScene = load(path) as PackedScene
	if packed == null:
		return null
	var inst := packed.instantiate()
	if not (inst is Node3D):
		inst.free()
		return null
	parent.add_child(inst)
	parent.visible = false
	return inst as Node3D


func _fail(reason: String) -> void:
	_load_ok = false
	_fail_reason = reason
	push_error("[REACTION_V11_LAB] FAIL fighter=%s %s" % [fighter_id, reason])


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
		_show_idle(); handled = true
	elif ident == KEY_2 or ident == KEY_KP_2:
		_trigger("V1"); handled = true
	elif ident == KEY_3 or ident == KEY_KP_3:
		_trigger("A"); handled = true
	elif ident == KEY_4 or ident == KEY_KP_4:
		_trigger("B"); handled = true
	elif ident == KEY_5 or ident == KEY_KP_5:
		_trigger("C"); handled = true
	elif ident == KEY_6 or ident == KEY_KP_6:
		_restore_camera(); handled = true
	if handled:
		_handled_frame = Engine.get_process_frames()
	return handled


func _process(_delta: float) -> void:
	_refresh_overlay()


func _clip_name(player: AnimationPlayer, token: String) -> String:
	if not _live(player):
		return ""
	var names := player.get_animation_list()
	for n in names:
		if String(n).to_lower().contains(token):
			return n
	return names[0] if names.size() > 0 else ""


func _stop_all() -> void:
	for id in _players.keys():
		var player: AnimationPlayer = _players[id]
		if _live(player):
			player.stop()
			player.active = false


func _hide_all_roots() -> void:
	for id in _roots.keys():
		var root: Node = _roots[id]
		if _live(root):
			root.visible = false


func _show_idle() -> void:
	_switching = true
	_once = false
	_pending = ""
	_mode = "IDLE"
	_stop_all()
	_hide_all_roots()
	var idle_root: Node = _roots.get("IDLE")
	if _live(idle_root):
		idle_root.visible = true
	var idle_player: AnimationPlayer = _players.get("IDLE")
	if _live(idle_player):
		idle_player.active = true
		idle_player.speed_scale = 1.0
		var idle := _clip_name(idle_player, "idle")
		if not idle.is_empty():
			var anim: Animation = idle_player.get_animation(idle)
			if anim:
				anim.loop_mode = Animation.LOOP_LINEAR
			idle_player.play(idle)
	_print_state("IDLE", "idle", 0.0)
	_restore_camera()
	_switching = false


func _trigger(which: String) -> void:
	if which not in REACTION_KEYS:
		return
	_switching = true
	_once = false
	_stop_all()
	_hide_all_roots()
	_pending = which
	_mode = which
	_once = true
	var root: Node = _roots.get(which)
	if _live(root):
		root.visible = true
	var player: AnimationPlayer = _players.get(which)
	if _live(player):
		player.active = true
		player.speed_scale = 1.0
		var clip := _clip_name(player, "reaction")
		if not clip.is_empty():
			var anim: Animation = player.get_animation(clip)
			if anim:
				anim.loop_mode = Animation.LOOP_NONE
			player.play(clip)
			player.seek(0.0, true)
	_print_state(which, "reaction", 0.0)
	_restore_camera()
	_switching = false


func _on_reaction_finished(_anim_name: StringName, which: String = "") -> void:
	if not _once or _switching:
		return
	if which != _pending:
		return
	_once = false
	_pending = ""
	_show_idle()


func _print_state(state: String, clip: String, time: float) -> void:
	print("[REACTION_V11_LAB] fighter=%s state=%s clip=%s time=%.3f" % [fighter_id, state, clip, time])


func _restore_camera() -> void:
	if not _live(_camera):
		return
	_camera.transform = _camera_xform
	_camera.current = true


func _find_player(node: Node) -> AnimationPlayer:
	if not (node != null and is_instance_valid(node)):
		return null
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		if not (child is Node):
			continue
		var found := _find_player(child)
		if found:
			return found
	return null


func _refresh_overlay() -> void:
	if _overlay == null:
		return
	if not _load_ok:
		_overlay.text = "REACTION V1.1 LAB FAILED | %s" % _fail_reason
		return
	var t := 0.0
	if _mode != "IDLE":
		var player: AnimationPlayer = _players.get(_mode)
		if _live(player):
			t = player.current_animation_position
	else:
		var idle_player: AnimationPlayer = _players.get("IDLE")
		if _live(idle_player):
			t = idle_player.current_animation_position
	var title: String = String(TITLES.get(_mode, _mode))
	_overlay.text = (
		"%s REACTION V1.1\n\n1 APPROVED IDLE\n2 ORIGINAL REACTION V1\n3 V1.1 LIGHT\n4 V1.1 MEDIUM\n5 V1.1 STRONG\n6 reset camera\n\nNOW %s  t=%.2f"
		% [fighter_id.to_upper(), title, t]
	)
