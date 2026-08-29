extends Node

## Isolated semantic V2 orientation experiment. Uses the same GLB load path as battle.

const HIP_NAMES := ["CC_Base_Hip", "CC_Base_Hip", "Hip", "mixamorig:Hips"]
const HEAD_NAMES := ["CC_Base_Head", "CC_Base_Head", "Head", "mixamorig:Head"]
const FOOT_NAMES := ["CC_Base_L_Foot", "CC_Base_R_Foot", "CC_Base_L_Foot", "CC_Base_R_Foot"]

const FIGHTERS := [
	{
		"id": "terere",
		"glb": "res://assets/fighters/processed/semantic_solver_v2/terere/terere_idle_semantic_v2.glb",
		"script": "res://fighters/terere/terere_semantic_v2_battle_candidate.gd",
	},
	{
		"id": "jaguarete",
		"glb": "res://assets/fighters/processed/semantic_solver_v2/jaguarete/jaguarete_idle_semantic_v2.glb",
		"script": "res://fighters/jaguarete/jaguarete_semantic_v2_battle_candidate.gd",
	},
]


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	await get_tree().process_frame
	OS.set_environment("SSK_USE_SEMANTIC_V2_CANDIDATE", "1")
	var report := {
		"env_SSK_USE_SEMANTIC_V2_CANDIDATE": true,
		"godot_euler_order": "Node3D.rotation is YXZ (yaw applied before pitch on the same node)",
		"fighters": {},
	}
	for cfg in FIGHTERS:
		report["fighters"][cfg["id"]] = await _audit_one(cfg)
	var chosen: Dictionary = _choose_correction(report)
	report["chosen_import_correction"] = chosen
	_write("res://docs/generated/SEMANTIC_V2_RUNTIME_ORIENTATION_AUDIT.json", report)
	print("SEMANTIC_V2_ORIENTATION_AUDIT_WRITTEN chosen=%s" % JSON.stringify(chosen))
	get_tree().quit(0)


func _audit_one(cfg: Dictionary) -> Dictionary:
	var host := Node3D.new()
	host.name = "OrientHost_%s" % cfg["id"]
	add_child(host)
	var native := await _measure_native_glb(host, str(cfg["glb"]))
	var matrix := _sweep_corrections(native)
	var visual := await _spawn_candidate_visual(host, str(cfg["script"]))
	var chain := {
		"spawn": _dump_chain(visual),
		"idle_frame": {},
		"facing_right": {},
		"facing_left": {},
	}
	await get_tree().process_frame
	chain["idle_frame"] = _dump_chain(visual)
	if visual and visual.has_method("set_facing"):
		visual.call("set_facing", 1.0)
		await get_tree().process_frame
		chain["facing_right"] = _dump_chain(visual)
		visual.call("set_facing", -1.0)
		await get_tree().process_frame
		chain["facing_left"] = _dump_chain(visual)
	var anim := _inspect_animation(visual)
	var first_break := _first_broken_up_node(chain["idle_frame"])
	if visual:
		visual.queue_free()
	await get_tree().process_frame
	host.queue_free()
	return {
		"glb": cfg["glb"],
		"load_path": native.get("load_path", ""),
		"native_unparented": native,
		"import_correction_sweep": matrix,
		"runtime_chain": chain,
		"animation_root_tracks": anim,
		"first_node_where_up_leaves_plus_y": first_break,
	}


func _measure_native_glb(host: Node3D, glb_path: String) -> Dictionary:
	var root := _load_glb_like_battle(glb_path)
	if root == null:
		return {"ok": false, "glb": glb_path}
	root.name = "NativeGLB"
	host.add_child(root)
	await get_tree().process_frame
	var skel := _find_skel(root)
	var armature := _find_named(root, "Armature")
	var mesh := _find_mesh(root)
	var hip_head := _hip_head(skel)
	var out := {
		"ok": skel != null,
		"load_path": "GLTFDocument.append_from_file (no .import PackedScene)",
		"glb_root": _xform(root),
		"armature": _xform(armature),
		"skeleton": _xform(skel),
		"mesh": _xform(mesh),
		"hip_head": hip_head,
		"native_up_axis": str(hip_head.get("dominant", "unknown")),
		"animation_list": _anim_names(root),
	}
	root.queue_free()
	await get_tree().process_frame
	return out


