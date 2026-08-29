class_name JeffreyResourceProbe
extends RefCounted

## Compact resource / memory dump for D3D12 RCA. First allocation failure is the symptom.


static func dump(tag: String, root: Node = null) -> Dictionary:
	var static_mem := float(OS.get_static_memory_usage())
	var peak := float(OS.get_static_memory_peak_usage())
	var tex := float(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED))
	var video := float(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED))
	var buf := float(Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED))
	var objects := int(Performance.get_monitor(Performance.OBJECT_COUNT))
	var resources := int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))
	var nodes := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var mesh_n := 0
	var mat_ids: Dictionary = {}
	var tex_ids: Dictionary = {}
	var noise_n := 0
	var env_n := 0
	var vp_n := 0
	if root != null:
		_walk(root, mat_ids, tex_ids)
		mesh_n = _count_class(root, "MeshInstance3D")
		env_n = _count_class(root, "WorldEnvironment")
		vp_n = _count_class(root, "SubViewport")
	var row := {
		"tag": tag,
		"static_mb": static_mem / 1048576.0,
		"peak_mb": peak / 1048576.0,
		"tex_mb": tex / 1048576.0,
		"video_mb": video / 1048576.0,
		"buffer_mb": buf / 1048576.0,
		"objects": objects,
		"resources": resources,
		"nodes": nodes,
		"mesh_instances": mesh_n,
		"unique_materials": mat_ids.size(),
		"unique_textures": tex_ids.size(),
		"noise_tex": noise_n,
		"environments": env_n,
		"subviewports": vp_n,
		"gpu": str(RenderingServer.get_video_adapter_name()),
	}
	print(
		"[JEFFREY_MEM] %s static=%.1fMB peak=%.1fMB tex=%.1fMB video=%.1fMB buf=%.1fMB objects=%d res=%d meshes=%d mats=%d texn=%d env=%d vp=%d gpu=%s"
		% [
			tag,
			row["static_mb"],
			row["peak_mb"],
			row["tex_mb"],
			row["video_mb"],
			row["buffer_mb"],
			objects,
			resources,
			mesh_n,
			mat_ids.size(),
			tex_ids.size(),
			env_n,
			vp_n,
			row["gpu"],
		]
	)
	return row


static func boot_line() -> void:
	print(
		"[JEFFREY_MEM] boot static=%.1fMB peak=%.1fMB tex=%.1fMB video=%.1fMB gpu=%s"
		% [
			float(OS.get_static_memory_usage()) / 1048576.0,
			float(OS.get_static_memory_peak_usage()) / 1048576.0,
			float(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)) / 1048576.0,
			float(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)) / 1048576.0,
			str(RenderingServer.get_video_adapter_name()),
		]
	)


static func _walk(node: Node, mat_ids: Dictionary, tex_ids: Dictionary) -> void:
	if node is MeshInstance3D:
		var mesh_inst := node as MeshInstance3D
		if mesh_inst.mesh != null:
			for i in mesh_inst.mesh.get_surface_count():
				var mat: Material = mesh_inst.get_active_material(i)
				if mat != null:
					mat_ids[mat.get_instance_id()] = true
					_collect_tex(mat, tex_ids)
	if node is WorldEnvironment:
		var env: Environment = (node as WorldEnvironment).environment
		if env != null:
			mat_ids[env.get_instance_id()] = true
	for child in node.get_children():
		_walk(child, mat_ids, tex_ids)


static func _collect_tex(mat: Material, tex_ids: Dictionary) -> void:
	if mat is BaseMaterial3D:
		var bm := mat as BaseMaterial3D
		for slot in [bm.albedo_texture, bm.normal_texture, bm.emission_texture, bm.roughness_texture]:
			if slot != null:
				tex_ids[slot.get_instance_id()] = true


static func _count_class(node: Node, cname: String) -> int:
	var n := 1 if node.get_class() == cname else 0
	for child in node.get_children():
		n += _count_class(child, cname)
	return n
