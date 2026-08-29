class_name ZombiesEnemy
extends CharacterBody3D

signal died
signal hurt
signal attack_started

enum State { SPAWN, CHASE, WINDUP, ATTACK, HIT, DEAD }

const Config := preload("res://scripts/zombies/zombies_config.gd")
const PowerScript := preload("res://scripts/zombies/zombies_power_up.gd")

const SLOT_COUNT := 11
const SLOT_RADIUS := 2.2
const SEPARATION_RADIUS := 1.35
const SEPARATION_GAIN := 1.35
const WINDUP_TIME := 0.28
const ATTACK_HOLD := 0.16
const SKIN := Color("#6a7a5c")
const SKIN_HIT := Color("#a34540")
const CLOTH := Color("#3a4034")
const BONE := Color("#c8c0a8")
const CLOTH_VARIANTS: Array[Color] = [
	Color("#3a4034"),
	Color("#4a3a32"),
	Color("#2e3a48"),
	Color("#4a4a38"),
	Color("#3a322c"),
]

var health: float = Config.ZOMBIE_HP
var target: Node3D
var alive: bool = true
var ai_enabled: bool = true
var use_navigation: bool = false
var drop_chance: float = Config.MAX_AMMO_CHANCE
var state: int = State.SPAWN
var slot_index: int = 0
var _attack_cd: float = 0.0
var _state_t: float = 0.0
var _agent: NavigationAgent3D
var _mesh: MeshInstance3D
var _mat: StandardMaterial3D
var _col: CollisionShape3D
var _visual: Node3D
var _knock: Vector3 = Vector3.ZERO
var _fade: float = 1.0
var _slot_jitter: float = 0.0
var _slot_radius_j: float = 0.0
var _reassign_cd: float = 0.0
var _arm_l: Node3D
var _arm_r: Node3D
var _leg_l: Node3D
var _leg_r: Node3D
var _head: Node3D
var _walk_t: float = 0.0
var _speed_mul: float = 1.0
var _cloth_mat: StandardMaterial3D
var _body_scale := Vector3.ONE


func _ready() -> void:
	collision_layer = Config.LAYER_ZOMBIE
	collision_mask = Config.LAYER_WORLD
	floor_snap_length = 0.25
	slot_index = absi(get_instance_id()) % SLOT_COUNT
	_slot_jitter = randf_range(-0.22, 0.22)
	_slot_radius_j = randf_range(-0.28, 0.32)
	_reassign_cd = randf_range(0.4, 1.6)
	_speed_mul = randf_range(0.88, 1.12)
	_walk_t = randf() * TAU
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = SKIN
	_mat.roughness = 0.9
	_cloth_mat = StandardMaterial3D.new()
	_cloth_mat.albedo_color = CLOTH_VARIANTS[absi(get_instance_id()) % CLOTH_VARIANTS.size()]
	_cloth_mat.roughness = 0.92
	_visual = Node3D.new()
	add_child(_visual)
	_build_humanoid()
	var body_s: float = randf_range(0.94, 1.08)
	_body_scale = Vector3(body_s, body_s * randf_range(0.96, 1.06), body_s)
	_visual.scale = _body_scale * 0.2
	_visual.rotation.x = 0.14
	_col = CollisionShape3D.new()
	var body := CapsuleShape3D.new()
	body.radius = 0.4
	body.height = 1.7
	_col.shape = body
	_col.position = Vector3(0, 0.85, 0)
	add_child(_col)
	_agent = NavigationAgent3D.new()
	_agent.path_desired_distance = 0.45
	_agent.target_desired_distance = 0.4
	_agent.radius = 0.42
	_agent.neighbor_distance = 2.4
	_agent.avoidance_enabled = true
	_agent.max_speed = Config.ZOMBIE_SPEED * _speed_mul
	add_child(_agent)
	state = State.SPAWN
	_state_t = 0.32
	if _visual != null:
		_visual.scale = _body_scale * 0.2


func configure_health(hp: float) -> void:
	health = hp


func take_damage(amount: float) -> void:
	if not alive or state == State.DEAD:
		return
	health -= amount
	hurt.emit()
	_spark()
	if _visual != null:
		_visual.scale = Vector3(_body_scale.x * 1.16, _body_scale.y * 0.84, _body_scale.z * 1.16)
	if health <= 0.0:
		_die()
		return
	state = State.HIT
	_state_t = 0.14
	_tint(SKIN_HIT)


func apply_knockback(dir: Vector3) -> void:
	if not alive:
		return
	var flat: Vector3 = Vector3(dir.x, 0.0, dir.z)
	if flat.length() > 0.01:
		_knock = flat.normalized() * 3.6


