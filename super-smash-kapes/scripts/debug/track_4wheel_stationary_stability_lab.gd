extends Node3D

## Flat-slab zero-input stability lab. Observer only. Does not freeze the RigidBody.

const FOUR_WHEEL_SCENE := "res://scenes/track/TrackCarWheelPhysics.tscn"
const SETTLE_S := 2.0
const OBSERVE_S := 10.0
const LAT_LIMIT_M := 0.02
const FWD_LIMIT_M := 0.02
const YAW_LIMIT_DEG := 0.25
const FINAL_SPEED_LIMIT := 0.03
const SAMPLE_HZ := 30.0

var _car: RigidBody3D
var _label: Label
var _cam: Camera3D
var _cases: Array[Dictionary] = []
var _case_i: int = 0
var _phase: String = "boot"
var _t: float = 0.0
var _sample_acc: float = 0.0
var _origin: Vector3 = Vector3.ZERO
var _yaw0: float = 0.0
var _fwd0: Vector3 = Vector3(0, 0, -1)
var _right0: Vector3 = Vector3(1, 0, 0)
var _max_lat_speed: float = 0.0
var _max_yaw_rate: float = 0.0
var _net_fx_peak: float = 0.0
var _net_fz_peak: float = 0.0
var _net_yaw_peak: float = 0.0
var _samples: Array = []
var _force_rows: Array = []
var _results: Array = []
var _smoke: bool = false
var _out_path: String = ""
var _injected: bool = false


func _ready() -> void:
	_smoke = OS.get_environment("SSK_STATIONARY_SMOKE").strip_edges() == "1"
	_out_path = OS.get_environment("SSK_STATIONARY_OUT").strip_edges()
	if _out_path.is_empty():
		_out_path = "res://docs/generated/track_4wheel_v4_iterations/iteration_01/stationary_stability.json"
	_cases = [
		{"id": "yaw0_rest", "yaw_deg": 0.0, "vlat": 0.0, "vlong": 0.0, "kind": "rest", "observe": 10.0},
		{"id": "yaw_p5_rest", "yaw_deg": 5.0, "vlat": 0.0, "vlong": 0.0, "kind": "rest", "observe": 10.0},
		{"id": "yaw_m5_rest", "yaw_deg": -5.0, "vlat": 0.0, "vlong": 0.0, "kind": "rest", "observe": 10.0},
		{"id": "yaw0_vlat_p", "yaw_deg": 0.0, "vlat": 0.2, "vlong": 0.0, "kind": "impulse", "observe": 10.0},
		{"id": "yaw0_vlat_m", "yaw_deg": 0.0, "vlat": -0.2, "vlong": 0.0, "kind": "impulse", "observe": 10.0},
		{"id": "throttle_launch", "yaw_deg": 0.0, "vlat": 0.0, "vlong": 0.0, "kind": "throttle", "observe": 2.0},
		{"id": "steer_at_rest", "yaw_deg": 0.0, "vlat": 0.0, "vlong": 0.0, "kind": "steer", "observe": 4.0},
	]
	_place_environment()
	_place_slab()
	_place_hud()
	_spawn_car()
	_begin_case()
	print("[TRACK_STATIONARY_LAB] cases=%d smoke=%s" % [_cases.size(), str(_smoke)])


func _physics_process(delta: float) -> void:
	if _car == null:
		return
	_t += delta
	if _phase == "settle":
		if _t >= SETTLE_S:
			_arm_observe()
		_refresh_hud()
		return
	if _phase != "observe":
		return
	if not _injected:
		_inject_case_velocity()
		_apply_case_input()
		_injected = true
		_capture_origin()
	_sample_acc += delta
	if _sample_acc >= 1.0 / SAMPLE_HZ:
		_sample_acc = 0.0
		_record_sample()
	var spec: Dictionary = _cases[_case_i]
	var observe_s: float = float(spec.get("observe", OBSERVE_S))
	if _t >= observe_s:
		_finish_case()
	_refresh_hud()


