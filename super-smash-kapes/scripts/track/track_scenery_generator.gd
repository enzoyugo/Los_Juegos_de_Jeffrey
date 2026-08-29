class_name TrackSceneryGenerator
extends Node3D

## ASUNCION_URBAN_V1 sockets around generated pieces. Visual-only except camera blockers.

const Config := preload("res://scripts/track/track_config.gd")
const PSX_PATH := "res://assets/environments/shopping_del_sol/processed/psx_industrial_pack.glb"
const URBAN := "res://assets/environments/shared/urban/"

const PALM := [
	URBAN + "processed/vegetation/palm_v2_01.glb",
	URBAN + "processed/vegetation/palm_v2_02.glb",
	URBAN + "vegetation/palm_01.glb",
	URBAN + "vegetation/palm_02.glb",
]
const TREE := [
	URBAN + "processed/vegetation/tree_v2_01.glb",
	URBAN + "processed/vegetation/tree_v2_02.glb",
	URBAN + "vegetation/tree_01.glb",
	URBAN + "vegetation/tree_02.glb",
]
const LAMP := URBAN + "lighting/lamp_street.glb"
const BUILD_SMALL := [
	URBAN + "street_props/building_small_01.glb",
	URBAN + "street_props/building_small_02.glb",
	URBAN + "street_props/building_small_03.glb",
]
const BUILD_MED := [
	URBAN + "street_props/building_med_01.glb",
	URBAN + "street_props/building_med_02.glb",
]
const BILLBOARD := [
	URBAN + "street_props/billboard_01.glb",
	URBAN + "street_props/billboard_02.glb",
]
const FENCE := URBAN + "street_props/fence_01.glb"
const GRANDSTAND := URBAN + "street_props/grandstand_01.glb"
const ARCH := URBAN + "street_props/jeffrey_arch_01.glb"
const ARCH_V2 := URBAN + "processed/landmarks/jeffrey_arch_v2.glb"
const CRANE := URBAN + "street_props/crane_01.glb"
const CONTAINER := URBAN + "industrial/container_01.glb"
const CAR_PARKED := [
	URBAN + "processed/vehicles/hilux_parked.glb",
	URBAN + "processed/vehicles/vaz_parked.glb",
	URBAN + "processed/vehicles/wreck_parked.glb",
	URBAN + "vehicles/car_pickup.glb",
	URBAN + "vehicles/car_sedan.glb",
]

const CAM_LAYER := 128

var road_clearance: float = 10.4
var landmarks: Array = []


func build(pieces: Array) -> void:
	_clear()
	var i := 0
	for piece in pieces:
		if piece == null or not piece.has_method("entry_global"):
			continue
		var xf: Transform3D = piece.entry_global()
		var right: Vector3 = xf.basis.x
		var fwd: Vector3 = -xf.basis.z
		var origin: Vector3 = xf.origin
		for side_i in 2:
			var side: float = -1.0 if side_i == 0 else 1.0
			var near: Vector3 = origin + right * (side * road_clearance)
			var plant: String = _first_existing(PALM if side < 0.0 else TREE, i)
			_instance(plant, near, xf.basis.get_euler().y)
			if i % 2 == 0:
				_instance(LAMP, origin + right * (side * (road_clearance + 2.0)), xf.basis.get_euler().y)
			if i % 3 == 0:
				_instance(FENCE, origin + right * (side * (road_clearance + 4.5)) + fwd * 1.2, xf.basis.get_euler().y + (0.0 if side > 0.0 else PI))
			if i % 4 == 0:
				var bpath: String = str(BUILD_SMALL[(i / 4) % BUILD_SMALL.size()])
				_instance(bpath, origin + right * (side * (road_clearance + 12.0)) + fwd * 2.0, xf.basis.get_euler().y, true)
			if i % 5 == 0:
				var car_path: String = _first_existing(CAR_PARKED, i)
				if not car_path.is_empty():
					_instance(car_path, origin + right * (side * (road_clearance + 6.5)), xf.basis.get_euler().y + PI * 0.5)
		i += 1
	_add_skyline(pieces)
	_add_landmarks(pieces)
	_maybe_industrial(pieces)
	_add_ground(pieces)


func _instance(path: String, pos: Vector3, yaw: float, camera_block: bool = false) -> Node3D:
	if path.is_empty() or not ResourceLoader.exists(path):
		return _fallback_box(pos, Vector3(1.2, 3.0, 1.2) if not camera_block else Vector3(6, 8, 6))
	var packed: PackedScene = load(path) as PackedScene
	if packed == null:
		return _fallback_box(pos, Vector3(1.2, 3.0, 1.2))
	var n := packed.instantiate()
	if not (n is Node3D):
		n.free()
		return null
	var root := n as Node3D
	add_child(root)
	root.global_position = pos
	root.rotation.y = yaw
	_strip_gameplay_collision(root)
	if camera_block:
		_add_camera_blocker(pos, Vector3(6.0, 8.0, 6.0))
	return root


