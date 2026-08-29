extends SceneTree

## Dump production fighter materials / textures. Detect cross-character contamination.

const OUTPUT_DIR := "res://docs/generated/"

const FIGHTERS := {
	"terere": "res://assets/fighters/processed/terere/terere_game_ready_v4.glb",
	"jaguarete": "res://assets/fighters/processed/jaguarete/jaguarete_game_ready_v4.glb",
}


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var all_ok := true
	var graphs: Dictionary = {}
	for fighter_id in FIGHTERS:
		var graph := _dump_fighter(fighter_id, FIGHTERS[fighter_id])
		graphs[fighter_id] = graph
		_write_json("%s%s_MATERIAL_GRAPH.json" % [OUTPUT_DIR, fighter_id.to_upper()], graph)
		print("MATERIAL_GRAPH %s materials=%d" % [fighter_id, (graph.get("materials", []) as Array).size()])
	var terere_tex: Array = graphs.get("terere", {}).get("texture_paths", [])
	var jagua_tex: Array = graphs.get("jaguarete", {}).get("texture_paths", [])
	var overlap: Array = []
	for path in terere_tex:
		if str(path).is_empty():
			continue
		if jagua_tex.has(path):
			overlap.append(path)
	var isolation := {
		"shared_texture_paths": overlap,
		"pass": overlap.is_empty(),
		"note": "Textures may share only if intentionally identical. Accidental cross-character albedo is a fail.",
	}
	_write_json(OUTPUT_DIR + "MATERIAL_ISOLATION_AUDIT.json", isolation)
	if not overlap.is_empty():
		all_ok = false
		print("MATERIAL_ISOLATION=FAIL overlap=%s" % str(overlap))
	else:
		print("MATERIAL_ISOLATION=PASS")
	quit(0 if all_ok else 1)


func _dump_fighter(fighter_id: String, glb_path: String) -> Dictionary:
	var abs_path := ProjectSettings.globalize_path(glb_path)
	var root := _load_glb(glb_path, abs_path)
	var materials: Array = []
	var textures: Array = []
	if root != null:
		_walk(root, materials, textures)
		root.free()
	return {
		"fighter": fighter_id,
		"glb": glb_path,
		"materials": materials,
		"texture_paths": textures,
	}


func _walk(node: Node, materials: Array, textures: Array) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.mesh != null:
			for i in mi.mesh.get_surface_count():
				var mat := mi.get_active_material(i)
				if mat == null:
					mat = mi.mesh.surface_get_material(i)
				materials.append(_material_record(mat, mi, i))
				_collect_tex(mat, textures)
	for child in node.get_children():
		_walk(child, materials, textures)


func _material_record(mat: Material, mi: MeshInstance3D, surface: int) -> Dictionary:
	if mat == null:
		return {"mesh": mi.name, "surface": surface, "missing": true}
	var rec := {
		"mesh": mi.name,
		"surface": surface,
		"material_name": mat.resource_name,
		"material_path": mat.resource_path,
		"class": mat.get_class(),
		"resource_local_to_scene": mat.resource_local_to_scene,
	}
	if mat is StandardMaterial3D:
		var sm := mat as StandardMaterial3D
		rec["albedo_texture"] = _tex_path(sm.albedo_texture)
		rec["normal_texture"] = _tex_path(sm.normal_texture)
		rec["roughness_texture"] = _tex_path(sm.roughness_texture)
		rec["metallic_texture"] = _tex_path(sm.metallic_texture)
		rec["albedo_color"] = [sm.albedo_color.r, sm.albedo_color.g, sm.albedo_color.b, sm.albedo_color.a]
	return rec


func _collect_tex(mat: Material, textures: Array) -> void:
	if not (mat is StandardMaterial3D):
		return
	var sm := mat as StandardMaterial3D
	for tex in [sm.albedo_texture, sm.normal_texture, sm.roughness_texture, sm.metallic_texture]:
		var path := _tex_path(tex)
		if path != "" and not textures.has(path):
			textures.append(path)


func _tex_path(tex: Texture2D) -> String:
	if tex == null:
		return ""
	if tex.resource_path != "":
		return tex.resource_path
	return tex.resource_name


func _load_glb(glb_path: String, abs_path: String) -> Node:
	if not FileAccess.file_exists(abs_path):
		print("MISSING %s" % glb_path)
		return null
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	if doc.append_from_file(abs_path, state) != OK:
		return null
	return doc.generate_scene(state)


func _write_json(path: String, data: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
		print("Wrote %s" % path)
