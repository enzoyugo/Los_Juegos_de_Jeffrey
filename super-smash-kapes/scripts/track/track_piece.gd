class_name TrackPiece
extends Node3D

## Visual + collision wrapper for one generated module. No gameplay generator logic.

const Registry := preload("res://scripts/track/track_piece_registry.gd")
const ContractScript := preload("res://scripts/track/track_piece_geometry_contract_v1.gd")

@export var piece_id: String = ""
@export var kit_dir: String = ""
@export var show_debug: bool = false

var contract
var meta: Dictionary = {}
var visual_root: Node3D
var collision_root: Node3D
var debug_root: Node3D
var entry: Node3D
var exit: Node3D
var player_spawn: Node3D
var finish_anchor: Node3D
var finish_area: Area3D
var boost_area: Area3D
## Dev toggle (B). Shared by BASELINE and 4WHEEL. Does not remove the Area3D.
static var boost_gameplay_enabled: bool = true


func _ready() -> void:
	if piece_id.is_empty():
		return
	_ensure_roots()
	_load_meta()
	_mount_visual()
	_find_markers()
	_normalize_entry()
	_build_collision()
	_apply_shared_materials(visual_root)
	_build_finish_trigger()
	_build_boost_trigger()
	_build_debug()
	set_debug_visible(show_debug)


func entry_local() -> Transform3D:
	if entry == null:
		return Transform3D.IDENTITY
	return global_transform.affine_inverse() * entry.global_transform


func exit_global() -> Transform3D:
	if exit == null:
		return global_transform
	return exit.global_transform


func entry_global() -> Transform3D:
	if entry == null:
		return global_transform
	return entry.global_transform


func align_entry_to(target: Transform3D) -> void:
	var local_entry := entry_local()
	global_transform = target * local_entry.affine_inverse()


func set_debug_visible(on: bool) -> void:
	show_debug = on
	if debug_root != null:
		debug_root.visible = on
	if collision_root != null:
		for child in collision_root.get_children():
			var dbg = child.get_node_or_null("DebugMesh")
			if dbg != null:
				dbg.visible = on


func _ensure_roots() -> void:
	visual_root = get_node_or_null("VisualRoot") as Node3D
	if visual_root == null:
		visual_root = Node3D.new()
		visual_root.name = "VisualRoot"
		add_child(visual_root)
	collision_root = get_node_or_null("CollisionRoot") as Node3D
	if collision_root == null:
		collision_root = Node3D.new()
		collision_root.name = "CollisionRoot"
		add_child(collision_root)
	debug_root = get_node_or_null("DebugRoot") as Node3D
	if debug_root == null:
		debug_root = Node3D.new()
		debug_root.name = "DebugRoot"
		add_child(debug_root)


func _mount_visual() -> void:
	if bool(meta.get("procedural", false)) or piece_id.begins_with("slope_") or piece_id.begins_with("crest_"):
		_build_procedural_visual()
		return
	var path := Registry.glb_path(piece_id, kit_dir)
	if not ResourceLoader.exists(path) and not FileAccess.file_exists(path):
		push_error("[TRACK_PIECE] missing %s" % path)
		return
	var packed: PackedScene = load(path) as PackedScene
	if packed == null:
		push_error("[TRACK_PIECE] failed load %s" % path)
		return
	var inst := packed.instantiate()
	inst.name = "ImportedPiece"
	visual_root.add_child(inst)


func _build_procedural_visual() -> void:
	var asphalt = load(Registry.ASPHALT)
	var shoulder = load(Registry.SHOULDER)
	var rail = load(Registry.GUARDRAIL)
	var boxes: Array = meta.get("collision", [])
	for item in boxes:
		if not (item is Dictionary):
			continue
		var box_d: Dictionary = item
		var kind := str(box_d.get("kind", "road"))
		var origin = box_d.get("origin", [0.0, 0.0, 0.0])
		var yaw := float(box_d.get("yaw", 0.0))
		var pitch := float(box_d.get("pitch", 0.0))
		var size_v = box_d.get("size", [11.0, 0.12, 2.0])
		var mesh := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(float(size_v[0]), float(size_v[1]), float(size_v[2]))
		mesh.mesh = box
		mesh.transform = Transform3D(Basis.from_euler(Vector3(pitch, yaw, 0.0)), Vector3(float(origin[0]), float(origin[1]), float(origin[2])))
		var mat = asphalt
		if kind == "shoulder":
			mat = shoulder
		elif kind == "rail":
			mat = rail
		if mat is Material:
			mesh.set_surface_override_material(0, mat)
		visual_root.add_child(mesh)


