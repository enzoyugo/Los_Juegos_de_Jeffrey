class_name TrackCarVisual
extends Node3D

## Runtime visual wrapper. Never owns gameplay collision or handling.
## One imported PackedScene, one shared 4K atlas. Per-instance materials
## are lightweight and keep the same albedo_texture RID.

const VisualConfig := preload("res://scripts/track/track_car_visual_config.gd")

@export var apply_runtime_transform: bool = true
@export var ghost_mode: bool = false
@export var show_debug_pivots: bool = false
@export var use_articulated: bool = false

static var _shared_atlas: Texture2D = null
static var _shared_ghost_mat: StandardMaterial3D = null
static var _player_mat_template: StandardMaterial3D = null
static var _source_instances: int = 0
static var _ghost_visuals: int = 0
static var _packed_source: PackedScene = null
static var _packed_articulated: PackedScene = null
static var _atlas_load_attempted: bool = false
static var _atlas_fallback: bool = false
static var _atlas_source_path: String = ""

const MODE_REST := 0
const MODE_STEER := 1
const MODE_SUSPENSION := 2
const MODE_SPIN := 3
const MODE_FULL := 4
const MODE_NAMES := ["REST_ONLY", "STEER_ONLY", "SUSPENSION_ONLY", "SPIN_ONLY", "FULL"]

var _imported: Node = null
var _character_id: String = ""
var _accent: Color = Color.WHITE
var _body_mats: Array[Material] = []
var _spin: float = 0.0
var _debug_pivots: Array[Node3D] = []
var _wheel_binds: Dictionary = {}
var articulation_mode: int = MODE_FULL
var _bind_logged: bool = false
var _live_counted: bool = false
var articulated_override_path: String = ""


func _ready() -> void:
	if OS.get_environment("SSK_SKIP_CAR_VISUAL") == "1":
		return
	add_to_group("track_car_visual")
	if apply_runtime_transform:
		scale = Vector3.ONE * VisualConfig.VISUAL_SCALE
		if use_articulated:
			rotation_degrees = VisualConfig.ARTICULATED_VISUAL_ROTATION_DEGREES
		else:
			rotation_degrees = VisualConfig.VISUAL_ROTATION_DEGREES
		position = VisualConfig.VISUAL_OFFSET
	_mount_source()
	if show_debug_pivots:
		_spawn_debug_pivots()
		_set_pivots_visible(true)


func _exit_tree() -> void:
	if _live_counted:
		_source_instances = maxi(_source_instances - 1, 0)
		_live_counted = false
		if ghost_mode:
			_ghost_visuals = maxi(_ghost_visuals - 1, 0)


func reset_motion() -> void:
	_spin = 0.0
	for pivot in _debug_pivots:
		if pivot != null:
			pivot.rotation = Vector3.ZERO
	for key in _wheel_binds.keys():
		_apply_bind_pose(str(key), 0.0, 0.0, 0.0, 0.12)


func set_articulation_mode(mode: int) -> int:
	articulation_mode = clampi(mode, MODE_REST, MODE_FULL)
	reset_motion()
	print("[TRACK_4WHEEL_VISUAL_MODE] %s" % MODE_NAMES[articulation_mode])
	return articulation_mode


func cycle_articulation_mode() -> int:
	return set_articulation_mode((articulation_mode + 1) % 5)


func articulation_mode_name() -> String:
	return MODE_NAMES[articulation_mode]


func chassis_forward() -> Vector3:
	return -global_transform.basis.z.normalized()


func visual_forward() -> Vector3:
	return semantic_forward()


func semantic_forward() -> Vector3:
	## Independent of wheel labels and body centroid: authored markers.
	var nose := _find_named(self, "NOSE_MARKER") as Node3D
	var rear := _find_named(self, "REAR_MARKER") as Node3D
	if nose != null and rear != null:
		var axis := nose.global_position - rear.global_position
		axis.y = 0.0
		if axis.length() > 0.001:
			return axis.normalized()
	return body_model_nose()


func body_model_nose() -> Vector3:
	## Processed articulated Body is -Z-nose in mesh space. World nose is -basis.z.
	var body := _find_named(self, "Body") as Node3D
	if body != null:
		var axis := -body.global_transform.basis.z
		if axis.length() > 0.001:
			return axis.normalized()
	if _imported is Node3D:
		var axis := -(_imported as Node3D).global_transform.basis.z
		if axis.length() > 0.001:
			return axis.normalized()
	return chassis_forward()


