class_name ZombiesParking
extends RefCounted

## Shopping del Sol parking from Street View / photo authority.
## Gameplay collision stays on the combat pad. Visual world extends beyond it.

const Config := preload("res://scripts/zombies/zombies_config.gd")
const Kit := preload("res://scripts/zombies/zombies_visual_kit.gd")

const PSX_PATH := "res://assets/environments/shopping_del_sol/processed/psx_industrial_pack.glb"


static func add_lot(parent: Node, nav: Node, visuals: bool = true) -> Dictionary:
	Kit.ensure()
	## Combat / nav asphalt (kept bounded).
	Kit.floor_body(nav, Vector3(0, -0.5, 26.0), Vector3(48, 1, 34), Kit.asphalt_mat())
	Kit.floor_body(nav, Vector3(0, -0.5, 8.9), Vector3(6.2, 1, 2.4), Kit.asphalt_mat())
	if visuals:
		## Visual lot extension (no extra nav).
		Kit.mesh_box(parent, Vector3(0, -0.52, 26.0), Vector3(78, 0.96, 52), Kit.asphalt_mat())
		Kit.mesh_box(parent, Vector3(-38.0, -0.52, 22.0), Vector3(22, 0.96, 40), Kit.asphalt_mat())
		Kit.mesh_box(parent, Vector3(38.0, -0.52, 22.0), Vector3(22, 0.96, 40), Kit.asphalt_mat())
		_add_plaza(parent)
		_add_stalls(parent)
		_add_islands_and_trees(parent)
		_add_lamps(parent)
		_add_cars(parent)
		_add_entrance_dressing(parent)
		_add_industrial(parent)
		Kit.add_skyline(parent)
		Kit.add_street_edge(parent)
	_add_boundaries(parent)
	var spawns: Array[Vector3] = [
		Vector3(-16.5, 0.05, 36.0),
		Vector3(16.5, 0.05, 36.5),
		Vector3(-18.0, 0.05, 22.0),
		Vector3(18.0, 0.05, 21.5),
		Vector3(-10.0, 0.05, 39.5),
		Vector3(10.0, 0.05, 39.0),
		Vector3(0.0, 0.05, 40.5),
		Vector3(-20.5, 0.05, 30.0),
		Vector3(20.5, 0.05, 29.5),
	]
	return {"spawns": spawns}


static func _add_plaza(parent: Node) -> void:
	## Pedestrian approach: tan tiles + darker zigzag, then white crosswalk.
	Kit.mesh_box(parent, Vector3(0, 0.015, 10.8), Vector3(12.0, 0.03, 4.6), Kit.plaza_mat())
	for i in 7:
		var x: float = -3.6 + float(i) * 1.2
		Kit.mesh_box(parent, Vector3(x, 0.022, 10.8), Vector3(0.55, 0.02, 4.2), Kit.color_mat(Kit.PLAZA_DARK, 0.8))
	for i in 6:
		Kit.mesh_box(parent, Vector3(-2.4 + float(i) * 0.95, 0.03, 9.35), Vector3(0.48, 0.02, 1.7), Kit.line_mat())


static func _add_stalls(parent: Node) -> void:
	## Center two-lane aisle with dashed divider (refs: drive toward entrance).
	for z in range(14, 42, 3):
		Kit.mesh_box(parent, Vector3(0, 0.025, float(z)), Vector3(0.18, 0.02, 1.4), Kit.line_mat())
	## Stall rows left / right of the aisle.
	for side in [-1.0, 1.0]:
		var x0: float = side * 8.2
		for i in 9:
			var z: float = 13.2 + float(i) * 3.15
			Kit.mesh_box(parent, Vector3(x0, 0.022, z), Vector3(4.8, 0.02, 0.08), Kit.line_mat())
			Kit.mesh_box(parent, Vector3(x0 + side * 2.4, 0.022, z + 1.5), Vector3(0.08, 0.02, 3.0), Kit.line_mat())
		## Outer row.
		var x1: float = side * 16.4
		for i in 8:
			var z2: float = 14.0 + float(i) * 3.15
			Kit.mesh_box(parent, Vector3(x1, 0.022, z2), Vector3(4.4, 0.02, 0.08), Kit.line_mat())
	for z in [18.0, 26.0, 34.0]:
		Kit.mesh_box(parent, Vector3(0.0, 0.03, z), Vector3(0.35, 0.02, 1.15), Kit.line_mat())
		Kit.mesh_box(parent, Vector3(0.0, 0.03, z - 0.55), Vector3(0.72, 0.02, 0.28), Kit.line_mat())


