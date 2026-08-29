class_name TrackCheckpointLayout
extends RefCounted

## Post-process checkpoints on a generated V2 sequence. Does not change Generator V4.


static func plan(sequence: Array, length_id: String) -> PackedInt32Array:
	var n: int = sequence.size()
	var want := 4
	match str(length_id).to_upper():
		"SHORT", "CORTA":
			want = clampi(n - 2, 3, 5)
		"MEDIUM", "MEDIA":
			want = clampi(int(round(float(n) * 0.45)), 5, 8)
		"LONG", "LARGA":
			want = clampi(int(round(float(n) * 0.4)), 7, 12)
		_:
			want = clampi(n - 2, 3, 8)
	var out := PackedInt32Array()
	if n < 3:
		return out
	var usable := n - 2
	want = mini(want, usable)
	var seen := {}
	for k in want:
		var idx := 1 + int(round(float(k + 1) * float(usable) / float(want + 1)))
		idx = clampi(idx, 1, n - 2)
		if seen.has(idx):
			idx = mini(idx + 1, n - 2)
		if not seen.has(idx):
			seen[idx] = true
			out.append(idx)
	if not out.has(n - 1):
		out.append(n - 1)
	return out


static func build_gates(parent: Node, pieces: Array, indices: PackedInt32Array, road_w: float = 11.0) -> Array:
	var gates: Array = []
	for i in indices.size():
		var pi: int = indices[i]
		if pi < 0 or pi >= pieces.size():
			continue
		var piece = pieces[pi]
		if piece == null or not piece.has_method("exit_global"):
			continue
		var xf: Transform3D = piece.exit_global()
		var finish := pi == pieces.size() - 1
		var gate := _gantry(road_w, finish, i)
		parent.add_child(gate)
		gate.global_transform = xf
		gates.append({"node": gate, "index": i, "piece": pi, "finish": finish})
	return gates


static func _gantry(road_w: float, finish: bool, index: int) -> Node3D:
	var glb_path := "res://assets/track/processed/kit_v8_15m/track_checkpoint_gantry_v1.glb"
	if not finish and ResourceLoader.exists(glb_path):
		var packed: PackedScene = load(glb_path) as PackedScene
		if packed != null:
			var glb := packed.instantiate() as Node3D
			if glb != null:
				glb.name = "Checkpoint_%d" % index
				_strip_col(glb)
				_attach_cp_area(glb, road_w, finish, index)
				var lab := Label3D.new()
				lab.text = "CP %d" % (index + 1)
				lab.position = Vector3(0.0, 4.55, 0.0)
				lab.font_size = 48
				lab.modulate = Color("#7ad0c8")
				lab.outline_size = 8
				glb.add_child(lab)
				return glb
	var root := Node3D.new()
	root.name = "Checkpoint_%d" % index
	var color := Color("#f0c43a") if finish else Color("#7ad0c8")
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 0.55
	var half := road_w * 0.5 + 0.9
	for side in [-1.0, 1.0]:
		var pole := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.22, 4.4, 0.22)
		pole.mesh = box
		pole.position = Vector3(side * half, 2.2, 0.0)
		pole.set_surface_override_material(0, mat)
		root.add_child(pole)
	var bar := MeshInstance3D.new()
	var bar_mesh := BoxMesh.new()
	bar_mesh.size = Vector3(road_w + 1.8, 0.18, 0.18)
	bar.mesh = bar_mesh
	bar.position = Vector3(0.0, 4.15, 0.0)
	bar.set_surface_override_material(0, mat)
	root.add_child(bar)
	var lab := Label3D.new()
	lab.text = "META" if finish else "CP %d" % (index + 1)
	lab.position = Vector3(0.0, 4.55, 0.0)
	lab.font_size = 48
	lab.modulate = color
	lab.outline_size = 8
	root.add_child(lab)
	var area := Area3D.new()
	area.collision_layer = 0
	area.collision_mask = 2
	area.monitoring = true
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(road_w + 2.0, 5.0, 3.2)
	col.shape = shape
	col.position = Vector3(0, 2.4, 0)
	area.add_child(col)
	root.add_child(area)
	root.set_meta("cp_area", area)
	root.set_meta("cp_finish", finish)
	root.set_meta("cp_index", index)
	return root


static func _attach_cp_area(root: Node3D, road_w: float, finish: bool, index: int) -> void:
	var area := Area3D.new()
	area.collision_layer = 0
	area.collision_mask = 2
	area.monitoring = true
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(road_w + 2.0, 5.0, 3.2)
	col.shape = shape
	col.position = Vector3(0, 2.4, 0)
	area.add_child(col)
	root.add_child(area)
	root.set_meta("cp_area", area)
	root.set_meta("cp_finish", finish)
	root.set_meta("cp_index", index)


static func _strip_col(node: Node) -> void:
	if node is CollisionObject3D:
		(node as CollisionObject3D).collision_layer = 0
		(node as CollisionObject3D).collision_mask = 0
	if node is CollisionShape3D:
		(node as CollisionShape3D).disabled = true
	for child in node.get_children():
		_strip_col(child)