func geometric_forward() -> Vector3:
	var front := front_axle_midpoint_global()
	var rear := rear_axle_midpoint_global()
	var axis := front - rear
	axis.y = 0.0
	if axis.length() < 0.001:
		return chassis_forward()
	return axis.normalized()


func front_axle_midpoint_global() -> Vector3:
	return _axle_midpoint(["FL", "FR"])


func rear_axle_midpoint_global() -> Vector3:
	return _axle_midpoint(["RL", "RR"])


func _axle_midpoint(ids: Array) -> Vector3:
	var acc := Vector3.ZERO
	var n := 0
	for wid in ids:
		var bind: Dictionary = wheel_bind(str(wid))
		var mount: Node3D = bind.get("mount")
		if mount != null:
			acc += mount.global_position
			n += 1
	if n < 1:
		return global_position
	return acc / float(n)


func wheel_bind(wheel_id: String) -> Dictionary:
	return _wheel_binds.get(wheel_id, {})


func wheel_mesh_rest_local(wheel_id: String) -> Vector3:
	var bind: Dictionary = wheel_bind(wheel_id)
	return bind.get("rest_local", Vector3.ZERO)


func wheel_center_global(wheel_id: String) -> Vector3:
	var bind: Dictionary = wheel_bind(wheel_id)
	var mesh: Node3D = bind.get("mesh")
	if mesh == null:
		var mount: Node3D = bind.get("mount")
		return mount.global_position if mount != null else global_position
	return mesh.global_position


func wheel_center_delta(wheel_id: String) -> float:
	var bind: Dictionary = wheel_bind(wheel_id)
	var mount: Node3D = bind.get("mount")
	if mount == null:
		return 0.0
	var susp: Node3D = bind.get("susp")
	var expected := mount.global_position
	if susp != null:
		expected = susp.global_position
	return wheel_center_global(wheel_id).distance_to(expected)


func wheel_aabb_size_local(wheel_id: String) -> Vector3:
	var bind: Dictionary = wheel_bind(wheel_id)
	var mesh: Node3D = bind.get("mesh")
	if mesh is MeshInstance3D and (mesh as MeshInstance3D).mesh != null:
		return (mesh as MeshInstance3D).mesh.get_aabb().size
	return Vector3.ZERO


func wheel_max_radius_local(wheel_id: String) -> float:
	var bind: Dictionary = wheel_bind(wheel_id)
	var mesh: Node3D = bind.get("mesh")
	if not (mesh is MeshInstance3D):
		return 0.0
	var m: Mesh = (mesh as MeshInstance3D).mesh
	if m == null:
		return 0.0
	var max_r := 0.0
	for si in m.get_surface_count():
		var arr: Array = m.surface_get_arrays(si)
		if arr.is_empty():
			continue
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		for v in verts:
			max_r = maxf(max_r, v.length())
	return max_r


func set_named_visible(part_name: String, on: bool) -> void:
	var node := _find_named(self, part_name)
	if node is Node3D:
		(node as Node3D).visible = on


func debug_apply_wheel_pose(wheel_id: String, steer: float, spin: float, susp_m: float) -> void:
	if _wheel_binds.is_empty():
		_bind_articulated_wheels()
	_apply_bind_pose(wheel_id, steer, spin, susp_m, 0.12)


func apply_motion(_steer: float, along: float, delta: float) -> void:
	if use_articulated and not _wheel_binds.is_empty():
		return
	if VisualConfig.WHEEL_STRUCTURE != "SEPARATE_NODES":
		_spin += along * delta / maxf(VisualConfig.WHEEL_RADIUS, 0.05)
		return
	_spin += along * delta / maxf(VisualConfig.WHEEL_RADIUS, 0.05)
	var steer_rad := clampf(_steer, -1.0, 1.0) * deg_to_rad(VisualConfig.MAX_VISUAL_STEER_DEGREES)
	for pivot in _debug_pivots:
		if pivot == null:
			continue
		var is_front := str(pivot.name).begins_with("WheelPivotF")
		pivot.rotation.y = steer_rad if is_front else 0.0
		pivot.rotation.x = _spin