func _die() -> void:
	alive = false
	state = State.DEAD
	_state_t = 0.5
	collision_layer = 0
	collision_mask = 0
	if _col != null:
		_col.disabled = true
	if _mat != null:
		_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	died.emit()
	if drop_chance > 0.0 and randf() < drop_chance:
		_drop_max_ammo()


func _drop_max_ammo() -> void:
	var parent := get_parent()
	if parent == null:
		return
	var drop := PowerScript.new()
	parent.add_child(drop)
	drop.global_position = global_position + Vector3(0, 0.15, 0)


func _physics_process(delta: float) -> void:
	_attack_cd = maxf(_attack_cd - delta, 0.0)
	_state_t = maxf(_state_t - delta, 0.0)
	_knock = _knock.move_toward(Vector3.ZERO, delta * 14.0)
	if _visual != null and state != State.SPAWN and state != State.DEAD:
		_visual.scale = _visual.scale.lerp(_body_scale, delta * 10.0)
	if state == State.SPAWN:
		var k: float = 1.0 - (_state_t / 0.32)
		if _visual != null:
			_visual.scale = _body_scale * clampf(k, 0.2, 1.0)
		if _state_t <= 0.0:
			if _visual != null:
				_visual.scale = _body_scale
			state = State.CHASE
		return
	if state == State.DEAD:
		_fade = move_toward(_fade, 0.0, delta * 1.8)
		if _visual != null:
			_visual.rotation.x = move_toward(_visual.rotation.x, 1.15, delta * 3.2)
			_visual.position.y = move_toward(_visual.position.y, -0.35, delta * 1.2)
		if _mat != null:
			_mat.albedo_color = Color(SKIN_HIT.r, SKIN_HIT.g, SKIN_HIT.b, _fade)
		if _state_t <= 0.0:
			queue_free()
		return
	if state == State.HIT:
		if _state_t <= 0.0:
			state = State.CHASE
			_tint(SKIN)
		velocity.x = _knock.x
		velocity.z = _knock.z
		_apply_gravity(delta)
		move_and_slide()
		return
	if not ai_enabled or target == null or not is_instance_valid(target):
		_apply_gravity(delta)
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return
	var player_pos: Vector3 = target.global_position
	_claim_slot(player_pos)
	var slot_pos: Vector3 = _slot_world(player_pos, slot_index)
	var to_player: Vector3 = player_pos - global_position
	to_player.y = 0.0
	var dist: float = to_player.length()
	var to_slot: Vector3 = slot_pos - global_position
	to_slot.y = 0.0
	var slot_dist: float = to_slot.length()
	var in_melee: bool = dist <= Config.ZOMBIE_RANGE or slot_dist <= 0.42
	if state == State.ATTACK or state == State.WINDUP:
		if dist > Config.ZOMBIE_RANGE + 0.55 and slot_dist > 0.75:
			in_melee = false
		else:
			in_melee = true
	if in_melee:
		if state != State.WINDUP and state != State.ATTACK:
			state = State.WINDUP
			_state_t = WINDUP_TIME
			attack_started.emit()
		if dist > 0.05:
			_face(to_player)
		if state == State.WINDUP:
			if _arm_r != null:
				_arm_r.rotation.x = move_toward(_arm_r.rotation.x, -1.15, delta * 8.0)
			if _state_t <= 0.0:
				state = State.ATTACK
				_state_t = ATTACK_HOLD
				if _attack_cd <= 0.0 and target.has_method("take_damage"):
					_attack_cd = Config.ZOMBIE_ATTACK_GAP
					target.call("take_damage", Config.ZOMBIE_DAMAGE)
		elif state == State.ATTACK:
			if _arm_r != null:
				_arm_r.rotation.x = move_toward(_arm_r.rotation.x, 0.55, delta * 14.0)
			if _state_t <= 0.0:
				state = State.CHASE
				if _arm_r != null:
					_arm_r.rotation.x = 0.0
		var hold: Vector3 = Vector3.ZERO
		if slot_dist > 0.30:
			hold = to_slot / slot_dist * minf(slot_dist, 1.4) * 1.6
		hold = _steer_apart(hold)
		if dist < 1.25 and dist > 0.05:
			var inward: Vector3 = to_player / dist
			var inward_speed: float = hold.dot(inward)
			if inward_speed > 0.0:
				hold -= inward * inward_speed
			if dist < 1.15:
				hold -= inward * 1.5
		if hold.length() > Config.ZOMBIE_SPEED * _speed_mul:
			hold = hold.normalized() * Config.ZOMBIE_SPEED * _speed_mul
		velocity.x = hold.x
		velocity.z = hold.z
		_apply_gravity(delta)
		move_and_slide()
		return
	state = State.CHASE
	var dir: Vector3 = Vector3.ZERO
	if slot_dist > 0.12:
		dir = to_slot / slot_dist
	if use_navigation and _agent != null:
		_agent.target_position = slot_pos
		if not _agent.is_navigation_finished():
			var nxt: Vector3 = _agent.get_next_path_position()
			var step: Vector3 = nxt - global_position
			step.y = 0.0
			if step.length() > 0.05:
				dir = step.normalized()
	dir = _steer_apart(dir)
	if dir.length() > 0.01:
		dir = dir.normalized()
		velocity.x = dir.x * Config.ZOMBIE_SPEED * _speed_mul + _knock.x
		velocity.z = dir.z * Config.ZOMBIE_SPEED * _speed_mul + _knock.z
		_face(dir)
		_walk_t += delta * (7.2 + _speed_mul * 2.2)
		var amp := 0.62 if _speed_mul > 1.05 else 0.48
		if _arm_l != null:
			_arm_l.rotation.x = sin(_walk_t) * amp
		if _arm_r != null:
			_arm_r.rotation.x = sin(_walk_t + PI) * amp
		if _leg_l != null:
			_leg_l.rotation.x = sin(_walk_t + PI) * (amp * 0.85)
		if _leg_r != null:
			_leg_r.rotation.x = sin(_walk_t) * (amp * 0.85)
		if _head != null:
			_head.rotation.y = sin(_walk_t * 0.5) * 0.16
			_head.rotation.x = -0.18 + sin(_walk_t * 0.7) * 0.07
		if _visual != null:
			_visual.position.y = absf(sin(_walk_t * 2.0)) * 0.07
			_visual.rotation.z = sin(_walk_t) * 0.04
	else:
		velocity.x = _knock.x
		velocity.z = _knock.z
	if _agent != null:
		_agent.set_velocity(Vector3(velocity.x, 0.0, velocity.z))
	_apply_gravity(delta)
	move_and_slide()


