extends SceneTree

## Validates production ActorCore V3 GLBs after Godot import.

const OUTPUT := "res://docs/generated/ACTORCORE_PRODUCTION_GODOT_VALIDATION.txt"

const MODELS := {
	"terere": {
		"glb": "res://assets/fighters/processed/terere/terere_game_ready_v4.glb",
		"height": 2.40,
	},
	"jaguarete": {
		"glb": "res://assets/fighters/processed/jaguarete/jaguarete_game_ready_v4.glb",
		"height": 3.15,
	},
}


func _initialize() -> void:
	var lines: PackedStringArray = PackedStringArray(["=== ActorCore Production Godot Validation ==="])
	var ok := true
	for fighter_id in MODELS:
		if not _validate(fighter_id, MODELS[fighter_id], lines):
			ok = false
	_write(OUTPUT, lines)
	print("ACTORCORE_PRODUCTION_VALIDATION=%s" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)


func _validate(fighter_id: String, cfg: Dictionary, lines: PackedStringArray) -> bool:
	lines.append("")
	lines.append("--- %s ---" % fighter_id)
	var glb_path: String = cfg["glb"]
	var abs_path := ProjectSettings.globalize_path(glb_path)
	lines.append("path=%s exists=%s" % [glb_path, FileAccess.file_exists(abs_path)])
	var root := _load_glb(glb_path, abs_path, lines)
	if root == null:
		return false
	var skeletons := _collect_skeletons(root)
	var player := _find_animation_player(root)
	lines.append("Skeleton3D_count=%d" % skeletons.size())
	var bone_count := skeletons[0].get_bone_count() if not skeletons.is_empty() else 0
	lines.append("bone_count=%d" % bone_count)
	lines.append("triangles=%d" % _count_triangles(root))
	lines.append("AnimationPlayer=%s" % (player != null))
	var idle_name := ""
	var track_count := 0
	var bone_tracks := 0
	if player != null:
		lines.append("clips=%s" % ",".join(player.get_animation_list()))
		for anim_name in player.get_animation_list():
			if anim_name.to_lower() == "idle" or anim_name.to_lower().ends_with("/idle"):
				idle_name = anim_name
				break
		if idle_name.is_empty():
			for anim_name in player.get_animation_list():
				if anim_name.to_lower().contains("idle"):
					idle_name = anim_name
					break
		if not idle_name.is_empty() and player.has_animation(idle_name):
			var anim: Animation = player.get_animation(idle_name)
			track_count = anim.get_track_count()
			var bones := {}
			for i in anim.get_track_count():
				if anim.track_get_type(i) == Animation.TYPE_ROTATION_3D:
					var path := String(anim.track_get_path(i))
					if ":" in path:
						bones[path.split(":")[-1]] = true
			bone_tracks = bones.size()
	lines.append("idle=%s" % idle_name)
	lines.append("idle_track_count=%d" % track_count)
	lines.append("idle_skeletal_tracks=%d" % bone_tracks)
	root.free()
	var passed := skeletons.size() == 1 and bone_count == 101 and not idle_name.is_empty() and bone_tracks >= 6
	lines.append("pipeline=ACTORCORE_V4" if passed else "pipeline=FAIL")
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


func _count_triangles(node: Node) -> int:
	var total := 0
	if node is MeshInstance3D:
		var mesh: Mesh = (node as MeshInstance3D).mesh
		if mesh != null:
			for i in mesh.get_surface_count():
				var arrays := mesh.surface_get_arrays(i)
				if arrays.size() > Mesh.ARRAY_INDEX and arrays[Mesh.ARRAY_INDEX] != null:
					total += int(arrays[Mesh.ARRAY_INDEX].size() / 3)
	for child in node.get_children():
		total += _count_triangles(child)
	return total


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