func apply_wheel_states(states: Array, _delta: float) -> void:
	if not use_articulated:
		return
	if _wheel_binds.is_empty():
		_bind_articulated_wheels()
	var rest := 0.12
	for item in states:
		if not (item is Dictionary):
			continue
		var wid := str(item.get("id", ""))
		if not _wheel_binds.has(wid):
			continue
		var steer := float(item.get("steer", 0.0))
		var spin := fmod(float(item.get("spin", 0.0)), TAU)
		rest = float(item.get("rest", rest))
		var length := float(item.get("length", rest))
		var susp := rest - length
		match articulation_mode:
			MODE_REST:
				steer = 0.0
				spin = 0.0
				susp = 0.0
			MODE_STEER:
				if not wid.begins_with("F"):
					steer = 0.0
				spin = 0.0
				susp = 0.0
			MODE_SUSPENSION:
				steer = 0.0
				spin = 0.0
			MODE_SPIN:
				steer = 0.0
				susp = 0.0
			MODE_FULL:
				pass
		_apply_bind_pose(wid, steer, spin, susp, rest)


func set_character_visual(character_id: String) -> void:
	_character_id = character_id


func set_player_accent(color: Color) -> void:
	_accent = color
	for mat in _body_mats:
		if mat is BaseMaterial3D:
			(mat as BaseMaterial3D).albedo_color = color


func set_debug_pivots_visible(on: bool) -> void:
	show_debug_pivots = on
	if on and _debug_pivots.is_empty():
		_spawn_debug_pivots()
	_set_pivots_visible(on)


func imported_root() -> Node:
	return _imported


static func shared_atlas() -> Texture2D:
	return _shared_atlas


static func shared_atlas_id() -> int:
	if _shared_atlas == null:
		return 0
	return int(_shared_atlas.get_instance_id())


static func ghost_material_id() -> int:
	if _shared_ghost_mat == null:
		return 0
	return int(_shared_ghost_mat.get_instance_id())


static func source_packed_resident() -> bool:
	return _packed_source != null


static func articulated_packed_resident() -> bool:
	return _packed_articulated != null


static func live_visuals() -> int:
	return _source_instances


static func ghost_visuals() -> int:
	return _ghost_visuals


static func atlas_resource_path() -> String:
	if _shared_atlas == null:
		return ""
	return _shared_atlas.resource_path


func _mount_source() -> void:
	_ensure_shared_atlas()
	var packed := _packed_for_mode()
	if packed == null:
		push_error("[TRACK_CAR_VISUAL] visual packed scene missing articulated=%s" % str(use_articulated))
		return
	_imported = packed.instantiate()
	_imported.name = "ImportedCar"
	add_child(_imported)
	_strip_imported_physics(_imported)
	if _shared_atlas == null:
		_capture_atlas(_imported)
	_bind_instance_materials(_imported)
	if use_articulated:
		_orient_articulated_body()
		_bind_articulated_wheels()
	_source_instances += 1
	_live_counted = true
	print("[TRACK_CAR_VISUAL] articulated_wheel_binds=%d live_visuals=%d" % [_wheel_binds.size(), _source_instances])
	if ghost_mode:
		_ghost_visuals += 1
	var mat_id := 0
	if not _body_mats.is_empty() and _body_mats[0] != null:
		mat_id = int(_body_mats[0].get_instance_id())
	var atlas_rid := ""
	var atlas_w := 0
	var atlas_h := 0
	if _shared_atlas != null:
		atlas_rid = str(_shared_atlas.get_rid())
		atlas_w = _shared_atlas.get_width()
		atlas_h = _shared_atlas.get_height()
	print("[TRACK_CAR_VISUAL] source_instances=%d ghost_visuals=%d atlas_id=%d player_mat_id=%d ghost_mat_id=%d ghost=%s authority=%s atlas_path=%s atlas_rid=%s atlas_px=%dx%d source_resident=%s articulated_resident=%s" % [
		_source_instances,
		_ghost_visuals,
		shared_atlas_id(),
		mat_id,
		ghost_material_id(),
		str(ghost_mode),
		"articulated" if use_articulated else "source",
		atlas_resource_path(),
		atlas_rid,
		atlas_w,
		atlas_h,
		str(source_packed_resident()),
		str(articulated_packed_resident()),
	])
	_log_atlas_diagnostics()