func _load_meta() -> void:
	meta = Registry.meta(piece_id, kit_dir)
	contract = ContractScript.new()
	contract.piece_id = piece_id
	contract.piece_family = str(meta.get("family", "core"))
	contract.road_width = float(meta.get("road_width", ContractScript.ROAD_WIDTH))
	contract.shoulder_width = float(meta.get("shoulder_width", ContractScript.SHOULDER_WIDTH))
	contract.centerline_length = float(meta.get("centerline_length", 0.0))
	contract.height_delta = float(meta.get("height_delta", 0.0))
	contract.yaw_delta = float(meta.get("yaw_delta", 0.0))
	contract.left_guardrail = bool(meta.get("left_guardrail", true))
	contract.right_guardrail = bool(meta.get("right_guardrail", true))
	contract.estimated_traversal_time = float(meta.get("estimated_traversal_time", 0.5))
	contract.difficulty = str(meta.get("difficulty", "tranqui"))
	var exit_d: Dictionary = meta.get("exit", {})
	var origin = exit_d.get("origin", [0.0, 0.0, 0.0])
	if origin is Array and origin.size() >= 3:
		contract.exit_forward = Basis.from_euler(Vector3(0.0, float(exit_d.get("yaw", 0.0)), 0.0)) * Vector3(0, 0, -1)


func _find_markers() -> void:
	entry = _find_named(self, "ENTRY") as Node3D
	exit = _find_named(self, "EXIT") as Node3D
	player_spawn = _find_named(self, "PLAYER_SPAWN") as Node3D
	finish_anchor = _find_named(self, "FINISH_TRIGGER_ANCHOR") as Node3D
	if entry == null:
		entry = Marker3D.new()
		entry.name = "ENTRY"
		add_child(entry)
	if exit == null:
		exit = Marker3D.new()
		exit.name = "EXIT"
		var exit_d: Dictionary = meta.get("exit", {})
		var origin = exit_d.get("origin", [0.0, 0.0, 0.0])
		if origin is Array and origin.size() >= 3:
			exit.position = Vector3(float(origin[0]), float(origin[1]), float(origin[2]))
			exit.rotation.y = float(exit_d.get("yaw", 0.0))
			exit.rotation.x = float(exit_d.get("pitch", 0.0))
		add_child(exit)
	var entry_d: Dictionary = meta.get("entry", {})
	if entry != null and float(entry_d.get("pitch", 0.0)) != 0.0 and absf(entry.rotation.x) < 0.0001:
		entry.rotation.x = float(entry_d.get("pitch", 0.0))
	if player_spawn == null and str(meta.get("type", "")) == "start":
		player_spawn = Marker3D.new()
		player_spawn.name = "PLAYER_SPAWN"
		player_spawn.position = Vector3(0.0, 1.15, -2.6)
		add_child(player_spawn)
	if finish_anchor == null and str(meta.get("type", "")) == "finish":
		finish_anchor = Marker3D.new()
		finish_anchor.name = "FINISH_TRIGGER_ANCHOR"
		var length := float(meta.get("centerline_length", 8.0))
		finish_anchor.position = Vector3(0.0, 0.5, -(length - 1.5))
		add_child(finish_anchor)


func _normalize_entry() -> void:
	if entry == null or visual_root == null:
		return
	var local := global_transform.affine_inverse() * entry.global_transform
	if local.origin.length() < 0.000001 and local.basis.get_euler().length() < 0.000001:
		return
	visual_root.transform = local.affine_inverse() * visual_root.transform


func _build_collision() -> void:
	for child in collision_root.get_children():
		child.queue_free()
	var boxes: Array = meta.get("collision", [])
	var n_road := 0
	var n_rail := 0
	for item in boxes:
		if not (item is Dictionary):
			continue
		var kind := str(item.get("kind", "road"))
		var body := StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		if kind == "road":
			n_road += 1
			body.name = "RoadCollider_%02d" % n_road
		elif kind == "rail":
			n_rail += 1
			body.name = "RailCollider_%02d" % n_rail
		else:
			body.name = "%sCollider_%02d" % [kind, collision_root.get_child_count()]
		body.set_meta("track_piece_id", piece_id)
		body.set_meta("track_piece_instance", int(get_meta("track_piece_instance", 0)))
		body.set_meta("collision_kind", kind)
		body.set_meta("road_kind", kind)
		var origin = item.get("origin", [0.0, 0.0, 0.0])
		var yaw := float(item.get("yaw", 0.0))
		var pitch := float(item.get("pitch", 0.0))
		var size_v = item.get("size", [11.0, 0.12, 2.0])
		body.transform = Transform3D(Basis.from_euler(Vector3(pitch, yaw, 0.0)), Vector3(float(origin[0]), float(origin[1]), float(origin[2])))
		var col := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(float(size_v[0]), float(size_v[1]), float(size_v[2]))
		col.shape = shape
		body.add_child(col)
		var dbg := MeshInstance3D.new()
		dbg.name = "DebugMesh"
		var box := BoxMesh.new()
		box.size = shape.size
		dbg.mesh = box
		var mat := StandardMaterial3D.new()
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		if kind == "road":
			mat.albedo_color = Color(0.2, 0.85, 0.4, 0.18)
		elif kind == "rail":
			mat.albedo_color = Color(0.95, 0.45, 0.12, 0.28)
		elif kind == "shoulder":
			mat.albedo_color = Color(0.75, 0.62, 0.22, 0.22)
		elif kind == "offtrack":
			mat.albedo_color = Color(0.25, 0.55, 0.22, 0.22)
		else:
			mat.albedo_color = Color(0.55, 0.2, 0.9, 0.22)
		dbg.set_surface_override_material(0, mat)
		dbg.visible = show_debug
		body.add_child(dbg)
		collision_root.add_child(body)
	_add_seam_stitch()


