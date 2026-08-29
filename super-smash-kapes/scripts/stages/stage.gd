extends StaticBody3D

func _ready() -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("#34495e")
	material.roughness = 0.72
	$Visual.material_override = material
	# The Defensores stage wraps this gameplay collision scene with its own
	# layered stadium artwork. Keep the greybox backdrop available for the
	# standalone M0 stage, but do not add it inside the production art scene.
	if get_parent() == null or get_parent().name != "StageGameplayRoot":
		_build_backdrop()

func _build_backdrop() -> void:
	var backdrop_material := StandardMaterial3D.new()
	backdrop_material.albedo_color = Color("#202b45")
	backdrop_material.roughness = 0.9
	for index in range(7):
		var tower := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		var tower_height: float = 3.0 + float((index * 5) % 5)
		mesh.size = Vector3(2.2, tower_height, 1.5)
		tower.mesh = mesh
		tower.material_override = backdrop_material
		tower.position = Vector3(-14.0 + index * 4.7, tower_height * 0.5 - 0.5, 2.7)
		add_child(tower)
	var rim_material := StandardMaterial3D.new()
	rim_material.albedo_color = Color("#e0a84b")
	rim_material.emission_enabled = true
	rim_material.emission = Color("#7d4c1f")
	var rim := MeshInstance3D.new()
	var rim_mesh := BoxMesh.new()
	rim_mesh.size = Vector3(30.0, 0.12, 0.18)
	rim.mesh = rim_mesh
	rim.material_override = rim_material
	rim.position = Vector3(0.0, 1.02, 1.9)
	add_child(rim)
