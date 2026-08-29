extends Node3D

## Isolated Clean Rig V1 inspection lab.
## No FighterCatalog, no V4, no FBX, no animation proxy, no fallback.
## 1 rest  2 skeleton debug  3 mesh visibility  4 reset camera

const PIPELINE := "CLEAN_RIG_V1"

@export var fighter_id: String = ""
@export var pipeline_id: String = PIPELINE
@export var target_height: float = 0.0
@export var asset_glb: String = ""
@export var camera_height: float = 1.8
@export var camera_distance: float = 6.0

var _model_root: Node3D
var _model: Node3D
var _camera: Camera3D
var _status: Label
var _skeleton: Skeleton3D
var _debug_root: Node3D
var _skeleton_debug := false
var _load_ok := false
var _fail_reason := ""


func _ready() -> void:
	_camera = get_node_or_null("Camera3D") as Camera3D
	_model_root = get_node_or_null("ModelRoot") as Node3D
	_ensure_hud()
	_bind_instanced_model()
	if _load_ok:
		_freeze_animation()
		_reset_rest_pose()
		_reset_camera()
	_print_dump()
	_refresh_status()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match (event as InputEventKey).keycode:
		KEY_1:
			_reset_rest_pose()
		KEY_2:
			_skeleton_debug = not _skeleton_debug
			_rebuild_skeleton_debug()
		KEY_3:
			_toggle_meshes()
		KEY_4:
			_reset_camera()
	_refresh_status()


func _bind_instanced_model() -> void:
	if asset_glb.is_empty():
		_fail("asset_glb is empty")
		return
	if pipeline_id != PIPELINE:
		_fail("pipeline_id must be %s, got %s" % [PIPELINE, pipeline_id])
		return
	if not ResourceLoader.exists(asset_glb):
		_fail("expected GLB missing: %s" % asset_glb)
		return
	if _model_root == null:
		_fail("ModelRoot node missing")
		return
	var inst: Node3D = null
	for child in _model_root.get_children():
		if child is Node3D:
			inst = child as Node3D
			break
	if inst == null:
		_fail("no GLB instance under ModelRoot")
		return
	var loaded_path := inst.scene_file_path
	if loaded_path.is_empty():
		loaded_path = asset_glb
	if loaded_path != asset_glb:
		_fail("instanced path %s != expected %s" % [loaded_path, asset_glb])
		return
	if loaded_path.find("game_ready_v") != -1 or loaded_path.find("source_rigged") != -1:
		_fail("refused non-clean asset: %s" % loaded_path)
		return
	_model = inst
	_skeleton = _find_skeleton(inst)
	if _skeleton == null:
		_fail("Skeleton3D missing in %s" % asset_glb)
		return
	_load_ok = true


func _fail(reason: String) -> void:
	_load_ok = false
	_fail_reason = reason
	push_error("[CLEAN_RIG_LAB] FAIL fighter=%s %s" % [fighter_id, reason])


func _freeze_animation() -> void:
	var players: Array[AnimationPlayer] = []
	_collect_anim_players(_model, players)
	for player in players:
		player.stop()
		player.active = false
		player.autoplay = ""


func _reset_rest_pose() -> void:
	if _skeleton == null:
		return
	_skeleton.reset_bone_poses()
	if _skeleton_debug:
		_rebuild_skeleton_debug()


func _toggle_meshes() -> void:
	if _model == null:
		return
	var meshes := _collect_meshes(_model)
	var any_visible := false
	for mi in meshes:
		if mi.visible:
			any_visible = true
			break
	for mi in meshes:
		mi.visible = not any_visible


func _reset_camera() -> void:
	if _camera == null:
		return
	_camera.current = true
	_camera.position = Vector3(0.0, camera_height, camera_distance)
	_camera.look_at(Vector3(0.0, max(camera_height * 0.55, 0.8), 0.0))


func _rebuild_skeleton_debug() -> void:
	if _debug_root != null:
		_debug_root.queue_free()
		_debug_root = null
	if not _skeleton_debug or _skeleton == null or not _load_ok:
		return
	_debug_root = Node3D.new()
	_debug_root.name = "SkeletonDebug"
	_model_root.add_child(_debug_root)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.15, 1.0, 0.4)
	for i in _skeleton.get_bone_count():
		var marker := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.018
		sphere.height = 0.036
		marker.mesh = sphere
		marker.material_override = mat
		marker.position = _skeleton.to_global(_skeleton.get_bone_global_pose(i).origin)
		_debug_root.add_child(marker)


