class_name ZombiesMallProps
extends RefCounted

## Additive Shopping del Sol interior dressing. No exterior GLB.

const Config := preload("res://scripts/zombies/zombies_config.gd")

const CREAM := Color("#e8dcc8")
const FRAME := Color("#d8cbb4")
const GLASS := Color("#1a2230")
const SHUTTER := Color("#6a6258")
const WOOD := Color("#6a5044")
const PLANT := Color("#3d6a3a")
const DIRT := Color("#4a3a2c")
const METAL := Color("#3a3836")
const LIGHT := Color("#f4e6c4")
static var _color_cache: Dictionary = {}
static var _floor_cached: StandardMaterial3D


static func color_material(color: Color) -> StandardMaterial3D:
	var key := str(color)
	if _color_cache.has(key):
		return _color_cache[key]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.82
	if color == GLASS:
		mat.albedo_color = Color(GLASS.r, GLASS.g, GLASS.b, 0.72)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.roughness = 0.12
		mat.metallic = 0.35
	_color_cache[key] = mat
	return mat


static func add_storefront(parent: Node, pos: Vector3, rot_y: float, width: float, title: String) -> void:
	var root := Node3D.new()
	root.position = pos
	root.rotation.y = rot_y
	parent.add_child(root)
	_box(root, Vector3(0, 1.7, 0), Vector3(width, 3.4, 0.12), FRAME, false)
	_box(root, Vector3(0, 1.65, 0.04), Vector3(width - 0.35, 2.55, 0.04), GLASS, false)
	_box(root, Vector3(0, 2.55, 0.08), Vector3(width - 0.28, 0.55, 0.05), SHUTTER, false)
	_box(root, Vector3(0, 0.18, 0.10), Vector3(width - 0.1, 0.36, 0.18), FRAME, true)
	if not title.is_empty():
		var tag := Label3D.new()
		tag.text = title
		tag.position = Vector3(0, 3.05, 0.12)
		tag.font_size = 42
		tag.modulate = CREAM
		tag.outline_size = 8
		tag.outline_modulate = Color(0, 0, 0, 0.85)
		root.add_child(tag)


static func add_directory(parent: Node, pos: Vector3) -> void:
	var root := Node3D.new()
	root.position = pos
	parent.add_child(root)
	_box(root, Vector3(0, 1.15, 0), Vector3(0.12, 2.3, 0.12), METAL, true)
	_box(root, Vector3(0, 2.15, 0.04), Vector3(1.35, 1.15, 0.08), FRAME, false)
	var title := Label3D.new()
	title.text = "SHOPPING del SOL"
	title.position = Vector3(0, 2.35, 0.10)
	title.font_size = 36
	title.modulate = Config.COLOR_CREAM
	title.outline_size = 8
	title.outline_modulate = Color(0, 0, 0, 0.9)
	root.add_child(title)
	var sub := Label3D.new()
	sub.text = "DIRECTORIO"
	sub.position = Vector3(0, 1.85, 0.10)
	sub.font_size = 22
	sub.modulate = Color("#c9a227")
	sub.outline_size = 6
	root.add_child(sub)


static func add_bench(parent: Node, pos: Vector3, rot_y: float) -> void:
	var root := Node3D.new()
	root.position = pos
	root.rotation.y = rot_y
	parent.add_child(root)
	_box(root, Vector3(0, 0.42, 0), Vector3(1.6, 0.12, 0.48), WOOD, true)
	_box(root, Vector3(0, 0.62, -0.18), Vector3(1.6, 0.36, 0.08), WOOD, false)
	_box(root, Vector3(-0.65, 0.22, 0), Vector3(0.12, 0.44, 0.44), WOOD, true)
	_box(root, Vector3(0.65, 0.22, 0), Vector3(0.12, 0.44, 0.44), WOOD, true)


static func add_planter(parent: Node, pos: Vector3) -> void:
	var root := Node3D.new()
	root.position = pos
	parent.add_child(root)
	_box(root, Vector3(0, 0.32, 0), Vector3(0.95, 0.64, 0.95), FRAME, true)
	_box(root, Vector3(0, 0.66, 0), Vector3(0.82, 0.08, 0.82), DIRT, false)
	_box(root, Vector3(0, 0.95, 0), Vector3(0.45, 0.55, 0.45), PLANT, false)