func _place_environment() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 20, 0)
	sun.light_energy = 1.1
	add_child(sun)
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#6a7c88")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#c8d2dc")
	env.ambient_light_energy = 0.55
	world.environment = env
	add_child(world)
	_cam = Camera3D.new()
	_cam.name = "FixedWorldCam"
	_cam.current = true
	add_child(_cam)
	_cam.look_at_from_position(Vector3(0.0, 9.5, 14.0), Vector3(0.0, 0.2, 0.0), Vector3.UP)


func _place_slab() -> void:
	var body := StaticBody3D.new()
	body.name = "FlatSlab"
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = Vector3(0.0, -0.5, 0.0)
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(24.0, 1.0, 40.0)
	col.shape = box
	body.add_child(col)
	var mesh := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(24.0, 1.0, 40.0)
	mesh.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.34, 0.38, 0.42)
	mesh.set_surface_override_material(0, mat)
	body.add_child(mesh)
	add_child(body)
	_add_grid()
	print("[TRACK_STATIONARY_LAB] slab top_y=0 normal=UP pitch=0 roll=0 size=24x40")


func _add_grid() -> void:
	var root := Node3D.new()
	root.name = "CenterlineGrid"
	add_child(root)
	for i in range(-10, 11):
		var line := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.04, 0.02, 40.0) if i != 0 else Vector3(0.08, 0.03, 40.0)
		line.mesh = box
		line.position = Vector3(float(i) * 1.0, 0.011, 0.0)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.95, 0.85, 0.2) if i == 0 else Color(0.55, 0.58, 0.6)
		line.set_surface_override_material(0, mat)
		root.add_child(line)
	var cross := MeshInstance3D.new()
	var cb := BoxMesh.new()
	cb.size = Vector3(24.0, 0.02, 0.04)
	cross.mesh = cb
	cross.position = Vector3(0.0, 0.012, 0.0)
	var cm := StandardMaterial3D.new()
	cm.albedo_color = Color(0.95, 0.35, 0.25)
	cross.set_surface_override_material(0, cm)
	root.add_child(cross)


func _place_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_label = Label.new()
	_label.position = Vector2(14, 10)
	_label.add_theme_font_size_override("font_size", 15)
	layer.add_child(_label)


func _spawn_car() -> void:
	var packed: PackedScene = load(FOUR_WHEEL_SCENE) as PackedScene
	_car = packed.instantiate() as RigidBody3D
	add_child(_car)
	_car.control_enabled = true
	_car.debug_enabled = true


func _begin_case() -> void:
	var spec: Dictionary = _cases[_case_i]
	_phase = "settle"
	_t = 0.0
	_sample_acc = 0.0
	_injected = false
	_samples.clear()
	_force_rows.clear()
	_max_lat_speed = 0.0
	_max_yaw_rate = 0.0
	_net_fx_peak = 0.0
	_net_fz_peak = 0.0
	_net_yaw_peak = 0.0
	Input.action_release("track_accel")
	Input.action_release("track_brake")
	Input.action_release("track_left")
	Input.action_release("track_right")
	var yaw: float = deg_to_rad(float(spec["yaw_deg"]))
	var xform := Transform3D(Basis.from_euler(Vector3(0.0, yaw, 0.0)), Vector3(0.0, 1.15, 0.0))
	if _car.has_method("reset_to"):
		_car.call("reset_to", xform)
	else:
		_car.global_transform = xform
		_car.linear_velocity = Vector3.ZERO
		_car.angular_velocity = Vector3.ZERO
	print("[TRACK_STATIONARY_LAB] BEGIN %s" % str(spec["id"]))


func _arm_observe() -> void:
	_phase = "observe"
	_t = 0.0
	_sample_acc = 0.0


