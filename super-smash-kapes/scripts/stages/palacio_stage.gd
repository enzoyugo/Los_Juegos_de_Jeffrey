class_name PalacioDeLopezStage
extends "res://scripts/stages/jeffrey_smash_stage_base.gd"

func _ready() -> void:
	stage_id = "palacio"
	display_name = "PALACIO DE LÓPEZ"
	sky_top = Color("#1a2038")
	sky_bottom = Color("#5a6e98")
	accent = Color("#c9a227")
	super._ready()


func _build_platform_colors() -> void:
	var root := get_node_or_null("StageGameplayRoot")
	if root == null:
		return
	_tint_meshes(root, Color("#6b5a48"))


func _build_silhouette_props(camera: Camera3D) -> void:
	var root := Node3D.new()
	root.name = "PalacioSilhouette"
	root.add_to_group("jeffrey_stage_silhouette")
	root.position = Vector3(0.0, -6.0, -95.0)
	camera.add_child(root)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color("#0e1424")
	# Central palace block + towers (stylized, not photoreal).
	_box(root, mat, Vector3(28, 14, 2), Vector3(0, 10, 0))
	_box(root, mat, Vector3(6, 20, 2.2), Vector3(-16, 12, 0))
	_box(root, mat, Vector3(6, 20, 2.2), Vector3(16, 12, 0))
	_box(root, mat, Vector3(10, 6, 2.1), Vector3(0, 20, 0))
	var flag_mat := StandardMaterial3D.new()
	flag_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flag_mat.albedo_color = Color("#c62828")
	_box(root, flag_mat, Vector3(3.2, 1.4, 0.2), Vector3(-4, 22, 1.2))
	var white := StandardMaterial3D.new()
	white.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	white.albedo_color = Color("#f5f0df")
	_box(root, white, Vector3(3.2, 1.4, 0.2), Vector3(0, 22, 1.2))
	var blue := StandardMaterial3D.new()
	blue.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	blue.albedo_color = Color("#2875b9")
	_box(root, blue, Vector3(3.2, 1.4, 0.2), Vector3(4, 22, 1.2))
	# A shallow, camera-facing landmark layer remains visible when the GLB is used.
	# It gives the otherwise broad facade a readable Palacio rhythm without adding
	# collision or touching the authored gameplay stage.
	var detail := Node3D.new()
	detail.name = "PalacioLandmarkDetails"
	# The imported facade sits around camera-relative Z -28; keep details in front.
	detail.position = Vector3(0.0, root.position.y, -25.5)
	camera.add_child(detail)
	var stone := StandardMaterial3D.new()
	stone.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	stone.albedo_color = Color("#e4c77c")
	var shadow := StandardMaterial3D.new()
	shadow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shadow.albedo_color = Color("#5b3f3c")
	var light := StandardMaterial3D.new()
	light.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	light.albedo_color = Color("#ffe9a8")
	# Main cornice, entrance, and six warm windows read as a landmark at game distance.
	_box(detail, stone, Vector3(27, 0.9, 0.35), Vector3(0, 17.0, 1.65))
	_box(detail, stone, Vector3(10.5, 0.7, 0.4), Vector3(0, 7.0, 1.65))
	_box(detail, shadow, Vector3(4.0, 6.0, 0.25), Vector3(0, 10.0, 1.72))
	for x in [-9.0, -5.5, 5.5, 9.0]:
		_box(detail, light, Vector3(1.6, 2.2, 0.22), Vector3(x, 11.0, 1.8))
	for x in [-13.0, 13.0]:
		_box(detail, stone, Vector3(1.0, 13.0, 0.35), Vector3(x, 11.0, 1.7))
	# A second, lower colonnade and lit roofline add depth at fighter scale while
	# remaining a camera-only presentation layer.
	for x in [-10.5, -7.0, 7.0, 10.5]:
		_box(detail, stone, Vector3(0.55, 7.0, 0.3), Vector3(x, 8.8, 1.78))
	_box(detail, shadow, Vector3(9.0, 0.45, 0.3), Vector3(0, 18.2, 1.75))
	for x in [-4.0, 0.0, 4.0]:
		_box(detail, light, Vector3(1.0, 0.55, 0.22), Vector3(x, 18.8, 1.8))


func _box(parent: Node3D, mat: Material, size: Vector3, pos: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
