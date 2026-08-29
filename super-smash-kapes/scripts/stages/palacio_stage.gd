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


func _box(parent: Node3D, mat: Material, size: Vector3, pos: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