func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= Config.GRAVITY * delta
	else:
		velocity.y = 0.0


func _claim_slot(_player_pos: Vector3) -> void:
	_reassign_cd = maxf(_reassign_cd - 0.016, 0.0)
	var occupied: Dictionary = {}
	for other in _others():
		var idx: int = other.slot_index
		if idx >= 0:
			occupied[idx] = true
	if slot_index >= 0 and not occupied.has(slot_index) and _reassign_cd > 0.0:
		return
	var start: int = absi(get_instance_id()) % SLOT_COUNT
	if slot_index >= 0 and not occupied.has(slot_index):
		return
	var chosen: int = start
	for i in SLOT_COUNT:
		var idx: int = (start + i) % SLOT_COUNT
		if not occupied.has(idx):
			chosen = idx
			break
	slot_index = chosen
	_reassign_cd = randf_range(0.35, 1.1)


func _slot_world(player_pos: Vector3, index: int) -> Vector3:
	var ang: float = TAU * float(index) / float(SLOT_COUNT) + _slot_jitter
	var rad: float = SLOT_RADIUS + _slot_radius_j
	return Vector3(player_pos.x + cos(ang) * rad, player_pos.y, player_pos.z + sin(ang) * rad)


func _steer_apart(dir: Vector3) -> Vector3:
	var sep: Vector3 = Vector3.ZERO
	for other in _others():
		var delta_xz: Vector3 = global_position - other.global_position
		delta_xz.y = 0.0
		var dist: float = delta_xz.length()
		if dist >= SEPARATION_RADIUS or dist <= 0.02:
			continue
		var away: Vector3 = delta_xz / dist
		if dir.length() > 0.01:
			var chase: Vector3 = dir.normalized()
			var lateral: Vector3 = away - chase * away.dot(chase)
			if lateral.length() > 0.02:
				away = lateral.normalized()
		var w: float = (SEPARATION_RADIUS - dist) / SEPARATION_RADIUS
		sep += away * w * SEPARATION_GAIN
		if dist < 0.8:
			sep += away * (0.8 - dist) * 2.4
	return dir + sep


func _others() -> Array:
	var out: Array = []
	var parent := get_parent()
	if parent == null:
		return out
	for child in parent.get_children():
		if child is ZombiesEnemy and child != self and child.alive:
			out.append(child)
	return out


func _face(dir: Vector3) -> void:
	var look: Vector3 = Vector3(dir.x, 0.0, dir.z)
	if look.length() < 0.02:
		return
	look_at(global_position + look.normalized(), Vector3.UP)


func _tint(color: Color) -> void:
	if _mat != null:
		_mat.albedo_color = color


func _spark() -> void:
	var p := CPUParticles3D.new()
	p.emitting = false
	p.one_shot = true
	p.explosiveness = 0.9
	p.amount = 7
	p.lifetime = 0.28
	p.direction = Vector3(0, 1, 0)
	p.spread = 55.0
	p.initial_velocity_min = 1.4
	p.initial_velocity_max = 3.2
	p.gravity = Vector3(0, -4.0, 0)
	p.color = Color("#d4b24a")
	p.position = Vector3(0, 1.1, 0)
	add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)


