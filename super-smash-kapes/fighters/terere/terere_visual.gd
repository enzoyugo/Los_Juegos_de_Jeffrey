class_name TerereVisual
extends "res://scripts/fighters/fighter_visual.gd"

const WOOD := Color("#9a5a2d")
const WOOD_DARK := Color("#6f3f1f")
const SKIN := Color("#e7a05a")
const YERBA := Color("#4f8f3d")
const METAL := Color("#c8d2dc")
const RED := Color("#d93b35")
const BLUE := Color("#2875b9")
const WHITE := Color("#f5f0df")
const NAVY := Color("#1b2f66")

var body_pivot: Node3D
var cup: MeshInstance3D
var bombilla: MeshInstance3D
var poncho: MeshInstance3D
var arm_l: Node3D
var arm_r: Node3D
var leg_l: Node3D
var leg_r: Node3D
var face: Node3D
var _materials: Array[StandardMaterial3D] = []

func _ready() -> void:
	body_pivot = Node3D.new()
	body_pivot.name = "BodyPivot"
	add_child(body_pivot)
	_build_body()
	_build_face()
	_build_limbs()
	_build_accessories()

func _build_body() -> void:
	var cup_mesh := CylinderMesh.new()
	cup_mesh.top_radius = 0.52
	cup_mesh.bottom_radius = 0.44
	cup_mesh.height = 1.05
	cup = _mesh_instance(cup_mesh, _mat(WOOD, 0.42), body_pivot, Transform3D(Basis.IDENTITY, Vector3(0.0, 1.05, 0.0)))
	var yerba_mesh := CylinderMesh.new()
	yerba_mesh.top_radius = 0.46
	yerba_mesh.bottom_radius = 0.48
	yerba_mesh.height = 0.08
	_mesh_instance(yerba_mesh, _mat(YERBA, 0.72), body_pivot, Transform3D(Basis.IDENTITY, Vector3(0.0, 1.58, 0.0)))
	var rim_mesh := TorusMesh.new()
	rim_mesh.inner_radius = 0.44
	rim_mesh.outer_radius = 0.54
	_mesh_instance(rim_mesh, _mat(WOOD_DARK, 0.35), body_pivot, Transform3D(Basis.IDENTITY, Vector3(0.0, 1.56, 0.0)))

func _build_face() -> void:
	face = Node3D.new()
	face.position = Vector3(0.0, 1.08, 0.43)
	body_pivot.add_child(face)
	var eye_l := _mesh_instance(SphereMesh.new(), _mat(WHITE, 0.2), face, Transform3D(Basis.IDENTITY, Vector3(-0.14, 0.08, 0.0)))
	(eye_l.mesh as SphereMesh).radius = 0.09
	(eye_l.mesh as SphereMesh).height = 0.18
	var eye_r := _mesh_instance(SphereMesh.new(), _mat(WHITE, 0.2), face, Transform3D(Basis.IDENTITY, Vector3(0.14, 0.08, 0.0)))
	(eye_r.mesh as SphereMesh).radius = 0.09
	(eye_r.mesh as SphereMesh).height = 0.18
	_mesh_instance(SphereMesh.new(), _mat(Color.BLACK, 0.1), face, Transform3D(Basis.IDENTITY, Vector3(-0.14, 0.08, 0.05))).mesh.radius = 0.035
	_mesh_instance(SphereMesh.new(), _mat(Color.BLACK, 0.1), face, Transform3D(Basis.IDENTITY, Vector3(0.14, 0.08, 0.05))).mesh.radius = 0.035
	var brow_mesh := BoxMesh.new()
	brow_mesh.size = Vector3(0.34, 0.05, 0.04)
	var brow := _mesh_instance(brow_mesh, _mat(Color("#24160f"), 0.5), face, Transform3D(Basis.IDENTITY, Vector3(0.0, 0.18, 0.02)))
	brow.rotation.z = -0.18
	var mouth_mesh := BoxMesh.new()
	mouth_mesh.size = Vector3(0.24, 0.08, 0.05)
	_mesh_instance(mouth_mesh, _mat(Color("#5a2418"), 0.45), face, Transform3D(Basis.IDENTITY, Vector3(0.0, -0.08, 0.02)))

