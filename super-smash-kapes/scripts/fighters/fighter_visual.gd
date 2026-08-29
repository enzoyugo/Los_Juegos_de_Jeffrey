class_name FighterVisual
extends Node3D

var fighter
var definition
var facing: float = 1.0
var _hit_flash_time: float = 0.0
var _attack_punch: float = 0.0
var _state_label: String = "IDLE"

func bind(fighter_ref, fighter_definition) -> void:
	fighter = fighter_ref
	definition = fighter_definition
	scale = Vector3.ONE * definition.visual_scale
	position = definition.visual_offset

func sync_from_fighter(delta: float) -> void:
	if fighter == null:
		return
	set_facing(fighter.facing)
	_hit_flash_time = maxf(_hit_flash_time - delta, 0.0)
	_attack_punch = maxf(_attack_punch - delta, 0.0)
	var next_state := _resolve_state()
	if next_state != _state_label:
		_on_state_changed(_state_label, next_state)
		_state_label = next_state
	_apply_motion(delta)
	_apply_hit_flash()

func set_facing(direction: float) -> void:
	facing = signf(direction) if abs(direction) > 0.01 else facing
	scale.x = absf(scale.x) * facing

func on_attack_started() -> void:
	_attack_punch = 0.18

func on_hit() -> void:
	_hit_flash_time = 0.08

func on_jump() -> void:
	pass

func on_land() -> void:
	pass

func on_respawn() -> void:
	pass

func on_eliminated() -> void:
	visible = false

func on_victory() -> void:
	pass

const STATE_DEAD := 3
const STATE_ATTACKING := 1
const STATE_HITSTUN := 2

func _resolve_state() -> String:
	if fighter.match_locked:
		return "VICTORY" if fighter.state != STATE_DEAD else "ELIMINATED"
	if fighter.invulnerability_time > 0.0:
		return "RESPAWN"
	match fighter.state:
		STATE_DEAD:
			return "KO"
		STATE_ATTACKING:
			return "ATTACK"
		STATE_HITSTUN:
			return "HITSTUN"
	return "AIR" if not fighter.is_on_floor() else ("RUN" if abs(fighter.velocity.x) > 0.5 else "IDLE")

func _on_state_changed(_old_state: String, _new_state: String) -> void:
	pass

func _apply_motion(delta: float) -> void:
	var bob := sin(fighter.visual_time * 5.0) * 0.035 if fighter.is_on_floor() and _state_label == "IDLE" else 0.0
	var lean := clampf(-fighter.velocity.x * 0.018, -0.14, 0.14)
	var target := Vector3(0.0, bob, 0.0)
	var target_rot := Vector3(0.0, 0.0, lean)
	if _state_label == "ATTACK":
		target.x = 0.18 * facing
	elif _state_label == "HITSTUN":
		target_rot.z = -0.18 * facing
	position.y = lerpf(position.y, target.y + definition.visual_offset.y, minf(delta * 12.0, 1.0))
	rotation.z = lerpf(rotation.z, target_rot.z, minf(delta * 10.0, 1.0))
	if fighter.invulnerability_time > 0.0:
		visible = fmod(fighter.invulnerability_time, 0.12) > 0.045
	else:
		visible = true

func _apply_hit_flash() -> void:
	pass

func _make_material(color: Color, roughness: float = 0.45, metallic: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	return material

func _mesh_instance(mesh: Mesh, material: StandardMaterial3D, parent: Node3D, transform: Transform3D = Transform3D.IDENTITY) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	node.transform = transform
	parent.add_child(node)
	return node
