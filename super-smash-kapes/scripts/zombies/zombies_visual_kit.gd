class_name ZombiesVisualKit
extends RefCounted

## Shared runtime art for Shopping del Sol exterior. Materials/meshes are reused.

const Config := preload("res://scripts/zombies/zombies_config.gd")
const Typography := preload("res://scripts/ui/jeffrey/system/jeffrey_typography.gd")

const ASPHALT := Color("#3a3d42")
const LINE := Color("#e8e2d4")
const CURB := Color("#8a8478")
const CURB_PAINT := Color("#c9b48a")
const GRASS := Color("#2f5a32")
const PALM := Color("#3d7a3a")
const TRUNK := Color("#6a4a32")
const POLE := Color("#6e7278")
const LAMP := Color("#ffd9a0")
const GLASS := Color("#9ec8e8")
const FACADE := Color("#c48a68")
const FACADE_DARK := Color("#8a5a44")
const CREAM := Color("#e8dcc8")
const PLAZA := Color("#c4b49a")
const PLAZA_DARK := Color("#8a6a52")
const METAL := Color("#3a3c40")
const RUBBER := Color("#1a1a1c")

const CAR_COLORS: Array[Color] = [
	Color("#d8dce0"),
	Color("#8a9098"),
	Color("#2a2e34"),
	Color("#3a4a68"),
	Color("#c4b49a"),
	Color("#5a1e22"),
	Color("#e8e4dc"),
	Color("#4a4038"),
]

static var _mats: Dictionary = {}
static var _asphalt: StandardMaterial3D
static var _plaza: StandardMaterial3D
static var _line_mat: StandardMaterial3D
static var _glass_mat: StandardMaterial3D
static var _lamp_mat: StandardMaterial3D
static var _car_body: Array = []
static var _car_glass: StandardMaterial3D
static var _car_rubber: StandardMaterial3D
static var _ready: bool = false


static func ensure() -> void:
	if _ready:
		return
	_ready = true
	_asphalt = _make_tex_mat(Color("#4a4e54"), Color("#3a3c42"), Color("#5a5e64"), 0.94, 0.08)
	_plaza = _make_tex_mat(Color("#d2c4a8"), Color("#c4b090"), Color("#e0d2b8"), 0.78, 0.12)
	_line_mat = color_mat(LINE, 0.55)
	_glass_mat = _make_glass()
	_lamp_mat = _make_emit(LAMP, 2.4)
	_car_glass = _make_glass()
	_car_rubber = color_mat(RUBBER, 0.92)
	for c in CAR_COLORS:
		_car_body.append(color_mat(c, 0.42))


static func color_mat(color: Color, roughness: float = 0.82) -> StandardMaterial3D:
	var key := "%s_%.2f" % [str(color), roughness]
	if _mats.has(key):
		return _mats[key]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	_mats[key] = mat
	return mat


static func asphalt_mat() -> StandardMaterial3D:
	ensure()
	return _asphalt


static func plaza_mat() -> StandardMaterial3D:
	ensure()
	return _plaza


static func line_mat() -> StandardMaterial3D:
	ensure()
	return _line_mat


static func glass_mat() -> StandardMaterial3D:
	ensure()
	return _glass_mat


