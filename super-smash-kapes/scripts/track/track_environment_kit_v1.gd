class_name TrackEnvironmentKitV1
extends RefCounted

## MultiMesh-friendly Asunción roadside kit.
## Prefers promoted first-party urban GLB meshes; falls back to primitives.
## Visual props are never intended for vehicle collision.

const RuntimeMeshes := preload("res://scripts/track/track_env_runtime_meshes_v1.gd")
const VQ := preload("res://scripts/track/track_visual_quality_v2.gd")

enum Piece {
	STREET_LIGHT_POLE,
	STREET_LIGHT_HEAD,
	UTILITY_POLE,
	LOW_WALL,
	TREE_TRUNK,
	TREE_CROWN,
	PALM_TRUNK,
	PALM_CROWN,
	BUILDING_SMALL,
	BUILDING_BLOCK,
	BILLBOARD_POLE,
	BILLBOARD_FACE,
	ROAD_SIGN,
	GUARD_RAIL,
	CURB,
	SKYLINE_BLOCK,
	SKYLINE_SILHOUETTE,
	BANNER,
	GROUND_PATCH,
	## Promoted full GLB meshes (single MultiMesh instance each).
	LAMP_PROMOTED,
	TREE_PROMOTED,
	PALM_PROMOTED,
	BUILDING_SMALL_PROMOTED,
	BUILDING_BLOCK_PROMOTED,
	BILLBOARD_PROMOTED,
	BARRIER_PROMOTED,
	SKYLINE_PROMOTED,
}

const COLORS := {
	"metal": Color("#7a8490"),
	"lamp": Color("#f0c95a"),
	"concrete": Color("#8a929c"),
	"wall": Color("#6a655c"),
	"trunk": Color("#4a3528"),
	"leaf": Color("#2f5c38"),
	"palm": Color("#2a6840"),
	"building_a": Color("#e8e4dc"),
	"building_b": Color("#d8cbb4"),
	"building_c": Color("#e0d08a"),
	"building_warm": Color("#d8cbb4"),
	"building_cool": Color("#e8e4dc"),
	"billboard": Color("#1a2230"),
	"billboard_face": Color("#e0b24a"),
	"sign": Color("#dce6ee"),
	"rail": Color("#5a5e58"),
	"curb": Color("#c9b89a"),
	"skyline": Color("#2a3038"),
	"silhouette": Color("#141820"),
	"banner": Color("#3db8c9"),
	"ground": Color("#2c3428"),
	"ground_green": Color("#2a3a28"),
	"jeffrey_cyan": Color("#3db8c9"),
}

var _meshes: Dictionary = {}
var _mats: Dictionary = {}
var _runtime = null
var _promoted: Dictionary = {} ## piece -> true when using GLB mesh
var _pivot_lift: Dictionary = {} ## piece -> y lift so mesh sits on ground
var promotion_report: Dictionary = {}
var _vq = null
var _building_variant_counter: int = 0
var _sign_variant_counter: int = 0


