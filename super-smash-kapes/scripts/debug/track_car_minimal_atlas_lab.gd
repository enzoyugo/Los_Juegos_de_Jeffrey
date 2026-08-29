extends Node3D

## Temporary diagnostic: one TrackCarVisual, camera, light. No track. No physics.

const VisualScript := preload("res://scripts/track/track_car_visual.gd")

var _frame: int = 0
var _smoke: bool = false
var _smoke_frames: int = 48


func _ready() -> void:
	_smoke = OS.get_environment("SSK_ATLAS_SMOKE").strip_edges() == "1"
	var hold := OS.get_environment("SSK_ATLAS_FRAMES").strip_edges()
	if not hold.is_empty():
		_smoke_frames = maxi(int(hold), 16)
	print("[TRACK_MINIMAL_ATLAS] os_static_memory_before_visual=%d" % OS.get_static_memory_usage())
	var light := DirectionalLight3D.new()
	light.name = "KeyLight"
	light.rotation_degrees = Vector3(-42.0, -35.0, 0.0)
	light.light_energy = 1.15
	add_child(light)
	var cam := Camera3D.new()
	cam.name = "OrbitCam"
	cam.current = true
	add_child(cam)
	cam.look_at_from_position(Vector3(4.2, 2.4, 5.6), Vector3(0.0, 0.6, 0.0), Vector3.UP)
	var visual: Node3D = VisualScript.new()
	visual.name = "TrackCarVisual"
	visual.set("use_articulated", true)
	visual.set("apply_runtime_transform", true)
	add_child(visual)
	print("[TRACK_MINIMAL_ATLAS] ready articulated=true track=false physics=false")
	print("[TRACK_MINIMAL_ATLAS] os_static_memory_after_visual=%d" % OS.get_static_memory_usage())
	call_deferred("_log_transform_probe", visual)


func _log_transform_probe(visual: Node) -> void:
	if visual == null or not is_instance_valid(visual):
		return
	if visual.has_method("geometric_forward"):
		print("[TRACK_MINIMAL_ATLAS] geometric_fwd=%s visual_fwd=%s chassis_fwd=%s body_nose=%s" % [
			str(visual.call("geometric_forward")),
			str(visual.call("visual_forward")),
			str(visual.call("chassis_forward")),
			str(visual.call("body_model_nose")),
		])
	for wid in ["FL", "FR", "RL", "RR"]:
		if not visual.has_method("debug_apply_wheel_pose"):
			break
		var c0: Vector3 = visual.wheel_center_global(wid)
		visual.debug_apply_wheel_pose(wid, 0.436332, 0.0, 0.0)
		var c_steer: Vector3 = visual.wheel_center_global(wid)
		visual.debug_apply_wheel_pose(wid, 0.0, PI * 0.5, 0.0)
		var c_spin: Vector3 = visual.wheel_center_global(wid)
		visual.debug_apply_wheel_pose(wid, 0.0, 0.0, 0.0)
		print("[TRACK_MINIMAL_ATLAS] %s rest=%s d_steer=%.6f d_spin=%.6f" % [
			wid,
			str(visual.wheel_mesh_rest_local(wid)),
			c0.distance_to(c_steer),
			c0.distance_to(c_spin),
		])


func _process(_delta: float) -> void:
	_frame += 1
	if _smoke and _frame >= _smoke_frames:
		print("[TRACK_MINIMAL_ATLAS] SMOKE END frames=%d atlas_id=%d atlas_path=%s" % [
			_frame,
			int(VisualScript.shared_atlas_id()),
			str(VisualScript.atlas_resource_path()),
		])
		get_tree().quit()
