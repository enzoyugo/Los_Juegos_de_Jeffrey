extends Node3D

## Isolated Clean Rig V5 inspection lab. REST only.
## Does not inherit production / semantic / battle labs.
## 1 mesh  2 skeleton  3 bbox  4 reset camera
## RMB orbit  wheel zoom

const PIPELINE := "V5"

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
var _bbox_node: MeshInstance3D
var _skeleton_debug := false
var _bbox_debug := false
var _load_ok := false
var _fail_reason := ""
var _orbit_yaw := 0.0
var _orbit_pitch := -0.25
var _orbit_dist := 6.0
var _orbit_target := Vector3(0.0, 1.0, 0.0)
var _orbiting := false


func _ready() -> void:
	_camera = get_node_or_null("Camera3D") as Camera3D
	_model_root = get_node_or_null("ModelRoot") as Node3D
	_orbit_dist = camera_distance
	_orbit_target = Vector3(0.0, max(camera_height * 0.55, 0.8), 0.0)
	_ensure_hud()
	_bind_instanced_model()
	if _load_ok:
		_freeze_animation()
		_reset_rest_pose()
		_reset_camera()
	_print_dump()
	_refresh_status()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match (event as InputEventKey).keycode:
			KEY_1:
				_toggle_meshes()
			KEY_2:
				_skeleton_debug = not _skeleton_debug
				_rebuild_skeleton_debug()
			KEY_3:
				_bbox_debug = not _bbox_debug
				_rebuild_bbox()
			KEY_4:
				_reset_camera()
		_refresh_status()
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			_orbiting = mb.pressed
			get_viewport().set_input_as_handled()
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_orbit_dist = max(1.2, _orbit_dist * 0.9)
			_apply_orbit()
			get_viewport().set_input_as_handled()
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_orbit_dist = min(18.0, _orbit_dist * 1.1)
			_apply_orbit()
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _orbiting:
		var mm := event as InputEventMouseMotion
		_orbit_yaw -= mm.relative.x * 0.007
		_orbit_pitch = clampf(_orbit_pitch - mm.relative.y * 0.007, -1.2, 1.2)
		_apply_orbit()
		get_viewport().set_input_as_handled()


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
		_fail("refused non-v5 asset: %s" % loaded_path)
		return
	if loaded_path.find("clean_rig_v5") == -1:
		_fail("refused non-clean-v5 asset: %s" % loaded_path)
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
	push_error("[CLEAN_RIG_V5_LAB] FAIL fighter=%s %s" % [fighter_id, reason])


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
	if _bbox_debug:
		_rebuild_bbox()


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
	_orbit_yaw = 0.0
	_orbit_pitch = -0.25
	_orbit_dist = camera_distance
	_orbit_target = Vector3(0.0, max(camera_height * 0.55, 0.8), 0.0)
	_apply_orbit()


func _apply_orbit() -> void:
	if _camera == null:
		return
	var cp := cos(_orbit_pitch)
	var offset := Vector3(
		sin(_orbit_yaw) * cp * _orbit_dist,
		sin(_orbit_pitch) * _orbit_dist + _orbit_target.y * 0.0,
		cos(_orbit_yaw) * cp * _orbit_dist
	)
	_camera.current = true
	_camera.position = _orbit_target + offset
	_camera.look_at(_orbit_target)


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


func _rebuild_bbox() -> void:
	if _bbox_node != null:
		_bbox_node.queue_free()
		_bbox_node = null
	if not _bbox_debug or _model == null or not _load_ok:
		return
	var aabb := AABB()
	var first := true
	for mi in _collect_meshes(_model):
		if mi.mesh == null:
			continue
		var local := mi.mesh.get_aabb()
		var world := mi.global_transform * local
		if first:
			aabb = world
			first = false
		else:
			aabb = aabb.merge(world)
	if first:
		return
	_bbox_node = MeshInstance3D.new()
	_bbox_node.name = "BBoxDebug"
	var box := BoxMesh.new()
	box.size = aabb.size
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1.0, 0.85, 0.2, 0.18)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_bbox_node.mesh = box
	_bbox_node.material_override = mat
	_bbox_node.position = aabb.position + aabb.size * 0.5
	_model_root.add_child(_bbox_node)


func _ensure_hud() -> void:
	var overlay := get_node_or_null("Overlay") as CanvasLayer
	if overlay == null:
		overlay = CanvasLayer.new()
		overlay.name = "Overlay"
		overlay.layer = 80
		add_child(overlay)
	_status = overlay.get_node_or_null("Status") as Label
	if _status == null:
		_status = Label.new()
		_status.name = "Status"
		_status.position = Vector2(20, 20)
		_status.add_theme_font_size_override("font_size", 18)
		overlay.add_child(_status)


func _print_dump() -> void:
	var dump := collect_dump()
	print("[CLEAN_RIG_V5_LAB]")
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
		"hip": _bone_pos(["pelvis", "CC_Base_Hip", "hip"]),
		"head": _bone_pos(["head", "CC_Base_Head"]),
		"l_hand": _bone_pos(["hand_l", "CC_Base_L_Hand"]),
		"r_hand": _bone_pos(["hand_r", "CC_Base_R_Hand"]),
		"l_foot": _bone_pos(["foot_l", "CC_Base_L_Foot"]),
		"r_foot": _bone_pos(["foot_r", "CC_Base_R_Foot"]),
		"l_upperarm": _bone_pos(["upperarm_l", "CC_Base_L_Upperarm"]),
		"r_upperarm": _bone_pos(["upperarm_r", "CC_Base_R_Upperarm"]),
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
		_status.text = "V5 LAB FAILED | fighter=%s | %s | %s" % [fighter_id, asset_glb, _fail_reason]
		return
	var bones := _skeleton.get_bone_count() if _skeleton else 0
	var meshes := _collect_meshes(_model) if _model else []
	_status.text = (
		"fighter=%s | pipeline=V5 | bone_count=%d | mesh_count=%d | animation_count=0 | GLB=%s | fallback=false | [1] mesh [2] skel %s [3] bbox %s [4] camera"
		% [
			fighter_id,
			bones,
			meshes.size(),
			asset_glb,
			"ON" if _skeleton_debug else "off",
			"ON" if _bbox_debug else "off",
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