func _ensure_hud() -> void:
	_status = Label.new()
	_status.position = Vector2(20, 20)
	_status.add_theme_font_size_override("font_size", 18)
	var layer := CanvasLayer.new()
	layer.layer = 80
	layer.add_child(_status)
	add_child(layer)


func _print_dump() -> void:
	var dump := collect_dump()
	print("[CLEAN_RIG_LAB]")
	for key in dump.keys():
		print("%s=%s" % [key, dump[key]])


func collect_dump() -> Dictionary:
	var meshes := _collect_meshes(_model) if _model else []
	var mats: Array[String] = []
	for mi in meshes:
		if mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var mat := mi.get_active_material(s)
			if mat:
				mats.append(str(mat.resource_path) if mat.resource_path else mat.resource_name)
	var players: Array[AnimationPlayer] = []
	if _model:
		_collect_anim_players(_model, players)
	var anim_count := 0
	for player in players:
		anim_count += player.get_animation_list().size()
	var bones := {
		"hip": _bone_pos(["CC_Base_Hip", "CC_Base_Hip"]),
		"head": _bone_pos(["CC_Base_Head", "CC_Base_Head"]),
		"l_hand": _bone_pos(["CC_Base_L_Hand", "CC_Base_L_Hand"]),
		"r_hand": _bone_pos(["CC_Base_R_Hand", "CC_Base_R_Hand"]),
		"l_foot": _bone_pos(["CC_Base_L_Foot", "CC_Base_L_Foot"]),
		"r_foot": _bone_pos(["CC_Base_R_Foot", "CC_Base_R_Foot"]),
	}
	return {
		"fighter": fighter_id,
		"pipeline": pipeline_id,
		"target_height": target_height,
		"asset": asset_glb,
		"loaded_path": _model.scene_file_path if _model else "",
		"load_ok": _load_ok,
		"fallback": false,
		"fail_reason": _fail_reason,
		"skeleton_count": 1 if _skeleton else 0,
		"bone_count": _skeleton.get_bone_count() if _skeleton else 0,
		"mesh_count": meshes.size(),
		"animation_count": anim_count,
		"materials": mats,
		"bones": bones,
	}


func _refresh_status() -> void:
	if _status == null:
		return
	if not _load_ok:
		_status.text = "CLEAN RIG LAB FAILED | fighter=%s | %s | %s" % [fighter_id, asset_glb, _fail_reason]
		return
	var bones := _skeleton.get_bone_count() if _skeleton else 0
	_status.text = (
		"CLEAN RIG V1 | fighter=%s | pipeline=%s | height=%.2f | asset=%s | bones=%d | fallback=false | [1] rest [2] skel %s [3] mesh [4] camera"
		% [
			fighter_id,
			pipeline_id,
			target_height,
			asset_glb,
			bones,
			"ON" if _skeleton_debug else "off",
		]
	)


func _bone_pos(names: Array) -> Dictionary:
	if _skeleton == null:
		return {"found": false}
	for name in names:
		var idx := _skeleton.find_bone(str(name))
		if idx >= 0:
			var p: Vector3 = _skeleton.to_global(_skeleton.get_bone_global_pose(idx).origin)
			return {"found": true, "name": str(name), "x": p.x, "y": p.y, "z": p.z}
	return {"found": false}


func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node as Skeleton3D
	for child in node.get_children():
		var found := _find_skeleton(child)
		if found:
			return found
	return null


func _collect_meshes(node: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if node == null:
		return out
	var stack: Array[Node] = [node]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is MeshInstance3D:
			out.append(n as MeshInstance3D)
		for child in n.get_children():
			stack.append(child)
	return out


func _collect_anim_players(node: Node, out: Array[AnimationPlayer]) -> void:
	if node is AnimationPlayer:
		out.append(node as AnimationPlayer)
	for child in node.get_children():
		_collect_anim_players(child, out)