func _build_limbs() -> void:
	arm_l = _build_arm(Vector3(-0.62, 0.98, 0.0), -1.0)
	arm_r = _build_arm(Vector3(0.62, 0.98, 0.0), 1.0)
	leg_l = _build_leg(Vector3(-0.22, 0.42, 0.0))
	leg_r = _build_leg(Vector3(0.22, 0.42, 0.0))

func _build_arm(pos: Vector3, side: float) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	body_pivot.add_child(root)
	var upper := CapsuleMesh.new()
	upper.radius = 0.13
	upper.height = 0.42
	_mesh_instance(upper, _mat(SKIN, 0.48), root, Transform3D(Basis.IDENTITY, Vector3(0.0, -0.12, 0.0)))
	var hand := SphereMesh.new()
	hand.radius = 0.12
	hand.height = 0.24
	_mesh_instance(hand, _mat(SKIN, 0.48), root, Transform3D(Basis.IDENTITY, Vector3(0.16 * side, -0.34, 0.0)))
	return root

func _build_leg(pos: Vector3) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	body_pivot.add_child(root)
	var leg := CapsuleMesh.new()
	leg.radius = 0.15
	leg.height = 0.42
	_mesh_instance(leg, _mat(SKIN, 0.48), root, Transform3D(Basis.IDENTITY, Vector3(0.0, -0.18, 0.0)))
	var foot := BoxMesh.new()
	foot.size = Vector3(0.24, 0.08, 0.34)
	_mesh_instance(foot, _mat(SKIN, 0.48), root, Transform3D(Basis.IDENTITY, Vector3(0.0, -0.42, 0.05)))
	var sandal := BoxMesh.new()
	sandal.size = Vector3(0.28, 0.04, 0.38)
	_mesh_instance(sandal, _mat(NAVY, 0.35), root, Transform3D(Basis.IDENTITY, Vector3(0.0, -0.47, 0.05)))
	return root

func _build_accessories() -> void:
	var straw := CylinderMesh.new()
	straw.top_radius = 0.025
	straw.bottom_radius = 0.025
	straw.height = 0.72
	bombilla = _mesh_instance(straw, _mat(METAL, 0.15, 0.85), body_pivot, Transform3D(Basis.IDENTITY, Vector3(0.18, 1.72, 0.08)))
	bombilla.rotation.z = -0.55
	var poncho_mesh := BoxMesh.new()
	poncho_mesh.size = Vector3(0.92, 0.08, 0.72)
	poncho = _mesh_instance(poncho_mesh, _mat(RED, 0.62), body_pivot, Transform3D(Basis.IDENTITY, Vector3(0.0, 1.02, -0.08)))
	poncho.rotation.x = -0.35
	var stripe := BoxMesh.new()
	stripe.size = Vector3(0.18, 0.09, 0.74)
	_mesh_instance(stripe, _mat(WHITE, 0.62), poncho, Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, 0.0)))
	_mesh_instance(stripe, _mat(BLUE, 0.62), poncho, Transform3D(Basis.IDENTITY, Vector3(0.22, 0.0, 0.0)))

func _apply_motion(delta: float) -> void:
	super._apply_motion(delta)
	if arm_l == null or arm_r == null:
		return
	var swing := sin(fighter.visual_time * 8.0) * 0.18 if _state_label == "RUN" else 0.0
	arm_l.rotation.z = 0.25 + swing
	arm_r.rotation.z = -0.25 - swing
	if _state_label == "ATTACK":
		arm_r.rotation.z = -1.05 * facing
		arm_r.position.x = 0.68
	elif _state_label == "HITSTUN":
		arm_l.rotation.z = 0.8
		arm_r.rotation.z = -0.8
	if bombilla != null:
		bombilla.rotation.z = -0.55 + sin(fighter.visual_time * 6.0) * 0.04
	if _state_label == "AIR":
		leg_l.rotation.x = -0.35
		leg_r.rotation.x = 0.25
	else:
		leg_l.rotation.x = 0.0
		leg_r.rotation.x = 0.0

func _apply_hit_flash() -> void:
	for material in _materials:
		if _hit_flash_time > 0.0:
			material.emission_enabled = true
			material.emission = Color(1.0, 0.92, 0.72)
			material.emission_energy_multiplier = 0.8
		else:
			material.emission_enabled = false

func _mat(color: Color, roughness: float, metallic: float = 0.0) -> StandardMaterial3D:
	var material := _make_material(color, roughness, metallic)
	_materials.append(material)
	return material
