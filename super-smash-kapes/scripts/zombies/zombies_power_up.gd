class_name ZombiesPowerUp
extends Area3D

signal collected

const Config := preload("res://scripts/zombies/zombies_config.gd")

var kind: String = "max_ammo"
var _taken: bool = false
var _mesh: MeshInstance3D
var _t: float = 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = Config.LAYER_PLAYER
	monitoring = true
	monitorable = true
	_mesh = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.5, 0.5, 0.5)
	_mesh.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("#ffe566")
	mat.emission_enabled = true
	mat.emission = Color("#ffd24a")
	mat.emission_energy_multiplier = 2.4
	_mesh.set_surface_override_material(0, mat)
	_mesh.position = Vector3(0, 0.42, 0)
	add_child(_mesh)
	var col := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.7
	col.shape = sphere
	col.position = Vector3(0, 0.35, 0)
	add_child(col)
	var tag := Label3D.new()
	tag.text = "MAX AMMO"
	tag.position = Vector3(0, 1.15, 0)
	tag.font_size = 36
	tag.modulate = Color("#ffe566")
	tag.outline_size = 8
	tag.outline_modulate = Color(0, 0, 0, 0.85)
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(tag)
	body_entered.connect(_on_body)


func _process(delta: float) -> void:
	if _taken:
		return
	_t += delta
	if _mesh != null:
		_mesh.rotate_y(delta * 1.8)
		_mesh.position.y = 0.42 + sin(_t * 2.4) * 0.10


func apply_to(player: Node) -> bool:
	if _taken or player == null:
		return false
	if not player.has_method("refill_all_ammo"):
		return false
	_taken = true
	_burst()
	player.call("refill_all_ammo")
	collected.emit()
	queue_free()
	return true


func _burst() -> void:
	var parent := get_parent()
	if parent == null:
		return
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = 12
	p.lifetime = 0.4
	p.direction = Vector3(0, 1, 0)
	p.spread = 70.0
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 4.5
	p.gravity = Vector3(0, -2.0, 0)
	p.color = Color("#ffe566")
	p.emitting = false
	parent.add_child(p)
	p.global_position = global_position + Vector3(0, 0.4, 0)
	p.emitting = true
	p.finished.connect(p.queue_free)


func _on_body(body: Node) -> void:
	apply_to(body)
