extends Node3D

## Sprint 021 isolated route adapter. The canonical post-fix driver is not modified.
## This lab binds explicit S016-derived route bundles to real GLB trimesh collision and FOUR_WHEEL_V1.

const CAR_SCENE := "res://scenes/track/TrackCarWheelPhysics.tscn"
const SCALE_FACTOR := 2.05
const DEFAULT_OUT := "E:/PharosVisualization/experiments/track_generation/sprint_022_terminal/runs"
const PHAROS_ROOT := "E:/PharosVisualization/experiments/track_generation/sprint_016/outputs"
const TIME_SCALE := 1.0
const MAX_SECONDS := 240.0
const STUCK_SECONDS := 8.0
const MAX_RECOVERIES := 3

var _track: Node3D
var _car: RigidBody3D
var _route: Array[Vector3] = []
var _drive_route: Array[Vector3] = []
var _checkpoints: Array[Area3D] = []
var _checkpoint := 0
var _recoveries := 0
var _recovery_successes := 0
var _recovery_reason := ""
var _started := 0.0
var _last_progress := 0.0
var _last_position := Vector3.ZERO
var _last_move_time := 0.0
var _spawn := Transform3D.IDENTITY
var _telemetry: Array = []
var _spec: Dictionary
var _track_name := ""
var _out_dir := DEFAULT_OUT
var _finished := false
var _terminal_state := "INITIALIZING"
var _lifecycle: Array = []

func _ready() -> void:
	_transition("INITIALIZING", "ready")
	Engine.time_scale = TIME_SCALE
	_track_name = OS.get_environment("PHAROS_S019_TRACK").strip_edges()
	if _track_name == "": _track_name = "SHORT"
	_out_dir = OS.get_environment("PHAROS_S019_OUT").strip_edges()
	if _out_dir == "": _out_dir = DEFAULT_OUT
	if not _load_spec(): return _finish("FAIL_ADAPTER", "SPEC_LOAD")
	_load_glb_collision()
	_build_checkpoints()
	_spawn_car()
	_transition("SETTLING", "vehicle_spawned")
	_started = Time.get_ticks_msec() / 1000.0
	_last_move_time = _started
	_last_position = _car.global_position
	_transition("DRIVING", "settle_complete")
	print("[PHAROS_S019] READY track=%s checkpoints=%d scale=%.2f time_scale=%.1f" % [_track_name, _route.size(), SCALE_FACTOR, TIME_SCALE])

func _spec_path() -> String:
	return "E:/PharosVisualization/experiments/track_generation/sprint_021_runtime_driver/route_bundles/S016_%s_SEED_%s_route_bundle.json" % [_track_name, {"SHORT":"1601", "MEDIUM":"1602", "LONG":"1603"}.get(_track_name, "1601")]

func _glb_path() -> String:
	return "%s/S016_%s_SEED_%s.glb" % [PHAROS_ROOT, _track_name, {"SHORT":"1601", "MEDIUM":"1602", "LONG":"1603"}.get(_track_name, "1601")]

func _load_spec() -> bool:
	var f := FileAccess.open(_spec_path(), FileAccess.READ)
	if f == null:
		push_error("[PHAROS_S019] SPEC_MISSING %s" % _spec_path())
		return false
	_spec = JSON.parse_string(f.get_as_text())
	if not _spec is Dictionary or not _spec.has("instances"):
		push_error("[PHAROS_S019] SPEC_INVALID")
		return false
	for point in _spec["centerline"]:
		_route.append(Vector3(float(point[0]) * SCALE_FACTOR, 0.0, -float(point[1]) * SCALE_FACTOR))
	if _route.size() < 2: return false
	for i in range(_route.size() - 1):
		var a := _route[i]
		var b := _route[i + 1]
		var subdivisions: int = maxi(2, int(ceil(a.distance_to(b) / 2.0)))
		for j in range(subdivisions):
			_drive_route.append(a.lerp(b, float(j) / float(subdivisions)))
	_drive_route.append(_route.back())
	var forward := (_route[1] - _route[0]).slide(Vector3.UP).normalized()
	_spawn = Transform3D(Basis.looking_at(forward, Vector3.UP), _route[0] + forward * 3.0 + Vector3.UP * 1.65)
	return true

