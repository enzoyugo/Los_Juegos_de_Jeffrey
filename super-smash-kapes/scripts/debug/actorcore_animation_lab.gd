extends Node3D

## Isolated ActorCore benchmark animation lab.
## 1 = rest pose | 2 = baked idle
## SOURCE: ACTORCORE + MIXAMO OFFLINE BAKE | RUNTIME RETARGET: OFF

@export var benchmark_glb: String = ""
@export var character_label: String = "ACTORCORE"
@export var camera_height: float = 1.8
@export var camera_distance: float = 6.0

var _model_root: Node3D
var _skeleton: Skeleton3D
var _animation_player: AnimationPlayer
var _resolved_idle: String = ""
var _status: Label
var _load_mode: String = "NONE"


func _ready() -> void:
	_build_environment()
	_load_benchmark_model()
	_status = Label.new()
	_status.position = Vector2(24, 24)
	_status.add_theme_font_size_override("font_size", 20)
	var layer := CanvasLayer.new()
	layer.layer = 20
	layer.add_child(_status)
	add_child(layer)
	call_deferred("_refresh_status")


func _build_environment() -> void:
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-42, 35, 0)
	light.light_energy = 1.15
	add_child(light)
	var cam := Camera3D.new()
	add_child(cam)
	cam.position = Vector3(0.0, camera_height, camera_distance)
	cam.look_at(Vector3(0.0, camera_height * 0.65, 0.0), Vector3.UP)
	cam.current = true
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(16, 16)
	floor_mesh.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.1, 0.12, 0.16)
	floor_mesh.material_override = mat
	add_child(floor_mesh)


func _load_benchmark_model() -> void:
	if benchmark_glb.is_empty():
		push_warning("[ACTORCORE_LAB] Empty benchmark_glb")
		return
	var abs_path := ProjectSettings.globalize_path(benchmark_glb)
	if not FileAccess.file_exists(abs_path):
		push_warning("[ACTORCORE_LAB] Missing benchmark GLB: %s" % benchmark_glb)
		return
	var root: Node = null
	if ResourceLoader.exists(benchmark_glb):
		var packed: PackedScene = load(benchmark_glb)
		if packed:
			root = packed.instantiate()
			_load_mode = "ResourceLoader"
	if root == null:
		var doc := GLTFDocument.new()
		var state := GLTFState.new()
		if doc.append_from_file(abs_path, state) == OK:
			root = doc.generate_scene(state)
			_load_mode = "GLTFDocument"
	if root == null:
		push_warning("[ACTORCORE_LAB] Failed to load %s" % benchmark_glb)
		return
	_model_root = root as Node3D
	_model_root.name = "BenchmarkModel"
	add_child(_model_root)
	_skeleton = _find_skeleton(_model_root)
	_animation_player = _find_animation_player(_model_root)
	_resolved_idle = _resolve_idle_name()
	if _animation_player and not _resolved_idle.is_empty():
		var anim: Animation = _animation_player.get_animation(_resolved_idle)
		if anim:
			anim.loop_mode = Animation.LOOP_LINEAR
		_animation_player.play(_resolved_idle)


func _resolve_idle_name() -> String:
	if _animation_player == null:
		return ""
	if _animation_player.has_animation("idle"):
		return "idle"
	for name in _animation_player.get_animation_list():
		if name.to_lower().contains("idle"):
			return name
	var names := _animation_player.get_animation_list()
	return names[0] if names.size() > 0 else ""


func _bone_track_count() -> int:
	if _animation_player == null or _resolved_idle.is_empty():
		return 0
	var anim: Animation = _animation_player.get_animation(_resolved_idle)
	if anim == null:
		return 0
	var bones := {}
	for t in anim.get_track_count():
		if anim.track_get_type(t) == Animation.TYPE_ROTATION_3D:
			var path := String(anim.track_get_path(t))
			if ":" in path:
				bones[path.split(":")[-1]] = true
	return bones.size()


func _input(event: InputEvent) -> void:
	_handle_lab_key(event)


func _unhandled_input(event: InputEvent) -> void:
	_handle_lab_key(event)


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
	_refresh_status()


func _refresh_status() -> void:
	if _status == null:
		return
	var skel := "FOUND" if _skeleton else "MISSING"
	var bones := _skeleton.get_bone_count() if _skeleton else 0
	var anim := _resolved_idle if not _resolved_idle.is_empty() else "NONE"
	var tracks := _bone_track_count()
	_status.text = (
		"MODEL: %s | SKELETON: %s (%d) | ANIMATION: %s | BONE TRACKS: %d | FPS: 30 | SOURCE: ACTORCORE + MIXAMO OFFLINE BAKE | RUNTIME RETARGET: OFF | LOAD: %s | [1] rest [2] idle"
		% [character_label, skel, bones, anim, tracks, _load_mode]
	)


func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node as Skeleton3D
	for child in node.get_children():
		var found := _find_skeleton(child)
		if found:
			return found
	return null


func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found:
			return found
	return null