func _inject_case_velocity() -> void:
	var spec: Dictionary = _cases[_case_i]
	var vlat: float = float(spec["vlat"])
	var vlong: float = float(spec["vlong"])
	if absf(vlat) < 0.0001 and absf(vlong) < 0.0001:
		return
	var fwd: Vector3 = -_car.global_transform.basis.z
	fwd.y = 0.0
	if fwd.length() < 0.001:
		fwd = Vector3(0, 0, -1)
	else:
		fwd = fwd.normalized()
	var right: Vector3 = _car.global_transform.basis.x
	right.y = 0.0
	if right.length() < 0.001:
		right = Vector3(1, 0, 0)
	else:
		right = right.normalized()
	var inj: Vector3 = right * vlat + fwd * vlong
	PhysicsServer3D.body_set_state(_car.get_rid(), PhysicsServer3D.BODY_STATE_LINEAR_VELOCITY, inj)
	PhysicsServer3D.body_set_state(_car.get_rid(), PhysicsServer3D.BODY_STATE_ANGULAR_VELOCITY, Vector3.ZERO)
	_car.linear_velocity = inj
	_car.angular_velocity = Vector3.ZERO


func _apply_case_input() -> void:
	var spec: Dictionary = _cases[_case_i]
	var kind: String = str(spec["kind"])
	if kind == "throttle":
		Input.action_press("track_accel", 1.0)
	elif kind == "steer":
		Input.action_press("track_right", 1.0)


func _capture_origin() -> void:
	_origin = _car.global_position
	_yaw0 = _car.global_rotation.y
	_fwd0 = -_car.global_transform.basis.z
	_fwd0.y = 0.0
	if _fwd0.length() < 0.001:
		_fwd0 = Vector3(0, 0, -1)
	else:
		_fwd0 = _fwd0.normalized()
	_right0 = Vector3.UP.cross(_fwd0)
	if _right0.length() < 0.001:
		_right0 = Vector3(1, 0, 0)
	else:
		_right0 = _right0.normalized()


func _record_sample() -> void:
	var snap: Dictionary = _snapshot()
	_samples.append(snap)
	_force_rows.append(snap)
	_max_lat_speed = maxf(_max_lat_speed, absf(float(snap["lat_speed"])))
	_max_yaw_rate = maxf(_max_yaw_rate, absf(float(snap["yaw_rate"])))
	_net_fx_peak = maxf(_net_fx_peak, absf(float(snap["net_force_x"])))
	_net_fz_peak = maxf(_net_fz_peak, absf(float(snap["net_force_z"])))
	_net_yaw_peak = maxf(_net_yaw_peak, absf(float(snap["net_yaw_torque"])))


