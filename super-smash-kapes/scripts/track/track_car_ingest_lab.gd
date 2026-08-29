class_name TrackCarIngestLab
extends Node3D

## Isolated GLB inspect. No Track gameplay controller.

const VisualConfig := preload("res://scripts/track/track_car_visual_config.gd")
const VisualScript := preload("res://scripts/track/track_car_visual.gd")

var _cam: Camera3D
var _yaw: float = 0.55
var _pitch: float = 0.42
var _dist: float = 2.4
var _focus: Vector3 = Vector3.ZERO
var _raw: Node = null
var _runtime_preview: Node3D = null
var _articulated: Node = null
var _articulated_spin: float = 0.0
var _articulated_steer: float = 0.0
var _articulated_susp: float = 0.0
var _collider_preview: MeshInstance3D
var _label: Label
var _axes_raw: Node3D
var _axes_runtime: Node3D
var _aabb_box: MeshInstance3D
var _show_collider: bool = true
var _show_pivots: bool = true
var _show_axes: bool = true
var _show_aabb: bool = true
var _show_anchors: bool = true
var _anchor_cam: MeshInstance3D
var _anchor_driver: MeshInstance3D


func _ready() -> void:
	_place_environment()
	_place_grid()
	_axes_raw = _make_axes(1.2)
	add_child(_axes_raw)
	_mount_raw()
	_mount_runtime_preview()
	_mount_articulated()
	_place_camera()
	_place_hud()
	_dump_audit()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1:
				_focus = Vector3.ZERO
				_dist = 2.4
			KEY_2:
				_focus = Vector3(8.0, 0.7, 0.0)
				_dist = 8.0
			KEY_3:
				_focus = Vector3(16.0, 0.7, 0.0)
				_dist = 8.0
			KEY_6:
				_articulated_steer = 0.45 if absf(_articulated_steer) < 0.2 else 0.0
				_apply_articulated_debug()
			KEY_7:
				_articulated_spin += 1.2
				_apply_articulated_debug()
			KEY_8:
				_articulated_susp = 0.08 if _articulated_susp < 0.04 else 0.0
				_apply_articulated_debug()
			KEY_F1:
				_show_collider = not _show_collider
				if _collider_preview != null:
					_collider_preview.visible = _show_collider
			KEY_F2:
				_show_axes = not _show_axes
				if _axes_raw != null:
					_axes_raw.visible = _show_axes
				if _axes_runtime != null:
					_axes_runtime.visible = _show_axes
			KEY_F3:
				_show_pivots = not _show_pivots
				if _runtime_preview != null and _runtime_preview.has_method("set_debug_pivots_visible"):
					_runtime_preview.call("set_debug_pivots_visible", _show_pivots)
			KEY_F4:
				_show_anchors = not _show_anchors
				if _anchor_cam != null:
					_anchor_cam.visible = _show_anchors
				if _anchor_driver != null:
					_anchor_driver.visible = _show_anchors
			KEY_F5:
				_show_aabb = not _show_aabb
				if _aabb_box != null:
					_aabb_box.visible = _show_aabb
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_dist = maxf(_dist * 0.9, 0.6)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_dist = minf(_dist * 1.1, 24.0)


func _process(delta: float) -> void:
	var yaw_axis := Input.get_axis("ui_left", "ui_right")
	var pitch_axis := Input.get_axis("ui_down", "ui_up")
	_yaw += yaw_axis * 1.4 * delta
	_pitch = clampf(_pitch + pitch_axis * 1.1 * delta, 0.08, 1.35)
	if _cam != null:
		var offset := Vector3(sin(_yaw) * cos(_pitch), sin(_pitch), cos(_yaw) * cos(_pitch)) * _dist
		_cam.global_position = _focus + offset
		_cam.look_at(_focus, Vector3.UP)
	_refresh_hud()


func _mount_raw() -> void:
	if not ResourceLoader.exists(VisualConfig.SOURCE_GLB):
		push_error("[TRACK_CAR_INGEST] missing source GLB")
		return
	var packed: PackedScene = load(VisualConfig.SOURCE_GLB) as PackedScene
	if packed == null:
		push_error("[TRACK_CAR_INGEST] GLB load failed")
		return
	_raw = packed.instantiate()
	_raw.name = "ImportedCar"
	add_child(_raw)
	_aabb_box = _make_aabb_overlay(_raw)
	if _aabb_box != null:
		add_child(_aabb_box)


