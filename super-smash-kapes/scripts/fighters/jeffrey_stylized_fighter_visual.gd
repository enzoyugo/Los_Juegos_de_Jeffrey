class_name JeffreyStylizedFighterVisual
extends "res://scripts/fighters/fighter_visual.gd"

## First-party stylized Smash visuals for catalog fighters without ActorCore GLBs.

var body_pivot: Node3D
var arm_l: Node3D
var arm_r: Node3D
var leg_l: Node3D
var leg_r: Node3D
var accent_node: Node3D
var _materials: Array[StandardMaterial3D] = []


func _ready() -> void:
	pass


func bind(fighter_ref, fighter_definition) -> void:
	super.bind(fighter_ref, fighter_definition)
	if body_pivot != null:
		return
	body_pivot = Node3D.new()
	body_pivot.name = "BodyPivot"
	add_child(body_pivot)
	var fid := str(definition.id) if definition != null else ""
	match fid:
		"cartes":
			_build_cartes()
		"fort":
			_build_fort()
		"pajaro_campana":
			_build_pajaro()
		_:
			_build_generic()


func _build_cartes() -> void:
	## Heavy silhouette: broad suit + blocky shoulders.
	var torso := BoxMesh.new()
	torso.size = Vector3(1.05, 1.15, 0.55)
	_mesh_instance(torso, _mat(Color("#243044"), 0.55), body_pivot, Transform3D(Basis.IDENTITY, Vector3(0.0, 1.15, 0.0)))
	var head := SphereMesh.new()
	head.radius = 0.34
	head.height = 0.68
	_mesh_instance(head, _mat(Color("#d2a878"), 0.48), body_pivot, Transform3D(Basis.IDENTITY, Vector3(0.0, 2.0, 0.05)))
	var sash := BoxMesh.new()
	sash.size = Vector3(1.08, 0.12, 0.58)
	_mesh_instance(sash, _mat(Color("#c62828"), 0.4), body_pivot, Transform3D(Basis.IDENTITY, Vector3(0.0, 1.35, 0.02)))
	var stripe := BoxMesh.new()
	stripe.size = Vector3(0.18, 0.14, 0.6)
	_mesh_instance(stripe, _mat(Color("#f5f0df"), 0.4), body_pivot, Transform3D(Basis.IDENTITY, Vector3(0.0, 1.35, 0.03)))
	_mesh_instance(stripe, _mat(Color("#2875b9"), 0.4), body_pivot, Transform3D(Basis.IDENTITY, Vector3(0.22, 1.35, 0.03)))
	arm_l = _limb(Vector3(-0.68, 1.35, 0.0), Color("#d2a878"), 0.16, 0.55)
	arm_r = _limb(Vector3(0.68, 1.35, 0.0), Color("#d2a878"), 0.16, 0.55)
	leg_l = _limb(Vector3(-0.28, 0.55, 0.0), Color("#1b2433"), 0.18, 0.55)
	leg_r = _limb(Vector3(0.28, 0.55, 0.0), Color("#1b2433"), 0.18, 0.55)
	accent_node = Node3D.new()
	body_pivot.add_child(accent_node)


func _build_fort() -> void:
	## Flashy medium-heavy: white jacket + gold spark accents.
	var torso := CapsuleMesh.new()
	torso.radius = 0.42
	torso.height = 1.2
	_mesh_instance(torso, _mat(Color("#f4f1ea"), 0.35), body_pivot, Transform3D(Basis.IDENTITY, Vector3(0.0, 1.2, 0.0)))
	var head := SphereMesh.new()
	head.radius = 0.32
	head.height = 0.64
	_mesh_instance(head, _mat(Color("#e8be96"), 0.45), body_pivot, Transform3D(Basis.IDENTITY, Vector3(0.0, 2.05, 0.0)))
	var glasses := TorusMesh.new()
	glasses.inner_radius = 0.18
	glasses.outer_radius = 0.26
	_mesh_instance(glasses, _mat(Color("#f0c848"), 0.2, 0.7), body_pivot, Transform3D(Basis.IDENTITY, Vector3(0.0, 2.08, 0.28)))
	var cape := BoxMesh.new()
	cape.size = Vector3(1.1, 0.9, 0.08)
	_mesh_instance(cape, _mat(Color("#f0c848"), 0.4), body_pivot, Transform3D(Basis.IDENTITY, Vector3(0.0, 1.15, -0.28)))
	arm_l = _limb(Vector3(-0.62, 1.4, 0.0), Color("#e8be96"), 0.14, 0.5)
	arm_r = _limb(Vector3(0.62, 1.4, 0.0), Color("#e8be96"), 0.14, 0.5)
	leg_l = _limb(Vector3(-0.22, 0.55, 0.0), Color("#2a2438"), 0.15, 0.5)
	leg_r = _limb(Vector3(0.22, 0.55, 0.0), Color("#2a2438"), 0.15, 0.5)
	accent_node = Node3D.new()
	body_pivot.add_child(accent_node)
	var star := SphereMesh.new()
	star.radius = 0.08
	star.height = 0.16
	_mesh_instance(star, _mat(Color("#fff2a8"), 0.2, 0.4), accent_node, Transform3D(Basis.IDENTITY, Vector3(0.0, 2.45, 0.0)))


