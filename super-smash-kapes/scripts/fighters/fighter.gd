class_name Fighter
extends CharacterBody3D

signal damage_changed(fighter: Fighter)
signal fighter_ko(fighter: Fighter)
signal attack_connected(attacker: Fighter, victim: Fighter, knockback: float)

enum FighterState { NORMAL, ATTACKING, HITSTUN, DEAD }

@export var player_id: int = 1
@export var stats: FighterStats
@export var attack_definition: AttackDefinition
@export var display_color: Color = Color(0.9, 0.15, 0.12)
@export var fighter_id: String = "terere"

const PLANE_Z := 0.0
const FIGHTER_CATALOG := preload("res://scripts/fighters/fighter_catalog.gd")

var state: FighterState = FighterState.NORMAL
var damage_percent: float = 0.0
var stocks: int = 3
var air_jumps_remaining: int = 1
var facing: float = 1.0
var hitstun_time: float = 0.0
var attack_time: float = 0.0
var attack_hit_targets: Dictionary = {}
var spawn_position: Vector3
var invulnerability_time: float = 0.0
var match_locked: bool = false
var jump_active: bool = false
var visual_time: float = 0.0
var definition

@onready var placeholder_visual: MeshInstance3D = $Visual
@onready var visual_root: Node3D = $VisualRoot
@onready var attack_hitbox: Area3D = $AttackHitbox

var character_visual
## Read-only MCP snapshot. Does not change combat values.
var jeffrey_debug_state: Dictionary = {}

func _ready() -> void:
	if stats == null:
		stats = FighterStats.new()
	if attack_definition == null:
		attack_definition = AttackDefinition.new()
		attack_definition.damage = stats.attack_damage
		attack_definition.base_knockback = stats.attack_base_knockback
		attack_definition.knockback_growth = stats.attack_knockback_growth
		attack_definition.angle_degrees = stats.attack_angle_degrees
	stocks = stats.starting_stocks
	air_jumps_remaining = stats.max_air_jumps
	spawn_position = global_position
	definition = FIGHTER_CATALOG.get_by_id(fighter_id)
	_setup_visual()
	$Hurtbox.set_meta("fighter", self)
	attack_hitbox.monitoring = false

func _process(delta: float) -> void:
	if match_locked or state == FighterState.DEAD:
		if character_visual != null:
			character_visual.sync_from_fighter(delta)
		_refresh_jeffrey_debug_state()
		return
	visual_time += delta
	if character_visual != null:
		character_visual.sync_from_fighter(delta)
	elif placeholder_visual.visible:
		var movement_lean: float = clampf(-velocity.x * 0.018, -0.14, 0.14)
		var target_scale := Vector3.ONE
		if state == FighterState.ATTACKING:
			target_scale = Vector3(1.12, 0.90, 1.0)
		elif state == FighterState.HITSTUN:
			target_scale = Vector3(0.88, 1.14, 1.0)
		var bob: float = sin(visual_time * 5.0) * 0.035 if is_on_floor() and state == FighterState.NORMAL else 0.0
		placeholder_visual.position.y = lerpf(placeholder_visual.position.y, 1.2 + bob, minf(delta * 12.0, 1.0))
		placeholder_visual.rotation.z = lerpf(placeholder_visual.rotation.z, movement_lean, minf(delta * 10.0, 1.0))
		placeholder_visual.scale = placeholder_visual.scale.lerp(target_scale, minf(delta * 14.0, 1.0))
	_refresh_jeffrey_debug_state()

func _physics_process(delta: float) -> void:
	if match_locked:
		_refresh_jeffrey_debug_state()
		return
	global_position.z = PLANE_Z
	if state == FighterState.DEAD:
		_refresh_jeffrey_debug_state()
		return
	if invulnerability_time > 0.0:
		invulnerability_time -= delta
		if character_visual == null:
			placeholder_visual.visible = fmod(invulnerability_time, 0.12) > 0.045
	elif character_visual == null:
		placeholder_visual.visible = true
	if hitstun_time > 0.0:
		hitstun_time -= delta
		state = FighterState.HITSTUN
		_apply_gravity(delta)
		move_and_slide()
		global_position.z = PLANE_Z
		_refresh_jeffrey_debug_state()
		return
	if state == FighterState.HITSTUN:
		state = FighterState.NORMAL
	if attack_time > 0.0:
		_process_movement(delta, attack_definition.ground_steering, attack_definition.air_steering)
		_process_attack(delta)
	else:
		_process_movement(delta)
		if _jump_pressed():
			_try_jump()
		if _attack_pressed():
			_start_attack()
	move_and_slide()
	global_position.z = PLANE_Z
	if is_on_floor():
		air_jumps_remaining = stats.max_air_jumps
	_refresh_jeffrey_debug_state()

