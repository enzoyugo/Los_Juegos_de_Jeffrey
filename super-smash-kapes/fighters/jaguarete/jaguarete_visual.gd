class_name JaguareteVisual
extends "res://scripts/fighters/fighter_visual.gd"

const FUR := Color("#d89a2d")
const FUR_DARK := Color("#1b1b1b")
const CREAM := Color("#f5e8c8")
const RED := Color("#d93b35")
const BLUE := Color("#2875b9")
const WHITE := Color("#f5f0df")
const CLAW := Color("#efe2c8")

var body_pivot: Node3D
var torso: MeshInstance3D
var head: Node3D
var tail_root: Node3D
var tail_segments: Array[Node3D] = []
var arm_l: Node3D
var arm_r: Node3D
var leg_l: Node3D
var leg_r: Node3D
var _materials: Array[StandardMaterial3D] = []

func _ready() -> void:
	body_pivot = Node3D.new()
	body_pivot.name = "BodyPivot"
	add_child(body_pivot)
	_build_body()
	_build_head()
	_build_limbs()
	_build_tail()
	_build_accessories()
	_add_spots(body_pivot, 14, 1.15)

func _build_body() -> void:
	var torso_mesh := CapsuleMesh.new()
	torso_mesh.radius = 0.34
	torso_mesh.height = 0.72
	torso = _mesh_instance(torso_mesh, _mat_fur(), body_pivot, Transform3D(Basis.IDENTITY, Vector3(0.0, 0.92, 0.0)))
	var belly_mesh := SphereMesh.new()
	belly_mesh.radius = 0.28
	belly_mesh.height = 0.56
	_mesh_instance(belly_mesh, _mat(CREAM, 0.55), body_pivot, Transform3D(Basis.IDENTITY, Vector3(0.0, 0.78, 0.12)))

func _build_head() -> void:
	head = Node3D.new()
	head.position = Vector3(0.0, 1.34, 0.0)
	body_pivot.add_child(head)
	var skull := SphereMesh.new()
	skull.radius = 0.34
	skull.height = 0.68
	_mesh_instance(skull, _mat_fur(), head, Transform3D(Basis.IDENTITY, Vector3(0.0, 0.08, 0.0)))
	var muzzle := SphereMesh.new()
	muzzle.radius = 0.18
	muzzle.height = 0.36
	_mesh_instance(muzzle, _mat(CREAM, 0.52), head, Transform3D(Basis.IDENTITY, Vector3(0.0, -0.04, 0.24)))
	var nose := SphereMesh.new()
	nose.radius = 0.05
	_mesh_instance(nose, _mat(Color.BLACK, 0.25), head, Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, 0.36)))
	for side in [-1.0, 1.0]:
		var ear := _mesh_instance(SphereMesh.new(), _mat_fur(), head, Transform3D(Basis.IDENTITY, Vector3(0.18 * side, 0.28, -0.04)))
		(ear.mesh as SphereMesh).radius = 0.08
	_mesh_instance(SphereMesh.new(), _mat(WHITE, 0.2), head, Transform3D(Basis.IDENTITY, Vector3(-0.12, 0.12, 0.28))).mesh.radius = 0.07
	_mesh_instance(SphereMesh.new(), _mat(WHITE, 0.2), head, Transform3D(Basis.IDENTITY, Vector3(0.12, 0.12, 0.28))).mesh.radius = 0.07
	_mesh_instance(SphereMesh.new(), _mat(Color.BLACK, 0.1), head, Transform3D(Basis.IDENTITY, Vector3(-0.12, 0.12, 0.33))).mesh.radius = 0.025
	_mesh_instance(SphereMesh.new(), _mat(Color.BLACK, 0.1), head, Transform3D(Basis.IDENTITY, Vector3(0.12, 0.12, 0.33))).mesh.radius = 0.025
	var hair := BoxMesh.new()
	hair.size = Vector3(0.12, 0.08, 0.08)
	_mesh_instance(hair, _mat(FUR_DARK, 0.4), head, Transform3D(Basis.IDENTITY, Vector3(0.0, 0.34, -0.02)))
	var fang_l := _mesh_instance(CylinderMesh.new(), _mat(WHITE, 0.2), head, Transform3D(Basis.IDENTITY, Vector3(-0.06, -0.08, 0.30)))
	(fang_l.mesh as CylinderMesh).top_radius = 0.015
	(fang_l.mesh as CylinderMesh).bottom_radius = 0.02
	(fang_l.mesh as CylinderMesh).height = 0.08
	fang_l.rotation.x = 0.4
	var fang_r := fang_l.duplicate() as MeshInstance3D
	fang_r.position.x = 0.06
	head.add_child(fang_r)

func _build_limbs() -> void:
	arm_l = _build_arm(Vector3(-0.42, 1.0, 0.0), -1.0)
	arm_r = _build_arm(Vector3(0.42, 1.0, 0.0), 1.0)
	leg_l = _build_leg(Vector3(-0.18, 0.52, 0.0))
	leg_r = _build_leg(Vector3(0.18, 0.52, 0.0))

func _build_arm(pos: Vector3, side: float) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	body_pivot.add_child(root)
	var upper := CapsuleMesh.new()
	upper.radius = 0.12
	upper.height = 0.34
	_mesh_instance(upper, _mat_fur(), root, Transform3D(Basis.IDENTITY, Vector3(0.0, -0.08, 0.0)))
	var paw := BoxMesh.new()
	paw.size = Vector3(0.22, 0.12, 0.26)
	var paw_node := _mesh_instance(paw, _mat(CREAM, 0.48), root, Transform3D(Basis.IDENTITY, Vector3(0.14 * side, -0.28, 0.04)))
	for i in range(3):
		var claw := _mesh_instance(CylinderMesh.new(), _mat(CLAW, 0.25), paw_node, Transform3D(Basis.IDENTITY, Vector3(-0.06 + i * 0.06, -0.05, 0.12)))
		(claw.mesh as CylinderMesh).top_radius = 0.01
		(claw.mesh as CylinderMesh).bottom_radius = 0.018
		(claw.mesh as CylinderMesh).height = 0.08
		claw.rotation.x = 0.5
	return root

