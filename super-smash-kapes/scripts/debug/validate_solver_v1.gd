extends SceneTree

## Isolated solver_v1 GLB load check. Does not touch battle.

const OUTPUT := "res://docs/generated/SOLVER_V1_GODOT_LAB_VALIDATION.txt"

const MODELS := {
	"terere": {
		"glb": "res://assets/fighters/processed/solver_v1/terere/terere_idle_solver_v1.glb",
		"scene": "res://scenes/debug/TerereSolverV1Lab.tscn",
	},
	"jaguarete": {
		"glb": "res://assets/fighters/processed/solver_v1/jaguarete/jaguarete_idle_solver_v1.glb",
		"scene": "res://scenes/debug/JaguareteSolverV1Lab.tscn",
	},
}


func _initialize() -> void:
	var lines: PackedStringArray = PackedStringArray(["=== ActorCore Rest-Axis Solver V1 Godot Lab ==="])
	var ok := true
	for fighter_id in MODELS:
		if not _validate(fighter_id, MODELS[fighter_id], lines):
			ok = false
	_write(OUTPUT, lines)
	print("SOLVER_V1_GODOT_LAB=%s" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)


func _validate(fighter_id: String, cfg: Dictionary, lines: PackedStringArray) -> bool:
	lines.append("")
	lines.append("--- %s ---" % fighter_id)
	var glb_path: String = cfg["glb"]
	var abs_path := ProjectSettings.globalize_path(glb_path)
	lines.append("path=%s exists=%s" % [glb_path, FileAccess.file_exists(abs_path)])
	lines.append("lab_scene_exists=%s" % FileAccess.file_exists(ProjectSettings.globalize_path(cfg["scene"])))
	var root := _load_glb(glb_path, abs_path, lines)
	if root == null:
		return false
	var skeletons := _collect_skeletons(root)
	var player := _find_animation_player(root)
	var bone_count := skeletons[0].get_bone_count() if not skeletons.is_empty() else 0
	lines.append("Skeleton3D_count=%d" % skeletons.size())
	lines.append("bone_count=%d" % bone_count)
	lines.append("AnimationPlayer=%s" % (player != null))
	var idle_name := ""
	var bone_tracks := 0
	if player != null:
		lines.append("clips=%s" % ",".join(player.get_animation_list()))
		for anim_name in player.get_animation_list():
			if anim_name.to_lower().contains("idle"):
				idle_name = anim_name
				break
		if not idle_name.is_empty() and player.has_animation(idle_name):
			var anim: Animation = player.get_animation(idle_name)
			var bones := {}
			for i in anim.get_track_count():
				if anim.track_get_type(i) == Animation.TYPE_ROTATION_3D:
					var path := String(anim.track_get_path(i))
					if ":" in path:
						bones[path.split(":")[-1]] = true
			bone_tracks = bones.size()
	lines.append("idle=%s" % idle_name)
	lines.append("idle_skeletal_tracks=%d" % bone_tracks)
	root.free()
	var passed := skeletons.size() == 1 and bone_count == 101 and not idle_name.is_empty() and bone_tracks >= 4
	lines.append("solver_lab=%s" % ("PASS" if passed else "FAIL"))
	return passed


func _load_glb(glb_path: String, abs_path: String, lines: PackedStringArray) -> Node:
	if ResourceLoader.exists(glb_path):
		var packed: PackedScene = load(glb_path)
		if packed:
			lines.append("LOAD_MODE=ResourceLoader")
			return packed.instantiate()
	if not FileAccess.file_exists(abs_path):
		lines.append("ERROR: missing file")
		return null
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	if doc.append_from_file(abs_path, state) != OK:
		lines.append("ERROR: GLTFDocument failed")
		return null
	lines.append("LOAD_MODE=GLTFDocument")
	return doc.generate_scene(state)


func _collect_skeletons(node: Node) -> Array[Skeleton3D]:
	var found: Array[Skeleton3D] = []
	if node is Skeleton3D:
		found.append(node as Skeleton3D)
	for child in node.get_children():
		found.append_array(_collect_skeletons(child))
	return found


func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found:
			return found
	return null


func _write(path: String, lines: PackedStringArray) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string("\n".join(lines) + "\n")
	print("Wrote %s" % path)