static func _add_islands_and_trees(parent: Node) -> void:
	## Structured green islands between aisle and stalls (not a forest).
	for z in [16.5, 24.5, 32.5, 40.0]:
		Kit.add_island(parent, Vector3(-5.6, 0, z), Vector3(1.5, 0.24, 5.2))
		Kit.add_island(parent, Vector3(5.6, 0, z), Vector3(1.5, 0.24, 5.2))
		Kit.add_palm(parent, Vector3(-5.6, 0, z), 5.4 + fmod(z, 3.0) * 0.15)
		Kit.add_palm(parent, Vector3(5.6, 0, z), 5.7 + fmod(z, 2.0) * 0.12)
	for z in [18.0, 28.0, 38.0]:
		Kit.add_island(parent, Vector3(-21.5, 0, z), Vector3(1.8, 0.24, 6.0))
		Kit.add_island(parent, Vector3(21.5, 0, z), Vector3(1.8, 0.24, 6.0))
		Kit.add_tree(parent, Vector3(-21.5, 0, z))
		Kit.add_palm(parent, Vector3(21.5, 0, z), 6.2)
	## Entrance planters.
	Kit.add_island(parent, Vector3(-3.4, 0, 12.2), Vector3(1.8, 0.24, 1.4))
	Kit.add_island(parent, Vector3(3.4, 0, 12.2), Vector3(1.8, 0.24, 1.4))
	Kit.add_palm(parent, Vector3(-3.4, 0, 12.2), 4.8)
	Kit.add_palm(parent, Vector3(3.4, 0, 12.2), 5.0)


static func _add_lamps(parent: Node) -> void:
	for pos in [
		Vector3(-5.6, 0, 16.5), Vector3(5.6, 0, 16.5),
		Vector3(-5.6, 0, 28.5), Vector3(5.6, 0, 28.5),
		Vector3(-5.6, 0, 40.0), Vector3(5.6, 0, 40.0),
		Vector3(-21.5, 0, 22.0), Vector3(21.5, 0, 22.0),
		Vector3(-21.5, 0, 34.0), Vector3(21.5, 0, 34.0),
	]:
		Kit.add_lamp(parent, pos, true)