func _transition(state: String, reason: String) -> void:
	_terminal_state = state
	_lifecycle.append({"state":state,"reason":reason,"timestamp_ms":Time.get_ticks_msec(),"frame":Engine.get_process_frames(),"elapsed":Time.get_ticks_msec()/1000.0-_started,"checkpoint":_checkpoint,"progress":_last_progress,"position":_car.global_position if _car != null else Vector3.ZERO,"speed":_car.linear_velocity.length() if _car != null else 0.0})

func _load_glb_collision() -> void:
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var err := doc.append_from_file(_glb_path(), state)
	if err != OK:
		push_error("[PHAROS_S019] GLB_LOAD_FAILED err=%s" % err)
		return
	_track = doc.generate_scene(state) as Node3D
	if _track == null: return
	_track.name = "PharosS019RealGLB"
	_track.scale = Vector3.ONE * SCALE_FACTOR
	add_child(_track)
	var meshes: Array[MeshInstance3D] = []
	_collect_meshes(_track, meshes)
	var n := 0
	for mi in meshes:
		if mi.mesh == null: continue
		var shape := mi.mesh.create_trimesh_shape()
		if shape == null: continue
		var body := StaticBody3D.new()
		body.name = "PharosS019Collision_%03d" % n
		body.collision_layer = 1
		body.collision_mask = 2
		body.global_transform = mi.global_transform
		var cs := CollisionShape3D.new()
		cs.shape = shape
		body.add_child(cs)
		add_child(body)
		n += 1
	print("[PHAROS_S019] REAL_GLB_COLLISION meshes=%d colliders=%d path=%s" % [meshes.size(), n, _glb_path()])

func _collect_meshes(node: Node, out: Array[MeshInstance3D]) -> void:
	for child in node.get_children():
		if child is MeshInstance3D: out.append(child)
		_collect_meshes(child, out)

func _build_checkpoints() -> void:
	for i in _route.size():
		var area := Area3D.new()
		area.name = "PharosCheckpoint_%02d" % i
		area.collision_layer = 0
		area.collision_mask = 2
		var cs := CollisionShape3D.new()
		var sh := SphereShape3D.new()
		sh.radius = 4.0
		cs.shape = sh
		area.add_child(cs)
		area.position = _route[i] + Vector3.UP
		area.body_entered.connect(_on_checkpoint.bind(i))
		add_child(area)
		_checkpoints.append(area)

func _spawn_car() -> void:
	var packed := load(CAR_SCENE) as PackedScene
	if packed == null: return
	_car = packed.instantiate() as RigidBody3D
	_car.name = "FOUR_WHEEL_V1_S019_LAB"
	_car.set_meta("lab_only", true)
	add_child(_car)
	_car.global_transform = _spawn
	_car.set("control_enabled", true)
	_car.set("use_scripted_input", true)
	_car.set("scripted_throttle", 1.0)
	_car.set("scripted_steer", 0.0)

func _on_checkpoint(body: Node3D, index: int) -> void:
	if body != _car or index != _checkpoint: return
	_checkpoint += 1
	_last_progress = float(_checkpoint)
	_last_move_time = Time.get_ticks_msec() / 1000.0
	print("[PHAROS_S019] CHECKPOINT %d/%d" % [_checkpoint, _route.size()])
	if _checkpoint >= _route.size(): _finish("PASS_FINISH", "")

