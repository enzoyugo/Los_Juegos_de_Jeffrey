extends "res://scripts/fighters/fighter_visual.gd"

const TUMBLE_SPEED_THRESHOLD := 9.0
const GLB_FIGHTER_CONFIG := preload("res://scripts/fighters/glb_fighter_config.gd")
const GAMEPLAY_COLLIDER_HEIGHT := 2.4

var config

var motion_root: Node3D
var presentation_root: Node3D
var facing_root: Node3D
var import_correction_root: Node3D
var model_root: Node3D
var model_instance: Node3D
var shadow_mesh: MeshInstance3D
var _delegate
var _using_fallback: bool = false
var _base_yaw: float = 0.0
var _base_pitch: float = 0.0
var _fit_scale: float = 1.0
var _presentation_scale: float = 1.0
var _ground_offset: float = 0.0
var _body_effective_height: float = 0.0
var _visual_width: float = 0.0
var _flash_materials: Array[StandardMaterial3D] = []
var _land_punch: float = 0.0
var _was_airborne: bool = false
var _tumble_angle: float = 0.0
var _model_audit_enabled: bool = OS.get_environment("SSK_MODEL_AUDIT") == "1"
static var debug_bounds_enabled: bool = false
var _bounds_debug_mesh: MeshInstance3D

func _ready() -> void:
	if config == null:
		push_error("GlbFighterVisual missing config")
		_spawn_fallback()
		return
	if not _load_glb_model():
		push_warning("GLB load failed for %s — procedural fallback" % config.glb_path)
		_spawn_fallback()

func bind(fighter_ref, fighter_definition) -> void:
	super.bind(fighter_ref, fighter_definition)
	if _using_fallback and _delegate != null:
		_delegate.bind(fighter_ref, fighter_definition)
	_audit_spawn()
	if has_method("_log_pipeline_audit"):
		call("_log_pipeline_audit")

func sync_from_fighter(delta: float) -> void:
	if _using_fallback:
		if _delegate != null:
			_delegate.sync_from_fighter(delta)
		return
	super.sync_from_fighter(delta)

func set_facing(direction: float) -> void:
	facing = signf(direction) if abs(direction) > 0.01 else facing
	if _using_fallback:
		if _delegate != null:
			_delegate.set_facing(direction)
		return
	if facing_root != null:
		facing_root.rotation = Vector3(0.0, 0.0 if facing > 0.0 else PI, 0.0)
	if model_root != null:
		model_root.rotation = Vector3(_base_pitch, _base_yaw, 0.0)
	_apply_import_correction()

func on_attack_started() -> void:
	if _using_fallback:
		if _delegate != null:
			_delegate.on_attack_started()
		return
	super.on_attack_started()

func on_hit() -> void:
	if _using_fallback:
		if _delegate != null:
			_delegate.on_hit()
		return
	super.on_hit()

func on_jump() -> void:
	if _using_fallback:
		if _delegate != null:
			_delegate.on_jump()
		return
	_land_punch = 0.0

func on_land() -> void:
	if _using_fallback:
		if _delegate != null:
			_delegate.on_land()
		return
	_land_punch = 0.12

func on_respawn() -> void:
	if _using_fallback:
		if _delegate != null:
			_delegate.on_respawn()
		return
	super.on_respawn()

func on_eliminated() -> void:
	if _using_fallback:
		if _delegate != null:
			_delegate.on_eliminated()
		return
	super.on_eliminated()

func on_victory() -> void:
	if _using_fallback:
		if _delegate != null:
			_delegate.on_victory()
		return
	super.on_victory()

func _idle_uses_skeletal() -> bool:
	return false