func _sweep_corrections(native: Dictionary) -> Array:
	var hip_head: Dictionary = native.get("hip_head", {})
	if not bool(hip_head.get("ok", false)):
		return []
	var delta := Vector3(
		float((hip_head["delta"] as Array)[0]),
		float((hip_head["delta"] as Array)[1]),
		float((hip_head["delta"] as Array)[2])
	)
	var trials: Array = [
		{"id": "none", "euler_deg": Vector3.ZERO, "compose": "identity"},
		{"id": "X+90", "euler_deg": Vector3(90, 0, 0), "compose": "Rx"},
		{"id": "X-90", "euler_deg": Vector3(-90, 0, 0), "compose": "Rx"},
		{"id": "Y+90", "euler_deg": Vector3(0, 90, 0), "compose": "Ry"},
		{"id": "Y-90", "euler_deg": Vector3(0, -90, 0), "compose": "Ry"},
		{"id": "Z+90", "euler_deg": Vector3(0, 0, 90), "compose": "Rz"},
		{"id": "Z-90", "euler_deg": Vector3(0, 0, -90), "compose": "Rz"},
		{"id": "current_modelroot_euler_YXZ_pitch-90_yaw-90", "euler_deg": Vector3(-90, -90, 0), "compose": "Node3D.rotation YXZ (yaw then pitch)"},
		{"id": "Rx-90_then_Ry-90", "euler_deg": Vector3(-90, -90, 0), "compose": "Ry * Rx (pitch first, then yaw)"},
		{"id": "Ry-90_then_Rx-90", "euler_deg": Vector3(-90, -90, 0), "compose": "Rx * Ry (yaw first, then pitch)"},
	]
	var results: Array = []
	for trial in trials:
		var basis := _basis_for_trial(trial)
		var mapped: Vector3 = basis * delta
		var score := _score_up(mapped)
		var row: Dictionary = trial.duplicate(true)
		row["euler_deg"] = [trial["euler_deg"].x, trial["euler_deg"].y, trial["euler_deg"].z]
		row["mapped_hip_head"] = [mapped.x, mapped.y, mapped.z]
		row["dominant"] = _dominant(mapped)
		row["head_above_hips"] = mapped.y > 0.0
		row["mostly_plus_y"] = score["mostly_plus_y"]
		row["horizontal_forward_ok"] = absf(mapped.y) >= maxf(absf(mapped.x), absf(mapped.z)) * 0.85
		row["score"] = score["score"]
		row["pass"] = bool(score["pass"])
		results.append(row)
	return results


func _basis_for_trial(trial: Dictionary) -> Basis:
	var e: Vector3 = trial["euler_deg"]
	var compose := str(trial["compose"])
	var rx := Basis.from_euler(Vector3(deg_to_rad(e.x), 0.0, 0.0))
	var ry := Basis.from_euler(Vector3(0.0, deg_to_rad(e.y), 0.0))
	var rz := Basis.from_euler(Vector3(0.0, 0.0, deg_to_rad(e.z)))
	if compose.begins_with("Ry * Rx"):
		return ry * rx
	if compose.begins_with("Rx * Ry"):
		return rx * ry
	if compose.begins_with("Node3D.rotation"):
		return Basis.from_euler(Vector3(deg_to_rad(e.x), deg_to_rad(e.y), deg_to_rad(e.z)))
	if compose == "identity":
		return Basis.IDENTITY
	return rz * ry * rx


func _score_up(mapped: Vector3) -> Dictionary:
	var length := maxf(mapped.length(), 0.0001)
	var y_ratio := mapped.y / length
	var pass_flag := y_ratio >= 0.85 and mapped.y > 0.0
	return {
		"mostly_plus_y": y_ratio >= 0.85,
		"y_ratio": y_ratio,
		"score": y_ratio,
		"pass": pass_flag,
	}


func _spawn_candidate_visual(host: Node3D, script_path: String) -> Node:
	var script: Script = load(script_path) as Script
	if script == null or not script.can_instantiate():
		push_error("cannot instantiate %s" % script_path)
		return null
	var visual: Node = script.new()
	visual.name = script_path.get_file().get_basename()
	host.add_child(visual)
	await get_tree().process_frame
	await get_tree().process_frame
	if visual.has_method("play_animation"):
		visual.call("play_animation", "idle")
	await get_tree().process_frame
	return visual


func _dump_chain(visual: Node) -> Dictionary:
	if visual == null:
		return {"ok": false}
	var skel := _find_skel(visual)
	var nodes: Array = []
	_collect_chain_nodes(visual, nodes)
	var hip_head := _hip_head(skel)
	return {
		"ok": true,
		"nodes": nodes,
		"hip_head_world": hip_head,
		"model_root_rotation_deg": _rot_deg(_named(visual, "ModelRoot")),
		"facing_root_rotation_deg": _rot_deg(_named(visual, "FacingRoot")),
		"motion_root_rotation_deg": _rot_deg(_named(visual, "VisualMotionRoot")),
		"presentation_root_rotation_deg": _rot_deg(_named(visual, "PresentationScaleRoot")),
		"visual_self_rotation_deg": _rot_deg(visual as Node3D),
	}


