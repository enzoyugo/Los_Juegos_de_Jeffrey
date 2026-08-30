class_name TrackSignage
extends Node3D

## Speed-readable signs. Distinct from BOOST / START / FINISH.

const Typography := preload("res://scripts/ui/jeffrey/system/jeffrey_typography.gd")


static func decorate(parent: Node, pieces: Array) -> void:
	var root := Node3D.new()
	root.name = "Signage"
	parent.add_child(root)
	for piece in pieces:
		if piece == null or not piece.has_method("entry_global"):
			continue
		var id := str(piece.piece_id) if "piece_id" in piece else str(piece.get("piece_id"))
		var xf: Transform3D = piece.entry_global()
		if id.contains("curve_l_90") or id.contains("curve_r_90"):
			_sign(root, xf, "90°", Color("#e8d24a"), true, id.contains("_l_"))
		elif id.contains("curve_l_45") or id.contains("curve_r_45"):
			_sign(root, xf, "45°", Color("#d8c8a0"), false, id.contains("_l_"))
		elif id.contains("chicane_lr"):
			_sign(root, xf, "IZQ → DER", Color("#f0e0a8"), true, true)
		elif id.contains("chicane_rl"):
			_sign(root, xf, "DER → IZQ", Color("#f0e0a8"), true, false)
		elif id.contains("boost"):
			_sign(root, xf, "BOOST", Color("#4ad4e8"), true, false)


static func _sign(parent: Node, xf: Transform3D, text: String, color: Color, big: bool, left: bool) -> void:
	var side := -1.0 if left else 1.0
	var pos: Vector3 = xf.origin + xf.basis.x * (side * 6.4) + Vector3(0, 2.4 if big else 1.8, 0) - xf.basis.z * 4.0
	var pole := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.12, 2.6, 0.12)
	pole.mesh = box
	parent.add_child(pole)
	pole.global_position = pos + Vector3(0, -0.6, 0)
	var lab := Label3D.new()
	Typography.apply_label3d(lab, Typography.TRACK)
	lab.text = text
	lab.font_size = 72 if big else 42
	lab.modulate = color
	lab.outline_size = 8
	lab.outline_modulate = Color(0, 0, 0, 0.9)
	parent.add_child(lab)
	lab.global_position = pos + Vector3(0, 1.1, 0)
	if big:
		for k in 3:
			var chev := MeshInstance3D.new()
			var cm := BoxMesh.new()
			cm.size = Vector3(0.7, 0.12, 0.18)
			chev.mesh = cm
			var mat := StandardMaterial3D.new()
			mat.albedo_color = color
			chev.set_surface_override_material(0, mat)
			parent.add_child(chev)
			chev.global_position = xf.origin + xf.basis.x * (side * 5.4) + Vector3(0, 0.9 + float(k) * 0.35, 0) - xf.basis.z * float(k) * 1.1