func _mount_runtime_preview() -> void:
	var holder := Node3D.new()
	holder.name = "RuntimePreviewHolder"
	holder.position = Vector3(8.0, 0.0, 0.0)
	add_child(holder)
	_runtime_preview = Node3D.new()
	_runtime_preview.set_script(VisualScript)
	_runtime_preview.name = "RuntimePreview"
	_runtime_preview.apply_runtime_transform = true
	_runtime_preview.show_debug_pivots = true
	holder.add_child(_runtime_preview)
	_axes_runtime = _make_axes(2.2)
	_axes_runtime.position = Vector3(8.0, 0.0, 0.0)
	add_child(_axes_runtime)
	_collider_preview = _make_box_mesh(VisualConfig.COLLIDER_SIZE, Color(1.0, 0.45, 0.1, 0.28))
	_collider_preview.name = "ColliderPreview"
	_collider_preview.position = Vector3(8.0, 0.0, 0.0) + VisualConfig.COLLIDER_OFFSET
	add_child(_collider_preview)
	_anchor_cam = _make_marker(Color(0.3, 0.85, 1.0), 0.08)
	_anchor_cam.name = "CameraAnchorPreview"
	_anchor_cam.position = Vector3(8.0, 0.0, 0.0) + VisualConfig.CAMERA_ANCHOR_OFFSET
	add_child(_anchor_cam)
	_anchor_driver = _make_marker(Color(0.95, 0.35, 0.85), 0.07)
	_anchor_driver.name = "DriverHeadAnchorPreview"
	_anchor_driver.position = Vector3(8.0, 0.0, 0.0) + VisualConfig.DRIVER_ANCHOR_OFFSET
	add_child(_anchor_driver)


func _mount_articulated() -> void:
	if not FileAccess.file_exists(VisualConfig.PROCESSED_ARTICULATED_GLB):
		print("[TRACK_CAR_INGEST] articulated GLB missing")
		return
	var holder := Node3D.new()
	holder.name = "ArticulatedPreviewHolder"
	holder.position = Vector3(16.0, 0.0, 0.0)
	add_child(holder)
	_articulated = Node3D.new()
	_articulated.set_script(VisualScript)
	_articulated.name = "ArticulatedPreview"
	_articulated.set("apply_runtime_transform", true)
	_articulated.set("use_articulated", true)
	_articulated.set("show_debug_pivots", true)
	holder.add_child(_articulated)
	var axes := _make_axes(2.2)
	axes.position = Vector3(16.0, 0.0, 0.0)
	add_child(axes)


func _apply_articulated_debug() -> void:
	if _articulated == null or not _articulated.has_method("apply_wheel_states"):
		return
	var states: Array = []
	for id in ["FL", "FR", "RL", "RR"]:
		var steer := _articulated_steer if id.begins_with("F") else 0.0
		states.append({
			"id": id,
			"steer": steer,
			"spin": _articulated_spin,
			"length": 0.12 - _articulated_susp,
			"rest": 0.12,
			"compression": _articulated_susp,
			"grounded": true,
		})
	_articulated.call("apply_wheel_states", states, 0.016)


func _place_camera() -> void:
	_cam = Camera3D.new()
	_cam.name = "DebugCamera"
	_cam.current = true
	_cam.fov = 62.0
	add_child(_cam)


func _place_environment() -> void:
	var sun := DirectionalLight3D.new()
	sun.name = "Lighting"
	sun.rotation_degrees = Vector3(-48, 40, 0)
	sun.light_energy = 1.15
	sun.shadow_enabled = false
	add_child(sun)
	var world := WorldEnvironment.new()
	world.name = "Environment"
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#6d7f90")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#c5d0db")
	env.ambient_light_energy = 0.55
	world.environment = env
	add_child(world)


func _place_grid() -> void:
	var grid := Node3D.new()
	grid.name = "ReferenceGrid"
	add_child(grid)
	for i in range(-6, 7):
		grid.add_child(_line(Vector3(float(i), 0.01, -6.0), Vector3(float(i), 0.01, 6.0), Color(0.2, 0.22, 0.26) if i != 0 else Color(0.55, 0.2, 0.2)))
		grid.add_child(_line(Vector3(-6.0, 0.01, float(i)), Vector3(6.0, 0.01, float(i)), Color(0.2, 0.22, 0.26) if i != 0 else Color(0.2, 0.45, 0.75)))
	var runtime_grid := Node3D.new()
	runtime_grid.name = "ReferenceGridRuntime"
	runtime_grid.position = Vector3(8.0, 0.0, 0.0)
	add_child(runtime_grid)
	for i in range(-4, 5):
		runtime_grid.add_child(_line(Vector3(float(i), 0.01, -4.0), Vector3(float(i), 0.01, 4.0), Color(0.25, 0.28, 0.32)))
		runtime_grid.add_child(_line(Vector3(-4.0, 0.01, float(i)), Vector3(4.0, 0.01, float(i)), Color(0.25, 0.28, 0.32)))


func _place_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 30
	add_child(layer)
	_label = Label.new()
	_label.position = Vector2(16, 12)
	_label.add_theme_font_size_override("font_size", 15)
	_label.add_theme_color_override("font_color", Color(1, 0.96, 0.8))
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_label.add_theme_constant_override("outline_size", 5)
	layer.add_child(_label)