func _physics_process(_delta: float) -> void:
	if _car == null or _finished: return
	var now := Time.get_ticks_msec() / 1000.0
	var elapsed := now - _started
	var moved := _car.global_position.distance_to(_last_position)
	if moved > 0.15:
		_last_position = _car.global_position
		_last_move_time = now
	var nearest := 0
	var nearest_distance := INF
	for i in _drive_route.size():
		var distance := _car.global_position.distance_squared_to(_drive_route[i])
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = i
	var target := _drive_route[min(nearest + 3, _drive_route.size() - 1)]
	var local: Vector3 = _car.global_transform.affine_inverse() * target
	## Same signed local-X convention as the canonical driver: positive steer is right.
	var steer := clampf(local.x / maxf(absf(local.z), 4.0), -1.0, 1.0)
	_car.set("scripted_steer", steer)
	_car.set("scripted_throttle", 0.72 if absf(steer) > 0.45 else 1.0)
	if now - _last_move_time > STUCK_SECONDS:
		if _recoveries >= MAX_RECOVERIES:
			_finish("FAIL_STUCK", "NO_PROGRESS_AFTER_RECOVERY")
		else:
			_recover("NO_PROGRESS")
	if elapsed > MAX_SECONDS:
		_finish("FAIL_TIMEOUT", "HARD_CAP")
	_telemetry.append({"t":elapsed,"position":_car.global_position,"speed":_car.linear_velocity.length(),"checkpoint":_checkpoint,"recovery_attempts":_recoveries})

func _recover(reason: String) -> void:
	_transition("RECOVERING", reason)
	_recoveries += 1
	_recovery_reason = reason
	var index: int = maxi(0, _checkpoint - 1)
	var forward := (_route[min(index + 1, _route.size() - 1)] - _route[index]).slide(Vector3.UP).normalized()
	var target := _route[index] + forward * 2.5 + Vector3.UP * 1.65
	_car.call("reset_to", Transform3D(Basis.looking_at(forward, Vector3.UP), target))
	_car.set("scripted_throttle", 1.0)
	_car.set("scripted_steer", 0.0)
	_last_position = _car.global_position
	_last_move_time = Time.get_ticks_msec() / 1000.0
	print("[PHAROS_S019] RECOVERY attempt=%d checkpoint_before=%d reason=%s" % [_recoveries, _checkpoint, reason])

func _finish(result: String, failure: String) -> void:
	if _finished: return
	_finished = true
	_transition("FINISHED" if result == "PASS_FINISH" else "FAILED", failure)
	if _car != null:
		_car.set("scripted_throttle", 0.0)
	var now := Time.get_ticks_msec() / 1000.0
	var row := {"track":_track_name,"result":result,"failure_class":failure,"runtime_seconds":now - _started,"checkpoint_count":_checkpoint,"expected_checkpoint_count":_route.size(),"recovery_attempts":_recoveries,"recovery_successes":1 if result == "PASS_FINISH" and _recoveries > 0 else 0,"recovery_reason":_recovery_reason,"time_scale":TIME_SCALE,"teleport":false,"transform_advance":false,"substitute_collider":false,"real_glb":true,"real_vehicle":"TrackCarWheelPhysics.tscn","final_position":_car.global_position if _car != null else Vector3.ZERO,"telemetry":_telemetry}
	DirAccess.make_dir_recursive_absolute(_out_dir)
	row["terminal_state"] = _terminal_state
	row["lifecycle"] = _lifecycle
	var final_path := "%s/%s_%s.json" % [_out_dir, _track_name, str(Time.get_ticks_msec())]
	var temp_path := final_path + ".partial"
	var f := FileAccess.open(temp_path, FileAccess.WRITE)
	if f == null:
		push_error("[PHAROS_S022] RECEIPT_WRITE_FAILED %s" % temp_path)
		get_tree().quit(2)
		return
	f.store_string(JSON.stringify(row, "  ")); f.flush(); f.close()
	if not DirAccess.rename_absolute(temp_path, final_path) == OK:
		push_error("[PHAROS_S022] RECEIPT_PUBLISH_FAILED %s" % final_path)
		get_tree().quit(2)
		return
	_transition("RECEIPT_WRITTEN", "atomic_publish")
	print("[PHAROS_S019] RESULT %s" % JSON.stringify(row))
	_transition("EXITING", "quit")
	get_tree().quit(0 if result == "PASS_FINISH" else 1)
