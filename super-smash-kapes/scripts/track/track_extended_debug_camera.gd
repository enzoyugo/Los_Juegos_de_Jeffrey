class_name TrackExtendedDebugCamera
extends Camera3D

## Extended-lab-only chase camera. Does not replace TrackMain / TrackCamera.

const MODE_CHASE := 0
const MODE_CHASE_CLOSE := 1
const MODE_LANDING_SIDE := 2
const MODE_TOPDOWN := 3
const MODE_LANDING_CLOSE := 4
const MODE_NAMES: PackedStringArray = ["CHASE_STANDARD", "CHASE_CLOSE", "LANDING_SIDE", "TOPDOWN", "LANDING_CLOSE"]
const CYCLE_MODES: Array[int] = [MODE_CHASE, MODE_LANDING_SIDE, MODE_LANDING_CLOSE, MODE_TOPDOWN]

var target: Node3D
var landing_anchor: Vector3 = Vector3(14.0, 6.2, 4.0)
var landing_look: Vector3 = Vector3(0.0, 1.0, 0.0)
var follow_car_on_side: bool = false
var auto_side_on_takeoff: bool = true
var topdown_anchor: Vector3 = Vector3(0.0, 92.0, -90.0)
var topdown_look: Vector3 = Vector3(0.0, 0.0, -90.0)
var _mode: int = MODE_CHASE
var _yaw_basis: Basis = Basis.IDENTITY
var _locked: bool = false


func snap_to_target() -> void:
	_locked = false


func set_mode(mode: int) -> void:
	_mode = mode % MODE_NAMES.size()
	if _mode != MODE_CHASE and _mode != MODE_CHASE_CLOSE:
		_locked = false
	print("[TRACK_EXTENDED_CAM] %s" % MODE_NAMES[_mode])


func cycle_mode() -> int:
	var idx := 0
	var n: int = CYCLE_MODES.size()
	for i in n:
		if CYCLE_MODES[i] == _mode:
			idx = i
			break
	set_mode(CYCLE_MODES[(idx + 1) % n])
	return _mode


func mode_name() -> String:
	return MODE_NAMES[_mode]


func _physics_process(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	if _mode == MODE_TOPDOWN:
		global_position = topdown_anchor
		if topdown_look.distance_to(global_position) > 0.05:
			look_at(topdown_look, Vector3.FORWARD)
		fov = 42.0
		return
	if _mode == MODE_LANDING_SIDE:
		var desired: Vector3 = landing_anchor
		var look: Vector3 = landing_look
		if follow_car_on_side and target is Node3D:
			look = (target as Node3D).global_position
		global_position = global_position.lerp(desired, clampf(delta * 6.0, 0.0, 1.0))
		if look.distance_to(global_position) > 0.05:
			look_at(look + Vector3(0, 0.4, 0), Vector3.UP)
		fov = 58.0
		return
	if _mode == MODE_LANDING_CLOSE:
		var chassis: Vector3 = target.global_position
		var away: Vector3 = landing_anchor - landing_look
		away.y = 0.0
		if away.length() < 0.15:
			away = Vector3(1.0, 0.0, 0.35)
		away = away.normalized()
		var desired_close: Vector3 = chassis + away * 9.0 + Vector3(0.0, 3.0, 0.0)
		global_position = global_position.lerp(desired_close, clampf(delta * 8.0, 0.0, 1.0))
		var look_close: Vector3 = chassis + Vector3(0.0, 0.45, 0.0)
		if look_close.distance_to(global_position) > 0.05:
			look_at(look_close, Vector3.UP)
		fov = 60.0
		return
	var car: Node = target
	var parent: Node = target.get_parent()
	if parent is RigidBody3D or parent is CharacterBody3D:
		car = parent
	var car_basis: Basis = (car as Node3D).global_transform.basis if car is Node3D else target.global_transform.basis
	if not _locked:
		_yaw_basis = car_basis
		_locked = true
	_yaw_basis = _yaw_basis.slerp(car_basis, 1.0 - exp(-10.0 * delta))
	var rear: Vector3 = target.global_position
	var nose: Vector3 = target.global_position + (-car_basis.z) * 2.0
	if car.has_method("rear_axle_midpoint_global"):
		rear = car.call("rear_axle_midpoint_global") as Vector3
	var vis: Node = car.get_node_or_null("VisualRoot")
	if vis != null:
		var n: Node = vis.find_child("NOSE_MARKER", true, false)
		var r: Node = vis.find_child("REAR_MARKER", true, false)
		if n is Node3D and r is Node3D:
			nose = (n as Node3D).global_position
			rear = (r as Node3D).global_position
	## CHASE_CLOSE must keep car + road horizon + landing deck in frame (not a bumper cam).
	var dist: float = 11.4 if _mode == MODE_CHASE_CLOSE else 9.2
	var height: float = 3.35 if _mode == MODE_CHASE_CLOSE else 2.7
	var back: Vector3 = rear - nose
	back.y = 0.0
	if back.length() < 0.05:
		back = car_basis.z
	back = back.normalized()
	var desired: Vector3 = rear + Vector3(0, height, 0) + back * dist
	global_position = global_position.lerp(desired, 1.0 - exp(-14.0 * delta))
	var look_pt: Vector3 = nose + Vector3(0, 0.55, 0)
	if _mode == MODE_CHASE_CLOSE:
		look_pt = nose + (-car_basis.z).normalized() * 14.0 + Vector3(0, 0.35, 0)
	if look_pt.distance_to(global_position) > 0.05:
		look_at(look_pt, Vector3.UP)
	fov = 62.0 if _mode == MODE_CHASE_CLOSE else 68.0
