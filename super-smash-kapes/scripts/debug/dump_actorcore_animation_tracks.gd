extends SceneTree

const OUTPUTS := {
	"terere": {
		"glb": "res://assets/fighters/processed/actorcore_benchmark/terere/terere_actorcore_idle.glb",
		"out": "res://docs/generated/TERERE_ACTORCORE_GODOT_TRACKS.txt",
	},
	"jaguarete": {
		"glb": "res://assets/fighters/processed/actorcore_benchmark/jaguarete/jaguarete_actorcore_idle.glb",
		"out": "res://docs/generated/JAGUARETE_ACTORCORE_GODOT_TRACKS.txt",
	},
}


func _initialize() -> void:
	var ok := true
	for key in OUTPUTS:
		if not _dump_character(key, OUTPUTS[key]):
			ok = false
	print("DUMP_ACTORCORE_TRACKS=%s" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)


func _dump_character(key: String, cfg: Dictionary) -> bool:
	var lines: PackedStringArray = []
	lines.append("=== %s ActorCore Godot Tracks ===" % key.to_upper())
	var glb_path: String = cfg["glb"]
	var abs_path := ProjectSettings.globalize_path(glb_path)
	if not FileAccess.file_exists(abs_path):
		lines.append("ERROR: missing %s" % glb_path)
		_write(cfg["out"], lines)
		return false
	var root: Node = _load_glb_root(glb_path, abs_path, lines)
	if root == null:
		_write(cfg["out"], lines)
		return false
	var player := _find_animation_player(root)
	var skeleton := _find_skeleton(root)
	lines.append("SKELETON=%s bones=%d" % [skeleton != null, skeleton.get_bone_count() if skeleton else 0])
	if player == null:
		lines.append("ERROR: no AnimationPlayer")
		root.queue_free()
		_write(cfg["out"], lines)
		return false
	var libs := player.get_animation_library_list()
	lines.append("LIBRARIES=%s" % str(libs))
	var bone_tracks := 0
	for lib_name in libs:
		var library: AnimationLibrary = player.get_animation_library(lib_name)
		for anim_name in library.get_animation_list():
			var full_name: String = "%s/%s" % [lib_name, anim_name] if lib_name else anim_name
			var anim: Animation = library.get_animation(anim_name)
			lines.append("ANIMATION=%s duration=%.3f tracks=%d" % [full_name, anim.length, anim.get_track_count()])
			for t in anim.get_track_count():
				var track_type := anim.track_get_type(t)
				var path := String(anim.track_get_path(t))
				var keys := anim.track_get_key_count(t)
				lines.append("  track type=%d path=%s keys=%d" % [track_type, path, keys])
				if skeleton and ":" in path:
					bone_tracks += 1
	lines.append("BONE_TRACK_COUNT=%d" % bone_tracks)
	root.queue_free()
	_write(cfg["out"], lines)
	return bone_tracks >= 6


func _load_glb_root(glb_path: String, abs_path: String, lines: PackedStringArray) -> Node:
	if ResourceLoader.exists(glb_path):
		var packed: PackedScene = load(glb_path)
		if packed:
			lines.append("LOAD_MODE=ResourceLoader")
			return packed.instantiate()
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var err := doc.append_from_file(abs_path, state)
	if err != OK:
		lines.append("ERROR: GLTFDocument failed err=%d for %s" % [err, glb_path])
		return null
	var scene := doc.generate_scene(state)
	if scene == null:
		lines.append("ERROR: generate_scene failed for %s" % glb_path)
		return null
	lines.append("LOAD_MODE=GLTFDocument")
	return scene


func _write(path: String, lines: PackedStringArray) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string("\n".join(lines))
	print("Wrote %s" % path)


func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node as Skeleton3D
	for child in node.get_children():
		var found := _find_skeleton(child)
		if found:
			return found
	return null


func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found:
			return found
	return null