func _snapshot() -> Dictionary:
	var pos: Vector3 = _car.global_position
	var delta: Vector3 = pos - _origin
	delta.y = 0.0
	var lat: float = delta.dot(_right0)
	var fwd: float = delta.dot(_fwd0)
	var vel: Vector3 = _car.linear_velocity
	var planar := Vector3(vel.x, 0.0, vel.z)
	var yaw: float = _car.global_rotation.y
	var wheels: Array = []
	if _car.has_method("wheels"):
		wheels = _car.call("wheels") as Array
	var sum_lat: float = 0.0
	var sum_long: float = 0.0
	var sum_spring: float = 0.0
	var grounded: int = 0
	var comps: Dictionary = {}
	var lats: Dictionary = {}
	var longs: Dictionary = {}
	var springs: Dictionary = {}
	var normals: Dictionary = {}
	var hits: Dictionary = {}
	for w in wheels:
		if w == null:
			continue
		var wid: String = str(w.wheel_id)
		if bool(w.is_grounded):
			grounded += 1
		var lf: float = float(w.last_lateral_force)
		var lo: float = float(w.last_longitudinal_force)
		var sp: float = float(w.last_suspension_force)
		sum_lat += lf
		sum_long += lo
		sum_spring += sp
		comps[wid] = float(w.compression)
		lats[wid] = lf
		longs[wid] = lo
		springs[wid] = sp
		var n: Vector3 = w.contact_normal
		normals[wid] = [n.x, n.y, n.z]
		var hp: Vector3 = w.contact_point
		hits[wid] = [hp.x, hp.y, hp.z]
	var right: Vector3 = _car.global_transform.basis.x
	right.y = 0.0
	if right.length() > 0.001:
		right = right.normalized()
	var forward: Vector3 = -_car.global_transform.basis.z
	forward.y = 0.0
	if forward.length() > 0.001:
		forward = forward.normalized()
	var net_x: float = right.x * sum_lat + forward.x * sum_long
	var net_z: float = right.z * sum_lat + forward.z * sum_long
	var track_half: float = 0.9
	var net_yaw: float = 0.0
	if wheels.size() >= 4:
		net_yaw = (float(lats.get("FL", 0.0)) + float(lats.get("RL", 0.0)) - float(lats.get("FR", 0.0)) - float(lats.get("RR", 0.0))) * track_half
	return {
		"t": _t,
		"x": pos.x,
		"y": pos.y,
		"z": pos.z,
		"lat": lat,
		"fwd": fwd,
		"yaw_deg": rad_to_deg(yaw),
		"yaw_delta_deg": rad_to_deg(_angle_delta(_yaw0, yaw)),
		"speed": planar.length(),
		"lat_speed": planar.dot(right),
		"fwd_speed": planar.dot(forward),
		"vy": vel.y,
		"yaw_rate": _car.angular_velocity.y,
		"grounded": grounded,
		"drift_state": str(_car.get("drift_state")),
		"throttle": float(_car.get("debug_throttle")),
		"steer": float(_car.get("debug_steer")),
		"brake": float(_car.get("debug_brake")),
		"sum_lat": sum_lat,
		"sum_long": sum_long,
		"sum_spring": sum_spring,
		"net_force_x": net_x,
		"net_force_z": net_z,
		"net_yaw_torque": net_yaw,
		"c": comps,
		"lat_f": lats,
		"long_f": longs,
		"spring_f": springs,
		"normals": normals,
		"hits": hits,
	}


func _angle_delta(a: float, b: float) -> float:
	return wrapf(b - a, -PI, PI)


func _finish_case() -> void:
	var spec: Dictionary = _cases[_case_i]
	var last: Dictionary = _samples[_samples.size() - 1] if _samples.size() > 0 else {}
	var lat: float = absf(float(last.get("lat", 0.0)))
	var fwd: float = absf(float(last.get("fwd", 0.0)))
	var yaw_d: float = absf(float(last.get("yaw_delta_deg", 0.0)))
	var final_lat: float = absf(float(last.get("lat_speed", 0.0)))
	var kind: String = str(spec["kind"])
	var observe_s: float = float(spec.get("observe", OBSERVE_S))
	var pass_rest: bool = lat <= LAT_LIMIT_M and fwd <= FWD_LIMIT_M and yaw_d <= YAW_LIMIT_DEG and final_lat <= FINAL_SPEED_LIMIT
	var pass_imp: bool = final_lat <= FINAL_SPEED_LIMIT and yaw_d <= 1.5
	var pass_thr: bool = float(last.get("speed", 0.0)) >= 2.0
	var pass_steer: bool = lat <= 0.03
	var ok: bool = pass_rest
	if kind == "impulse":
		ok = pass_imp
	elif kind == "throttle":
		ok = pass_thr
	elif kind == "steer":
		ok = pass_steer
	var row := {
		"id": spec["id"],
		"kind": kind,
		"duration": observe_s,
		"dx": float(last.get("x", 0.0)) - _origin.x,
		"dz": float(last.get("z", 0.0)) - _origin.z,
		"lateral_displacement": lat,
		"forward_displacement": fwd,
		"max_lat_speed": _max_lat_speed,
		"final_lat_speed": final_lat,
		"yaw_delta": yaw_d,
		"max_yaw_rate": _max_yaw_rate,
		"net_force_x_peak": _net_fx_peak,
		"net_force_z_peak": _net_fz_peak,
		"net_yaw_torque_peak": _net_yaw_peak,
		"contacts_stable": int(last.get("grounded", 0)) == 4,
		"drift_state": str(last.get("drift_state", "")),
		"PASS": ok,
		"samples": _samples.duplicate(),
	}
	_results.append(row)
	print("[TRACK_STATIONARY] duration=%.1f dx=%.4f dz=%.4f lateral_displacement=%.4f forward_displacement=%.4f max_lat_speed=%.4f final_lat_speed=%.4f yaw_delta=%.3f max_yaw_rate=%.4f net_force_x_peak=%.1f net_force_z_peak=%.1f net_yaw_torque_peak=%.1f contacts_stable=%s PASS=%s id=%s" % [
		observe_s,
		float(row["dx"]),
		float(row["dz"]),
		lat,
		fwd,
		_max_lat_speed,
		final_lat,
		yaw_d,
		_max_yaw_rate,
		_net_fx_peak,
		_net_fz_peak,
		_net_yaw_peak,
		str(row["contacts_stable"]),
		str(ok),
		str(spec["id"]),
	])
	_case_i += 1
	if _case_i >= _cases.size():
		_write_report()
		_phase = "done"
		if _smoke:
			var any_fail := false
			for item in _results:
				if not bool(item["PASS"]):
					any_fail = true
			get_tree().quit(0)
		return
	_begin_case()


