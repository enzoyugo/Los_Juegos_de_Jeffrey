extends "res://scripts/debug/actorcore_animation_lab.gd"

## Production idle/library lab.
## 1 REST  2 IDLE  3 skeleton overlay  4 material debug  5 bbox debug
## RUNTIME RETARGET: OFF

@export var fighter_id: String = "terere"
@export var pipeline_id: String = "ACTORCORE_V4"
@export var target_height: float = 2.40
@export var production_glb: String = ""

var _skel_overlay: bool = false
var _mat_debug: bool = false
var _bbox_debug: bool = false
var _bbox_mesh: MeshInstance3D
var _overlay_meshes: Array[MeshInstance3D] = []


func _ready() -> void:
	if production_glb != "":
		benchmark_glb = production_glb
	super._ready()
	_refresh_status()


func _handle_lab_key(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match (event as InputEventKey).keycode:
		KEY_1:
			if _animation_player:
				_animation_player.stop()
			if _skeleton:
				_skeleton.reset_bone_poses()
		KEY_2:
			if _animation_player and not _resolved_idle.is_empty():
				_animation_player.play(_resolved_idle, 0.1)
		KEY_3:
			_skel_overlay = not _skel_overlay
			_apply_skeleton_overlay()
		KEY_4:
			_mat_debug = not _mat_debug
			_apply_material_debug()
		KEY_5:
			_bbox_debug = not _bbox_debug
			_apply_bbox_debug()
	_refresh_status()


func _refresh_status() -> void:
	if _status == null:
		return
	var bones := _skeleton.get_bone_count() if _skeleton else 0
	var anim := _resolved_idle if not _resolved_idle.is_empty() else "NONE"
	var tracks := _bone_track_count()
	var frame := 0.0
	if _animation_player and _animation_player.is_playing():
		frame = _animation_player.current_animation_position
	var aabb := _model_aabb()
	_status.text = (
		"FIGHTER %s | MODEL %s | PIPELINE %s | BONES %d | ACTION %s | FRAME %.2f | TRACKS %d | TARGET HEIGHT %.2f | BOUNDING BOX %.2f x %.2f x %.2f | MATERIAL %s | FALLBACK none | RETARGET OFF | [1] REST [2] IDLE [3] SKEL %s [4] MAT %s [5] BBOX %s"
		% [
			fighter_id,
			benchmark_glb.get_file(),
			pipeline_id,
			bones,
			anim,
			frame,
			tracks,
			target_height,
			aabb.size.x,
			aabb.size.y,
			aabb.size.z,
			"DEBUG" if _mat_debug else "PRODUCTION",
			"ON" if _skel_overlay else "off",
			"ON" if _mat_debug else "off",
			"ON" if _bbox_debug else "off",
		]
	)


func _model_aabb() -> AABB:
	if _model_root == null:
		return AABB()
	var combined := AABB()
	var first := true
	var stack: Array[Node] = [_model_root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
			var mi := node as MeshInstance3D
			var local: AABB = mi.mesh.get_aabb()
			for i in 8:
				var pt: Vector3 = mi.global_transform * local.get_endpoint(i)
				if first:
					combined = AABB(pt, Vector3.ZERO)
					first = false
				else:
					combined = combined.expand(pt)
		for child in node.get_children():
			stack.append(child)
	return combined


func _apply_skeleton_overlay() -> void:
	if _skeleton == null:
		return
	for mesh in _overlay_meshes:
		if is_instance_valid(mesh):
			mesh.queue_free()
	_overlay_meshes.clear()
	if not _skel_overlay:
		return
	for i in _skeleton.get_bone_count():
		var marker := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.012
		sphere.height = 0.024
		marker.mesh = sphere
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(0.2, 1.0, 0.45)
		marker.material_override = mat
		marker.position = _skeleton.to_global(_skeleton.get_bone_global_pose(i).origin)
		_model_root.add_child(marker)
		_overlay_meshes.append(marker)


func _apply_material_debug() -> void:
	var stack: Array[Node] = [_model_root] if _model_root else []
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is MeshInstance3D:
			var mi := node as MeshInstance3D
			if mi.mesh == null:
				continue
			for i in mi.mesh.get_surface_count():
				var source := mi.get_surface_override_material(i)
				if source == null:
					source = mi.mesh.surface_get_material(i)
				if source is StandardMaterial3D:
					var sm := source as StandardMaterial3D
					if _mat_debug:
						sm.emission_enabled = true
						sm.emission = Color(0.15, 0.55, 1.0)
						sm.emission_energy_multiplier = 0.35
					else:
						sm.emission_enabled = false
						sm.emission_energy_multiplier = 0.0
		for child in node.get_children():
			stack.append(child)


func _apply_bbox_debug() -> void:
	if _bbox_mesh == null:
		_bbox_mesh = MeshInstance3D.new()
		_bbox_mesh.name = "BBoxDebug"
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(1.0, 0.85, 0.2, 0.28)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_bbox_mesh.material_override = mat
		add_child(_bbox_mesh)
	_bbox_mesh.visible = _bbox_debug
	if not _bbox_debug:
		return
	var aabb := _model_aabb()
	var box := BoxMesh.new()
	box.size = aabb.size
	_bbox_mesh.mesh = box
	_bbox_mesh.global_position = aabb.position + aabb.size * 0.5