func _collect_chain_nodes(visual: Node, out: Array) -> void:
	var wanted := {
		"VisualRoot": true,
		"VisualMotionRoot": true,
		"PresentationScaleRoot": true,
		"FacingRoot": true,
		"ImportCorrectionRoot": true,
		"ModelRoot": true,
		"ImportedModel": true,
		"Armature": true,
		"Skeleton3D": true,
	}
	out.append(_node_dump(visual as Node3D, "FighterVisual"))
	var walk: Array[Node] = [visual]
	while not walk.is_empty():
		var node: Node = walk.pop_back()
		for child in node.get_children():
			walk.append(child)
			if child is Skeleton3D or child is MeshInstance3D or wanted.has(String(child.name)):
				out.append(_node_dump(child as Node3D, String(child.name)))


func _first_broken_up_node(chain: Dictionary) -> Dictionary:
	var hip_head: Dictionary = chain.get("hip_head_world", {})
	var dominant := str(hip_head.get("dominant", ""))
	if dominant == "Y" and float((hip_head.get("delta", [0, 1, 0]) as Array)[1]) > 0.0:
		return {"status": "world_hip_head_already_plus_y", "dominant": dominant}
	var culprit := ""
	for node_row in chain.get("nodes", []):
		var gdeg: Array = node_row.get("global_rotation_deg", [0, 0, 0])
		var gx := absf(float(gdeg[0]))
		var gz := absf(float(gdeg[2]))
		if gx > 15.0 or gz > 15.0:
			culprit = str(node_row.get("name", ""))
			return {
				"status": "first_non_yaw_global_rotation",
				"node": culprit,
				"global_rotation_deg": gdeg,
				"local_rotation_deg": node_row.get("local_rotation_deg", []),
				"world_hip_head_dominant": dominant,
			}
	return {"status": "no_pitch_roll_on_nodes_hip_head_still_not_y", "dominant": dominant, "hip_head": hip_head}


func _inspect_animation(visual: Node) -> Dictionary:
	var player := _find_player(visual)
	if player == null:
		return {"ok": false}
	var idle := ""
	for anim_name in player.get_animation_list():
		if String(anim_name).to_lower().contains("idle"):
			idle = anim_name
			break
	if idle.is_empty() or not player.has_animation(idle):
		return {"ok": false, "clips": player.get_animation_list()}
	var anim: Animation = player.get_animation(idle)
	var tracks: Array = []
	var whole_body_rot := false
	for i in anim.get_track_count():
		var path := String(anim.track_get_path(i))
		var type := anim.track_get_type(i)
		var interesting := (
			path.to_lower().contains("armature")
			or path.to_lower().contains("hip")
			or path.ends_with(":position")
			or path.ends_with(":rotation")
			or path.ends_with(":scale")
			or not path.contains(":")
		)
		if not interesting and type != Animation.TYPE_ROTATION_3D and type != Animation.TYPE_POSITION_3D:
			continue
		if not path.contains(":") and type == Animation.TYPE_ROTATION_3D:
			whole_body_rot = true
		if path.to_lower().contains("armature") and (type == Animation.TYPE_ROTATION_3D or type == Animation.TYPE_SCALE_3D or type == Animation.TYPE_POSITION_3D):
			whole_body_rot = true
		var lower := path.to_lower()
		if lower.contains("cc_base_hip") or lower.contains("cc_base_hip") or lower.ends_with("/armature") or lower.contains("armature:"):
			tracks.append({
				"path": path,
				"type": type,
				"keys": anim.track_get_key_count(i),
			})
		elif not path.contains(":"):
			tracks.append({"path": path, "type": type, "keys": anim.track_get_key_count(i), "note": "node_transform_track"})
	return {
		"ok": true,
		"idle_clip": idle,
		"track_count": anim.get_track_count(),
		"root_or_armature_or_hip_tracks": tracks,
		"whole_body_rotation_track": whole_body_rot,
	}


func _choose_correction(report: Dictionary) -> Dictionary:
	var fighters: Dictionary = report.get("fighters", {})
	var votes := {}
	for fighter_id in fighters.keys():
		var sweep: Array = (fighters[fighter_id] as Dictionary).get("import_correction_sweep", [])
		var best_id := ""
		var best_score := -999.0
		for row in sweep:
			if str(row.get("id", "")).begins_with("current_"):
				continue
			if bool(row.get("pass", false)) and float(row.get("score", 0.0)) > best_score:
				best_score = float(row.get("score", 0.0))
				best_id = str(row.get("id", ""))
		if not best_id.is_empty():
			votes[best_id] = int(votes.get(best_id, 0)) + 1
	var winner := "X-90"
	var win_n := 0
	for key in votes.keys():
		if int(votes[key]) > win_n:
			win_n = int(votes[key])
			winner = str(key)
	return {"id": winner, "votes": votes, "note": "single ImportCorrectionRoot basis; ModelRoot must stay identity for semantic V2"}


