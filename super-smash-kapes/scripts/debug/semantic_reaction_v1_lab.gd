extends Node3D

## Isolated Semantic Reaction V1 lab.
## 1 APPROVED IDLE  2 REACTION LOOP  3 SINGLE REACTION TRIGGER  4 skeleton  5 bbox  6 reset camera
## Does not extend actorcore / production / semantic-solver labs. No battle / HUD.
## Reaction playback does not depend on debug drawing.

const PIPELINE := "SEMANTIC_REACTION_V1"
const FORBIDDEN := [
	"game_ready_v4",
	"game_ready_v3",
	"semantic_solver_v2",
	"solver_v1",
	"actorcore_benchmark",
	"source_rigged",
	"native_skin_audit",
]

@export var fighter_id: String = "terere"
@export var pipeline_id: String = PIPELINE
@export var idle_glb: String = ""
@export var reaction_glb: String = ""

var _camera: Camera3D
var _overlay: Label
var _idle_root: Node3D
var _reaction_root: Node3D
var _idle_node: Node3D
var _reaction_node: Node3D
var _idle_player: AnimationPlayer
var _reaction_player: AnimationPlayer
var _active_skel: Skeleton3D
var _mode := "IDLE"
var _load_ok := false
var _fail_reason := ""
var _handled_frame := -1
var _camera_xform := Transform3D.IDENTITY
var _skel_on := false
var _bbox_on := false
var _skel_markers: Array[MeshInstance3D] = []
var _bbox_mesh: MeshInstance3D
var _bbox_box: BoxMesh
var _once := false
var _last_print_t := -1.0
var _switching := false
var _probe := false
var _probe_t := 0.0
var _probe_i := 0
var _probe_steps: Array = []


func _ready() -> void:
	set_process_input(true)
	set_process_unhandled_input(true)
	set_process(true)
	_camera = get_node_or_null("Camera3D") as Camera3D
	_overlay = get_node_or_null("CanvasLayer/Overlay") as Label
	_idle_root = get_node_or_null("IdleRoot") as Node3D
	_reaction_root = get_node_or_null("ReactionRoot") as Node3D
	if _camera:
		_camera.current = true
		_camera_xform = _camera.transform
	_bind()
	_setup_probe()
	if _load_ok:
		_show_idle()
	_refresh_overlay()


func _bind() -> void:
	if pipeline_id != PIPELINE:
		_fail("pipeline_id must be %s" % PIPELINE)
		return
	for path in [idle_glb, reaction_glb]:
		for token in FORBIDDEN:
			if path.find(token) != -1:
				_fail("refused non-lab asset %s" % path)
				return
		if not ResourceLoader.exists(path):
			_fail("missing %s" % path)
			return
	_idle_node = _instantiate(idle_glb, _idle_root)
	_reaction_node = _instantiate(reaction_glb, _reaction_root)
	if _idle_node == null or _reaction_node == null:
		_fail("failed to instance idle/reaction")
		return
	_idle_player = _find_player(_idle_node)
	_reaction_player = _find_player(_reaction_node)
	if _live(_reaction_player):
		_reaction_player.animation_finished.connect(_on_reaction_finished)
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
	return inst as Node3D


func _fail(reason: String) -> void:
	_load_ok = false
	_fail_reason = reason
	push_error("[REACTION_LAB] FAIL fighter=%s %s" % [fighter_id, reason])


func _live(node: Node) -> bool:
	return (
		node != null
		and is_instance_valid(node)
		and not node.is_queued_for_deletion()
		and node.is_inside_tree()
	)


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
	if _apply_key(ident):
		_handled_frame = Engine.get_process_frames()
		return true
	return false


func _apply_key(ident: int) -> bool:
	if ident == KEY_1 or ident == KEY_KP_1:
		_show_idle()
		return true
	if ident == KEY_2 or ident == KEY_KP_2:
		_show_reaction_loop()
		return true
	if ident == KEY_3 or ident == KEY_KP_3:
		_trigger_once()
		return true
	if ident == KEY_4 or ident == KEY_KP_4:
		_skel_on = not _skel_on
		if _skel_on:
			_ensure_skeleton_debug()
		else:
			_clear_skeleton_debug()
		return true
	if ident == KEY_5 or ident == KEY_KP_5:
		_bbox_on = not _bbox_on
		if _bbox_on:
			_ensure_bbox_debug()
		else:
			_hide_bbox_debug()
		return true
	if ident == KEY_6 or ident == KEY_KP_6:
		_restore_camera()
		return true
	return false


func _process(delta: float) -> void:
	_process_probe(delta)
	if not _load_ok or _switching:
		_refresh_overlay()
		return
	if _skel_on:
		_update_skeleton_debug()
	if _bbox_on:
		_update_bbox_debug()
	if _once and _live(_reaction_player):
		var t := _reaction_player.current_animation_position
		if _last_print_t < 0.0 or t - _last_print_t >= 0.12:
			_last_print_t = t
			_print_state("REACTION", "reaction", t)
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
	for player in [_idle_player, _reaction_player]:
		if _live(player):
			player.stop()
			player.active = false