func _load_glb_model() -> bool:
	var packed_root := _instantiate_glb(config.glb_path)
	if packed_root == null:
		return false
	motion_root = Node3D.new()
	motion_root.name = "VisualMotionRoot"
	add_child(motion_root)
	presentation_root = Node3D.new()
	presentation_root.name = "PresentationScaleRoot"
	motion_root.add_child(presentation_root)
	facing_root = Node3D.new()
	facing_root.name = "FacingRoot"
	presentation_root.add_child(facing_root)
	import_correction_root = Node3D.new()
	import_correction_root.name = "ImportCorrectionRoot"
	facing_root.add_child(import_correction_root)
	model_root = Node3D.new()
	model_root.name = "ModelRoot"
	import_correction_root.add_child(model_root)
	model_instance = packed_root
	model_instance.name = "ImportedModel"
	model_root.add_child(model_instance)
	_align_model_to_gameplay()
	_cache_flash_materials(model_instance)
	if config.shadow_enabled:
		_add_blob_shadow()
	return true


func _instantiate_glb(path: String) -> Node3D:
	if path.is_empty():
		return null
	var abs_path := ProjectSettings.globalize_path(path)
	if ResourceLoader.exists(config.glb_path, "PackedScene") and path == config.glb_path:
		var packed: PackedScene = load(config.glb_path)
		if packed:
			var inst := packed.instantiate() as Node3D
			if inst:
				return inst
	elif ResourceLoader.exists(path, "PackedScene"):
		var packed_alt: PackedScene = load(path)
		if packed_alt:
			var inst_alt := packed_alt.instantiate() as Node3D
			if inst_alt:
				return inst_alt
	if not FileAccess.file_exists(abs_path):
		return null
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	if doc.append_from_file(abs_path, state) != OK:
		return null
	var generated := doc.generate_scene(state) as Node3D
	if generated != null:
		_isolate_fighter_textures(generated, path.get_file().get_basename())
		_vram_compress_runtime_textures(generated)
	return generated


func _isolate_fighter_textures(node: Node, prefix: String) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.mesh != null:
			for i in mi.mesh.get_surface_count():
				var mat := mi.mesh.surface_get_material(i)
				if mat is StandardMaterial3D:
					var isolated: StandardMaterial3D = (mat as StandardMaterial3D).duplicate(false) as StandardMaterial3D
					if isolated != null:
						isolated.resource_local_to_scene = true
						isolated.resource_name = "%s_mat%d" % [prefix, i]
						isolated.albedo_texture = _prefixed_texture(isolated.albedo_texture, prefix + "_albedo")
						isolated.normal_texture = _prefixed_texture(isolated.normal_texture, prefix + "_normal")
						mi.mesh.surface_set_material(i, isolated)
	for child in node.get_children():
		_isolate_fighter_textures(child, prefix)


func _prefixed_texture(tex: Texture2D, prefix: String) -> Texture2D:
	if tex == null:
		return null
	var copy := tex.duplicate(true) as Texture2D
	if copy == null:
		return tex
	copy.resource_name = prefix
	copy.resource_local_to_scene = true
	return copy