func _write_report() -> void:
	var rest_fail := 0
	for item in _results:
		if str(item["kind"]) == "rest" and not bool(item["PASS"]):
			rest_fail += 1
	var payload := {
		"lab": "Track4WheelStationaryStabilityLab",
		"slab": {"top_y": 0.0, "normal": [0.0, 1.0, 0.0], "pitch": 0.0, "roll": 0.0},
		"limits": {
			"lateral_m": LAT_LIMIT_M,
			"forward_m": FWD_LIMIT_M,
			"yaw_deg": YAW_LIMIT_DEG,
			"final_lat_speed": FINAL_SPEED_LIMIT,
		},
		"rest_fail_count": rest_fail,
		"overall_rest_pass": rest_fail == 0,
		"cases": _strip_samples(_results),
	}
	var text: String = JSON.stringify(payload, "\t")
	var abs_path: String = ProjectSettings.globalize_path(_out_path)
	DirAccess.make_dir_recursive_absolute(abs_path.get_base_dir())
	var fh := FileAccess.open(abs_path, FileAccess.WRITE)
	if fh != null:
		fh.store_string(text)
		print("[TRACK_STATIONARY_LAB] wrote %s rest_pass=%s" % [abs_path, str(payload["overall_rest_pass"])])
	var force_path: String = abs_path.get_base_dir().path_join("stationary_force_breakdown.json")
	var force_fh := FileAccess.open(force_path, FileAccess.WRITE)
	if force_fh != null:
		force_fh.store_string(JSON.stringify({"cases": _results}, "\t"))
		print("[TRACK_STATIONARY_LAB] wrote %s" % force_path)


func _strip_samples(rows: Array) -> Array:
	var out: Array = []
	for item in rows:
		var copy: Dictionary = item.duplicate(true)
		var samples: Array = copy.get("samples", [])
		var thin: Array = []
		var i: int = 0
		while i < samples.size():
			thin.append(samples[i])
			i += 15
		if samples.size() > 0:
			thin.append(samples[samples.size() - 1])
		copy["samples"] = thin
		copy["sample_count"] = samples.size()
		out.append(copy)
	return out


func _refresh_hud() -> void:
	if _label == null:
		return
	var spec: Dictionary = _cases[mini(_case_i, _cases.size() - 1)]
	_label.text = "STATIONARY STABILITY LAB\ncase %s  phase %s  t=%.1f\nFIXED WORLD CAMERA (not chase)\ncontrols must stay zero" % [
		str(spec["id"]), _phase, _t
	]