func _load_glb_like_battle(path: String) -> Node3D:
	if ResourceLoader.exists(path, "PackedScene"):
		var packed: PackedScene = load(path)
		if packed:
			var inst := packed.instantiate() as Node3D
			if inst:
				return inst
	var abs_path := ProjectSettings.globalize_path(path)
	if not FileAccess.file_exists(abs_path):
		return null
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	if doc.append_from_file(abs_path, state) != OK:
		return null
	return doc.generate_scene(state) as Node3D


func _hip_head(skel: Skeleton3D) -> Dictionary:
	if skel == null:
		return {"ok": false}
	var hip_i := _find_bone(skel, HIP_NAMES)
	var head_i := _find_bone(skel, HEAD_NAMES)
	if hip_i < 0 or head_i < 0:
		return {"ok": false, "hip_index": hip_i, "head_index": head_i, "bones": skel.get_bone_count()}
	var hip: Vector3 = skel.to_global(skel.get_bone_global_pose(hip_i).origin)
	var head: Vector3 = skel.to_global(skel.get_bone_global_pose(head_i).origin)
	var delta := head - hip
	return {
		"ok": true,
		"hip": [hip.x, hip.y, hip.z],
		"head": [head.x, head.y, head.z],
		"delta": [delta.x, delta.y, delta.z],
		"dominant": _dominant(delta),
		"head_above_hips": head.y > hip.y,
	}


func _find_bone(skel: Skeleton3D, names: PackedStringArray) -> int:
	for bone_name in names:
		var idx := skel.find_bone(bone_name)
		if idx >= 0:
			return idx
	return -1


func _dominant(v: Vector3) -> String:
	var ax := absf(v.x)
	var ay := absf(v.y)
	var az := absf(v.z)
	if ay >= ax and ay >= az:
		return "Y"
	if ax >= ay and ax >= az:
		return "X"
	return "Z"


func _node_dump(n3: Node3D, label: String) -> Dictionary:
	if n3 == null:
		return {"name": label, "missing": true}
	var q := n3.quaternion
	var gq := n3.global_transform.basis.get_rotation_quaternion()
	var gb := n3.global_transform.basis
	return {
		"name": n3.name,
		"label": label,
		"class": n3.get_class(),
		"local_position": [n3.position.x, n3.position.y, n3.position.z],
		"local_rotation_deg": [rad_to_deg(n3.rotation.x), rad_to_deg(n3.rotation.y), rad_to_deg(n3.rotation.z)],
		"local_quaternion": [q.x, q.y, q.z, q.w],
		"scale": [n3.scale.x, n3.scale.y, n3.scale.z],
		"global_rotation_deg": [rad_to_deg(n3.global_rotation.x), rad_to_deg(n3.global_rotation.y), rad_to_deg(n3.global_rotation.z)],
		"global_quaternion": [gq.x, gq.y, gq.z, gq.w],
		"global_basis": {
			"x": [gb.x.x, gb.x.y, gb.x.z],
			"y": [gb.y.x, gb.y.y, gb.y.z],
			"z": [gb.z.x, gb.z.y, gb.z.z],
		},
	}


func _xform(n3: Node) -> Dictionary:
	if n3 == null or not (n3 is Node3D):
		return {"missing": true}
	return _node_dump(n3 as Node3D, n3.name)


func _rot_deg(n3: Node3D) -> Array:
	if n3 == null:
		return [0.0, 0.0, 0.0]
	return [rad_to_deg(n3.rotation.x), rad_to_deg(n3.rotation.y), rad_to_deg(n3.rotation.z)]


func _named(root: Node, node_name: String) -> Node3D:
	if root == null:
		return null
	if root.name == node_name and root is Node3D:
		return root as Node3D
	var found := root.find_child(node_name, true, false)
	return found as Node3D


func _find_skel(node: Node) -> Skeleton3D:
	if node == null:
		return null
	if node is Skeleton3D:
		return node
	for child in node.get_children():
		var found := _find_skel(child)
		if found:
			return found
	return null


func _find_player(node: Node) -> AnimationPlayer:
	if node == null:
		return null
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found := _find_player(child)
		if found:
			return found
	return null


func _find_mesh(node: Node) -> MeshInstance3D:
	if node == null:
		return null
	if node is MeshInstance3D:
		return node
	for child in node.get_children():
		var found := _find_mesh(child)
		if found:
			return found
	return null


func _find_named(node: Node, node_name: String) -> Node3D:
	if node == null:
		return null
	if node.name == node_name and node is Node3D:
		return node as Node3D
	return node.find_child(node_name, true, false) as Node3D


func _anim_names(root: Node) -> PackedStringArray:
	var player := _find_player(root)
	if player == null:
		return PackedStringArray()
	return player.get_animation_list()


func _write(path: String, data: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
		print("Wrote %s" % path)