func _build_pajaro() -> void:
	## Light/fast: bird-like body + crest.
	var body := SphereMesh.new()
	body.radius = 0.48
	body.height = 0.9
	_mesh_instance(body, _mat(Color("#f0d246"), 0.4), body_pivot, Transform3D(Basis.IDENTITY, Vector3(0.0, 1.15, 0.0)))
	var head := SphereMesh.new()
	head.radius = 0.28
	head.height = 0.56
	_mesh_instance(head, _mat(Color("#ffe27a"), 0.35), body_pivot, Transform3D(Basis.IDENTITY, Vector3(0.0, 1.85, 0.12)))
	var beak := CylinderMesh.new()
	beak.top_radius = 0.02
	beak.bottom_radius = 0.08
	beak.height = 0.28
	var beak_n := _mesh_instance(beak, _mat(Color("#e07020"), 0.4), body_pivot, Transform3D(Basis.IDENTITY, Vector3(0.0, 1.8, 0.38)))
	beak_n.rotation.x = deg_to_rad(90.0)
	var crest := BoxMesh.new()
	crest.size = Vector3(0.08, 0.28, 0.18)
	_mesh_instance(crest, _mat(Color("#c62828"), 0.4), body_pivot, Transform3D(Basis.IDENTITY, Vector3(0.0, 2.2, 0.0)))
	arm_l = _limb(Vector3(-0.55, 1.25, 0.0), Color("#c8e070"), 0.1, 0.42)
	arm_r = _limb(Vector3(0.55, 1.25, 0.0), Color("#c8e070"), 0.1, 0.42)
	leg_l = _limb(Vector3(-0.16, 0.55, 0.0), Color("#e07020"), 0.09, 0.4)
	leg_r = _limb(Vector3(0.16, 0.55, 0.0), Color("#e07020"), 0.09, 0.4)
	accent_node = Node3D.new()
	body_pivot.add_child(accent_node)


func _build_generic() -> void:
	var body := CapsuleMesh.new()
	body.radius = 0.4
	body.height = 1.2
	_mesh_instance(body, _mat(Color("#888888"), 0.5), body_pivot, Transform3D(Basis.IDENTITY, Vector3(0.0, 1.1, 0.0)))
	arm_l = _limb(Vector3(-0.55, 1.3, 0.0), Color("#aaaaaa"), 0.12, 0.45)
	arm_r = _limb(Vector3(0.55, 1.3, 0.0), Color("#aaaaaa"), 0.12, 0.45)
	leg_l = _limb(Vector3(-0.2, 0.5, 0.0), Color("#666666"), 0.14, 0.45)
	leg_r = _limb(Vector3(0.2, 0.5, 0.0), Color("#666666"), 0.14, 0.45)


func _limb(pos: Vector3, color: Color, radius: float, height: float) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	body_pivot.add_child(root)
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	_mesh_instance(mesh, _mat(color, 0.48), root, Transform3D(Basis.IDENTITY, Vector3(0.0, -height * 0.35, 0.0)))
	return root


func _apply_motion(delta: float) -> void:
	super._apply_motion(delta)
	if arm_l == null or arm_r == null:
		return
	var t: float = fighter.visual_time if fighter != null else 0.0
	var swing := 0.0
	match _state_label:
		"RUN":
			swing = sin(t * 11.0) * 0.38
		"IDLE":
			swing = sin(t * 2.4) * 0.08
		_:
			swing = 0.0
	arm_l.rotation.z = 0.2 + swing
	arm_r.rotation.z = -0.2 - swing
	if leg_l and leg_r:
		if _state_label == "RUN":
			leg_l.rotation.x = sin(t * 11.0) * 0.55
			leg_r.rotation.x = -sin(t * 11.0) * 0.55
		elif _state_label == "AIR":
			leg_l.rotation.x = -0.45
			leg_r.rotation.x = 0.35
		elif _state_label == "IDLE":
			leg_l.rotation.x = sin(t * 2.4) * 0.04
			leg_r.rotation.x = -sin(t * 2.4) * 0.04
		else:
			leg_l.rotation.x = 0.0
			leg_r.rotation.x = 0.0
	if _state_label == "ATTACK":
		arm_r.rotation.z = -1.35 * facing
		arm_r.position.x = 0.85
		arm_r.rotation.x = -0.35
	elif _state_label == "HITSTUN":
		arm_l.rotation.z = 0.95
		arm_r.rotation.z = -0.95
		if body_pivot:
			body_pivot.rotation.z = sin(t * 28.0) * 0.08
	elif _state_label == "KO":
		if body_pivot:
			body_pivot.rotation.x = -1.1
	if accent_node != null and definition != null and str(definition.id) == "fort":
		accent_node.rotation.y = t * 4.0
	## Pájaro: wing flap / bob for readability.
	if definition != null and str(definition.id).begins_with("pajaro"):
		if body_pivot:
			body_pivot.position.y = sin(t * 6.0) * 0.04
		arm_l.rotation.z = 0.55 + sin(t * 14.0) * 0.45
		arm_r.rotation.z = -0.55 - sin(t * 14.0) * 0.45
		if _state_label == "ATTACK":
			arm_r.rotation.z = -1.5
			arm_l.rotation.z = 0.9


func _apply_hit_flash() -> void:
	for material in _materials:
		if _hit_flash_time > 0.0:
			material.emission_enabled = true
			material.emission = Color(1.0, 0.92, 0.72)
			material.emission_energy_multiplier = 0.85
		else:
			material.emission_enabled = false


func _mat(color: Color, roughness: float, metallic: float = 0.0) -> StandardMaterial3D:
	var material := _make_material(color, roughness, metallic)
	_materials.append(material)
	return material