func _packed_for_mode() -> PackedScene:
	if use_articulated:
		if not articulated_override_path.is_empty() and ResourceLoader.exists(articulated_override_path):
			return load(articulated_override_path) as PackedScene
		if _packed_articulated == null and ResourceLoader.exists(VisualConfig.PROCESSED_ARTICULATED_GLB):
			_packed_articulated = load(VisualConfig.PROCESSED_ARTICULATED_GLB) as PackedScene
		if _packed_articulated != null:
			return _packed_articulated
	if _packed_source == null and ResourceLoader.exists(VisualConfig.SOURCE_GLB):
		_packed_source = load(VisualConfig.SOURCE_GLB) as PackedScene
	return _packed_source


func _ensure_shared_atlas() -> void:
	## Canonical imported Texture2D only. Never pull CPU image pixels,
	## decompress, blit, resize, or ImageTexture-rebuild the 4K atlas at runtime.
	if _atlas_is_usable(_shared_atlas):
		return
	if _atlas_load_attempted:
		if not _atlas_is_usable(_shared_atlas):
			_shared_atlas = _make_fallback_atlas()
			_atlas_fallback = true
		return
	_atlas_load_attempted = true
	_atlas_source_path = VisualConfig.SHARED_ATLAS
	var loaded: Texture2D = _load_canonical_atlas()
	if _atlas_is_usable(loaded):
		_shared_atlas = loaded
		_atlas_fallback = false
		print("[TRACK_ATLAS] source_path=%s" % _atlas_source_path)
		print("[TRACK_ATLAS] loaded=true")
		_log_atlas_size_and_format(_shared_atlas)
		return
	push_error("[TRACK_ATLAS] LOAD_FAILED path=%s fallback=true" % _atlas_source_path)
	print("[TRACK_ATLAS] source_path=%s" % _atlas_source_path)
	print("[TRACK_ATLAS] loaded=false")
	print("[TRACK_ATLAS] LOAD_FAILED path=%s fallback=true" % _atlas_source_path)
	_shared_atlas = _make_fallback_atlas()
	_atlas_fallback = true
	_log_atlas_size_and_format(_shared_atlas)


func _load_canonical_atlas() -> Texture2D:
	## One ResourceLoader.load of the source JPEG (imported CompressedTexture2D).
	## Do not retry via .tres ExtResource after failure — that re-enters the same import.
	var path := VisualConfig.SHARED_ATLAS
	if not ResourceLoader.exists(path):
		return null
	var res: Resource = ResourceLoader.load(path, "Texture2D", ResourceLoader.CACHE_MODE_REUSE)
	if res is Texture2D:
		return res as Texture2D
	return null


func _atlas_is_usable(tex: Texture2D) -> bool:
	if tex == null:
		return false
	if tex.get_width() < 2 or tex.get_height() < 2:
		return false
	var rid := tex.get_rid()
	if rid == RID() or not rid.is_valid():
		return false
	return true


func _make_fallback_atlas() -> Texture2D:
	## Tiny CPU image only. Never allocate a 4K ImageTexture after a failed load.
	var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.92, 0.12, 0.78, 1.0))
	return ImageTexture.create_from_image(img)


func _log_atlas_size_and_format(tex: Texture2D) -> void:
	if tex == null:
		print("[TRACK_ATLAS] size=0x0")
		print("[TRACK_ATLAS] format=null")
		return
	print("[TRACK_ATLAS] size=%dx%d" % [tex.get_width(), tex.get_height()])
	print("[TRACK_ATLAS] format=%s" % tex.get_class())


func _log_atlas_diagnostics() -> void:
	var tex := _shared_atlas
	var unique := _unique_atlas_resource_count()
	print("[TRACK_ATLAS] source_path=%s" % (_atlas_source_path if not _atlas_source_path.is_empty() else VisualConfig.SHARED_ATLAS))
	print("[TRACK_ATLAS] loaded=%s" % str(_atlas_is_usable(tex) and not _atlas_fallback))
	_log_atlas_size_and_format(tex)
	print("[TRACK_ATLAS] material_users=%d" % _body_mats.size())
	print("[TRACK_ATLAS] unique_texture_resources=%d" % unique)
	print("[TRACK_ATLAS] fallback=%s rid_valid=%s rid=%s" % [
		str(_atlas_fallback),
		str(tex != null and tex.get_rid().is_valid()),
		str(tex.get_rid()) if tex != null else "",
	])
	print("[TRACK_ATLAS] os_static_memory=%d peak=%d texture_mem=%d video_mem=%d" % [
		OS.get_static_memory_usage(),
		OS.get_static_memory_peak_usage(),
		int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED)),
		int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED)),
	])


