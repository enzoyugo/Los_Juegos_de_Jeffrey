class_name TrackCheckpoint
extends Area3D

signal reached(index: int, is_finish: bool)

var index: int = 0
var is_finish: bool = false


func setup(p_index: int, xform: Transform3D, finish: bool) -> void:
	index = p_index
	is_finish = finish
	global_transform = xform
	monitoring = true
	monitorable = false
	collision_layer = 0
	collision_mask = 2
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(12, 6, 4)
	shape.shape = box
	shape.position = Vector3(0, 2.5, 0)
	add_child(shape)
	## Visual language lives on TrackVisualQualityV2 gantries/markers.
	## Keep a minimal road paint so gates remain readable if VQ fails to attach.
	var vis := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(10.2, 0.08, 0.35)
	vis.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("#e8b84a") if finish else Color("#3db8c9")
	mat.emission_enabled = true
	mat.emission = mat.albedo_color
	mat.emission_energy_multiplier = 0.85
	vis.set_surface_override_material(0, mat)
	vis.position = Vector3(0, 0.55, 0)
	vis.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(vis)
	body_entered.connect(_on_body)


func _on_body(body: Node) -> void:
	if body is CharacterBody3D:
		reached.emit(index, is_finish)