func _fallback_box(pos: Vector3, size: Vector3) -> Node3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	add_child(mi)
	mi.global_position = pos + Vector3(0, size.y * 0.5, 0)
	return mi


func _strip_gameplay_collision(node: Node) -> void:
	if node is CollisionObject3D:
		(node as CollisionObject3D).collision_layer = 0
		(node as CollisionObject3D).collision_mask = 0
	if node is CollisionShape3D:
		(node as CollisionShape3D).disabled = true
	for child in node.get_children():
		_strip_gameplay_collision(child)


func _add_camera_blocker(pos: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = CAM_LAYER
	body.collision_mask = 0
	body.position = pos + Vector3(0, size.y * 0.5, 0)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	add_child(body)


func _add_skyline(pieces: Array) -> void:
	if pieces.is_empty():
		return
	var mid = pieces[int(pieces.size() * 0.5)]
	if mid == null or not (mid is Node3D):
		return
	var c: Vector3 = (mid as Node3D).global_position
	for k in 4:
		var path: String = str(BUILD_MED[k % BUILD_MED.size()])
		var pos: Vector3 = c + Vector3(-52.0 + float(k) * 28.0, 0.0, -78.0)
		_instance(path, pos, 0.0, true)


func _add_landmarks(pieces: Array) -> void:
	landmarks.clear()
	if pieces.size() < 4:
		return
	var picks: Array = [pieces[2], pieces[int(pieces.size() * 0.45)], pieces[int(pieces.size() * 0.7)]]
	var jeffrey: String = ARCH_V2 if ResourceLoader.exists(ARCH_V2) else ARCH
	var assets: PackedStringArray = PackedStringArray([jeffrey, GRANDSTAND, CRANE])
	var labels: PackedStringArray = PackedStringArray(["JEFFREY", "GRADA", "GRUA"])
	for i in mini(picks.size(), 3):
		var piece = picks[i]
		if piece == null or not piece.has_method("entry_global"):
			continue
		var xf: Transform3D = piece.entry_global()
		var pos: Vector3 = xf.origin + xf.basis.x * (road_clearance + 16.0)
		_instance(assets[i], pos, xf.basis.get_euler().y, true)
		if i < BILLBOARD.size() and ResourceLoader.exists(BILLBOARD[i]):
			_instance(BILLBOARD[i], pos + xf.basis.x * 6.0 + xf.basis.z * -8.0, xf.basis.get_euler().y)
		landmarks.append(labels[i])


func _maybe_industrial(pieces: Array) -> void:
	if pieces.size() < 3:
		return
	var xf: Transform3D = pieces[mini(4, pieces.size() - 1)].entry_global()
	if ResourceLoader.exists(CONTAINER):
		_instance(CONTAINER, xf.origin + xf.basis.x * -(road_clearance + 14.0), xf.basis.get_euler().y)
		return
	if not ResourceLoader.exists(PSX_PATH):
		return
	var packed: PackedScene = load(PSX_PATH) as PackedScene
	if packed == null:
		return
	var inst := packed.instantiate()
	inst.visible = false
	add_child(inst)
	var src := _find_named(inst, "CargoContainer")
	if src is Node3D:
		var clone := (src as Node3D).duplicate()
		clone.visible = true
		add_child(clone)
		clone.global_position = xf.origin + xf.basis.x * -20.0
	inst.queue_free()


func _first_existing(paths: Array, seed_i: int) -> String:
	var usable: Array = []
	for p in paths:
		var s := str(p)
		if ResourceLoader.exists(s):
			usable.append(s)
	if usable.is_empty():
		return ""
	return str(usable[seed_i % usable.size()])


func _add_ground(pieces: Array) -> void:
	if pieces.is_empty():
		return
	var aabb := AABB()
	var first := true
	for p in pieces:
		if not (p is Node3D):
			continue
		if first:
			aabb = AABB((p as Node3D).global_position, Vector3.ZERO)
			first = false
		else:
			aabb = aabb.expand((p as Node3D).global_position)
	var mi := MeshInstance3D.new()
	mi.name = "UrbanGround"
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(maxf(aabb.size.x, 80.0) + 90.0, maxf(aabb.size.z, 80.0) + 90.0)
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.22, 0.28, 0.18)
	mat.roughness = 0.95
	mi.set_surface_override_material(0, mat)
	add_child(mi)
	mi.global_position = aabb.get_center() + Vector3(0, -0.04, 0)


func _find_named(node: Node, wanted: String) -> Node:
	if node.name == wanted:
		return node
	for child in node.get_children():
		var found := _find_named(child, wanted)
		if found != null:
			return found
	return null


func _clear() -> void:
	for child in get_children():
		child.queue_free()
	landmarks.clear()
