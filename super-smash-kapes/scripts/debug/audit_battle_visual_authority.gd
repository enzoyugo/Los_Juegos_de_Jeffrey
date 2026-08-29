extends Node

## Runtime battle visual authority. Run as a packed scene so class_name types load.

const POSE_BONES := [
	"CC_Base_L_Clavicle", "CC_Base_R_Clavicle",
	"CC_Base_L_Upperarm", "CC_Base_R_Upperarm",
	"CC_Base_L_Forearm", "CC_Base_R_Forearm",
	"CC_Base_L_Hand", "CC_Base_R_Hand",
	"CC_Base_Spine01", "CC_Base_Head",
	"CC_Base_L_Thigh", "CC_Base_R_Thigh",
	"CC_Base_L_Calf", "CC_Base_R_Calf",
	"CC_Base_Hip",
]

const CATALOG := preload("res://scripts/fighters/fighter_catalog.gd")

const FIGHTERS := [
	{
		"id": "terere",
		"production_script": "res://fighters/terere/terere_actorcore_visual.gd",
		"candidate_script": "res://fighters/terere/terere_semantic_v2_battle_candidate.gd",
		"production_glb": "res://assets/fighters/processed/terere/terere_game_ready_v4.glb",
		"candidate_glb": "res://assets/fighters/processed/semantic_solver_v2/terere/terere_idle_semantic_v2.glb",
		"stack_out": "res://docs/generated/TERERE_BATTLE_TRANSFORM_STACK.json",
		"parity_out": "res://docs/generated/TERERE_POSE_PARITY.json",
		"target_height": 2.40,
	},
	{
		"id": "jaguarete",
		"production_script": "res://fighters/jaguarete/jaguarete_actorcore_visual.gd",
		"candidate_script": "res://fighters/jaguarete/jaguarete_semantic_v2_battle_candidate.gd",
		"production_glb": "res://assets/fighters/processed/jaguarete/jaguarete_game_ready_v4.glb",
		"candidate_glb": "res://assets/fighters/processed/semantic_solver_v2/jaguarete/jaguarete_idle_semantic_v2.glb",
		"stack_out": "res://docs/generated/JAGUARETE_BATTLE_TRANSFORM_STACK.json",
		"parity_out": "res://docs/generated/JAGUARETE_POSE_PARITY.json",
		"target_height": 3.15,
	},
]


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	await get_tree().process_frame
	var env_on := OS.get_environment("SSK_USE_SEMANTIC_V2_CANDIDATE") == "1"
	var authority := {
		"env_SSK_USE_SEMANTIC_V2_CANDIDATE": env_on,
		"catalog_default_pipeline": "ACTORCORE_V4",
		"catalog_swapped": false,
		"spawn_path": "Fighter._setup_visual -> FighterDefinition.create_visual -> visual_script.new -> ActorCoreFighterVisual._ready",
		"audit_host": "packed_scene",
	}
	var host := Node3D.new()
	host.name = "AuditHost"
	add_child(host)
	for cfg in FIGHTERS:
		authority[cfg["id"]] = await _audit_fighter(host, cfg, env_on)
	_write("res://docs/generated/BATTLE_FIGHTER_VISUAL_AUTHORITY.json", authority)
	print("BATTLE_VISUAL_AUTHORITY_WRITTEN env_candidate=%s" % env_on)
	get_tree().quit(0)


