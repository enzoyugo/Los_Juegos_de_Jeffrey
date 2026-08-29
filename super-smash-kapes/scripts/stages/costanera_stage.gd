class_name CostaneraDeAsuncionStage
extends "res://scripts/stages/jeffrey_smash_stage_base.gd"

func _ready() -> void:
	stage_id = "costanera"
	display_name = "COSTANERA DE ASUNCIÓN"
	sky_top = Color("#1c3a58")
	sky_bottom = Color("#f0a060")
	accent = Color("#3db8c9")
	super._ready()


func _build_platform_colors() -> void:
	var root := get_node_or_null("StageGameplayRoot")
	if root == null:
		return
	_tint_meshes(root, Color("#5a6670"))


func _build_silhouette_props(camera: Camera3D) -> void:
	var root := Node3D.new()
	root.name = "CostaneraSilhouette"
	root.position = Vector3(0.0, -10.0, -95.0)
	camera.add_child(root)
	var river := StandardMaterial3D.new()
	river.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	river.albedo_color = Color("#1e5a78")
	_box(root, river, Vector3(80, 1.2, 2), Vector3(0, 2, 0))
	var city := StandardMaterial3D.new()
	city.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	city.albedo_color = Color("#152033")
	for i in range(-4, 5):
		var h := 6.0 + abs(i) * 1.4 + float(i % 2) * 2.0
		_box(root, city, Vector3(4.5, h, 2), Vector3(i * 7.0, 4.0 + h * 0.5, -2.0))
	var lamp := StandardMaterial3D.new()
	lamp.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lamp.albedo_color = Color("#f5d76e")
	for x in [-18.0, -9.0, 0.0, 9.0, 18.0]:
		_box(root, lamp, Vector3(0.35, 0.35, 0.35), Vector3(x, 8.5, 1.0))


func _box(parent: Node3D, mat: Material, size: Vector3, pos: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