func _unique_atlas_resource_count() -> int:
	var ids: Dictionary = {}
	if _shared_atlas != null:
		ids[int(_shared_atlas.get_instance_id())] = true
	for mat in _body_mats:
		if mat is BaseMaterial3D:
			var t: Texture2D = (mat as BaseMaterial3D).albedo_texture
			if t != null:
				ids[int(t.get_instance_id())] = true
	if _shared_ghost_mat != null and _shared_ghost_mat.albedo_texture != null:
		ids[int(_shared_ghost_mat.albedo_texture.get_instance_id())] = true
	return ids.size()


func _strip_imported_physics(node: Node) -> void:
	if node is CollisionObject3D:
		(node as CollisionObject3D).collision_layer = 0
		(node as CollisionObject3D).collision_mask = 0
	if node is CollisionShape3D:
		(node as CollisionShape3D).disabled = true
	for child in node.get_children():
		_strip_imported_physics(child)


func _capture_atlas(node: Node) -> void:
	if _atlas_is_usable(_shared_atlas):
		return
	if node is MeshInstance3D:
		var mesh_inst := node as MeshInstance3D
		if mesh_inst.mesh != null:
			for i in mesh_inst.mesh.get_surface_count():
				var src := mesh_inst.get_active_material(i)
				if src is BaseMaterial3D:
					var tex: Texture2D = (src as BaseMaterial3D).albedo_texture
					if _atlas_is_usable(tex):
						_shared_atlas = tex
						_atlas_fallback = false
						return
	for child in node.get_children():
		_capture_atlas(child)