func _audit_fighter(host: Node3D, cfg: Dictionary, env_on: bool) -> Dictionary:
	var production := await _spawn_via_catalog(host, str(cfg["id"]), false)
	var candidate := await _spawn_via_catalog(host, str(cfg["id"]), true)
	if candidate == null:
		candidate = await _spawn_script(host, str(cfg["candidate_script"]))
	var prod_row := _describe_visual(production, "ACTORCORE_V4", str(cfg["production_glb"]))
	var cand_row := _describe_visual(candidate, "ACTORCORE_SEMANTIC_V2_CANDIDATE", str(cfg["candidate_glb"]))
	var stacks := {
		"production_spawn": _full_stack(production),
		"candidate_spawn": _full_stack(candidate),
		"candidate_facing_right": {},
		"candidate_facing_left": {},
		"candidate_after_idle_air_idle": {},
	}
	if candidate != null:
		_call_facing(candidate, 1.0)
		await get_tree().process_frame
		stacks["candidate_facing_right"] = _full_stack(candidate)
		stacks["candidate_aabb_right"] = _aabb(candidate)
		stacks["candidate_upright_right"] = _upright_from_skeleton(candidate)
		_call_facing(candidate, -1.0)
		await get_tree().process_frame
		stacks["candidate_facing_left"] = _full_stack(candidate)
		stacks["candidate_aabb_left"] = _aabb(candidate)
		stacks["candidate_upright_left"] = _upright_from_skeleton(candidate)
		if candidate.has_method("_on_state_changed"):
			candidate.call("_on_state_changed", "IDLE", "AIR")
			await get_tree().process_frame
			candidate.call("_on_state_changed", "AIR", "IDLE")
			await get_tree().process_frame
		if candidate.has_method("snap_motion_roots_neutral"):
			candidate.call("snap_motion_roots_neutral")
		stacks["candidate_after_idle_air_idle"] = _full_stack(candidate)
	_write(str(cfg["stack_out"]), stacks)
	var lab := await _sample_glb_direct(str(cfg["candidate_glb"]))
	var blender := _blender_pose_slice(str(cfg["id"]))
	var standing_sample := _pose_sample(candidate, "canonical_standing")
	var parity := {
		"fighter": cfg["id"],
		"target_visual_height": cfg["target_height"],
		"production_glb": cfg["production_glb"],
		"candidate_glb": cfg["candidate_glb"],
		"blender": blender,
		"godot_lab_direct_glb": lab,
		"production_idle": _pose_sample(production, "idle"),
		"candidate_rest": _pose_sample(candidate, "rest"),
		"candidate_standing": standing_sample,
		"candidate_idle": _pose_sample(candidate, "idle"),
		"production_aabb": _aabb(production),
		"candidate_aabb": _aabb(candidate),
		"production_upright": _upright_from_skeleton(production),
		"candidate_upright": _upright_from_skeleton(candidate),
		"upright_hint_production": _upright_hint(_aabb(production)),
		"upright_hint_candidate": _upright_hint(_aabb(candidate)),
		"bone_local_delta_standing_vs_blender": _bone_delta(
			_blender_standing_quats(str(cfg["id"])),
			standing_sample
		),
	}
	_write(str(cfg["parity_out"]), parity)
	if production:
		production.queue_free()
	if candidate:
		candidate.queue_free()
	await get_tree().process_frame
	var catalog_def = CATALOG.get_by_id(str(cfg["id"]))
	return {
		"pipeline": "ACTORCORE_SEMANTIC_V2_CANDIDATE" if env_on else "ACTORCORE_V4",
		"glb": cfg["candidate_glb"] if env_on else cfg["production_glb"],
		"visual_script": cfg["candidate_script"] if env_on else cfg["production_script"],
		"catalog_visual_script": str(catalog_def.visual_script.resource_path) if catalog_def and catalog_def.visual_script else "",
		"catalog_production_glb": str(catalog_def.production_glb_path) if catalog_def else "",
		"catalog_pipeline_id": str(catalog_def.pipeline_id) if catalog_def else "",
		"animation": "idle",
		"experimental_semantic_v2": env_on,
		"production": prod_row,
		"candidate": cand_row,
		"sideways_root_cause": _sideways_cause(prod_row, cand_row, parity),
	}


func _spawn_via_catalog(host: Node3D, fighter_id: String, candidate: bool) -> Node:
	OS.set_environment("SSK_USE_SEMANTIC_V2_CANDIDATE", "1" if candidate else "0")
	var def = CATALOG.get_by_id(fighter_id)
	if def == null:
		return null
	var visual: Node = def.create_visual()
	if visual == null:
		return null
	visual.name = "%s_%s" % [fighter_id, "candidate" if candidate else "production"]
	host.add_child(visual)
	await get_tree().process_frame
	await get_tree().process_frame
	_play(visual, "idle")
	await get_tree().process_frame
	return visual


func _spawn_script(host: Node3D, script_path: String) -> Node:
	var script: Script = load(script_path) as Script
	if script == null or not script.can_instantiate():
		push_error("missing visual %s" % script_path)
		return null
	var visual: Node = script.new()
	visual.name = script_path.get_file().get_basename()
	host.add_child(visual)
	await get_tree().process_frame
	await get_tree().process_frame
	return visual


func _play(visual: Node, clip: String) -> void:
	if visual == null:
		return
	if visual.has_method("play_animation"):
		visual.call("play_animation", clip)
	elif visual.has_method("play_animation"):
		visual.call("play_animation", clip)


func _call_facing(visual: Node, direction: float) -> void:
	if visual.has_method("set_facing"):
		visual.call("set_facing", direction)
	elif visual.has_method("set_facing"):
		visual.call("set_facing", direction)


