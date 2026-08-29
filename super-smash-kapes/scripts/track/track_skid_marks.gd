class_name TrackSkidMarks
extends Node3D

## Persists across Hotseat attempts. Shared material. Cap instance count.

const Telemetry := preload("res://scripts/track/track_debug_telemetry.gd")
const MAX_MARKS := 420

var car: Node
var _mat: StandardMaterial3D
var _marks: Array[MeshInstance3D] = []
var _smoke: GPUParticles3D
var _clock: float = 0.0


func setup(p_car: Node) -> void:
	car = p_car
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = Color(0.08, 0.08, 0.09, 0.72)
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.roughness = 1.0
	_smoke = GPUParticles3D.new()
	_smoke.amount = 48
	_smoke.lifetime = 0.55
	_smoke.emitting = false
	var proc := ParticleProcessMaterial.new()
	proc.direction = Vector3(0, 1, 0)
	proc.spread = 18.0
	proc.initial_velocity_min = 0.4
	proc.initial_velocity_max = 1.6
	proc.gravity = Vector3(0, 0.4, 0)
	_smoke.process_material = proc
	var draw := SphereMesh.new()
	draw.radius = 0.18
	draw.height = 0.36
	_smoke.draw_pass_1 = draw
	add_child(_smoke)


func _physics_process(delta: float) -> void:
	if car == null or not is_instance_valid(car) or not (car is Node3D):
		return
	_clock += delta
	var slip := absf(Telemetry.debug_float(car, "debug_slip_angle", 0.0))
	var speed := Telemetry.debug_float(car, "debug_speed", 0.0)
	var state := Telemetry.debug_string(car, "drift_state", "")
	var on := state == "drift" and slip > 0.08 and speed > 8.0
	if _smoke != null:
		_smoke.emitting = on
		_smoke.global_position = (car as Node3D).global_position + Vector3(0, 0.25, 0)
	if on and _clock > 0.04:
		_clock = 0.0
		_stamp((car as Node3D).global_transform, clampf(slip, 0.15, 0.9))


func _stamp(xf: Transform3D, strength: float) -> void:
	var mesh_i := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.28, 0.025, 0.7)
	mesh_i.mesh = box
	mesh_i.set_surface_override_material(0, _mat)
	add_child(mesh_i)
	var pos: Vector3 = xf.origin + Vector3(0, 0.03, 0) + xf.basis.z * 0.9
	mesh_i.global_transform = Transform3D(xf.basis, pos)
	mesh_i.scale = Vector3(1.0, 1.0, 0.7 + strength)
	_marks.append(mesh_i)
	if _marks.size() > MAX_MARKS:
		var old: MeshInstance3D = _marks.pop_front()
		if is_instance_valid(old):
			old.queue_free()