static func _add_cars(parent: Node) -> void:
	## Varied density: not every stall. Combat aisle stays open.
	var parked: Array = [
		[Vector3(-8.4, 0, 14.6), 0.04, "suv", 0, true],
		[Vector3(-8.2, 0, 17.8), -0.03, "sedan", 1, true],
		[Vector3(-8.5, 0, 24.2), 0.06, "pickup", 2, true],
		[Vector3(-8.3, 0, 27.4), 0.02, "suv", 6, true],
		[Vector3(-8.6, 0, 33.8), -0.05, "sedan", 3, true],
		[Vector3(-16.6, 0, 16.0), 0.1, "suv", 4, true],
		[Vector3(-16.4, 0, 22.4), -0.08, "sedan", 7, true],
		[Vector3(-16.8, 0, 31.6), 0.05, "pickup", 5, true],
		[Vector3(8.5, 0, 15.0), 3.18, "sedan", 0, true],
		[Vector3(8.3, 0, 21.4), 3.10, "suv", 2, true],
		[Vector3(8.6, 0, 24.6), 3.20, "pickup", 1, true],
		[Vector3(8.4, 0, 30.8), 3.08, "suv", 6, true],
		[Vector3(8.7, 0, 37.2), 3.16, "sedan", 4, true],
		[Vector3(16.5, 0, 18.2), -1.52, "suv", 3, true],
		[Vector3(16.8, 0, 27.0), -1.58, "sedan", 7, true],
		[Vector3(16.4, 0, 35.4), -1.48, "pickup", 5, true],
		## Distant visual-only fill.
		[Vector3(-28.0, 0, 20.0), 0.2, "suv", 1, false],
		[Vector3(-28.4, 0, 26.5), 0.05, "sedan", 2, false],
		[Vector3(-27.6, 0, 33.0), -0.1, "suv", 0, false],
		[Vector3(28.2, 0, 19.5), 3.2, "pickup", 4, false],
		[Vector3(27.8, 0, 28.8), 3.05, "suv", 6, false],
		[Vector3(28.5, 0, 36.2), 3.14, "sedan", 3, false],
		[Vector3(-12.0, 0, 44.5), 1.55, "suv", 7, false],
		[Vector3(11.5, 0, 45.0), -1.58, "sedan", 1, false],
	]
	for row in parked:
		Kit.add_car(parent, row[0], float(row[1]), str(row[2]), int(row[3]), bool(row[4]))


static func _add_entrance_dressing(parent: Node) -> void:
	## Glass arch + canopy — the landmark from spawn.
	var cream := Kit.color_mat(Kit.CREAM, 0.55)
	var facade := Kit.color_mat(Kit.FACADE, 0.72)
	var dark := Kit.color_mat(Kit.FACADE_DARK, 0.7)
	Kit.mesh_box(parent, Vector3(0, 5.6, 8.55), Vector3(7.4, 0.35, 1.8), cream)
	Kit.mesh_box(parent, Vector3(-3.6, 3.2, 8.55), Vector3(0.45, 6.4, 1.4), cream)
	Kit.mesh_box(parent, Vector3(3.6, 3.2, 8.55), Vector3(0.45, 6.4, 1.4), cream)
	Kit.mesh_box(parent, Vector3(0, 3.4, 8.72), Vector3(6.6, 5.6, 0.12), Kit.glass_mat())
	## Circular sunburst disc above the doors.
	Kit.mesh_box(parent, Vector3(0, 6.35, 8.85), Vector3(1.6, 1.6, 0.18), Kit.color_mat(Color("#d4a017"), 0.35))
	Kit.mesh_box(parent, Vector3(0, 4.9, 9.4), Vector3(8.2, 0.12, 2.4), cream)
	## Facade wings (code-built; GLB is identity-unusable at this scale).
	Kit.box(parent, Vector3(-14.5, 5.2, 8.7), Vector3(18.0, 10.4, 1.6), facade, true)
	Kit.box(parent, Vector3(14.5, 5.2, 8.7), Vector3(18.0, 10.4, 1.6), facade, true)
	Kit.mesh_box(parent, Vector3(-14.5, 9.6, 9.45), Vector3(16.0, 1.4, 0.35), dark)
	Kit.mesh_box(parent, Vector3(14.5, 9.6, 9.45), Vector3(16.0, 1.4, 0.35), dark)
	var win := Kit.glass_mat()
	for side in [-1.0, 1.0]:
		for i in 4:
			Kit.mesh_box(parent, Vector3(side * (8.2 + float(i) * 3.2), 6.4, 9.52), Vector3(2.4, 2.2, 0.08), win)
			Kit.mesh_box(parent, Vector3(side * (8.2 + float(i) * 3.2), 3.4, 9.52), Vector3(2.4, 1.8, 0.08), win)
	## Warm facade uplights.
	_spot(parent, Vector3(-10.0, 0.4, 10.2), Vector3(-55, 0, 0), 2.2)
	_spot(parent, Vector3(10.0, 0.4, 10.2), Vector3(-55, 0, 0), 2.2)
	_spot(parent, Vector3(0.0, 1.2, 11.0), Vector3(-40, 0, 0), 1.8)