func _build_humanoid() -> void:
	## Stylized low-poly: readable silhouette, hunched party-horror. Not gore.
	_part_box(Vector3(0.52, 0.62, 0.28), Vector3(0, 1.18, 0.04), CLOTH, true)
	_part_box(Vector3(0.62, 0.16, 0.22), Vector3(0, 1.46, 0.02), CLOTH, true)
	_head = Node3D.new()
	_head.position = Vector3(0, 1.62, 0.06)
	_visual.add_child(_head)
	_part_box_on(_head, Vector3(0.28, 0.32, 0.26), Vector3(0, 0.12, 0.02), SKIN)
	_part_box_on(_head, Vector3(0.22, 0.10, 0.16), Vector3(0, -0.08, 0.08), SKIN)
	_part_box_on(_head, Vector3(0.08, 0.06, 0.06), Vector3(-0.08, 0.14, 0.12), BONE)
	_part_box_on(_head, Vector3(0.08, 0.06, 0.06), Vector3(0.08, 0.14, 0.12), BONE)
	_mesh = _part_box(Vector3(0.22, 0.08, 0.16), Vector3(0, 1.42, 0.08), BONE)
	_arm_l = Node3D.new()
	_arm_l.position = Vector3(-0.38, 1.36, 0)
	_visual.add_child(_arm_l)
	_part_box_on(_arm_l, Vector3(0.13, 0.42, 0.13), Vector3(0, -0.18, 0), SKIN)
	_part_box_on(_arm_l, Vector3(0.11, 0.32, 0.11), Vector3(0, -0.48, 0.04), SKIN)
	_part_box_on(_arm_l, Vector3(0.14, 0.10, 0.16), Vector3(0, -0.66, 0.06), SKIN)
	_arm_r = Node3D.new()
	_arm_r.position = Vector3(0.38, 1.36, 0)
	_visual.add_child(_arm_r)
	_part_box_on(_arm_r, Vector3(0.13, 0.42, 0.13), Vector3(0, -0.18, 0), SKIN)
	_part_box_on(_arm_r, Vector3(0.11, 0.32, 0.11), Vector3(0, -0.48, 0.04), SKIN)
	_part_box_on(_arm_r, Vector3(0.14, 0.10, 0.16), Vector3(0, -0.66, 0.06), SKIN)
	_leg_l = Node3D.new()
	_leg_l.position = Vector3(-0.14, 0.82, 0)
	_visual.add_child(_leg_l)
	_part_box_on(_leg_l, Vector3(0.16, 0.48, 0.16), Vector3(0, -0.18, 0), CLOTH, true)
	_part_box_on(_leg_l, Vector3(0.14, 0.38, 0.14), Vector3(0, -0.52, 0.02), CLOTH, true)
	_part_box_on(_leg_l, Vector3(0.18, 0.10, 0.28), Vector3(0, -0.74, 0.06), Color("#2a2824"))
	_leg_r = Node3D.new()
	_leg_r.position = Vector3(0.14, 0.82, 0)
	_visual.add_child(_leg_r)
	_part_box_on(_leg_r, Vector3(0.16, 0.48, 0.16), Vector3(0, -0.18, 0), CLOTH, true)
	_part_box_on(_leg_r, Vector3(0.14, 0.38, 0.14), Vector3(0, -0.52, 0.02), CLOTH, true)
	_part_box_on(_leg_r, Vector3(0.18, 0.10, 0.28), Vector3(0, -0.74, 0.06), Color("#2a2824"))


func _part_box(size: Vector3, pos: Vector3, color: Color = SKIN, cloth: bool = false) -> MeshInstance3D:
	return _part_box_on(_visual, size, pos, color, cloth)


func _part_box_on(parent: Node, size: Vector3, pos: Vector3, color: Color, cloth: bool = false) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.position = pos
	if color == SKIN or color == SKIN_HIT:
		mesh.set_surface_override_material(0, _mat)
	elif cloth or color == CLOTH:
		mesh.set_surface_override_material(0, _cloth_mat)
	else:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.roughness = 0.9
		mesh.set_surface_override_material(0, mat)
	parent.add_child(mesh)
	return mesh


func _part_sphere(radius: float, pos: Vector3, _color: Color = SKIN) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var ball := SphereMesh.new()
	ball.radius = radius
	ball.height = radius * 2.0
	mesh.mesh = ball
	mesh.position = pos
	mesh.set_surface_override_material(0, _mat)
	_visual.add_child(mesh)
	return mesh