func _process_movement(delta: float, ground_control: float = 1.0, air_control: float = 1.0) -> void:
	var direction := Input.get_axis(_action("left"), _action("right"))
	if abs(direction) > 0.01:
		facing = sign(direction)
		var acceleration: float = stats.ground_acceleration * ground_control if is_on_floor() else stats.air_control * air_control
		velocity.x = move_toward(velocity.x, direction * stats.walk_speed, acceleration * delta)
	else:
		var braking: float = stats.ground_deceleration * ground_control if is_on_floor() else stats.air_control * air_control * 0.35
		velocity.x = move_toward(velocity.x, 0.0, braking * delta)
	_apply_gravity(delta)
	if not is_on_floor() and velocity.y <= 0.0 and Input.is_action_pressed(_action("down")):
		velocity.y = -stats.fast_fall_speed
	if jump_active and velocity.y > 0.0 and not Input.is_action_pressed(_action("jump")):
		velocity.y = minf(velocity.y, stats.short_hop_velocity)
	if velocity.y <= 0.0:
		jump_active = false

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y = move_toward(velocity.y, -stats.max_fall_speed, stats.gravity * delta)

func _try_jump() -> void:
	if is_on_floor():
		velocity.y = stats.jump_velocity
		jump_active = true
		if character_visual != null:
			character_visual.on_jump()
	elif air_jumps_remaining > 0:
		air_jumps_remaining -= 1
		velocity.y = stats.double_jump_velocity
		jump_active = true
		if character_visual != null:
			character_visual.on_jump()

func _start_attack() -> void:
	state = FighterState.ATTACKING
	attack_time = attack_definition.total_duration()
	attack_hit_targets.clear()
	attack_hitbox.monitoring = false
	if character_visual != null:
		character_visual.on_attack_started()

func _process_attack(delta: float) -> void:
	var elapsed: float = attack_definition.total_duration() - attack_time
	attack_time -= delta
	attack_hitbox.position.x = 0.95 * facing
	if elapsed >= attack_definition.startup_seconds and elapsed < attack_definition.startup_seconds + attack_definition.active_seconds:
		attack_hitbox.monitoring = true
		for area in attack_hitbox.get_overlapping_areas():
			var victim: Fighter = area.get_meta("fighter", null) as Fighter
			if victim is Fighter and victim != self and not attack_hit_targets.has(victim.get_instance_id()):
				attack_hit_targets[victim.get_instance_id()] = true
				var force: float = victim.receive_attack(attack_definition.damage, attack_definition.base_knockback, attack_definition.knockback_growth, attack_definition.angle_degrees, facing)
				if force > 0.0:
					attack_connected.emit(self, victim, force)
	else:
		attack_hitbox.monitoring = false
	if attack_time <= 0.0:
		state = FighterState.NORMAL
		attack_time = 0.0

func receive_attack(damage: float, base_knockback: float, growth: float, angle_degrees: float, launch_direction: float) -> float:
	if state == FighterState.DEAD or invulnerability_time > 0.0:
		return 0.0
	attack_time = 0.0
	attack_hitbox.monitoring = false
	attack_hit_targets.clear()
	jump_active = false
	damage_percent += damage
	damage_changed.emit(self)
	var target_weight: float = maxf(stats.weight, 1.0)
	var force: float = (base_knockback + damage_percent * growth) * (100.0 / target_weight)
	var angle: float = deg_to_rad(angle_degrees)
	velocity.x = cos(angle) * force * launch_direction
	velocity.y = sin(angle) * force
	hitstun_time = clampf(force * attack_definition.hitstun_scale, 0.12, 0.55)
	state = FighterState.HITSTUN
	if character_visual != null:
		character_visual.on_hit()
	return force

func ko() -> void:
	if state == FighterState.DEAD:
		return
	state = FighterState.DEAD
	attack_time = 0.0
	attack_hit_targets.clear()
	jump_active = false
	stocks = max(stocks - 1, 0)
	attack_hitbox.monitoring = false
	fighter_ko.emit(self)

func respawn() -> void:
	global_position = spawn_position
	velocity = Vector3.ZERO
	damage_percent = 0.0
	state = FighterState.NORMAL
	attack_time = 0.0
	attack_hit_targets.clear()
	jump_active = false
	air_jumps_remaining = stats.max_air_jumps
	invulnerability_time = 1.5
	damage_changed.emit(self)
	if character_visual != null:
		character_visual.on_respawn()