static func add_trash(parent: Node, pos: Vector3) -> void:
	var root := Node3D.new()
	root.position = pos
	parent.add_child(root)
	_box(root, Vector3(0, 0.45, 0), Vector3(0.38, 0.9, 0.38), METAL, true)
	_box(root, Vector3(0, 0.92, 0), Vector3(0.42, 0.06, 0.42), Color("#2a2826"), false)


static func add_column_wrap(parent: Node, pos: Vector3) -> StaticBody3D:
	var body := _box(parent, pos + Vector3(0, 2, 0), Vector3(0.78, 4.0, 0.78), CREAM, true)
	_box(parent, pos + Vector3(0, 0.22, 0), Vector3(0.95, 0.44, 0.95), FRAME, false)
	_box(parent, pos + Vector3(0, 3.85, 0), Vector3(0.95, 0.28, 0.95), FRAME, false)
	return body


static func add_strip_light(parent: Node, pos: Vector3, size: Vector3) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.position = pos
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = LIGHT
	mat.emission_enabled = true
	mat.emission = LIGHT
	mat.emission_energy_multiplier = 1.6
	mesh.set_surface_override_material(0, mat)
	parent.add_child(mesh)


static func add_kiosk(parent: Node, pos: Vector3) -> void:
	var root := Node3D.new()
	root.position = pos
	parent.add_child(root)
	_box(root, Vector3(0, 0.55, 0), Vector3(2.4, 1.1, 1.35), WOOD, true)
	_box(root, Vector3(0, 1.12, 0), Vector3(2.55, 0.08, 1.48), FRAME, false)
	_box(root, Vector3(0, 1.85, 0), Vector3(2.2, 0.08, 1.15), CREAM, false)
	_box(root, Vector3(-1.05, 1.5, 0), Vector3(0.08, 0.7, 1.1), FRAME, false)
	_box(root, Vector3(1.05, 1.5, 0), Vector3(0.08, 0.7, 1.1), FRAME, false)
	var tag := Label3D.new()
	tag.text = "KIOSCO"
	tag.position = Vector3(0, 1.55, 0.72)
	tag.font_size = 28
	tag.modulate = Color("#c9a227")
	tag.outline_size = 6
	root.add_child(tag)


static func add_smg_silhouette(parent: Node, pos: Vector3) -> void:
	var root := Node3D.new()
	root.position = pos
	parent.add_child(root)
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color("#2a2e34")
	glow.emission_enabled = true
	glow.emission = Color("#c9a227")
	glow.emission_energy_multiplier = 0.85
	_box_mat(root, Vector3(0, 1.35, 0), Vector3(0.08, 0.12, 0.55), glow)
	_box_mat(root, Vector3(0, 1.18, 0.05), Vector3(0.06, 0.22, 0.10), glow)
	_box_mat(root, Vector3(0, 1.36, 0.32), Vector3(0.05, 0.08, 0.16), glow)
	_box_mat(root, Vector3(0, 1.38, -0.22), Vector3(0.04, 0.05, 0.18), glow)


static func floor_material() -> StandardMaterial3D:
	if _floor_cached != null:
		return _floor_cached
	var img := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	img.set_pixel(0, 0, Color("#cfc6b0"))
	img.set_pixel(1, 1, Color("#cfc6b0"))
	img.set_pixel(1, 0, Color("#b7b09a"))
	img.set_pixel(0, 1, Color("#b7b09a"))
	var tex := ImageTexture.create_from_image(img)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("#d8d0bc")
	mat.albedo_texture = tex
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.uv1_triplanar = true
	mat.uv1_world_triplanar = true
	mat.uv1_scale = Vector3(0.55, 0.55, 0.55)
	mat.roughness = 0.72
	_floor_cached = mat
	return mat


static func _box(parent: Node, pos: Vector3, size: Vector3, color: Color, collide: bool) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = Config.LAYER_WORLD if collide else 0
	body.collision_mask = 0
	body.position = pos
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.set_surface_override_material(0, color_material(color))
	body.add_child(mesh)
	if collide:
		var col := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		col.shape = shape
		body.add_child(col)
	parent.add_child(body)
	return body


static func _box_mat(parent: Node, pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.position = pos
	mesh.set_surface_override_material(0, mat)
	parent.add_child(mesh)
	return mesh