func _describe_visual(visual: Node, pipeline: String, expected_glb: String) -> Dictionary:
	if visual == null:
		return {"ok": false, "pipeline": pipeline, "expected_glb": expected_glb}
	var glb := ""
	if visual.get("config") != null:
		glb = str(visual.config.glb_path)
	var skel := _find_skel(visual)
	var player := _find_player(visual)
	var aabb: Dictionary = _aabb(visual)
	var upright := _upright_from_skeleton(visual)
	var pipeline_live := pipeline
	if visual.has_method("pipeline_name"):
		pipeline_live = str(visual.call("pipeline_name"))
	var fallback := false
	if visual.get("_using_fallback") != null:
		fallback = bool(visual.get("_using_fallback"))
	elif visual.get("_fallback_used") != null:
		fallback = bool(visual.get("_fallback_used"))
	var yaw := 0.0
	if visual.get("config") != null:
		yaw = rad_to_deg(float(visual.config.model_yaw_offset))
	return {
		"ok": true,
		"pipeline": pipeline_live,
		"script": visual.get_script().resource_path if visual.get_script() else "",
		"glb": glb,
		"expected_glb": expected_glb,
		"glb_matches_expected": glb == expected_glb,
		"skeleton_bones": skel.get_bone_count() if skel else 0,
		"clips": player.get_animation_list() if player else PackedStringArray(),
		"playing": player.current_animation if player else "",
		"model_yaw_deg": yaw,
		"aabb": aabb,
		"upright_hint": _upright_hint(aabb),
		"skeleton_upright": upright,
		"fallback": fallback,
	}


func _pose_sample(visual: Node, clip: String) -> Dictionary:
	var skel := _find_skel(visual)
	var player := _find_player(visual)
	if skel == null:
		return {"missing": true}
	if player != null:
		var resolved := _resolve_clip(player, clip)
		if not resolved.is_empty() and player.has_animation(resolved):
			player.play(resolved)
			player.seek(0.0, true)
			player.advance(0.0)
	return {"clip": clip, "bones": _sample_bones(skel)}


func _sample_bones(skel: Skeleton3D) -> Dictionary:
	var bones := {}
	for bone_name in POSE_BONES:
		var idx := skel.find_bone(bone_name)
		if idx < 0:
			bones[bone_name] = {"missing": true}
			continue
		var pose := skel.get_bone_pose_rotation(idx)
		var rest := skel.get_bone_rest(idx).basis.get_rotation_quaternion()
		bones[bone_name] = {
			"quat": [pose.x, pose.y, pose.z, pose.w],
			"rest_quat": [rest.x, rest.y, rest.z, rest.w],
			"angle_deg": rad_to_deg(pose.get_angle()),
		}
	return bones


func _sample_glb_direct(glb_path: String) -> Dictionary:
	var abs_path := ProjectSettings.globalize_path(glb_path)
	if not FileAccess.file_exists(abs_path):
		return {"missing": true, "glb": glb_path}
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	if doc.append_from_file(abs_path, state) != OK:
		return {"load_failed": true, "glb": glb_path}
	var root := doc.generate_scene(state) as Node3D
	if root == null:
		return {"generate_failed": true, "glb": glb_path}
	add_child(root)
	await get_tree().process_frame
	var skel := _find_skel(root)
	var player := _find_player(root)
	var out := {
		"glb": glb_path,
		"bones": skel.get_bone_count() if skel else 0,
		"clips": player.get_animation_list() if player else PackedStringArray(),
		"rest": {},
		"canonical_standing": {},
		"idle": {},
		"upright_rest": {},
		"upright_standing": {},
		"upright_idle": {},
	}
	if skel:
		skel.reset_bone_poses()
		out["rest"] = _sample_bones(skel)
		out["upright_rest"] = _upright_metric(skel)
	if player and skel:
		for clip in ["canonical_standing", "idle"]:
			var resolved := _resolve_clip(player, clip)
			if resolved.is_empty():
				continue
			player.play(resolved)
			player.seek(0.0, true)
			player.advance(0.0)
			await get_tree().process_frame
			out[clip] = _sample_bones(skel)
			if clip == "canonical_standing":
				out["upright_standing"] = _upright_metric(skel)
			else:
				out["upright_idle"] = _upright_metric(skel)
	root.queue_free()
	return out