func eliminate() -> void:
	state = FighterState.DEAD
	velocity = Vector3.ZERO
	attack_time = 0.0
	attack_hitbox.monitoring = false
	attack_hitbox.collision_layer = 0
	attack_hitbox.collision_mask = 0
	$Hurtbox.monitoring = false
	$Hurtbox.monitorable = false
	$Hurtbox.collision_layer = 0
	$Hurtbox.collision_mask = 0
	collision_layer = 0
	collision_mask = 0
	if character_visual != null:
		character_visual.on_eliminated()
	else:
		placeholder_visual.visible = false

func lock_match() -> void:
	match_locked = true
	velocity = Vector3.ZERO
	attack_time = 0.0
	attack_hitbox.monitoring = false
	attack_hitbox.collision_layer = 0
	attack_hitbox.collision_mask = 0
	$Hurtbox.monitoring = false
	$Hurtbox.monitorable = false
	$Hurtbox.collision_layer = 0
	$Hurtbox.collision_mask = 0
	if character_visual != null and state != FighterState.DEAD:
		character_visual.on_victory()


func _refresh_jeffrey_debug_state() -> void:
	var phase := "idle"
	if state == FighterState.DEAD:
		phase = "dead"
	elif state == FighterState.HITSTUN:
		phase = "hitstun"
	elif state == FighterState.ATTACKING and attack_definition != null:
		var elapsed: float = attack_definition.total_duration() - attack_time
		if elapsed < attack_definition.startup_seconds:
			phase = "startup"
		elif elapsed < attack_definition.startup_seconds + attack_definition.active_seconds:
			phase = "active"
		else:
			phase = "recovery"
	var anim: Variant = "UNAVAILABLE"
	if character_visual != null:
		var label = character_visual.get("_state_label")
		if label != null:
			anim = label
		var semantic = character_visual.get("_current_semantic")
		if semantic != null and str(semantic) != "":
			anim = semantic
		var player = character_visual.get("animation_player")
		if player != null and str(player.current_animation) != "":
			anim = str(player.current_animation)
	var gp := global_position
	var vel := velocity
	jeffrey_debug_state = {
		"fighter_identity": fighter_id,
		"player_slot": player_id,
		"damage": damage_percent,
		"stocks": stocks,
		"position": [gp.x, gp.y, gp.z],
		"velocity": [vel.x, vel.y, vel.z],
		"grounded": is_on_floor(),
		"state": state,
		"hitstun_remaining": hitstun_time,
		"invulnerability": invulnerability_time,
		"attack_phase": phase,
		"active_animation": anim,
		"last_hit": "UNAVAILABLE",
		"mutating": false,
	}


func get_display_name() -> String:
	if definition != null:
		return definition.display_name
	return stats.fighter_name if stats != null else "P%d" % player_id

func _setup_visual() -> void:
	placeholder_visual.visible = false
	if definition == null:
		placeholder_visual.visible = true
		var material := StandardMaterial3D.new()
		material.albedo_color = display_color
		material.metallic = 0.08
		material.roughness = 0.32
		placeholder_visual.material_override = material
		return
	character_visual = definition.create_visual()
	if character_visual == null:
		var fallback_script: Script = definition.load_fallback_visual_script()
		if fallback_script != null:
			push_error("[FIGHTER_PIPELINE][ERROR] ActorCore production asset failed. fighter=%s" % fighter_id)
			character_visual = fallback_script.new()
	if character_visual == null:
		push_error("[FIGHTER_PIPELINE][ERROR] ActorCore production asset failed. emergency_capsule fighter=%s" % fighter_id)
		placeholder_visual.visible = true
		return
	character_visual.name = "CharacterVisual"
	visual_root.add_child(character_visual)
	character_visual.bind(self, definition)
	if OS.get_environment("SSK_SHOW_FIGHTER_COLLIDERS") == "1":
		_show_collider_debug()

func _show_collider_debug() -> void:
	placeholder_visual.visible = true
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(display_color.r, display_color.g, display_color.b, 0.22)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	placeholder_visual.material_override = material

func _action(name: String) -> String:
	return "p%d_%s" % [player_id, name]

func _jump_pressed() -> bool:
	return Input.is_action_just_pressed(_action("jump"))

func _attack_pressed() -> bool:
	return Input.is_action_just_pressed(_action("attack"))