func _vram_compress_runtime_textures(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_inst := node as MeshInstance3D
		var mesh := mesh_inst.mesh
		if mesh != null:
			for i in mesh.get_surface_count():
				var mat := mesh_inst.get_active_material(i)
				if mat == null:
					mat = mesh.surface_get_material(i)
				_compress_standard_material(mat)
	for child in node.get_children():
		_vram_compress_runtime_textures(child)


func _compress_standard_material(mat: Material) -> void:
	if not (mat is StandardMaterial3D):
		return
	var sm := mat as StandardMaterial3D
	sm.albedo_texture = _compressed_texture(sm.albedo_texture, false)
	sm.normal_texture = _compressed_texture(sm.normal_texture, true)


func _compressed_texture(tex: Texture2D, is_normal: bool) -> Texture2D:
	if tex == null or tex is CompressedTexture2D:
		return tex
	if not (tex is ImageTexture):
		return tex
	var img: Image = (tex as ImageTexture).get_image()
	if img == null or img.is_empty() or img.is_compressed():
		return tex
	if img.get_mipmap_count() == 0:
		img.generate_mipmaps()
	var source := Image.COMPRESS_SOURCE_NORMAL if is_normal else Image.COMPRESS_SOURCE_GENERIC
	if img.compress(Image.COMPRESS_BPTC, source) != OK:
		img.compress(Image.COMPRESS_S3TC, source)
	var compressed := ImageTexture.create_from_image(img)
	return compressed

func _align_model_to_gameplay() -> void:
	var full_bounds := _compute_local_aabb(model_instance)
	if full_bounds.size.length() < 0.001:
		return
	_base_pitch = config.model_pitch_offset
	_base_yaw = config.model_yaw_offset
	_apply_import_correction()
	model_root.rotation = Vector3(_base_pitch, _base_yaw, 0.0)
	if facing_root != null:
		facing_root.rotation = Vector3(0.0, 0.0 if facing > 0.0 else PI, 0.0)
	var oriented_bounds := _aabb_after_import_rotation(full_bounds)
	var measured_body_height: float = _measure_body_height(oriented_bounds)
	var ground_min_y: float = oriented_bounds.position.y
	var width_src: float = maxf(oriented_bounds.size.x, oriented_bounds.size.z)
	if _uses_import_correction() or absf(_base_pitch) > 0.0001:
		var skel_ext := _skeleton_y_extent()
		if skel_ext.y > 0.05:
			measured_body_height = _measure_body_height(AABB(Vector3(0.0, skel_ext.x, 0.0), Vector3(0.1, skel_ext.y, 0.1)))
			ground_min_y = skel_ext.x
			width_src = maxf(skel_ext.y * 0.4, 0.35)
	_body_effective_height = measured_body_height
	var target_height: float = maxf(config.target_visual_height, 0.1)
	_fit_scale = 1.0
	_presentation_scale = target_height / maxf(measured_body_height, 0.001)
	presentation_root.scale = Vector3.ONE * _presentation_scale
	var scaled_min_y: float = ground_min_y * _presentation_scale
	_ground_offset = -scaled_min_y + config.ground_anchor
	if _uses_import_correction() or absf(_base_pitch) > 0.0001:
		model_root.position = Vector3(
			config.extra_offset.x,
			_ground_offset + config.extra_offset.y,
			config.extra_offset.z
		)
	else:
		var anchor_x: float = lerpf(oriented_bounds.position.x, oriented_bounds.position.x + oriented_bounds.size.x, config.horizontal_anchor_fraction)
		var anchor_z: float = oriented_bounds.position.z + oriented_bounds.size.z * 0.5
		model_root.position = Vector3(
			-anchor_x * _presentation_scale + config.extra_offset.x,
			_ground_offset + config.extra_offset.y,
			-anchor_z * _presentation_scale + config.extra_offset.z
		)
	_visual_width = width_src * _presentation_scale
	if shadow_mesh != null:
		shadow_mesh.scale = Vector3(config.shadow_width, 1.0, config.shadow_depth)
	_refresh_bounds_debug()


func _uses_import_correction() -> bool:
	if config == null:
		return false
	return (
		absf(config.import_correction_pitch_deg) > 0.01
		or absf(config.import_correction_yaw_deg) > 0.01
		or absf(config.import_correction_roll_deg) > 0.01
	)


func _apply_import_correction() -> void:
	if import_correction_root == null or config == null:
		return
	var rx := Basis.from_euler(Vector3(deg_to_rad(config.import_correction_pitch_deg), 0.0, 0.0))
	var ry := Basis.from_euler(Vector3(0.0, deg_to_rad(config.import_correction_yaw_deg), 0.0))
	var rz := Basis.from_euler(Vector3(0.0, 0.0, deg_to_rad(config.import_correction_roll_deg)))
	## Pitch first, then yaw: matches the measured Rx-90 then Ry-90 standing+facing basis.
	import_correction_root.basis = ry * rx * rz
	import_correction_root.position = Vector3.ZERO
	var full_bounds := _compute_local_aabb(model_instance)
	if full_bounds.size.length() < 0.001:
		return
	_base_pitch = config.model_pitch_offset
	_base_yaw = config.model_yaw_offset
	model_root.rotation = Vector3(_base_pitch, _base_yaw, 0.0)
	if facing_root != null:
		facing_root.rotation = Vector3(0.0, 0.0 if facing > 0.0 else PI, 0.0)
	var oriented_bounds := _aabb_after_import_rotation(full_bounds)
	var measured_body_height: float = _measure_body_height(oriented_bounds)
	var ground_min_y: float = oriented_bounds.position.y
	var width_src: float = maxf(oriented_bounds.size.x, oriented_bounds.size.z)
	if absf(_base_pitch) > 0.0001:
		var skel_ext := _skeleton_y_extent()
		if skel_ext.y > 0.05:
			measured_body_height = _measure_body_height(AABB(Vector3(0.0, skel_ext.x, 0.0), Vector3(0.1, skel_ext.y, 0.1)))
			ground_min_y = skel_ext.x
			width_src = maxf(skel_ext.y * 0.4, 0.35)
	_body_effective_height = measured_body_height
	var target_height: float = maxf(config.target_visual_height, 0.1)
	_fit_scale = 1.0
	_presentation_scale = target_height / maxf(measured_body_height, 0.001)
	presentation_root.scale = Vector3.ONE * _presentation_scale
	var scaled_min_y: float = ground_min_y * _presentation_scale
	_ground_offset = -scaled_min_y + config.ground_anchor
	if absf(_base_pitch) > 0.0001:
		model_root.position = Vector3(
			config.extra_offset.x,
			_ground_offset + config.extra_offset.y,
			config.extra_offset.z
		)
	else:
		var anchor_x: float = lerpf(oriented_bounds.position.x, oriented_bounds.position.x + oriented_bounds.size.x, config.horizontal_anchor_fraction)
		var anchor_z: float = oriented_bounds.position.z + oriented_bounds.size.z * 0.5
		model_root.position = Vector3(
			-anchor_x * _presentation_scale + config.extra_offset.x,
			_ground_offset + config.extra_offset.y,
			-anchor_z * _presentation_scale + config.extra_offset.z
		)
	_visual_width = width_src * _presentation_scale
	if shadow_mesh != null:
		shadow_mesh.scale = Vector3(config.shadow_width, 1.0, config.shadow_depth)
	_refresh_bounds_debug()

func _measure_body_height(full_bounds: AABB) -> float:
	var mode: String = str(config.body_measure_mode)
	if mode == "IGNORE_TOP" or (mode.is_empty() and config.fit_ignore_top_ratio > 0.0):
		var ignore_ratio: float = clampf(config.fit_ignore_top_ratio, 0.0, 0.45)
		return full_bounds.size.y * (1.0 - ignore_ratio)
	if mode == "BODY_FRACTION" or mode == "FRACTION" or config.body_height_fraction < 0.999:
		var fraction: float = clampf(config.body_height_fraction, 0.55, 1.0)
		return full_bounds.size.y * fraction
	return full_bounds.size.y


func _aabb_after_import_rotation(src: AABB) -> AABB:
	var basis := Basis.from_euler(Vector3(_base_pitch, _base_yaw, 0.0))
	var out := AABB()
	var first := true
	for i in 8:
		var point: Vector3 = basis * src.get_endpoint(i)
		if first:
			out = AABB(point, Vector3.ZERO)
			first = false
		else:
			out = out.expand(point)
	return out


func _skeleton_y_extent() -> Vector2:
	var skel := _find_child_skeleton(model_instance)
	if skel == null:
		return Vector2.ZERO
	var min_y := INF
	var max_y := -INF
	for bone_i in skel.get_bone_count():
		var origin: Vector3 = skel.to_global(skel.get_bone_global_pose(bone_i).origin)
		if presentation_root != null:
			origin = presentation_root.to_local(origin)
		min_y = minf(min_y, origin.y)
		max_y = maxf(max_y, origin.y)
	if min_y == INF:
		return Vector2.ZERO
	return Vector2(min_y, max_y - min_y)


func _find_child_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for child in node.get_children():
		var found := _find_child_skeleton(child)
		if found:
			return found
	return null


func _compute_body_bounds(full_bounds: AABB) -> AABB:
	var fraction: float = clampf(config.body_height_fraction, 0.55, 1.0)
	var body_height: float = full_bounds.size.y * fraction
	var body_min_y: float = full_bounds.position.y
	return AABB(
		Vector3(full_bounds.position.x, body_min_y, full_bounds.position.z),
		Vector3(full_bounds.size.x, body_height, full_bounds.size.z)
	)

func _compute_local_aabb(root: Node3D) -> AABB:
	var combined := AABB()
	var first := true
	for mesh_inst in _collect_mesh_instances(root):
		if mesh_inst.mesh == null:
			continue
		var mesh_aabb: AABB = mesh_inst.mesh.get_aabb()
		for i in 8:
			var point: Vector3 = mesh_inst.transform * mesh_aabb.get_endpoint(i)
			if first:
				combined = AABB(point, Vector3.ZERO)
				first = false
			else:
				combined = combined.expand(point)
	return combined

func _collect_mesh_instances(node: Node) -> Array[MeshInstance3D]:
	var found: Array[MeshInstance3D] = []
	_gather_meshes(node, found)
	return found

func _gather_meshes(node: Node, found: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		found.append(node)
	for child in node.get_children():
		_gather_meshes(child, found)

func _cache_flash_materials(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_inst := node as MeshInstance3D
		var surface_count := mesh_inst.get_surface_override_material_count()
		if surface_count == 0 and mesh_inst.mesh != null:
			surface_count = mesh_inst.mesh.get_surface_count()
		for i in surface_count:
			var source := mesh_inst.get_surface_override_material(i)
			if source == null and mesh_inst.mesh != null:
				source = mesh_inst.mesh.surface_get_material(i)
			if source == null:
				continue
			var duplicate_mat: StandardMaterial3D = source.duplicate(false) as StandardMaterial3D
			if duplicate_mat == null:
				continue
			mesh_inst.set_surface_override_material(i, duplicate_mat)
			_flash_materials.append(duplicate_mat)
	for child in node.get_children():
		_cache_flash_materials(child)

func _add_blob_shadow() -> void:
	shadow_mesh = MeshInstance3D.new()
	shadow_mesh.name = "BlobShadow"
	var quad := QuadMesh.new()
	quad.size = Vector2(config.shadow_width, config.shadow_depth)
	shadow_mesh.mesh = quad
	shadow_mesh.rotation.x = -PI * 0.5
	shadow_mesh.position = Vector3(0.0, 0.02, 0.0)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.0, 0.0, 0.0, 0.32)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	shadow_mesh.material_override = mat
	add_child(shadow_mesh)

func _spawn_fallback() -> void:
	_using_fallback = true
	push_error("[FIGHTER_PIPELINE][ERROR] ActorCore production asset failed. path=%s" % (config.glb_path if config else "?"))
	var fallback_script: Script = config.fallback_visual_script if config else null
	if fallback_script == null and config != null and not config.fallback_visual_path.is_empty():
		fallback_script = load(config.fallback_visual_path) as Script
	if fallback_script != null:
		_delegate = fallback_script.new()
		_delegate.name = "EmergencyFallback"
		add_child(_delegate)

func _apply_motion(delta: float) -> void:
	if motion_root == null or fighter == null:
		return
	var speed := Vector2(fighter.velocity.x, fighter.velocity.y).length()
	var on_floor: bool = fighter.is_on_floor()
	if on_floor and _was_airborne:
		_land_punch = maxf(_land_punch, 0.12)
	_was_airborne = not on_floor

	var bob := 0.0
	var breath := 1.0
	var lean_z := 0.0
	var lean_x := 0.0
	var offset := Vector3.ZERO
	var squash := Vector3.ONE
	var tumble_z := 0.0

	match _state_label:
		"IDLE":
			if _idle_uses_skeletal():
				bob = 0.0
				breath = 1.0
				lean_z = 0.0
			else:
				bob = sin(fighter.visual_time * 4.8) * 0.018
				breath = 1.0 + sin(fighter.visual_time * 3.2) * 0.012
				lean_z = sin(fighter.visual_time * 2.4) * 0.02
		"RUN":
			bob = abs(sin(fighter.visual_time * 10.0)) * 0.028
			lean_x = 0.08 * facing
			lean_z = sin(fighter.visual_time * 10.0) * 0.04
		"AIR":
			lean_z = clampf(-fighter.velocity.x * 0.012, -0.12, 0.12)
			squash = Vector3(0.97, 1.05, 0.98)
		"ATTACK":
			var punch := _attack_punch / 0.18
			lean_x = 0.14 * facing * punch
			lean_z = -0.06 * facing * punch
			offset.x = 0.08 * facing * punch
			squash = Vector3(1.04, 0.96, 1.0)
		"HITSTUN":
			lean_z = -0.16 * facing
			if speed >= TUMBLE_SPEED_THRESHOLD:
				_tumble_angle += delta * clampf(speed * 0.45, 4.0, 12.0) * signf(fighter.velocity.y if absf(fighter.velocity.y) > 0.1 else 1.0)
				tumble_z = _tumble_angle
			else:
				_tumble_angle = lerpf(_tumble_angle, 0.0, minf(delta * 8.0, 1.0))
				tumble_z = _tumble_angle
		"RESPAWN":
			bob = sin(fighter.visual_time * 8.0) * 0.01
		"VICTORY":
			breath = 1.0 + sin(fighter.visual_time * 5.0) * 0.02
			lean_z = 0.08 * facing
		"KO":
			tumble_z = lerpf(_tumble_angle, 0.8 * signf(fighter.velocity.y), minf(delta * 3.0, 1.0))

	if _land_punch > 0.0:
		var land_strength := _land_punch / 0.12
		squash = Vector3(1.08, 0.9, 1.08) * land_strength + Vector3.ONE * (1.0 - land_strength)
		_land_punch = maxf(_land_punch - delta, 0.0)

	if _state_label != "HITSTUN" and _state_label != "KO":
		_tumble_angle = lerpf(_tumble_angle, 0.0, minf(delta * 10.0, 1.0))
		tumble_z = _tumble_angle

	if _idle_uses_skeletal() and _state_label == "IDLE":
		_reset_motion_roots(delta)
		position.y = lerpf(position.y, definition.visual_offset.y, minf(delta * 12.0, 1.0))
	else:
		motion_root.position = motion_root.position.lerp(offset, minf(delta * 16.0, 1.0))
		motion_root.rotation.z = lerpf(motion_root.rotation.z, lean_z + tumble_z, minf(delta * 12.0, 1.0))
		motion_root.rotation.x = lerpf(motion_root.rotation.x, lean_x, minf(delta * 12.0, 1.0))
		motion_root.scale = motion_root.scale.lerp(squash * breath, minf(delta * 14.0, 1.0))
		position.y = lerpf(position.y, bob + definition.visual_offset.y, minf(delta * 12.0, 1.0))

	if fighter.invulnerability_time > 0.0:
		visible = fmod(fighter.invulnerability_time, 0.12) > 0.045
	else:
		visible = true


func _reset_motion_roots(delta: float = 1.0) -> void:
	if motion_root == null:
		return
	var t := minf(delta * 16.0, 1.0)
	motion_root.position = motion_root.position.lerp(Vector3.ZERO, t)
	motion_root.rotation.x = lerpf(motion_root.rotation.x, 0.0, minf(delta * 12.0, 1.0))
	motion_root.rotation.z = lerpf(motion_root.rotation.z, 0.0, minf(delta * 12.0, 1.0))
	motion_root.scale = motion_root.scale.lerp(Vector3.ONE, minf(delta * 14.0, 1.0))
	_tumble_angle = 0.0


func snap_motion_roots_neutral() -> void:
	_reset_motion_roots(1.0)
	if motion_root != null:
		motion_root.transform = Transform3D.IDENTITY


func collect_transform_stack() -> Array:
	var stack: Array = []
	var node: Node = self
	while node != null:
		if node is Node3D:
			var n3 := node as Node3D
			var q := n3.quaternion
			stack.append({
				"name": n3.name,
				"class": n3.get_class(),
				"position": [n3.position.x, n3.position.y, n3.position.z],
				"rotation_deg": [rad_to_deg(n3.rotation.x), rad_to_deg(n3.rotation.y), rad_to_deg(n3.rotation.z)],
				"quaternion": [q.x, q.y, q.z, q.w],
				"scale": [n3.scale.x, n3.scale.y, n3.scale.z],
			})
		node = node.get_parent()
	stack.reverse()
	var descendants: Array[Node3D] = [motion_root, presentation_root, facing_root, model_root, model_instance]
	for child in descendants:
		if child == null:
			continue
		var q2: Quaternion = child.quaternion
		stack.append({
			"name": child.name,
			"class": child.get_class(),
			"position": [child.position.x, child.position.y, child.position.z],
			"rotation_deg": [rad_to_deg(child.rotation.x), rad_to_deg(child.rotation.y), rad_to_deg(child.rotation.z)],
			"quaternion": [q2.x, q2.y, q2.z, q2.w],
			"scale": [child.scale.x, child.scale.y, child.scale.z],
		})
	return stack


func _apply_hit_flash() -> void:
	var flashing := _hit_flash_time > 0.0
	for material in _flash_materials:
		material.emission_enabled = flashing
		if flashing:
			material.emission = Color(1.0, 0.92, 0.78)
			material.emission_energy_multiplier = 0.85
		else:
			material.emission_energy_multiplier = 0.0

func _refresh_bounds_debug() -> void:
	if _using_fallback or model_root == null or model_instance == null:
		return
	if _bounds_debug_mesh == null:
		_bounds_debug_mesh = MeshInstance3D.new()
		_bounds_debug_mesh.name = "VisualBoundsDebug"
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(0.2, 1.0, 0.45, 0.35)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_bounds_debug_mesh.material_override = mat
		model_root.add_child(_bounds_debug_mesh)
	_bounds_debug_mesh.visible = debug_bounds_enabled
	if not debug_bounds_enabled:
		return
	var bounds := _compute_local_aabb(model_instance)
	var box := BoxMesh.new()
	box.size = bounds.size
	_bounds_debug_mesh.mesh = box
	_bounds_debug_mesh.position = bounds.position + bounds.size * 0.5

func _audit_spawn() -> void:
	if not _model_audit_enabled or _using_fallback:
		return
	var id_text: String = definition.id if definition != null else "unknown"
	var mesh_count := _collect_mesh_instances(model_instance).size() if model_instance != null else 0
	var ratio: float = (_body_effective_height * _presentation_scale) / GAMEPLAY_COLLIDER_HEIGHT
	print(
		"[MODEL_AUDIT] fighter=%s class=%s target=%.2f measured=%.3f presentation=%.4f body_h=%.3f ground_y=%.4f width=%.3f collider_h=%.2f ratio=%.2f yaw=%.2f meshes=%d mats=%d" % [
			id_text,
			config.size_class if config != null else "?",
			config.target_visual_height if config != null else 0.0,
			_body_effective_height,
			_presentation_scale,
			_body_effective_height * _presentation_scale,
			_ground_offset,
			_visual_width,
			GAMEPLAY_COLLIDER_HEIGHT,
			(_body_effective_height * _presentation_scale) / GAMEPLAY_COLLIDER_HEIGHT,
			_base_yaw,
			mesh_count,
			_flash_materials.size()
		]
	)