static func _spot(parent: Node, pos: Vector3, rot_deg: Vector3, energy: float) -> void:
	var s := SpotLight3D.new()
	s.position = pos
	s.rotation_degrees = rot_deg
	s.light_energy = energy
	s.light_color = Color("#ffd4a0")
	s.spot_range = 16.0
	s.spot_angle = 42.0
	s.shadow_enabled = false
	parent.add_child(s)


static func _add_boundaries(parent: Node) -> void:
	## Soft edge, not a brown box. Low walls + planters; visual world continues.
	Kit.box(parent, Vector3(0, 0.45, 44.8), Vector3(52, 0.9, 0.35), Kit.color_mat(Kit.CURB, 0.85), true)
	Kit.box(parent, Vector3(-24.6, 0.55, 26.0), Vector3(0.35, 1.1, 36.0), Kit.color_mat(Kit.CURB, 0.85), true)
	Kit.box(parent, Vector3(24.6, 0.55, 26.0), Vector3(0.35, 1.1, 36.0), Kit.color_mat(Kit.CURB, 0.85), true)
	for i in 5:
		Kit.mesh_box(parent, Vector3(-24.2, 0.7, 14.0 + float(i) * 6.0), Vector3(0.12, 1.4, 0.12), Kit.METAL_MAT())
		Kit.mesh_box(parent, Vector3(24.2, 0.7, 14.0 + float(i) * 6.0), Vector3(0.12, 1.4, 0.12), Kit.METAL_MAT())


static func _add_industrial(parent: Node) -> void:
	var placed := 0
	if ResourceLoader.exists(PSX_PATH):
		var packed: PackedScene = load(PSX_PATH) as PackedScene
		if packed != null:
			var inst := packed.instantiate()
			inst.visible = false
			parent.add_child(inst)
			placed += 1 if _place_named(parent, inst, "Crate", Vector3(-22.8, 0, 14.5), 0.0) else 0
			placed += 1 if _place_named(parent, inst, "CrateWood", Vector3(-22.5, 0, 12.8), 0.4) else 0
			placed += 1 if _place_named(parent, inst, "BarrelOil", Vector3(22.6, 0, 13.5), 0.2) else 0
			placed += 1 if _place_named(parent, inst, "Dumpster", Vector3(22.2, 0, 40.5), 0.1) else 0
			placed += 1 if _place_named(parent, inst, "CargoContainer", Vector3(-22.4, 0, 40.2), 1.57) else 0
			inst.queue_free()
	if placed > 0:
		return
	Kit.box(parent, Vector3(-22.8, 0.55, 14.5), Vector3(1.1, 1.1, 1.1), Kit.color_mat(Color("#6a5040"), 0.85), true)


static func _place_named(parent: Node, tree: Node, wanted: String, pos: Vector3, yaw: float) -> bool:
	var src := _find_named(tree, wanted)
	if src == null or not (src is Node3D):
		return false
	var clone := (src as Node3D).duplicate()
	clone.visible = true
	parent.add_child(clone)
	clone.global_position = pos
	clone.rotation.y = yaw
	var body := StaticBody3D.new()
	body.collision_layer = Config.LAYER_WORLD
	body.collision_mask = 0
	body.position = pos
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.4, 1.2, 1.4)
	col.shape = shape
	col.position = Vector3(0, 0.6, 0)
	body.add_child(col)
	parent.add_child(body)
	return true


static func _find_named(node: Node, wanted: String) -> Node:
	if node.name == wanted:
		return node
	for child in node.get_children():
		var found := _find_named(child, wanted)
		if found != null:
			return found
	return null