static func mesh_box(parent: Node, pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.position = pos
	mesh.set_surface_override_material(0, mat)
	parent.add_child(mesh)
	return mesh


static func box(parent: Node, pos: Vector3, size: Vector3, mat: Material, collide: bool) -> Node3D:
	if collide:
		var body := StaticBody3D.new()
		body.collision_layer = Config.LAYER_WORLD
		body.collision_mask = 0
		body.position = pos
		parent.add_child(body)
		mesh_box(body, Vector3.ZERO, size, mat)
		var col := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		col.shape = shape
		body.add_child(col)
		return body
	mesh_box(parent, pos, size, mat)
	return parent


static func floor_body(parent: Node, pos: Vector3, size: Vector3, mat: Material) -> StaticBody3D:
	return box(parent, pos, size, mat, true) as StaticBody3D


static func add_car(parent: Node, pos: Vector3, yaw: float, kind: String, color_i: int, collide: bool) -> void:
	ensure()
	var root: Node3D
	if collide:
		var body := StaticBody3D.new()
		body.collision_layer = Config.LAYER_WORLD
		body.collision_mask = 0
		root = body
	else:
		root = Node3D.new()
	root.position = pos
	root.rotation.y = yaw
	parent.add_child(root)
	var ci: int = color_i % _car_body.size()
	var body_mat: StandardMaterial3D = _car_body[ci]
	match kind:
		"suv":
			mesh_box(root, Vector3(0, 0.62, 0), Vector3(1.85, 0.72, 4.35), body_mat)
			mesh_box(root, Vector3(0, 1.28, -0.15), Vector3(1.72, 0.72, 2.55), body_mat)
			mesh_box(root, Vector3(0, 1.32, 0.05), Vector3(1.55, 0.48, 2.1), _car_glass)
		"pickup":
			mesh_box(root, Vector3(0, 0.58, 0.35), Vector3(1.82, 0.62, 3.5), body_mat)
			mesh_box(root, Vector3(0, 1.18, 0.85), Vector3(1.68, 0.68, 1.7), body_mat)
			mesh_box(root, Vector3(0, 1.22, 0.9), Vector3(1.5, 0.42, 1.35), _car_glass)
			mesh_box(root, Vector3(0, 0.72, -1.15), Vector3(1.7, 0.35, 1.7), METAL_MAT())
		_:
			mesh_box(root, Vector3(0, 0.48, 0), Vector3(1.72, 0.48, 4.15), body_mat)
			mesh_box(root, Vector3(0, 0.95, -0.2), Vector3(1.58, 0.48, 2.05), body_mat)
			mesh_box(root, Vector3(0, 1.0, -0.05), Vector3(1.42, 0.34, 1.55), _car_glass)
	_wheel(root, Vector3(-0.72, 0.28, 1.28))
	_wheel(root, Vector3(0.72, 0.28, 1.28))
	_wheel(root, Vector3(-0.72, 0.28, -1.32))
	_wheel(root, Vector3(0.72, 0.28, -1.32))
	if collide:
		var col := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(1.9, 1.35, 4.4)
		col.shape = shape
		col.position = Vector3(0, 0.65, 0)
		root.add_child(col)


static func METAL_MAT() -> StandardMaterial3D:
	return color_mat(METAL, 0.55)


static func add_palm(parent: Node, pos: Vector3, height: float = 5.8) -> void:
	ensure()
	var root := Node3D.new()
	root.position = pos
	parent.add_child(root)
	mesh_box(root, Vector3(0, height * 0.42, 0), Vector3(0.22, height * 0.84, 0.22), color_mat(TRUNK, 0.9))
	var crown_y: float = height * 0.88
	for i in 5:
		var yaw: float = float(i) * TAU / 5.0
		var leaf := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.42, 0.08, 2.35)
		leaf.mesh = box
		leaf.position = Vector3(sin(yaw) * 0.55, crown_y, cos(yaw) * 0.55)
		leaf.rotation = Vector3(-0.48, yaw, 0.0)
		leaf.set_surface_override_material(0, color_mat(PALM, 0.78))
		root.add_child(leaf)


static func add_tree(parent: Node, pos: Vector3) -> void:
	ensure()
	var root := Node3D.new()
	root.position = pos
	parent.add_child(root)
	mesh_box(root, Vector3(0, 0.85, 0), Vector3(0.28, 1.7, 0.28), color_mat(TRUNK, 0.9))
	mesh_box(root, Vector3(0, 2.15, 0), Vector3(1.8, 1.4, 1.8), color_mat(Color("#2a5a30"), 0.88))
	mesh_box(root, Vector3(0.35, 2.55, -0.2), Vector3(1.1, 0.9, 1.1), color_mat(Color("#3a6a38"), 0.86))