func _blender_pose_slice(fighter_id: String) -> Dictionary:
	var arm: Dictionary = _read_json("res://docs/generated/SEMANTIC_V2_ARM_CHAIN_AUDIT.json")
	var hand: Dictionary = _read_json("res://docs/generated/SEMANTIC_V2_HAND_CHAIN_AUDIT.json")
	var row: Dictionary = arm.get(fighter_id, {})
	var hand_row: Dictionary = hand.get(fighter_id, {})
	var standing: Dictionary = row.get("canonical_standing", row.get("canonical_standing", {}))
	return {
		"arm_rest": ((row.get("rest", {}) as Dictionary).get("bones", {})),
		"arm_standing": ((standing as Dictionary).get("bones", {})),
		"hand_rest": hand_row.get("rest", {}),
		"hand_standing": hand_row.get("canonical_standing", hand_row.get("canonical_standing", {})),
		"standing_hand_differs_from_rest": bool(hand_row.get("standing_hand_differs_from_rest", false)),
	}


func _blender_standing_quats(fighter_id: String) -> Dictionary:
	var arm: Dictionary = _read_json("res://docs/generated/SEMANTIC_V2_ARM_CHAIN_AUDIT.json")
	var row: Dictionary = arm.get(fighter_id, {})
	var standing: Dictionary = row.get("canonical_standing", row.get("canonical_standing", {}))
	return (standing as Dictionary).get("bones", {})


func _bone_delta(blender_bones: Dictionary, godot_sample: Dictionary) -> Dictionary:
	var godot_bones: Dictionary = godot_sample.get("bones", {})
	var out := {}
	for bone_name in POSE_BONES:
		if not blender_bones.has(bone_name) or not godot_bones.has(bone_name):
			continue
		var bq: Array = (blender_bones[bone_name] as Dictionary).get("quat", [])
		var gq: Array = (godot_bones[bone_name] as Dictionary).get("quat", [])
		if bq.size() < 4 or gq.size() < 4:
			continue
		var qb := Quaternion(float(bq[0]), float(bq[1]), float(bq[2]), float(bq[3])).normalized()
		var qg := Quaternion(float(gq[0]), float(gq[1]), float(gq[2]), float(gq[3])).normalized()
		var qdot := absf(qb.dot(qg))
		out[bone_name] = {
			"quat_dot": qdot,
			"angle_deg": rad_to_deg(2.0 * acos(clampf(qdot, 0.0, 1.0))),
			"blender": bq,
			"godot": gq,
		}
	return out


func _resolve_clip(player: AnimationPlayer, token: String) -> String:
	if player.has_animation(token):
		return token
	for anim_name in player.get_animation_list():
		if String(anim_name).to_lower().contains(token.to_lower()):
			return anim_name
	return ""


func _full_stack(visual: Node) -> Array:
	var stack: Array = []
	if visual != null and visual.has_method("collect_transform_stack"):
		stack = visual.collect_transform_stack()
	if visual == null:
		return stack
	var extra: Array[Node] = []
	_gather(visual, extra)
	for node in extra:
		if node is Skeleton3D or node is MeshInstance3D or String(node.name).contains("Armature"):
			var n3 := node as Node3D
			if n3 == null:
				continue
			var q := n3.quaternion
			stack.append({
				"name": n3.name,
				"class": n3.get_class(),
				"path": str(visual.get_path_to(n3)),
				"position": [n3.position.x, n3.position.y, n3.position.z],
				"rotation_deg": [rad_to_deg(n3.rotation.x), rad_to_deg(n3.rotation.y), rad_to_deg(n3.rotation.z)],
				"quaternion": [q.x, q.y, q.z, q.w],
				"scale": [n3.scale.x, n3.scale.y, n3.scale.z],
			})
	return stack


func _aabb(visual: Node) -> Dictionary:
	if visual == null:
		return {"size": [0.0, 0.0, 0.0], "position": [0.0, 0.0, 0.0]}
	var combined := AABB()
	var first := true
	var walk: Array[Node] = [visual]
	while not walk.is_empty():
		var node: Node = walk.pop_back()
		if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
			var mi := node as MeshInstance3D
			var local: AABB = mi.get_aabb()
			for i in 8:
				var pt: Vector3 = mi.global_transform * local.get_endpoint(i)
				if first:
					combined = AABB(pt, Vector3.ZERO)
					first = false
				else:
					combined = combined.expand(pt)
		for child in node.get_children():
			walk.append(child)
	return {
		"size": [combined.size.x, combined.size.y, combined.size.z],
		"position": [combined.position.x, combined.position.y, combined.position.z],
	}


