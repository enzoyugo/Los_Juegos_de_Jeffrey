extends SceneTree

## Headless rig audit for Jaguareté v2 + Mixamo FBX sources.
## Run: Godot --headless --path project --script res://scripts/debug/rig_inventory_audit.gd

func _initialize() -> void:
	print("[RIG_AUDIT] start")
	_audit_packed("res://assets/fighters/models/jaguarete/jaguarete_v2.glb", "JAGUARETE_V2")
	_audit_packed("res://assets/fighters/models/terere/terere_v2.glb", "TERERE_V2")
	_audit_packed("res://assets/fighters/animations/Idle.fbx", "MIXAMO_IDLE")
	_audit_packed("res://assets/fighters/animations/Mutant Punch.fbx", "MIXAMO_PUNCH")
	_audit_packed("res://assets/fighters/animations/Unarmed Jump.fbx", "MIXAMO_JUMP")
	print("[RIG_AUDIT] done")
	quit(0)

func _audit_packed(path: String, label: String) -> void:
	print("[RIG_AUDIT] === %s === path=%s exists=%s" % [label, path, ResourceLoader.exists(path)])
	if not ResourceLoader.exists(path):
		return
	var packed = load(path)
	if packed == null:
		print("[RIG_AUDIT] load failed")
		return
	print("[RIG_AUDIT] type=", packed.get_class())
	if packed is PackedScene:
		var root: Node = packed.instantiate()
		_dump_node(root, 0)
		var skeletons := _find_typed(root, "Skeleton3D")
		var players := _find_typed(root, "AnimationPlayer")
		var meshes := _find_typed(root, "MeshInstance3D")
		print("[RIG_AUDIT] skeletons=%d players=%d meshes=%d" % [skeletons.size(), players.size(), meshes.size()])
		for sk in skeletons:
			var skeleton := sk as Skeleton3D
			print("[RIG_AUDIT] skeleton_path=", root.get_path_to(skeleton), " bones=", skeleton.get_bone_count())
			for i in skeleton.get_bone_count():
				var parent := skeleton.get_bone_parent(i)
				print("[RIG_AUDIT] bone[%d]=%s parent=%d" % [i, skeleton.get_bone_name(i), parent])
		for ap in players:
			var player := ap as AnimationPlayer
			print("[RIG_AUDIT] anim_player=", root.get_path_to(player), " list=", player.get_animation_list())
			for anim_name in player.get_animation_list():
				var anim: Animation = player.get_animation(anim_name)
				if anim == null:
					continue
				print("[RIG_AUDIT] clip=%s length=%.3f tracks=%d" % [anim_name, anim.length, anim.get_track_count()])
		# Neutral AABB of meshes under root
		var aabb := _combined_aabb(root)
		print("[RIG_AUDIT] aabb size=%s pos=%s height=%.4f" % [aabb.size, aabb.position, aabb.size.y])
		root.free()
	elif packed is Animation:
		print("[RIG_AUDIT] raw Animation length=", packed.length, " tracks=", packed.get_track_count())
	elif packed is AnimationLibrary:
		print("[RIG_AUDIT] AnimationLibrary keys=", packed.get_animation_list())

func _dump_node(node: Node, depth: int) -> void:
	var indent := ""
	for _i in depth:
		indent += "  "
	print("[RIG_AUDIT] %s%s (%s)" % [indent, node.name, node.get_class()])
	for child in node.get_children():
		_dump_node(child, depth + 1)

func _find_typed(node: Node, type_name: String) -> Array:
	var found: Array = []
	_gather_typed(node, type_name, found)
	return found

func _gather_typed(node: Node, type_name: String, found: Array) -> void:
	if node.get_class() == type_name:
		found.append(node)
	for child in node.get_children():
		_gather_typed(child, type_name, found)

func _combined_aabb(node: Node) -> AABB:
	var combined := AABB()
	var first := true
	for mesh_node in _find_typed(node, "MeshInstance3D"):
		var mi := mesh_node as MeshInstance3D
		if mi.mesh == null:
			continue
		var local := mi.mesh.get_aabb()
		for i in 8:
			var p: Vector3 = mi.global_transform * local.get_endpoint(i)
			if first:
				combined = AABB(p, Vector3.ZERO)
				first = false
			else:
				combined = combined.expand(p)
	return combined
