extends SceneTree

const PATHS := [
	"res://assets/fighters/models/terere/terere_glb_1.glb",
	"res://assets/fighters/models/jaguarete/jaguarete_glb_1.glb",
]

func _initialize() -> void:
	for path in PATHS:
		_audit_path(path)
	quit()

func _audit_path(path: String) -> void:
	print("[MODEL_AUDIT] path=%s" % path)
	if not ResourceLoader.exists(path):
		print("[MODEL_AUDIT] MISSING")
		return
	var scene: PackedScene = load(path)
	if scene == null:
		print("[MODEL_AUDIT] load failed")
		return
	var root: Node = scene.instantiate()
	var meshes: Array[MeshInstance3D] = []
	_collect_meshes(root, meshes)
	print("[MODEL_AUDIT] mesh_count=%d" % meshes.size())
	var combined := AABB()
	var first := true
	for mesh_inst in meshes:
		if mesh_inst.mesh == null:
			continue
		var local_aabb := mesh_inst.mesh.get_aabb()
		var global_xform := mesh_inst.global_transform
		var corners: Array[Vector3] = []
		for i in 8:
			corners.append(global_xform * local_aabb.get_endpoint(i))
		for corner in corners:
			if first:
				combined = AABB(corner, Vector3.ZERO)
				first = false
			else:
				combined = combined.expand(corner)
		print(
			"[MODEL_AUDIT] mesh=%s tris=%d mats=%s" % [
				mesh_inst.name,
				mesh_inst.mesh.get_faces().size() if mesh_inst.mesh.has_method("get_faces") else -1,
				mesh_inst.get_surface_override_material_count()
			]
		)
	if not first:
		print("[MODEL_AUDIT] aabb_size=%s center=%s min_y=%s max_y=%s" % [
			combined.size,
			combined.get_center(),
			combined.position.y,
			combined.position.y + combined.size.y
		])
	root.queue_free()

func _collect_meshes(node: Node, out: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		out.append(node)
	for child in node.get_children():
		_collect_meshes(child, out)