func _bind_instance_materials(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_inst := node as MeshInstance3D
		if mesh_inst.mesh != null:
			for i in mesh_inst.mesh.get_surface_count():
				if ghost_mode:
					mesh_inst.set_surface_override_material(i, _ghost_material())
				else:
					var inst := _make_player_material(mesh_inst.get_active_material(i))
					mesh_inst.set_surface_override_material(i, inst)
					_body_mats.append(inst)
	for child in node.get_children():
		_bind_instance_materials(child)


func _make_player_material(source: Material) -> StandardMaterial3D:
	## Unique material, shared atlas. Never clone the imported resource
	## (embedded 4K would be copied onto the GPU again). Shallow duplicate
	## of the player template keeps the same albedo_texture RID.
	if _player_mat_template == null and not _atlas_fallback and ResourceLoader.exists(VisualConfig.PLAYER_MATERIAL):
		var tmpl: Resource = ResourceLoader.load(VisualConfig.PLAYER_MATERIAL, "StandardMaterial3D", ResourceLoader.CACHE_MODE_REUSE)
		if tmpl is StandardMaterial3D:
			_player_mat_template = tmpl as StandardMaterial3D
	var mat: StandardMaterial3D
	if _player_mat_template != null:
		mat = _player_mat_template.duplicate(false) as StandardMaterial3D
	else:
		mat = StandardMaterial3D.new()
	mat.albedo_texture = _shared_atlas
	mat.albedo_color = _accent
	mat.metallic = 0.0
	mat.roughness = 0.5
	if source is BaseMaterial3D:
		var src := source as BaseMaterial3D
		mat.metallic = src.metallic
		mat.roughness = src.roughness
		if not _atlas_is_usable(_shared_atlas) and _atlas_is_usable(src.albedo_texture):
			_shared_atlas = src.albedo_texture
			_atlas_fallback = false
			mat.albedo_texture = _shared_atlas
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return mat


func _ghost_material() -> StandardMaterial3D:
	if _shared_ghost_mat != null:
		return _shared_ghost_mat
	_shared_ghost_mat = StandardMaterial3D.new()
	_shared_ghost_mat.albedo_texture = _shared_atlas
	_shared_ghost_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_shared_ghost_mat.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	_shared_ghost_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_shared_ghost_mat.albedo_color = Color(0.72, 0.86, 1.0, 0.38)
	_shared_ghost_mat.metallic = 0.0
	_shared_ghost_mat.roughness = 0.45
	_shared_ghost_mat.emission_enabled = true
	_shared_ghost_mat.emission = Color(0.35, 0.55, 0.95)
	_shared_ghost_mat.emission_energy_multiplier = 0.28
	if ResourceLoader.exists(VisualConfig.GHOST_MATERIAL):
		var tmpl = load(VisualConfig.GHOST_MATERIAL)
		if tmpl is BaseMaterial3D:
			var t := tmpl as BaseMaterial3D
			_shared_ghost_mat.albedo_color = t.albedo_color
			_shared_ghost_mat.emission = t.emission
			_shared_ghost_mat.emission_energy_multiplier = t.emission_energy_multiplier
	return _shared_ghost_mat


func _spawn_debug_pivots() -> void:
	var mapping := {
		"WheelPivotFL": VisualConfig.WHEEL_FL_SOURCE,
		"WheelPivotFR": VisualConfig.WHEEL_FR_SOURCE,
		"WheelPivotRL": VisualConfig.WHEEL_RL_SOURCE,
		"WheelPivotRR": VisualConfig.WHEEL_RR_SOURCE,
	}
	for key in mapping.keys():
		var marker := MeshInstance3D.new()
		marker.name = str(key)
		var sphere := SphereMesh.new()
		sphere.radius = 0.03
		sphere.height = 0.06
		marker.mesh = sphere
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(1.0, 0.85, 0.2, 0.8)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		marker.set_surface_override_material(0, mat)
		marker.position = mapping[key]
		add_child(marker)
		_debug_pivots.append(marker)


func _set_pivots_visible(on: bool) -> void:
	for pivot in _debug_pivots:
		if pivot != null:
			pivot.visible = on


func _orient_articulated_body() -> void:
	if _imported == null:
		return
	var body := _find_named(_imported, "Body") as Node3D
	if body == null:
		return
	body.rotation_degrees.y = VisualConfig.ARTICULATED_BODY_YAW_DEGREES
	print("[TRACK_4WHEEL_BODY] body_yaw=%.1f visual_fwd=%s chassis_fwd=%s geometric_fwd=%s body_nose=%s" % [
		VisualConfig.ARTICULATED_BODY_YAW_DEGREES,
		visual_forward(),
		chassis_forward(),
		geometric_forward() if not _wheel_binds.is_empty() else Vector3.ZERO,
		body_model_nose(),
	])


func _apply_bind_pose(wheel_id: String, steer: float, spin: float, susp_m: float, _rest: float) -> void:
	var bind: Dictionary = _wheel_binds.get(wheel_id, {})
	var steer_p: Node3D = bind.get("steer")
	var spin_p: Node3D = bind.get("spin")
	var susp_p: Node3D = bind.get("susp")
	var mesh: Node3D = bind.get("mesh")
	if steer_p != null:
		steer_p.rotation = Vector3(0.0, steer, 0.0)
		steer_p.scale = Vector3.ONE
	if spin_p != null:
		spin_p.rotation = Vector3(fmod(spin, TAU), 0.0, 0.0)
		spin_p.scale = Vector3.ONE
	if susp_p != null:
		susp_p.rotation = Vector3.ZERO
		susp_p.scale = Vector3.ONE
		susp_p.position = Vector3(0.0, VisualConfig.physics_meters_to_visual_local(susp_m), 0.0)
	if mesh != null and bind.has("rest_transform"):
		mesh.transform = bind["rest_transform"]


func _mesh_vertex_mean(node: Node3D) -> Vector3:
	if not (node is MeshInstance3D):
		return Vector3.ZERO
	var mesh: Mesh = (node as MeshInstance3D).mesh
	if mesh == null or mesh.get_surface_count() < 1:
		return Vector3.ZERO
	var acc := Vector3.ZERO
	var count := 0
	for si in mesh.get_surface_count():
		var arr: Array = mesh.surface_get_arrays(si)
		if arr.is_empty():
			continue
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		for v in verts:
			acc += v
			count += 1
	if count < 1:
		return mesh.get_aabb().get_center()
	return acc / float(count)


func _mesh_centroid_local(node: Node3D) -> Vector3:
	## Axle = inlier vertex mean. Full AABB is polluted by leftover split verts.
	var seed := _mesh_vertex_mean(node)
	if not (node is MeshInstance3D):
		return seed
	var mesh: Mesh = (node as MeshInstance3D).mesh
	if mesh == null or mesh.get_surface_count() < 1:
		return seed
	var acc := Vector3.ZERO
	var count := 0
	for si in mesh.get_surface_count():
		var arr: Array = mesh.surface_get_arrays(si)
		if arr.is_empty():
			continue
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		for v in verts:
			if v.distance_to(seed) <= 0.12:
				acc += v
				count += 1
	if count < 32:
		return seed
	return acc / float(count)


func _bind_articulated_wheels() -> void:
	## V3 wheels are authored with origin at the axle. Mount uses that translation.
	## WheelMesh rest is identity. No inlier-centroid reconstruction.
	if _imported == null:
		return
	var names := ["Wheel_FL", "Wheel_FR", "Wheel_RL", "Wheel_RR"]
	var ids := ["FL", "FR", "RL", "RR"]
	for i in names.size():
		var mesh_node := _find_named(_imported, names[i])
		if mesh_node == null or not (mesh_node is Node3D):
			continue
		var mesh3 := mesh_node as Node3D
		if _wheel_binds.has(ids[i]):
			continue
		var parent := mesh3.get_parent()
		if parent == null:
			continue
		var axle_parent: Vector3 = mesh3.position
		var mount := Node3D.new()
		mount.name = "WheelMount" + ids[i]
		parent.add_child(mount)
		mount.transform = Transform3D(Basis.IDENTITY, axle_parent)
		mount.scale = Vector3.ONE
		var steer := _make_identity_pivot(mount, "SteerPivot")
		var susp := _make_identity_pivot(steer, "SuspensionPivot")
		var spin := _make_identity_pivot(susp, "SpinPivot")
		mesh3.reparent(spin, false)
		mesh3.transform = Transform3D.IDENTITY
		_wheel_binds[ids[i]] = {
			"mount": mount,
			"steer": steer,
			"susp": susp,
			"spin": spin,
			"mesh": mesh3,
			"rest_local": mesh3.position,
			"rest_transform": mesh3.transform,
			"centroid_local": Vector3.ZERO,
			"axle_parent": axle_parent,
		}
		var spin_axis := spin.global_transform.basis.x.normalized()
		print("[TRACK_4WHEEL_BIND] %s mount=%s mesh_rest=%s centroid=%s spin_axis=%s steer=Y spin=X" % [
			ids[i],
			str(mount.position),
			str(mesh3.position),
			str(Vector3.ZERO),
			str(spin_axis),
		])
	_assert_front_rear()
	print("[TRACK_4WHEEL_BODY] geometric_fwd=%s visual_fwd=%s chassis_fwd=%s semantic_fwd=%s" % [
		geometric_forward(), visual_forward(), chassis_forward(), semantic_forward()
	])
	_bind_logged = true


func _make_identity_pivot(parent: Node3D, pname: String) -> Node3D:
	var node := Node3D.new()
	node.name = pname
	parent.add_child(node)
	node.transform = Transform3D.IDENTITY
	node.scale = Vector3.ONE
	return node


func _assert_front_rear() -> void:
	var fl: Dictionary = _wheel_binds.get("FL", {})
	var rl: Dictionary = _wheel_binds.get("RL", {})
	var fl_z := 0.0
	var rl_z := 0.0
	if fl.has("axle_parent"):
		fl_z = float((fl["axle_parent"] as Vector3).z)
	if rl.has("axle_parent"):
		rl_z = float((rl["axle_parent"] as Vector3).z)
	if fl_z >= -0.02 or rl_z <= 0.02:
		push_warning("[TRACK_4WHEEL_BIND] front/rear Z unexpected FL.z=%s RL.z=%s (want FL -Z, RL +Z)" % [str(fl_z), str(rl_z)])
	else:
		print("[TRACK_4WHEEL_BIND] front_rear_ok FL.z=%.3f RL.z=%.3f" % [fl_z, rl_z])


func _find_named(node: Node, wanted: String) -> Node:
	if node.name == wanted:
		return node
	for child in node.get_children():
		var found := _find_named(child, wanted)
		if found != null:
			return found
	return null
