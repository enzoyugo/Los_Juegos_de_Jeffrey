class_name ZombiesShoppingShell
extends Node3D

## Visual exterior authority. No gameplay collision. Markers for alignment.

const SHELL_PATH := "res://assets/environments/shopping_del_sol/models/final/shopping_del_sol_exterior_v01.glb"
const FALLBACK := "res://assets/environments/shopping_del_sol/models/blockout/shopping_del_sol_blockout.glb"

var shell_loaded: bool = false
var shell_path_used: String = ""
var aabb := AABB()
var front_marker: Marker3D
var center_marker: Marker3D
var entrance_marker: Marker3D
var up_marker: Marker3D
var _inst: Node3D


func load_shell() -> bool:
	var path := SHELL_PATH
	if not ResourceLoader.exists(path) and not FileAccess.file_exists(path):
		path = FALLBACK
	if not ResourceLoader.exists(path) and not FileAccess.file_exists(path):
		push_warning("[ZOMBIES_SHELL] missing shopping glb")
		return false
	var packed: PackedScene = load(path) as PackedScene
	if packed == null:
		return false
	_inst = packed.instantiate() as Node3D
	if _inst == null:
		return false
	add_child(_inst)
	shell_path_used = path
	shell_loaded = true
	_strip_collision(_inst)
	_hide_parking(_inst)
	_clip_parking_overhang(_inst)
	aabb = _compute_aabb(_inst)
	## GLB remaining band is ~86×31×6 m with source UVs that read as giant tiles
	## and swallow spawn as a fake ceiling. Keep the node for shell_loaded + markers;
	## gameplay-readable facade is code-built terracotta / glass.
	_inst.visible = false
	_place_markers()
	print("[ZOMBIES_SHELL] loaded=%s aabb=%s size=%s" % [path, str(aabb.position), str(aabb.size)])
	return true


func _strip_collision(node: Node) -> void:
	if node is CollisionShape3D:
		(node as CollisionShape3D).disabled = true
	if node is StaticBody3D or node is AnimatableBody3D:
		(node as CollisionObject3D).collision_layer = 0
		(node as CollisionObject3D).collision_mask = 0
	var n := str(node.name)
	if n.begins_with("COL_"):
		if node is Node3D:
			(node as Node3D).visible = false
	for child in node.get_children():
		_strip_collision(child)


func _hide_parking(node: Node) -> void:
	var n := str(node.name).to_lower()
	if (
		n.contains("parking") or n.contains("stall") or n.contains("dropoff") or n.contains("drop-off")
		or n.contains("interior") or n.contains("lot") or n.contains("roof") or n.contains("floor")
		or n.contains("ground") 		or n.begins_with("sds_main") or n.begins_with("sds_rear")
		or n.begins_with("sds_wing") or n.begins_with("sds_pavilion")
		or n.contains("canopy") or n.contains("gallery")
	):
		if node is Node3D:
			(node as Node3D).visible = false
	if node is VisualInstance3D and (node as Node3D).visible:
		var a: AABB = (node as VisualInstance3D).get_aabb()
		if a.size.y < 1.2 and a.size.x > 8.0 and a.size.z > 8.0:
			(node as Node3D).visible = false
	for child in node.get_children():
		_hide_parking(child)


func _clip_parking_overhang(node: Node) -> void:
	## Y-180 puts backside modules over spawn as a fake ceiling. Keep only the facade band.
	if node is VisualInstance3D and (node as Node3D).visible:
		var vis := node as VisualInstance3D
		var local: AABB = vis.get_aabb()
		var xf: Transform3D = (node as Node3D).global_transform
		var world := AABB(xf * local.position, Vector3.ZERO)
		for i in 8:
			world = world.expand(xf * local.get_endpoint(i))
		if world.position.z + world.size.z > 12.2 or world.position.z < 6.0:
			(node as Node3D).visible = false
	for child in node.get_children():
		_clip_parking_overhang(child)


func _log_shell_tree(node: Node, depth: int) -> void:
	if depth > 3:
		return
	var extra := ""
	if node is VisualInstance3D:
		var a: AABB = (node as VisualInstance3D).get_aabb()
		extra = " aabb=%s vis=%s" % [str(a.size), str((node as Node3D).visible)]
	print("[ZOMBIES_SHELL] %s%s%s" % ["  ".repeat(depth), node.name, extra])
	for child in node.get_children():
		_log_shell_tree(child, depth + 1)


func _compute_aabb(node: Node) -> AABB:
	var first := true
	var out := AABB()
	if node is Node3D and not (node as Node3D).visible:
		return AABB()
	if node is VisualInstance3D:
		var local: AABB = (node as VisualInstance3D).get_aabb()
		var xf: Transform3D = (node as Node3D).global_transform
		var world := AABB(xf * local.position, Vector3.ZERO)
		for i in 8:
			world = world.expand(xf * local.get_endpoint(i))
		out = world
		first = false
	for child in node.get_children():
		var sub := _compute_aabb(child)
		if sub.size == Vector3.ZERO and sub.position == Vector3.ZERO:
			continue
		if first:
			out = sub
			first = false
		else:
			out = out.merge(sub)
	return out


func _place_markers() -> void:
	center_marker = _marker("SHOPPING_CENTER", aabb.get_center())
	up_marker = _marker("WORLD_UP", aabb.get_center() + Vector3(0, aabb.size.y * 0.5, 0))
	var front := Vector3(aabb.get_center().x, 0.05, aabb.position.z + aabb.size.z)
	if absf(aabb.position.z) < absf(aabb.position.z + aabb.size.z):
		front.z = aabb.position.z
	front_marker = _marker("SHOPPING_FRONT", front)
	entrance_marker = _marker("MAIN_ENTRANCE", Vector3(0.0, 0.05, 8.2))


func _marker(mname: String, pos: Vector3) -> Marker3D:
	var m := Marker3D.new()
	m.name = mname
	m.position = pos
	add_child(m)
	return m
