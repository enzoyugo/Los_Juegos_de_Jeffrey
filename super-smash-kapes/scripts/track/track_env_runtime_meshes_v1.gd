class_name TrackEnvRuntimeMeshesV1
extends RefCounted

## Extracts reusable Mesh resources from first-party urban GLBs for MultiMesh.
## Prefer baked .res under assets/track/environment/runtime/; fall back to live extract.
## Does not mutate source GLBs.

const RUNTIME_DIR := "res://assets/track/environment/runtime/"

const CATALOG := {
	"lamp_street": "res://assets/environments/shared/urban/lighting/lamp_street.glb",
	"barrier": "res://assets/environments/shared/urban/street_props/barrier_01.glb",
	"fence": "res://assets/environments/shared/urban/street_props/fence_01.glb",
	"building_small": "res://assets/environments/shared/urban/street_props/building_small_01.glb",
	"building_med": "res://assets/environments/shared/urban/street_props/building_med_01.glb",
	"building_mid": "res://assets/environments/shared/urban/processed/architecture/building_mid_01.glb",
	"building_shop": "res://assets/environments/shared/urban/processed/architecture/building_shop_01.glb",
	"tower": "res://assets/environments/shared/urban/processed/architecture/tower_01.glb",
	"billboard": "res://assets/environments/shared/urban/street_props/billboard_01.glb",
	"palm": "res://assets/environments/shared/urban/processed/vegetation/palm_v2_01.glb",
	"tree": "res://assets/environments/shared/urban/processed/vegetation/tree_v2_01.glb",
}

## Rejected for live race (too heavy / wrong role).
const REJECTED := [
	"res://assets/environments/shared/urban/processed/vehicles/wreck_parked.glb",
	"res://assets/environments/shared/urban/processed/street_props/market_extracted_cluster.glb",
	"res://assets/environments/shared/urban/processed/industrial/cement_bags.glb",
	"res://assets/environments/shared/urban/processed/vehicles/vaz_parked.glb",
	"res://assets/environments/shared/urban/processed/vehicles/hilux_parked.glb",
	"res://assets/environments/shared/urban/processed/industrial/psx_industrial_pack.glb",
]

var _cache: Dictionary = {} ## id -> { mesh, aabb, source, mode }
var _stats: Dictionary = {}


func inventory() -> Dictionary:
	return {
		"catalog": CATALOG.keys(),
		"rejected": REJECTED,
		"cached": _cache.keys(),
		"stats": _stats.duplicate(true),
	}


func get_mesh(id: String) -> Mesh:
	var entry: Dictionary = _ensure(id)
	return entry.get("mesh", null)


func get_entry(id: String) -> Dictionary:
	return _ensure(id)


func has_promoted(id: String) -> bool:
	var entry: Dictionary = _ensure(id)
	return entry.get("mesh", null) != null


func bake_all_to_disk() -> Dictionary:
	## Writes ArrayMesh .res files for lab/runtime. Safe to re-run.
	var report := {"ok": [], "fail": [], "dir": RUNTIME_DIR}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(RUNTIME_DIR))
	for id in CATALOG.keys():
		var entry: Dictionary = _ensure(str(id))
		var mesh: Mesh = entry.get("mesh", null)
		if mesh == null:
			report["fail"].append(id)
			continue
		var path := RUNTIME_DIR + str(id) + ".res"
		var err := ResourceSaver.save(mesh, path)
		if err == OK:
			report["ok"].append({"id": id, "path": path, "aabb": str(entry.get("aabb", ""))})
		else:
			report["fail"].append("%s err=%d" % [id, err])
	return report


func _ensure(id: String) -> Dictionary:
	if _cache.has(id):
		return _cache[id]
	var baked_path := RUNTIME_DIR + id + ".res"
	if ResourceLoader.exists(baked_path):
		var baked = load(baked_path)
		if baked is Mesh:
			var e := {"mesh": baked, "aabb": baked.get_aabb(), "source": baked_path, "mode": "baked"}
			_cache[id] = e
			_stats[id] = {"mode": "baked", "aabb_size": baked.get_aabb().size}
			return e
	var src := str(CATALOG.get(id, ""))
	if src.is_empty() or not ResourceLoader.exists(src):
		var miss := {"mesh": null, "aabb": AABB(), "source": src, "mode": "missing"}
		_cache[id] = miss
		return miss
	var extracted: Dictionary = _extract_from_glb(src)
	extracted["source"] = src
	_cache[id] = extracted
	_stats[id] = {
		"mode": extracted.get("mode", "extract"),
		"aabb_size": (extracted.get("aabb", AABB()) as AABB).size,
		"surfaces": int(extracted.get("surfaces", 0)),
	}
	return extracted


func _extract_from_glb(path: String) -> Dictionary:
	var packed: PackedScene = load(path) as PackedScene
	if packed == null:
		return {"mesh": null, "aabb": AABB(), "mode": "load_fail"}
	var root := packed.instantiate()
	if root == null:
		return {"mesh": null, "aabb": AABB(), "mode": "inst_fail"}
	var meshes: Array = []
	_collect_meshes(root, meshes, Transform3D.IDENTITY)
	root.free()
	if meshes.is_empty():
		return {"mesh": null, "aabb": AABB(), "mode": "no_mesh"}
	## Prefer single largest mesh by AABB volume for MultiMesh friendliness.
	meshes.sort_custom(func(a, b) -> bool:
		var va: float = (a["aabb"] as AABB).get_volume()
		var vb: float = (b["aabb"] as AABB).get_volume()
		return va > vb
	)
	var best: Dictionary = meshes[0]
	var mesh: Mesh = best["mesh"]
	## If multiple meshes, merge into one ArrayMesh when small count.
	if meshes.size() > 1 and meshes.size() <= 6:
		var merged := _try_merge(meshes)
		if merged != null:
			mesh = merged
			best["aabb"] = mesh.get_aabb()
	return {
		"mesh": mesh,
		"aabb": best.get("aabb", mesh.get_aabb()),
		"mode": "extract",
		"surfaces": mesh.get_surface_count() if mesh != null else 0,
	}


func _collect_meshes(node: Node, out: Array, xf: Transform3D) -> void:
	var local := xf
	if node is Node3D:
		local = xf * (node as Node3D).transform
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.mesh != null:
			out.append({"mesh": mi.mesh, "aabb": mi.mesh.get_aabb(), "xf": local})
	for child in node.get_children():
		_collect_meshes(child, out, local)


func _try_merge(meshes: Array) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var any := false
	for item in meshes:
		var mesh: Mesh = item["mesh"]
		var xf: Transform3D = item.get("xf", Transform3D.IDENTITY)
		for s in mesh.get_surface_count():
			var arrays := mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var norms = arrays[Mesh.ARRAY_NORMAL]
			var uvs = arrays[Mesh.ARRAY_TEX_UV]
			var idx = arrays[Mesh.ARRAY_INDEX]
			if verts.is_empty():
				continue
			any = true
			if idx != null and idx.size() > 0:
				for i in idx:
					var vi: int = int(i)
					st.set_normal(norms[vi] if norms != null and norms.size() > vi else Vector3.UP)
					if uvs != null and uvs.size() > vi:
						st.set_uv(uvs[vi])
					st.add_vertex(xf * verts[vi])
			else:
				for vi in verts.size():
					st.set_normal(norms[vi] if norms != null and norms.size() > vi else Vector3.UP)
					if uvs != null and uvs.size() > vi:
						st.set_uv(uvs[vi])
					st.add_vertex(xf * verts[vi])
	if not any:
		return null
	st.generate_normals()
	return st.commit()
