extends SceneTree

## Numeric REST / idle frame bone poses + skinned AABB sanity.

const MODELS := {
	"terere": {
		"glb": "res://assets/fighters/processed/terere/terere_game_ready_v4.glb",
		"out": "res://docs/generated/TERERE_GODOT_BONE_POSES.json",
		"height": 2.40,
	},
	"jaguarete": {
		"glb": "res://assets/fighters/processed/jaguarete/jaguarete_game_ready_v4.glb",
		"out": "res://docs/generated/JAGUARETE_GODOT_BONE_POSES.json",
		"height": 3.15,
	},
}

const SAMPLE_BONES = [
	"CC_Base_Hip", "CC_Base_Spine01", "CC_Base_Head",
	"CC_Base_L_Upperarm", "CC_Base_L_Forearm", "CC_Base_R_Upperarm",
	"CC_Base_R_Thigh", "CC_Base_R_Calf",
]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var ok := true
	for fighter_id in MODELS:
		var passed: bool = await _dump(fighter_id, MODELS[fighter_id])
		if not passed:
			ok = false
	print("GODOT_BONE_POSES=%s" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)


func _dump(fighter_id: String, cfg: Dictionary) -> bool:
	var abs_path := ProjectSettings.globalize_path(str(cfg["glb"]))
	if not FileAccess.file_exists(abs_path):
		print("MISSING %s" % cfg["glb"])
		return false
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	if doc.append_from_file(abs_path, state) != OK:
		return false
	var root := doc.generate_scene(state) as Node3D
	if root == null:
		return false
	root.name = fighter_id
	root_node_add(root)
	var skeleton := _find_skeleton(root)
	var player := _find_player(root)
	var report := {
		"fighter": fighter_id,
		"glb": cfg["glb"],
		"bones": skeleton.get_bone_count() if skeleton else 0,
		"clips": player.get_animation_list() if player else PackedStringArray(),
		"target_height": cfg["height"],
		"samples": {},
		"aabb": {},
	}
	if skeleton == null or player == null:
		_write(str(cfg["out"]), report)
		root.queue_free()
		return false
	var idle := _idle_name(player)
	report["idle"] = idle
	var rest_aabb := _mesh_aabb(root)
	skeleton.reset_bone_poses()
	report["samples"]["REST"] = _sample_bones(skeleton)
	report["aabb"]["rest"] = _aabb_dict(rest_aabb)
	if idle != "" and player.has_animation(idle):
		var anim: Animation = player.get_animation(idle)
		report["idle_length"] = anim.length
		report["idle_tracks"] = anim.get_track_count()
		player.play(idle)
		player.seek(0.0, true)
		await process_frame
		report["samples"]["idle_frame_1"] = _sample_bones(skeleton)
		report["aabb"]["idle_frame_1"] = _aabb_dict(_mesh_aabb(root))
		player.seek(anim.length * 0.5, true)
		await process_frame
		report["samples"]["idle_mid"] = _sample_bones(skeleton)
		report["aabb"]["idle_mid"] = _aabb_dict(_mesh_aabb(root))
		player.seek(anim.length, true)
		await process_frame
		report["samples"]["idle_final"] = _sample_bones(skeleton)
		report["aabb"]["idle_final"] = _aabb_dict(_mesh_aabb(root))
	var rest_h: float = maxf(rest_aabb.size.y, 0.001)
	var max_h: float = rest_h
	for key in report["aabb"]:
		max_h = maxf(max_h, float((report["aabb"][key] as Dictionary).get("size_y", rest_h)))
	var height_ratio := max_h / rest_h
	report["idle_height_ratio"] = height_ratio
	report["bbox_sane"] = height_ratio < 3.0
	_write(str(cfg["out"]), report)
	root.queue_free()
	print("%s bones=%d idle=%s height_ratio=%.3f sane=%s" % [fighter_id, skeleton.get_bone_count(), idle, height_ratio, report["bbox_sane"]])
	return bool(report["bbox_sane"]) and skeleton.get_bone_count() == 101 and idle != ""


func root_node_add(node: Node) -> void:
	root.add_child(node)


func _idle_name(player: AnimationPlayer) -> String:
	for name in player.get_animation_list():
		var lower := name.to_lower()
		if lower == "idle" or lower.ends_with("/idle"):
			return name
	return ""


func _sample_bones(skeleton: Skeleton3D) -> Dictionary:
	var out := {}
	for bone_name in SAMPLE_BONES:
		var idx := skeleton.find_bone(bone_name)
		if idx < 0:
			out[bone_name] = {"missing": true}
			continue
		var pose := skeleton.get_bone_pose(idx)
		var rest := skeleton.get_bone_rest(idx)
		out[bone_name] = {
			"pose_origin": [pose.origin.x, pose.origin.y, pose.origin.z],
			"rest_origin": [rest.origin.x, rest.origin.y, rest.origin.z],
		}
	return out


func _mesh_aabb(root: Node) -> AABB:
	var combined := AABB()
	var first := true
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
			var mi := node as MeshInstance3D
			var local: AABB = mi.mesh.get_aabb()
			for i in 8:
				var pt: Vector3 = mi.global_transform * local.get_endpoint(i)
				if first:
					combined = AABB(pt, Vector3.ZERO)
					first = false
				else:
					combined = combined.expand(pt)
		for child in node.get_children():
			stack.append(child)
	return combined


func _aabb_dict(aabb: AABB) -> Dictionary:
	return {
		"size_x": aabb.size.x,
		"size_y": aabb.size.y,
		"size_z": aabb.size.z,
		"volume": aabb.size.x * aabb.size.y * aabb.size.z,
	}


func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for child in node.get_children():
		var found := _find_skeleton(child)
		if found:
			return found
	return null


func _find_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found := _find_player(child)
		if found:
			return found
	return null


func _write(path: String, data: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
		print("Wrote %s" % path)