func ensure_built() -> void:
	if not _meshes.is_empty():
		return
	_vq = VQ.shared()
	_runtime = RuntimeMeshes.new()
	_meshes[Piece.STREET_LIGHT_POLE] = _box(0.16, 4.2, 0.16)
	_meshes[Piece.STREET_LIGHT_HEAD] = _box(0.85, 0.16, 0.45)
	_meshes[Piece.UTILITY_POLE] = _box(0.22, 5.4, 0.22)
	_meshes[Piece.LOW_WALL] = _box(0.28, 1.15, 3.2)
	_meshes[Piece.TREE_TRUNK] = _box(0.35, 2.4, 0.35)
	_meshes[Piece.TREE_CROWN] = _box(2.2, 2.0, 2.2)
	_meshes[Piece.PALM_TRUNK] = _box(0.28, 4.0, 0.28)
	_meshes[Piece.PALM_CROWN] = _box(2.8, 0.55, 2.8)
	_meshes[Piece.BUILDING_SMALL] = _box(6.0, 5.5, 5.0)
	_meshes[Piece.BUILDING_BLOCK] = _box(9.0, 8.5, 7.0)
	_meshes[Piece.BILLBOARD_POLE] = _box(0.2, 4.5, 0.2)
	_meshes[Piece.BILLBOARD_FACE] = _box(5.5, 3.0, 0.18)
	_meshes[Piece.ROAD_SIGN] = _box(0.12, 2.4, 0.9)
	_meshes[Piece.GUARD_RAIL] = _box(0.12, 0.55, 3.0)
	_meshes[Piece.CURB] = _box(0.35, 0.22, 3.0)
	_meshes[Piece.SKYLINE_BLOCK] = _box(8.0, 14.0, 6.0)
	_meshes[Piece.SKYLINE_SILHOUETTE] = _box(18.0, 10.0, 2.0)
	_meshes[Piece.BANNER] = _box(0.08, 1.6, 2.4)
	_meshes[Piece.GROUND_PATCH] = _box(8.0, 0.08, 8.0)
	for key in COLORS.keys():
		_mats[key] = _mat(COLORS[key])
	_try_promote(Piece.LAMP_PROMOTED, "lamp_street", 4.4)
	_try_promote(Piece.TREE_PROMOTED, "tree", 5.0)
	_try_promote(Piece.PALM_PROMOTED, "palm", 6.0)
	_try_promote(Piece.BUILDING_SMALL_PROMOTED, "building_small", 6.0)
	_try_promote(Piece.BUILDING_BLOCK_PROMOTED, "building_med", 9.0)
	if not bool(_promoted.get(Piece.BUILDING_BLOCK_PROMOTED, false)):
		_try_promote(Piece.BUILDING_BLOCK_PROMOTED, "building_mid", 10.0)
	## Billboard face stays a UV-friendly box so the signage atlas reads at race distance.
	## (Promoted billboard GLB UVs do not map atlas cells.)
	_try_promote(Piece.BARRIER_PROMOTED, "barrier", 1.2)
	_try_promote(Piece.SKYLINE_PROMOTED, "tower", 16.0)
	if not bool(_promoted.get(Piece.SKYLINE_PROMOTED, false)):
		_try_promote(Piece.SKYLINE_PROMOTED, "building_mid", 14.0)
	promotion_report = {
		"promoted": _promoted.keys(),
		"runtime": _runtime.inventory() if _runtime != null else {},
	}


func uses_promoted(piece: int) -> bool:
	ensure_built()
	return bool(_promoted.get(piece, false))


func mesh_for(piece: int) -> Mesh:
	ensure_built()
	return _meshes[piece]


func material_for(piece: int) -> StandardMaterial3D:
	ensure_built()
	match piece:
		Piece.STREET_LIGHT_POLE, Piece.UTILITY_POLE, Piece.BILLBOARD_POLE, Piece.LAMP_PROMOTED:
			return _mats["metal"]
		Piece.STREET_LIGHT_HEAD:
			return _mats["lamp"]
		Piece.LOW_WALL, Piece.CURB, Piece.BARRIER_PROMOTED:
			return _mats["curb"] if piece == Piece.CURB else _mats["wall"]
		Piece.TREE_TRUNK, Piece.PALM_TRUNK:
			return _mats["trunk"]
		Piece.TREE_CROWN, Piece.TREE_PROMOTED:
			return _mats["leaf"]
		Piece.PALM_CROWN, Piece.PALM_PROMOTED:
			return _mats["palm"]
		Piece.BUILDING_SMALL, Piece.BUILDING_SMALL_PROMOTED:
			_building_variant_counter += 1
			return _vq.building_material(_building_variant_counter)
		Piece.BUILDING_BLOCK, Piece.BUILDING_BLOCK_PROMOTED:
			_building_variant_counter += 3
			return _vq.building_material(_building_variant_counter)
		Piece.BILLBOARD_FACE, Piece.BILLBOARD_PROMOTED:
			_sign_variant_counter += 1
			return _vq.signage_material(_sign_variant_counter)
		Piece.ROAD_SIGN:
			return _vq.signage_material(0)
		Piece.GUARD_RAIL:
			return _mats["rail"]
		Piece.SKYLINE_BLOCK, Piece.SKYLINE_PROMOTED:
			return _mats["skyline"]
		Piece.SKYLINE_SILHOUETTE:
			return _mats["silhouette"]
		Piece.BANNER:
			return _mats["jeffrey_cyan"]
		Piece.GROUND_PATCH:
			return _mats["ground"]
		_:
			return _mats["building_c"]