static func add_lamp(parent: Node, pos: Vector3, double_arm: bool = true) -> void:
	ensure()
	var pole_m := color_mat(POLE, 0.45)
	mesh_box(parent, pos + Vector3(0, 4.1, 0), Vector3(0.16, 8.2, 0.16), pole_m)
	if double_arm:
		mesh_box(parent, pos + Vector3(0, 8.15, 0), Vector3(2.6, 0.1, 0.12), pole_m)
		mesh_box(parent, pos + Vector3(-1.15, 8.05, 0), Vector3(0.35, 0.12, 0.35), pole_m)
		mesh_box(parent, pos + Vector3(1.15, 8.05, 0), Vector3(0.35, 0.12, 0.35), pole_m)
		_omni(parent, pos + Vector3(-1.15, 7.85, 0), 2.45, 15.0, LAMP)
		_omni(parent, pos + Vector3(1.15, 7.85, 0), 2.45, 15.0, LAMP)
		mesh_box(parent, pos + Vector3(-1.15, 7.92, 0), Vector3(0.28, 0.08, 0.28), _lamp_mat)
		mesh_box(parent, pos + Vector3(1.15, 7.92, 0), Vector3(0.28, 0.08, 0.28), _lamp_mat)
	else:
		mesh_box(parent, pos + Vector3(0, 8.15, 0.45), Vector3(0.18, 0.1, 1.1), pole_m)
		_omni(parent, pos + Vector3(0, 7.9, 0.55), 1.7, 12.0, LAMP)
		mesh_box(parent, pos + Vector3(0, 7.95, 0.7), Vector3(0.32, 0.08, 0.32), _lamp_mat)


static func add_island(parent: Node, pos: Vector3, size: Vector3) -> void:
	ensure()
	box(parent, pos + Vector3(0, 0.12, 0), Vector3(size.x, 0.24, size.z), color_mat(CURB, 0.88), true)
	mesh_box(parent, pos + Vector3(0, 0.28, 0), Vector3(size.x - 0.25, 0.16, size.z - 0.25), color_mat(GRASS, 0.9))


static func add_skyline(parent: Node) -> void:
	ensure()
	var concrete := color_mat(Color("#d0d4d8"), 0.7)
	var concrete_b := color_mat(Color("#b8c0c8"), 0.72)
	var night_win := _make_emit(Color("#d8e8ff"), 0.55)
	var blue_strip := _make_emit(Color("#4a88d8"), 1.4)
	var red_sign := _make_emit(Color("#c02028"), 1.8)
	## Towers visible from parking looking away from the mall (+Z / +X).
	_tower(parent, Vector3(34.0, 0, 52.0), Vector3(9.0, 42.0, 9.0), concrete, night_win, "BYSPANIA")
	_tower(parent, Vector3(44.0, 0, 58.0), Vector3(8.0, 36.0, 8.0), concrete_b, night_win, "")
	mesh_box(parent, Vector3(40.5, 18.0, 52.0), Vector3(0.6, 22.0, 0.6), red_sign)
	_tower(parent, Vector3(-38.0, 0, 18.0), Vector3(8.5, 38.0, 8.5), concrete, night_win, "")
	mesh_box(parent, Vector3(-38.0, 20.0, 22.2), Vector3(0.45, 28.0, 0.45), blue_strip)
	## Lower hotel-like mass.
	box(parent, Vector3(-32.0, 6.0, 46.0), Vector3(14.0, 12.0, 8.0), color_mat(Color("#e8e4dc"), 0.68), false)
	var ibis := Label3D.new()
	Typography.apply_label3d(ibis, Typography.ZOMBIES)
	ibis.text = "ibis"
	ibis.position = Vector3(-32.0, 12.2, 50.2)
	ibis.font_size = 64
	ibis.modulate = Color("#c02028")
	ibis.outline_size = 8
	parent.add_child(ibis)
	## Distant street-side blocks behind / beside the mall.
	box(parent, Vector3(-48.0, 8.0, -6.0), Vector3(10.0, 16.0, 12.0), concrete_b, false)
	box(parent, Vector3(50.0, 7.0, -4.0), Vector3(9.0, 14.0, 10.0), concrete, false)
	box(parent, Vector3(0.0, 9.0, -38.0), Vector3(22.0, 18.0, 8.0), color_mat(Color("#9aa4ae"), 0.75), false)