func _add_seam_stitch() -> void:
	## Extra road plates at ENTRY/EXIT. Never fill intentional gaps / takeoff lips.
	if bool(meta.get("has_gap", false)) or str(meta.get("type", "")) == "gap" or piece_id == "gap_logical":
		return
	var w := float(meta.get("road_width", 15.0)) + 2.0 * float(meta.get("shoulder_width", 0.9)) + 1.2
	if str(meta.get("type", "")) != "start":
		_add_road_stitch_plate("RoadCollider_Seam", Transform3D(Basis.IDENTITY, Vector3(0.0, -0.08, 0.0)), w, 1.6)
	var skip_exit := piece_id == "ramp_takeoff" or str(meta.get("type", "")).contains("takeoff") or str(meta.get("type", "")).contains("jump")
	if exit != null and not skip_exit:
		var local_exit := global_transform.affine_inverse() * exit.global_transform
		var xf := Transform3D(local_exit.basis, local_exit.origin + Vector3(0.0, -0.08, 0.0))
		_add_road_stitch_plate("RoadCollider_SeamExit", xf, w, 1.6)


func _add_road_stitch_plate(plate_name: String, xf: Transform3D, width: float, length: float) -> void:
	var body := StaticBody3D.new()
	body.name = plate_name
	body.collision_layer = 1
	body.collision_mask = 0
	body.set_meta("track_piece_id", piece_id)
	body.set_meta("track_piece_instance", int(get_meta("track_piece_instance", 0)))
	body.set_meta("collision_kind", "road")
	body.set_meta("road_kind", "road")
	body.transform = xf
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(width, 0.32, length)
	col.shape = shape
	body.add_child(col)
	collision_root.add_child(body)


func _build_finish_trigger() -> void:
	if str(meta.get("type", "")) != "finish":
		return
	var anchor := finish_anchor
	if anchor == null:
		return
	finish_area = Area3D.new()
	finish_area.name = "FinishTrigger"
	finish_area.monitoring = true
	finish_area.monitorable = false
	finish_area.collision_layer = 0
	finish_area.collision_mask = 2
	finish_area.transform = global_transform.affine_inverse() * anchor.global_transform
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(float(meta.get("road_width", 11.0)), 2.4, 1.6)
	col.shape = shape
	finish_area.add_child(col)
	add_child(finish_area)


func _build_boost_trigger() -> void:
	if str(meta.get("type", "")) != "boost":
		return
	boost_area = Area3D.new()
	boost_area.name = "BoostTrigger"
	boost_area.monitoring = true
	boost_area.monitorable = false
	boost_area.collision_layer = 0
	boost_area.collision_mask = 2
	var length := float(meta.get("centerline_length", 12.0))
	boost_area.position = Vector3(0.0, 1.0, -length * 0.5)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(float(meta.get("road_width", 11.0)), 2.4, maxf(length * 0.7, 4.0))
	col.shape = shape
	boost_area.add_child(col)
	boost_area.body_entered.connect(_on_boost_body)
	add_child(boost_area)
	_add_boost_chevrons()


func _add_boost_chevrons() -> void:
	var mat = load(Registry.BOOST)
	if not (mat is Material):
		return
	var length := float(meta.get("centerline_length", 12.0))
	var mesh := _chevron_mesh()
	var n := 5
	for i in n:
		var inst := MeshInstance3D.new()
		inst.name = "BoostChevron_%d" % i
		inst.mesh = mesh
		inst.position = Vector3(0.0, 0.045, -2.0 - float(i) * (length - 3.0) / float(maxi(n - 1, 1)))
		inst.set_surface_override_material(0, mat)
		add_child(inst)