func piece_names() -> PackedStringArray:
	return PackedStringArray([
		"street_light", "utility_pole", "low_wall", "tree_a", "palm",
		"building_small", "building_block", "billboard", "road_sign",
		"guard_rail", "curb", "skyline_block", "skyline_silhouette", "banner",
		"lamp_promoted", "tree_promoted", "palm_promoted",
		"building_small_promoted", "building_block_promoted",
		"billboard_promoted", "barrier_promoted", "skyline_promoted",
	])


func emit_batch(host: Node3D, piece: int, transforms: Array) -> MultiMeshInstance3D:
	if transforms.is_empty():
		return null
	ensure_built()
	var building := piece in [
		Piece.BUILDING_SMALL, Piece.BUILDING_BLOCK,
		Piece.BUILDING_SMALL_PROMOTED, Piece.BUILDING_BLOCK_PROMOTED,
	]
	var billboard := piece in [Piece.BILLBOARD_FACE, Piece.BILLBOARD_PROMOTED, Piece.ROAD_SIGN]
	if building or billboard:
		var last_mmi: MultiMeshInstance3D = null
		var groups: Dictionary = {}
		var group_n := 4
		for i in transforms.size():
			var v := i % group_n
			if not groups.has(v):
				groups[v] = []
			groups[v].append(transforms[i])
		for v in groups.keys():
			last_mmi = _emit_one(host, piece, groups[v], (
				_vq.building_material(int(v) * 2 + (3 if building and piece in [Piece.BUILDING_BLOCK, Piece.BUILDING_BLOCK_PROMOTED] else 0))
				if building else _vq.signage_material(int(v) * 2)
			))
		return last_mmi
	return _emit_one(host, piece, transforms, null)