func _begin_switch() -> void:
	_switching = true
	_active_skel = null


func _finish_switch() -> void:
	_reacquire_debug_targets()
	_switching = false
	if _skel_on:
		_ensure_skeleton_debug()
	if _bbox_on:
		_ensure_bbox_debug()
	_restore_camera()


func _reacquire_debug_targets() -> void:
	_active_skel = null
	var root := _active_node()
	if _live(root):
		_active_skel = _find_skeleton(root)


func _show_idle() -> void:
	_begin_switch()
	_once = false
	_mode = "IDLE"
	_stop_all()
	if _idle_root:
		_idle_root.visible = true
	if _reaction_root:
		_reaction_root.visible = false
	if _live(_idle_player):
		_idle_player.active = true
		_idle_player.speed_scale = 1.0
		var idle := _clip_name(_idle_player, "idle")
		if not idle.is_empty():
			var anim: Animation = _idle_player.get_animation(idle)
			if anim:
				anim.loop_mode = Animation.LOOP_LINEAR
			_idle_player.play(idle)
	_print_state("IDLE", "idle", 0.0)
	_finish_switch()


func _show_reaction_loop() -> void:
	_begin_switch()
	_once = false
	_mode = "REACTION_LOOP"
	_stop_all()
	if _idle_root:
		_idle_root.visible = false
	if _reaction_root:
		_reaction_root.visible = true
	if _live(_reaction_player):
		_reaction_player.active = true
		_reaction_player.speed_scale = 1.0
		var clip := _clip_name(_reaction_player, "reaction")
		if not clip.is_empty():
			var anim: Animation = _reaction_player.get_animation(clip)
			if anim:
				anim.loop_mode = Animation.LOOP_LINEAR
			_reaction_player.play(clip)
	_print_state("REACTION", "reaction", 0.0)
	_finish_switch()


func _trigger_once() -> void:
	_begin_switch()
	_once = true
	_last_print_t = -1.0
	_mode = "REACTION"
	_stop_all()
	if _idle_root:
		_idle_root.visible = false
	if _reaction_root:
		_reaction_root.visible = true
	if _live(_reaction_player):
		_reaction_player.active = true
		_reaction_player.speed_scale = 1.0
		var clip := _clip_name(_reaction_player, "reaction")
		if not clip.is_empty():
			var anim: Animation = _reaction_player.get_animation(clip)
			if anim:
				anim.loop_mode = Animation.LOOP_NONE
			_reaction_player.play(clip)
			_reaction_player.seek(0.0, true)
	_print_state("REACTION", "reaction", 0.0)
	_finish_switch()


func _on_reaction_finished(_anim_name: StringName) -> void:
	if not _once:
		return
	var t := 0.0
	if _live(_reaction_player):
		t = _reaction_player.current_animation_length
	_print_state("REACTION", "reaction", t)
	_once = false
	_show_idle()


func _print_state(state: String, clip: String, time: float) -> void:
	print("[REACTION_LAB] fighter=%s state=%s clip=%s time=%.3f" % [fighter_id, state, clip, time])


func _restore_camera() -> void:
	if not _live(_camera):
		return
	_camera.transform = _camera_xform
	_camera.current = true


func _active_node() -> Node3D:
	if _mode == "IDLE":
		return _idle_node if _live(_idle_node) else null
	return _reaction_node if _live(_reaction_node) else null


func _current_skeleton() -> Skeleton3D:
	if _live(_active_skel):
		return _active_skel
	var root := _active_node()
	if not _live(root):
		return null
	_active_skel = _find_skeleton(root)
	return _active_skel if _live(_active_skel) else null


func _find_skeleton(node: Node) -> Skeleton3D:
	if not _live(node):
		return null
	if node is Skeleton3D:
		return node as Skeleton3D
	for child in node.get_children():
		if not (child is Node):
			continue
		var found := _find_skeleton(child)
		if found:
			return found
	return null


func _clear_skeleton_debug() -> void:
	for marker in _skel_markers:
		if is_instance_valid(marker) and not marker.is_queued_for_deletion():
			marker.queue_free()
	_skel_markers.clear()


func _ensure_skeleton_debug() -> void:
	if not _skel_on:
		return
	var skel := _current_skeleton()
	if not _live(skel):
		return
	var n := skel.get_bone_count()
	if _skel_markers.size() != n:
		_clear_skeleton_debug()
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(0.2, 1.0, 0.45)
		for _i in n:
			var marker := MeshInstance3D.new()
			var sphere := SphereMesh.new()
			sphere.radius = 0.012
			sphere.height = 0.024
			marker.mesh = sphere
			marker.material_override = mat
			add_child(marker)
			_skel_markers.append(marker)
	_update_skeleton_debug()