func _refresh_hud() -> void:
	if _label == null:
		return
	_label.text = "\n".join(PackedStringArray([
		"TRACK CAR INGEST LAB",
		"source  %s" % VisualConfig.SOURCE_GLB,
		"wheels  %s" % VisualConfig.WHEEL_STRUCTURE,
		"artic   %s" % VisualConfig.ARTICULATED_WHEEL_STRUCTURE,
		"processed %s" % VisualConfig.PROCESSED_ARTICULATED_GLB,
		"scale   %.4f  (one VisualRoot layer)" % VisualConfig.VISUAL_SCALE,
		"yaw     180 deg (nose +Z → Godot -Z)",
		"collider BoxShape3D %s @ %s" % [str(VisualConfig.COLLIDER_SIZE), str(VisualConfig.COLLIDER_OFFSET)],
		"1 raw   2 fused runtime   3 articulated   wheel zoom   arrows orbit",
		"F1 collider  F2 axes  F3 wheel pivots  F4 anchors  F5 AABB",
		"6 steer front  7 spin  8 suspension (articulated only)",
	]))


func _dump_audit() -> void:
	print("[TRACK_CAR_INGEST] source=%s" % VisualConfig.SOURCE_GLB)
	print("[TRACK_CAR_INGEST] wheel_structure=%s" % VisualConfig.WHEEL_STRUCTURE)
	print("[TRACK_CAR_INGEST] visual_scale=%.5f" % VisualConfig.VISUAL_SCALE)
	if _raw == null:
		print("[TRACK_CAR_INGEST] raw=null")
		return
	print("[TRACK_CAR_INGEST] raw_root=%s type=%s" % [_raw.name, _raw.get_class()])
	var meshes: Array[MeshInstance3D] = []
	_collect_meshes(_raw, meshes)
	print("[TRACK_CAR_INGEST] mesh_count=%d" % meshes.size())
	var verts := 0
	var tris := 0
	var mats := 0
	for mesh_inst in meshes:
		print("[TRACK_CAR_INGEST] mesh_node=%s parent=%s" % [mesh_inst.name, mesh_inst.get_parent().name if mesh_inst.get_parent() else ""])
		if mesh_inst.mesh == null:
			continue
		for s in mesh_inst.mesh.get_surface_count():
			verts += int(mesh_inst.mesh.surface_get_array_len(s))
			var arrays := mesh_inst.mesh.surface_get_arrays(s)
			if arrays.size() > Mesh.ARRAY_INDEX and arrays[Mesh.ARRAY_INDEX] != null:
				tris += int(arrays[Mesh.ARRAY_INDEX].size() / 3)
			mats += 1
		var aabb: AABB = mesh_inst.mesh.get_aabb()
		print("[TRACK_CAR_INGEST] aabb_size=%s aabb_pos=%s" % [aabb.size, aabb.position])
	print("[TRACK_CAR_INGEST] verts=%d tris=%d surfaces=%d" % [verts, tris, mats])
	_dump_tree(_raw, 0)


func _dump_tree(node: Node, depth: int) -> void:
	var pad := ""
	for _i in depth:
		pad += "  "
	print("[TRACK_CAR_INGEST] %s%s (%s)" % [pad, node.name, node.get_class()])
	for child in node.get_children():
		_dump_tree(child, depth + 1)


func _collect_meshes(node: Node, out: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		out.append(node)
	for child in node.get_children():
		_collect_meshes(child, out)


func _make_aabb_overlay(root: Node) -> MeshInstance3D:
	var meshes: Array[MeshInstance3D] = []
	_collect_meshes(root, meshes)
	if meshes.is_empty() or meshes[0].mesh == null:
		return null
	var aabb: AABB = meshes[0].mesh.get_aabb()
	var box := _make_box_mesh(aabb.size, Color(0.2, 0.9, 0.4, 0.12))
	box.name = "BoundingBox"
	box.position = aabb.position + aabb.size * 0.5
	return box


func _make_axes(length: float) -> Node3D:
	var root := Node3D.new()
	root.name = "ReferenceAxes"
	root.add_child(_line(Vector3.ZERO, Vector3(length, 0, 0), Color(0.9, 0.2, 0.2)))
	root.add_child(_line(Vector3.ZERO, Vector3(0, length, 0), Color(0.2, 0.85, 0.3)))
	root.add_child(_line(Vector3.ZERO, Vector3(0, 0, length), Color(0.2, 0.45, 1.0)))
	return root


func _line(a: Vector3, b: Vector3, color: Color) -> MeshInstance3D:
	var mesh_inst := MeshInstance3D.new()
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	im.surface_set_color(color)
	im.surface_add_vertex(a)
	im.surface_add_vertex(b)
	im.surface_end()
	mesh_inst.mesh = im
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = color
	mesh_inst.set_surface_override_material(0, mat)
	return mesh_inst


func _make_box_mesh(size: Vector3, color: Color) -> MeshInstance3D:
	var mesh_inst := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh_inst.mesh = box
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = color
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh_inst.set_surface_override_material(0, mat)
	return mesh_inst


func _make_marker(color: Color, radius: float) -> MeshInstance3D:
	var mesh_inst := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	mesh_inst.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 0.6
	mesh_inst.set_surface_override_material(0, mat)
	return mesh_inst