func _upright_hint(aabb: Dictionary) -> String:
	if not aabb.has("size"):
		return "unknown"
	var s: Array = aabb["size"]
	var y := absf(float(s[1]))
	var xz := maxf(absf(float(s[0])), absf(float(s[2])))
	if y >= xz * 0.85:
		return "UPRIGHT"
	if xz >= y * 1.35:
		return "SIDEWAYS_OR_FLAT"
	return "AMBIGUOUS"


func _upright_from_skeleton(visual: Node) -> Dictionary:
	var skel := _find_skel(visual)
	if skel == null:
		return {"ok": false}
	return _upright_metric(skel)


func _upright_metric(skel: Skeleton3D) -> Dictionary:
	var hip = _bone_world(skel, "CC_Base_Hip")
	var head = _bone_world(skel, "CC_Base_Head")
	if hip == null or head == null:
		return {"ok": false, "reason": "missing_hip_or_head"}
	var delta: Vector3 = head - hip
	var ax := absf(delta.x)
	var ay := absf(delta.y)
	var az := absf(delta.z)
	var dominant := "Y"
	if ax >= ay and ax >= az:
		dominant = "X"
	elif az >= ay and az >= ax:
		dominant = "Z"
	var classification := "UPRIGHT"
	if dominant != "Y":
		classification = "SIDEWAYS"
	elif ay < maxf(ax, az) * 1.05:
		classification = "AMBIGUOUS"
	return {
		"ok": true,
		"hip": [hip.x, hip.y, hip.z],
		"head": [head.x, head.y, head.z],
		"delta": [delta.x, delta.y, delta.z],
		"dominant_axis": dominant,
		"classification": classification,
	}


func _bone_world(skel: Skeleton3D, bone_name: String) -> Variant:
	var idx := skel.find_bone(bone_name)
	if idx < 0:
		return null
	return skel.global_transform * skel.get_bone_global_pose(idx).origin


func _sideways_cause(prod_row: Dictionary, cand_row: Dictionary, parity: Dictionary) -> Dictionary:
	var prod_sk: Dictionary = prod_row.get("skeleton_upright", {})
	var cand_sk: Dictionary = cand_row.get("skeleton_upright", {})
	var prod_class := str(prod_sk.get("classification", parity.get("upright_hint_production", "")))
	var cand_class := str(cand_sk.get("classification", parity.get("upright_hint_candidate", "")))
	var cause := "unknown"
	var evidence: PackedStringArray = PackedStringArray()
	if not bool(prod_row.get("ok", false)):
		cause = "production_visual_failed_to_instantiate"
		evidence.append("production ok=false")
	elif bool(prod_row.get("fallback", false)):
		cause = "production_fallback_visual_not_skeletal_glb"
		evidence.append("fallback=true")
	elif prod_class == "SIDEWAYS" and cand_class == "UPRIGHT":
		cause = "production_v4_idle_or_import_pose_is_sideways_candidate_semantic_v2_is_upright"
		evidence.append("hip-head dominant axis production=%s candidate=%s" % [prod_sk.get("dominant_axis"), cand_sk.get("dominant_axis")])
		evidence.append("default battle still loads production V4 GLB")
	elif prod_class == "SIDEWAYS" and cand_class == "SIDEWAYS":
		cause = "shared_import_or_yaw_stack_lays_both_assets_down"
		evidence.append("both hip-head axes non-Y")
	elif prod_class == "UPRIGHT" and cand_class == "SIDEWAYS":
		cause = "candidate_yaw_or_facing_incorrect_v4_already_upright"
		evidence.append("candidate laid down while production stands")
	elif prod_class == "UPRIGHT":
		cause = "production_spawn_is_upright_human_sideways_is_not_the_current_identity_spawn_stack"
		evidence.append("current production hip-head is Y-dominant")
	if str(prod_row.get("glb", "")).contains("game_ready_v4"):
		evidence.append("default battle GLB is production V4 not semantic_solver_v2")
	return {
		"production_classification": prod_class,
		"candidate_classification": cand_class,
		"production_upright_hint": str(prod_row.get("upright_hint", "")),
		"candidate_upright_hint": str(cand_row.get("upright_hint", "")),
		"cause": cause,
		"evidence": evidence,
		"production_still_v4": true,
		"candidate_uses_semantic_v2_glb": bool(cand_row.get("glb_matches_expected", false)),
	}


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


func _gather(node: Node, out: Array[Node]) -> void:
	for child in node.get_children():
		out.append(child)
		_gather(child, out)


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}


func _write(path: String, data: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
		print("Wrote %s" % path)
