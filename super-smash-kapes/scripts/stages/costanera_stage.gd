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
	root.add_to_group("jeffrey_stage_silhouette")
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
		var h: float = 6.0 + float(absi(i)) * 1.4 + float(i % 2) * 2.0
		_box(root, city, Vector3(4.5, h, 2), Vector3(i * 7.0, 4.0 + h * 0.5, -2.0))
	var lamp := StandardMaterial3D.new()
	lamp.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lamp.albedo_color = Color("#f5d76e")
	for x in [-18.0, -9.0, 0.0, 9.0, 18.0]:
		_box(root, lamp, Vector3(0.35, 0.35, 0.35), Vector3(x, 8.5, 1.0))
	# Keep a readable waterfront layer over the GLB blockout: bridge rail,
	# sunset windows, and palms are visual-only and do not affect the stage body.
	var detail := Node3D.new()
	detail.name = "CostaneraLandmarkDetails"
	# The imported skyline sits around camera-relative Z -28; keep details in front.
	detail.position = Vector3(0.0, root.position.y, -25.5)
	camera.add_child(detail)
	var bridge := StandardMaterial3D.new()
	bridge.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bridge.albedo_color = Color("#d3a35a")
	_box(detail, bridge, Vector3(72, 0.55, 0.3), Vector3(0, 7.0, 1.55))
	for x in range(-32, 33, 4):
		_box(detail, bridge, Vector3(0.22, 2.1, 0.22), Vector3(float(x), 6.0, 1.7))
	var window := StandardMaterial3D.new()
	window.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	window.albedo_color = Color("#f6c96b")
	for x in [-28.0, -21.0, -14.0, -7.0, 0.0, 7.0, 14.0, 21.0, 28.0]:
		_box(detail, window, Vector3(1.1, 1.2, 0.22), Vector3(x, 7.8 + fmod(absf(x), 3.0), 1.7))
	var palm := StandardMaterial3D.new()
	palm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	palm.albedo_color = Color("#2b6b62")
	for x in [-31.0, 31.0]:
		_box(detail, bridge, Vector3(0.45, 6.0, 0.45), Vector3(x, 5.0, 1.5))
		_box(detail, palm, Vector3(3.0, 1.0, 0.35), Vector3(x, 8.2, 1.5))
	# A near-water band and warm promenade lights make the waterfront read as
	# Costanera instead of a generic grey skyline, without adding collision.
	var water := StandardMaterial3D.new()
	water.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	water.albedo_color = Color("#2c7891")
	_box(detail, water, Vector3(70, 1.0, 0.28), Vector3(0, 3.8, 1.25))
	for x in range(-28, 29, 7):
		_box(detail, window, Vector3(0.45, 0.45, 0.24), Vector3(float(x), 6.8, 1.72))


func _box(parent: Node3D, mat: Material, size: Vector3, pos: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