func _update_skeleton_debug() -> void:
	if not _skel_on or _switching:
		return
	var skel := _current_skeleton()
	if not _live(skel):
		return
	if _skel_markers.size() != skel.get_bone_count():
		_ensure_skeleton_debug()
		return
	var bone_count := skel.get_bone_count()
	for i in bone_count:
		var marker := _skel_markers[i]
		if not _live(marker):
			_ensure_skeleton_debug()
			return
		if not _live(skel):
			return
		marker.global_position = skel.to_global(skel.get_bone_global_pose(i).origin)


func _is_debug_mesh(node: Node) -> bool:
	if node == null:
		return false
	if node == _bbox_mesh:
		return true
	if node.name == "BBoxDebug":
		return true
	for marker in _skel_markers:
		if node == marker:
			return true
	return false


func _model_aabb(node: Node) -> AABB:
	var combined := AABB()
	var first := true
	var stack: Array[Node] = []
	if _live(node):
		stack.append(node)
	while not stack.is_empty():
		var cur: Node = stack.pop_back()
		if not _live(cur) or _is_debug_mesh(cur):
			continue
		if cur is MeshInstance3D:
			var mi := cur as MeshInstance3D
			if mi.mesh != null and _live(mi):
				var local: AABB = mi.mesh.get_aabb()
				for i in 8:
					var pt: Vector3 = mi.global_transform * local.get_endpoint(i)
					if first:
						combined = AABB(pt, Vector3.ZERO)
						first = false
					else:
						combined = combined.expand(pt)
		for child in cur.get_children():
			if child is Node:
				stack.append(child)
	return combined


func _ensure_bbox_debug() -> void:
	if not _bbox_on:
		_hide_bbox_debug()
		return
	if not _live(_bbox_mesh):
		_bbox_mesh = MeshInstance3D.new()
		_bbox_mesh.name = "BBoxDebug"
		_bbox_box = BoxMesh.new()
		_bbox_mesh.mesh = _bbox_box
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(1.0, 0.85, 0.2, 0.28)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_bbox_mesh.material_override = mat
		add_child(_bbox_mesh)
	_bbox_mesh.visible = true
	_update_bbox_debug()


func _hide_bbox_debug() -> void:
	if _live(_bbox_mesh):
		_bbox_mesh.visible = false


func _update_bbox_debug() -> void:
	if not _bbox_on or _switching:
		return
	if not _live(_bbox_mesh):
		_bbox_mesh = null
		_ensure_bbox_debug()
		return
	var root := _active_node()
	if not _live(root):
		_bbox_mesh.visible = false
		return
	var aabb := _model_aabb(root)
	if aabb.size.length() < 0.0001:
		_bbox_mesh.visible = false
		return
	_bbox_mesh.visible = true
	if _bbox_box == null or _bbox_mesh.mesh != _bbox_box:
		_bbox_box = BoxMesh.new()
		_bbox_mesh.mesh = _bbox_box
	_bbox_box.size = aabb.size
	if _live(_bbox_mesh):
		_bbox_mesh.global_position = aabb.position + aabb.size * 0.5


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
		_overlay.text = "REACTION LAB FAILED | %s" % _fail_reason
		return
	var t := 0.0
	if _mode != "IDLE" and _live(_reaction_player):
		t = _reaction_player.current_animation_position
	elif _live(_idle_player):
		t = _idle_player.current_animation_position
	_overlay.text = (
		"%s REACTION V1\n\n1 APPROVED IDLE\n2 REACTION LOOP\n3 SINGLE REACTION TRIGGER\n4 skeleton %s\n5 bbox %s\n6 reset camera\n\nSTATE %s  t=%.2f"
		% [fighter_id.to_upper(), "ON" if _skel_on else "off", "ON" if _bbox_on else "off", _mode, t]
	)


func _setup_probe() -> void:
	_probe = false
	for arg in OS.get_cmdline_user_args():
		if str(arg) == "--runtime-probe":
			_probe = true
			break
	if not _probe:
		return
	_probe_t = 0.0
	_probe_i = 0
	_probe_steps = [
		{"t": 1.0, "key": KEY_1},
		{"t": 2.0, "key": KEY_3},
		{"t": 5.0, "key": KEY_3},
		{"t": 8.0, "key": KEY_3},
		{"t": 11.0, "key": KEY_4},
		{"t": 12.0, "key": KEY_3},
		{"t": 15.5, "key": KEY_4},
		{"t": 16.5, "key": KEY_5},
		{"t": 17.5, "key": KEY_3},
		{"t": 20.5, "key": KEY_5},
	]
	print("[REACTION_LAB] probe=START fighter=%s" % fighter_id)


func _process_probe(delta: float) -> void:
	if not _probe:
		return
	_probe_t += delta
	while _probe_i < _probe_steps.size() and _probe_t >= float(_probe_steps[_probe_i]["t"]):
		var key := int(_probe_steps[_probe_i]["key"])
		print("[REACTION_LAB] probe=KEY %s t=%.2f" % [key, _probe_t])
		_apply_key(key)
		_probe_i += 1
	if _probe_t >= 60.0:
		print("[REACTION_LAB] probe=DONE fighter=%s" % fighter_id)
		_probe = false
		get_tree().quit()