func _emit_one(host: Node3D, piece: int, transforms: Array, mat_override) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh_for(piece)
	mm.instance_count = transforms.size()
	for i in transforms.size():
		mm.set_instance_transform(i, transforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "EnvKit_%d" % piece
	mmi.multimesh = mm
	var force_mat := piece in [
		Piece.BUILDING_SMALL, Piece.BUILDING_BLOCK,
		Piece.BUILDING_SMALL_PROMOTED, Piece.BUILDING_BLOCK_PROMOTED,
		Piece.BILLBOARD_FACE, Piece.BILLBOARD_PROMOTED, Piece.ROAD_SIGN,
		Piece.CURB, Piece.GUARD_RAIL, Piece.GROUND_PATCH,
		Piece.SKYLINE_BLOCK, Piece.SKYLINE_PROMOTED, Piece.SKYLINE_SILHOUETTE,
	]
	if mat_override != null:
		mmi.material_override = mat_override
	elif force_mat or not bool(_promoted.get(piece, false)):
		mmi.material_override = material_for(piece)
	var shadows := piece in [
		Piece.BUILDING_SMALL, Piece.BUILDING_BLOCK,
		Piece.BUILDING_SMALL_PROMOTED, Piece.BUILDING_BLOCK_PROMOTED,
		Piece.TREE_PROMOTED, Piece.PALM_PROMOTED, Piece.LOW_WALL, Piece.BARRIER_PROMOTED,
	]
	mmi.cast_shadow = (
		GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows
		else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	)
	if piece == Piece.SKYLINE_PROMOTED or piece == Piece.SKYLINE_BLOCK or piece == Piece.SKYLINE_SILHOUETTE:
		mmi.visibility_range_begin = 12.0
		mmi.visibility_range_end = 220.0
		mmi.visibility_range_end_margin = 20.0
	host.add_child(mmi)
	return mmi


func ground_lift(piece: int) -> float:
	ensure_built()
	return float(_pivot_lift.get(piece, 0.0))


func showcase_row(host: Node3D, origin: Vector3 = Vector3.ZERO) -> void:
	ensure_built()
	var x := 0.0
	var gap := 12.0
	if uses_promoted(Piece.LAMP_PROMOTED):
		_place_single(host, Piece.LAMP_PROMOTED, origin + Vector3(x, ground_lift(Piece.LAMP_PROMOTED), 0))
	else:
		_place_single(host, Piece.STREET_LIGHT_POLE, origin + Vector3(x, 2.1, 0))
		_place_single(host, Piece.STREET_LIGHT_HEAD, origin + Vector3(x, 4.35, 0.15))
	x += gap
	_place_single(host, Piece.UTILITY_POLE, origin + Vector3(x, 2.7, 0))
	x += gap
	if uses_promoted(Piece.BARRIER_PROMOTED):
		_place_single(host, Piece.BARRIER_PROMOTED, origin + Vector3(x, ground_lift(Piece.BARRIER_PROMOTED), 0))
	else:
		_place_single(host, Piece.LOW_WALL, origin + Vector3(x, 0.55, 0))
	x += gap
	if uses_promoted(Piece.TREE_PROMOTED):
		_place_single(host, Piece.TREE_PROMOTED, origin + Vector3(x, ground_lift(Piece.TREE_PROMOTED), 0))
	else:
		_place_single(host, Piece.TREE_TRUNK, origin + Vector3(x, 1.2, 0))
		_place_single(host, Piece.TREE_CROWN, origin + Vector3(x, 3.4, 0))
	x += gap
	if uses_promoted(Piece.PALM_PROMOTED):
		_place_single(host, Piece.PALM_PROMOTED, origin + Vector3(x, ground_lift(Piece.PALM_PROMOTED), 0))
	else:
		_place_single(host, Piece.PALM_TRUNK, origin + Vector3(x, 2.0, 0))
		_place_single(host, Piece.PALM_CROWN, origin + Vector3(x, 4.2, 0))
	x += gap
	if uses_promoted(Piece.BUILDING_SMALL_PROMOTED):
		_place_single(host, Piece.BUILDING_SMALL_PROMOTED, origin + Vector3(x, ground_lift(Piece.BUILDING_SMALL_PROMOTED), 0))
	else:
		_place_single(host, Piece.BUILDING_SMALL, origin + Vector3(x, 2.75, 0))
	x += gap + 4.0
	if uses_promoted(Piece.BUILDING_BLOCK_PROMOTED):
		_place_single(host, Piece.BUILDING_BLOCK_PROMOTED, origin + Vector3(x, ground_lift(Piece.BUILDING_BLOCK_PROMOTED), 0))
	else:
		_place_single(host, Piece.BUILDING_BLOCK, origin + Vector3(x, 4.25, 0))
	x += gap + 4.0
	if uses_promoted(Piece.BILLBOARD_PROMOTED):
		_place_single(host, Piece.BILLBOARD_PROMOTED, origin + Vector3(x, ground_lift(Piece.BILLBOARD_PROMOTED), 0))
	else:
		_place_single(host, Piece.BILLBOARD_POLE, origin + Vector3(x, 2.25, 0))
		_place_single(host, Piece.BILLBOARD_FACE, origin + Vector3(x, 4.2, 0))
	x += gap + 6.0
	if uses_promoted(Piece.SKYLINE_PROMOTED):
		_place_single(host, Piece.SKYLINE_PROMOTED, origin + Vector3(x, ground_lift(Piece.SKYLINE_PROMOTED), 0))
	else:
		_place_single(host, Piece.SKYLINE_BLOCK, origin + Vector3(x, 7.0, 0))


func _try_promote(piece: int, catalog_id: String, target_height: float) -> void:
	if _runtime == null:
		return
	var entry: Dictionary = _runtime.get_entry(catalog_id)
	var mesh: Mesh = entry.get("mesh", null)
	if mesh == null:
		return
	var aabb: AABB = entry.get("aabb", mesh.get_aabb())
	var h := maxf(aabb.size.y, 0.05)
	var scale := target_height / h
	## Bake scale into a thin wrapper via MeshDataTool is heavy; store lift + scale factor on transforms instead.
	## Duplicate mesh reference; scale applied at placement via Basis.
	_meshes[piece] = mesh
	_promoted[piece] = true
	_promo_scale[piece] = scale
	_pivot_lift[piece] = -aabb.position.y * scale


var _promo_scale: Dictionary = {}


func promo_scale(piece: int) -> float:
	ensure_built()
	return float(_promo_scale.get(piece, 1.0))


func _place_single(host: Node3D, piece: int, pos: Vector3) -> void:
	var s := promo_scale(piece)
	var xf := Transform3D(Basis.IDENTITY.scaled(Vector3(s, s, s)), pos)
	emit_batch(host, piece, [xf])


func _box(x: float, y: float, z: float) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = Vector3(x, y, z)
	return m


func _mat(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.86
	mat.metallic = 0.06
	if color.is_equal_approx(COLORS["lamp"]) or color.is_equal_approx(COLORS["jeffrey_cyan"]):
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 1.35 if color.is_equal_approx(COLORS["jeffrey_cyan"]) else 1.6
	return mat