static func add_street_edge(parent: Node) -> void:
	ensure()
	## Visual-only continuation of the lot toward Aviadores.
	mesh_box(parent, Vector3(0, -0.52, 58.0), Vector3(90.0, 1.0, 28.0), asphalt_mat())
	mesh_box(parent, Vector3(0, 0.02, 70.0), Vector3(90.0, 0.04, 4.0), color_mat(Color("#5a5e64"), 0.9))
	for x in [-28.0, -14.0, 0.0, 14.0, 28.0]:
		add_lamp(parent, Vector3(x, 0, 62.0), false)
	for i in 6:
		add_car(parent, Vector3(-22.0 + float(i) * 7.5, 0, 54.5), 0.08 * float(i % 3 - 1), _kind(i), i + 2, false)


static func _kind(i: int) -> String:
	var m: int = i % 3
	if m == 0:
		return "sedan"
	if m == 1:
		return "suv"
	return "pickup"


static func _tower(parent: Node, pos: Vector3, size: Vector3, body: Material, win: Material, tag: String) -> void:
	mesh_box(parent, pos + Vector3(0, size.y * 0.5, 0), size, body)
	for y in 8:
		mesh_box(parent, pos + Vector3(0, 4.0 + float(y) * (size.y / 9.0), size.z * 0.51), Vector3(size.x * 0.72, 0.9, 0.08), win)
	if not tag.is_empty():
		var lab := Label3D.new()
		Typography.apply_label3d(lab, Typography.ZOMBIES)
		lab.text = tag
		lab.position = pos + Vector3(0, size.y + 1.2, size.z * 0.52)
		lab.font_size = 48
		lab.modulate = Color("#6aa0e8")
		lab.outline_size = 8
		parent.add_child(lab)


static func _omni(parent: Node, pos: Vector3, energy: float, rng: float, color: Color) -> void:
	var light := OmniLight3D.new()
	light.position = pos
	light.light_energy = energy
	light.omni_range = rng
	light.light_color = color
	light.shadow_enabled = false
	parent.add_child(light)


static func _wheel(parent: Node, pos: Vector3) -> void:
	var mesh := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.28
	cyl.bottom_radius = 0.28
	cyl.height = 0.22
	mesh.mesh = cyl
	mesh.position = pos
	mesh.rotation.z = PI * 0.5
	mesh.set_surface_override_material(0, _car_rubber)
	parent.add_child(mesh)


static func _make_tex_mat(base: Color, a: Color, b: Color, roughness: float, scale: float) -> StandardMaterial3D:
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	for y in 32:
		for x in 32:
			var n: float = 0.5 + 0.5 * sin(float(x) * 0.37 + float(y) * 0.21) * 0.35
			n += 0.08 * float((x * 13 + y * 7) % 5)
			n = clampf(n, 0.0, 1.0)
			img.set_pixel(x, y, a.lerp(b, n))
	var tex := ImageTexture.create_from_image(img)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = base
	mat.albedo_texture = tex
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	mat.uv1_triplanar = true
	mat.uv1_world_triplanar = true
	mat.uv1_scale = Vector3(scale * 4.0, scale * 4.0, scale * 4.0)
	mat.roughness = roughness
	return mat


static func _make_glass() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(GLASS.r, GLASS.g, GLASS.b, 0.42)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 0.08
	mat.metallic = 0.55
	mat.emission_enabled = true
	mat.emission = Color("#c8e4ff")
	mat.emission_energy_multiplier = 0.35
	return mat


static func _make_emit(color: Color, energy: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = energy
	return mat