func _chevron_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var nrm := Vector3.UP
	_st_tri(st, Vector3(0.0, 0.0, -0.95), Vector3(-1.15, 0.0, 0.55), Vector3(-0.28, 0.0, 0.55), nrm)
	_st_tri(st, Vector3(0.0, 0.0, -0.95), Vector3(0.28, 0.0, 0.55), Vector3(1.15, 0.0, 0.55), nrm)
	st.generate_normals()
	return st.commit()


func _st_tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, nrm: Vector3) -> void:
	st.set_normal(nrm)
	st.set_uv(Vector2(0.5, 0.0))
	st.add_vertex(a)
	st.set_normal(nrm)
	st.set_uv(Vector2(0.0, 1.0))
	st.add_vertex(b)
	st.set_normal(nrm)
	st.set_uv(Vector2(1.0, 1.0))
	st.add_vertex(c)


func rearm_boost_trigger() -> void:
	if boost_area == null:
		return
	boost_area.monitoring = false
	boost_area.set_deferred("monitoring", true)


func _on_boost_body(body: Node) -> void:
	if not boost_gameplay_enabled:
		return
	if body == null or not body.has_method("apply_track_boost"):
		return
	## Piece forward after assembly, planarized so boost cannot launch vertically.
	var fwd := -global_transform.basis.z
	fwd.y = 0.0
	if fwd.length() < 0.001:
		fwd = Vector3(0, 0, -1)
	body.call("apply_track_boost", fwd.normalized(), float(meta.get("boost_strength", 1.35)))


func _build_debug() -> void:
	for child in debug_root.get_children():
		child.queue_free()
	_axis_gizmo("EntryGizmo", entry, Color(0.2, 0.9, 0.4))
	_axis_gizmo("ExitGizmo", exit, Color(0.95, 0.35, 0.2))
	var lab := Label3D.new()
	lab.text = piece_id
	lab.position = Vector3(0.0, 2.2, -1.0)
	lab.font_size = 42
	lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	debug_root.add_child(lab)


func collision_count() -> int:
	if collision_root == null:
		return 0
	return collision_root.get_child_count()


func uses_shared_materials() -> bool:
	return _count_shared_overrides(visual_root, 0) > 0


func _count_shared_overrides(node: Node, acc: int) -> int:
	if node is MeshInstance3D:
		var mesh_inst := node as MeshInstance3D
		if mesh_inst.mesh != null:
			for i in mesh_inst.mesh.get_surface_count():
				var mat := mesh_inst.get_surface_override_material(i)
				if mat != null:
					var path := str(mat.resource_path)
					if path == Registry.ASPHALT or path == Registry.SHOULDER or path == Registry.GUARDRAIL or path == Registry.MARKER or path == Registry.BOOST:
						acc += 1
	for child in node.get_children():
		acc = _count_shared_overrides(child, acc)
	return acc


func _axis_gizmo(gname: String, marker: Node3D, color: Color) -> void:
	if marker == null:
		return
	var mesh := MeshInstance3D.new()
	mesh.name = gname
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.04
	cyl.bottom_radius = 0.04
	cyl.height = 1.4
	mesh.mesh = cyl
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mesh.set_surface_override_material(0, mat)
	debug_root.add_child(mesh)
	var local := global_transform.affine_inverse() * marker.global_transform
	mesh.transform = local
	mesh.rotate_object_local(Vector3.RIGHT, -PI * 0.5)


func _apply_shared_materials(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_inst := node as MeshInstance3D
		var key := str(node.name).to_upper()
		var path := Registry.ASPHALT
		if key.begins_with("SHOULDER"):
			path = Registry.SHOULDER
		elif key.begins_with("RAIL") or key.begins_with("GUARD"):
			path = Registry.GUARDRAIL
		elif str(meta.get("type", "")) == "boost" and (key.begins_with("MARKER") or key.begins_with("BOOST") or key.begins_with("CHEVRON")):
			path = Registry.BOOST
		elif key.begins_with("MARKER") or key.begins_with("START") or key.begins_with("FINISH"):
			path = Registry.MARKER
		var mat = load(path)
		if mat is Material and mesh_inst.mesh != null:
			for i in mesh_inst.mesh.get_surface_count():
				mesh_inst.set_surface_override_material(i, mat)
	for child in node.get_children():
		_apply_shared_materials(child)


func _find_named(node: Node, wanted: String) -> Node:
	if node.name == wanted:
		return node
	for child in node.get_children():
		var found := _find_named(child, wanted)
		if found != null:
			return found
	return null
