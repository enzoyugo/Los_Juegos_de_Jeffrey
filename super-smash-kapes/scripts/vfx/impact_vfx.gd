class_name ImpactVFX
extends Node3D

var tint: Color = Color("#f5c66b")
var strength: float = 1.0

func _ready() -> void:
	var shard_material := StandardMaterial3D.new()
	shard_material.albedo_color = tint
	shard_material.emission_enabled = true
	shard_material.emission = tint
	shard_material.emission_energy_multiplier = 2.5
	for index in range(8):
		var shard := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.13 + strength * 0.05, 0.13 + strength * 0.05, 0.13 + strength * 0.05)
		shard.mesh = mesh
		shard.material_override = shard_material
		var angle: float = TAU * float(index) / 8.0
		var direction := Vector3(cos(angle), sin(angle), 0.0)
		shard.position = direction * 0.18
		add_child(shard)
		var target_position := direction * (0.65 + strength * 0.08)
		var tween := create_tween().set_parallel()
		tween.tween_property(shard, "position", target_position, 0.18 + strength * 0.015)
		tween.tween_property(shard, "scale", Vector3.ZERO, 0.20 + strength * 0.02)
	var light := OmniLight3D.new()
	light.light_color = tint
	light.light_energy = 1.4 + strength * 0.35
	light.omni_range = 3.0 + strength * 0.3
	add_child(light)
	var light_tween := create_tween()
	light_tween.tween_property(light, "light_energy", 0.0, 0.22)
	var cleanup := create_tween()
	cleanup.tween_interval(0.28 + strength * 0.02)
	cleanup.tween_callback(queue_free)