func _build_leg(pos: Vector3) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	body_pivot.add_child(root)
	var upper := CapsuleMesh.new()
	upper.radius = 0.13
	upper.height = 0.34
	_mesh_instance(upper, _mat_fur(), root, Transform3D(Basis.IDENTITY, Vector3(0.0, -0.12, 0.0)))
	var foot := BoxMesh.new()
	foot.size = Vector3(0.24, 0.10, 0.30)
	var foot_node := _mesh_instance(foot, _mat(CREAM, 0.48), root, Transform3D(Basis.IDENTITY, Vector3(0.0, -0.34, 0.05)))
	for i in range(3):
		var claw := _mesh_instance(CylinderMesh.new(), _mat(CLAW, 0.25), foot_node, Transform3D(Basis.IDENTITY, Vector3(-0.06 + i * 0.06, -0.04, 0.12)))
		(claw.mesh as CylinderMesh).top_radius = 0.012
		(claw.mesh as CylinderMesh).bottom_radius = 0.018
		(claw.mesh as CylinderMesh).height = 0.07
		claw.rotation.x = 0.55
	return root

func _build_tail() -> void:
	tail_root = Node3D.new()
	tail_root.position = Vector3(0.0, 0.72, -0.28)
	body_pivot.add_child(tail_root)
	var last := tail_root
	for index in range(3):
		var segment := Node3D.new()
		segment.position = Vector3(0.0, 0.0, -0.18 - index * 0.08)
		last.add_child(segment)
		var mesh := CapsuleMesh.new()
		mesh.radius = 0.08 - index * 0.015
		mesh.height = 0.22
		_mesh_instance(mesh, _mat_fur() if index < 2 else _mat(FUR_DARK, 0.45), segment)
		tail_segments.append(segment)
		last = segment

func _build_accessories() -> void:
	var sash := BoxMesh.new()
	sash.size = Vector3(0.78, 0.08, 0.18)
	var sash_node := _mesh_instance(sash, _mat(RED, 0.62), body_pivot, Transform3D(Basis.IDENTITY, Vector3(0.0, 0.95, 0.18)))
	sash_node.rotation.y = 0.45
	_mesh_instance(BoxMesh.new(), _mat(WHITE, 0.62), sash_node).mesh.size = Vector3(0.18, 0.09, 0.19)
	_mesh_instance(BoxMesh.new(), _mat(BLUE, 0.62), sash_node, Transform3D(Basis.IDENTITY, Vector3(0.22, 0.0, 0.0))).mesh.size = Vector3(0.16, 0.09, 0.19)
	var badge := CylinderMesh.new()
	badge.top_radius = 0.08
	badge.height = 0.03
	_mesh_instance(badge, _mat(BLUE, 0.35), body_pivot, Transform3D(Basis.IDENTITY, Vector3(-0.18, 0.88, 0.24)))
	for side in [-1.0, 1.0]:
		var band := BoxMesh.new()
		band.size = Vector3(0.12, 0.06, 0.12)
		_mesh_instance(band, _mat(RED, 0.62), body_pivot, Transform3D(Basis.IDENTITY, Vector3(0.34 * side, 0.98, 0.0)))

func _add_spots(parent: Node3D, count: int, radius: float) -> void:
	for index in range(count):
		var spot := SphereMesh.new()
		spot.radius = 0.035 + (index % 3) * 0.01
		var node := _mesh_instance(spot, _mat(FUR_DARK, 0.35), parent)
		var angle := float(index) / float(count) * TAU
		node.position = Vector3(cos(angle) * radius * 0.35, 0.85 + sin(angle * 2.0) * 0.18, sin(angle) * radius * 0.25)

func _apply_motion(delta: float) -> void:
	super._apply_motion(delta)
	if arm_l == null:
		return
	var swing := sin(fighter.visual_time * 9.0) * 0.22 if _state_label == "RUN" else 0.0
	arm_l.rotation.z = 0.35 + swing
	arm_r.rotation.z = -0.35 - swing
	if _state_label == "ATTACK":
		arm_r.rotation.z = -1.1 * facing
	elif _state_label == "HITSTUN":
		head.rotation.z = -0.2 * facing
	if tail_root != null:
		var tail_wave := sin(fighter.visual_time * 7.0) * 0.12
		tail_root.rotation.y = tail_wave
		for index in tail_segments.size():
			tail_segments[index].rotation.y = tail_wave * (index + 1) * 0.6
	if _state_label == "AIR":
		leg_l.rotation.x = -0.45
		leg_r.rotation.x = 0.35
	else:
		leg_l.rotation.x = 0.0
		leg_r.rotation.x = 0.0

func _apply_hit_flash() -> void:
	for material in _materials:
		if _hit_flash_time > 0.0:
			material.emission_enabled = true
			material.emission = Color("#ffdca0")
			material.emission_energy_multiplier = 0.9
		else:
			material.emission_enabled = false

func _mat_fur() -> StandardMaterial3D:
	return _mat(FUR, 0.58)

func _mat(color: Color, roughness: float, metallic: float = 0.0) -> StandardMaterial3D:
	var material := _make_material(color, roughness, metallic)
	_materials.append(material)
	return material
