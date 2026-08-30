class_name ZombiesPlayer
extends CharacterBody3D

signal died
signal fired
signal damaged
signal dry_fired
signal max_ammo_taken

const Config := preload("res://scripts/zombies/zombies_config.gd")
const WeaponScript := preload("res://scripts/zombies/zombies_weapon.gd")
const ViewScript := preload("res://scripts/zombies/zombies_viewmodel.gd")

var health: float = Config.PLAYER_HP
var yaw: float = 0.0
var pitch: float = 0.0
var _cam: Camera3D
var control_enabled: bool = true
var capture_mouse: bool = true
var game_state
var interact_prompt: String = ""
var gun
var owned: Dictionary = {}
var last_hit_was_zombie: bool = false
var last_hit_was_kill: bool = false
var _flash: OmniLight3D
var _flash_left: float = 0.0
var _kick: float = 0.0
var _hurt_kick: float = 0.0
var _viewmodel
var _moving: bool = false


func _ready() -> void:
	Config.ensure_actions()
	collision_layer = Config.LAYER_PLAYER
	collision_mask = Config.LAYER_WORLD
	floor_snap_length = 0.25
	_cam = Camera3D.new()
	_cam.position = Vector3(0, 1.6, 0)
	_cam.fov = 75.0
	add_child(_cam)
	_cam.current = capture_mouse
	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = 1.7
	shape.shape = cap
	shape.position = Vector3(0, 0.85, 0)
	add_child(shape)
	_flash = OmniLight3D.new()
	_flash.light_energy = 0.0
	_flash.omni_range = 3.5
	_flash.light_color = Color("#ffdca8")
	_flash.shadow_enabled = false
	_flash.position = Vector3(0.2, -0.12, -0.45)
	_cam.add_child(_flash)
	_viewmodel = ViewScript.new()
	_viewmodel.name = "Viewmodel"
	_cam.add_child(_viewmodel)
	if capture_mouse and not Config.is_headless():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if gun == null:
		give_weapon("pistol")


func _exit_tree() -> void:
	if capture_mouse:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func camera() -> Camera3D:
	return _cam


func current_weapon():
	return gun


func switch_weapon(id: String) -> bool:
	if not owned.has(id):
		return false
	var next = owned.get(id)
	if next == null:
		return false
	gun = next
	if _viewmodel != null and _viewmodel.has_method("set_weapon"):
		_viewmodel.call("set_weapon", id)
	return true


func switch_next_weapon() -> bool:
	var ids: Array[String] = []
	for key in owned.keys():
		ids.append(str(key))
	ids.sort()
	if ids.size() < 2:
		return false
	var current_id: String = ""
	if gun != null and gun.data != null:
		current_id = str(gun.data.id)
	var index: int = ids.find(current_id)
	if index < 0:
		index = 0
	return switch_weapon(ids[(index + 1) % ids.size()])


func owns_weapon(id: String) -> bool:
	return owned.has(id)


func spend_points(amount: int) -> bool:
	if game_state == null:
		return false
	return game_state.spend(amount)


func give_weapon(id: String) -> void:
	var data = Config.load_weapon(id)
	var w := WeaponScript.new()
	w.setup(data)
	owned[id] = w
	gun = w
	if _viewmodel != null and _viewmodel.has_method("set_weapon"):
		_viewmodel.call("set_weapon", id)


func refill_weapon(id: String) -> void:
	if not owned.has(id):
		return
	var w = owned[id]
	if w != null and w.has_method("refill"):
		w.refill(true)


func refill_all_ammo() -> void:
	for key in owned.keys():
		var w = owned[key]
		if w != null and w.has_method("refill"):
			w.refill(true)
	max_ammo_taken.emit()


func try_reload() -> bool:
	if gun == null:
		return false
	return gun.begin_reload()


func try_interact() -> bool:
	_update_interact()
	if last_interactable() == null:
		return false
	return last_interactable().try_interact(self)


func last_interactable():
	var node = get_meta("interact_node", null)
	if node != null and node.has_method("try_interact"):
		return node
	return null


func try_fire() -> bool:
	if not control_enabled or gun == null:
		return false
	if gun.is_reloading():
		return false
	if gun.mag <= 0:
		if gun.fire_cd <= 0.0:
			gun.fire_cd = 0.16
			dry_fired.emit()
			if _viewmodel != null and _viewmodel.has_method("play_dry"):
				_viewmodel.call("play_dry")
		return false
	if not gun.consume_shot():
		return false
	fired.emit()
	_flash_left = 0.05
	var auto: bool = gun.data != null and gun.data.automatic
	_kick = 0.014 if auto else 0.032
	if _viewmodel != null and _viewmodel.has_method("play_recoil"):
		_viewmodel.call("play_recoil", auto)
	last_hit_was_zombie = false
	last_hit_was_kill = false
	if _cam == null:
		return true
	var spread: float = 0.0
	if gun.data != null:
		spread = gun.data.spread
	var reach: float = 80.0
	if gun.data != null:
		reach = gun.data.range_m
	var dmg: float = Config.DAMAGE
	if gun.data != null:
		dmg = gun.data.damage
	var from := _cam.global_position
	var forward := -_cam.global_transform.basis.z
	if spread > 0.0:
		forward += _cam.global_transform.basis.x * randf_range(-spread, spread)
		forward += _cam.global_transform.basis.y * randf_range(-spread, spread)
		forward = forward.normalized()
	var to := from + forward * reach
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = Config.LAYER_ZOMBIE
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return true
	var col = hit.get("collider")
	if col != null and col.has_method("take_damage"):
		if col.has_method("apply_knockback"):
			col.call("apply_knockback", forward)
		col.call("take_damage", dmg)
		last_hit_was_zombie = true
		if col.get("alive") == false:
			last_hit_was_kill = true
	return true


func take_damage(amount: float) -> void:
	if health <= 0.0:
		return
	health = maxf(health - amount, 0.0)
	_hurt_kick = 0.045
	damaged.emit()
	if health <= 0.0:
		control_enabled = false
		died.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not control_enabled:
		return
	if event is InputEventMouseMotion:
		yaw -= event.relative.x * Config.MOUSE * 0.01
		pitch = clampf(pitch - event.relative.y * Config.MOUSE * 0.01, -Config.PITCH_MAX, Config.PITCH_MAX)
		rotation.y = yaw
		if _cam != null:
			_cam.rotation.x = pitch + _kick + _hurt_kick
	if event.is_action_pressed("z_reload"):
		try_reload()
		get_viewport().set_input_as_handled()
	if event.is_action_pressed("z_interact"):
		try_interact()
		get_viewport().set_input_as_handled()
	if event.is_action_pressed("z_weapon_next"):
		switch_next_weapon()
		get_viewport().set_input_as_handled()


func _physics_process(delta: float) -> void:
	if gun != null:
		gun.tick(delta)
	_flash_left = maxf(_flash_left - delta, 0.0)
	if _flash != null:
		_flash.light_energy = 4.5 if _flash_left > 0.0 else 0.0
	_kick = move_toward(_kick, 0.0, delta * 0.22)
	_hurt_kick = move_toward(_hurt_kick, 0.0, delta * 0.28)
	if _cam != null:
		_cam.rotation.x = pitch + _kick + _hurt_kick
	var reloading: bool = gun != null and gun.is_reloading()
	if _viewmodel != null and _viewmodel.has_method("tick"):
		_viewmodel.call("tick", delta, _moving, reloading)
	_update_interact()
	if not control_enabled:
		_moving = false
		return
	var wish := Vector3.ZERO
	var basis_flat := Basis(Vector3.UP, yaw)
	if Input.is_action_pressed("z_forward"):
		wish -= basis_flat.z
	if Input.is_action_pressed("z_back"):
		wish += basis_flat.z
	if Input.is_action_pressed("z_left"):
		wish -= basis_flat.x
	if Input.is_action_pressed("z_right"):
		wish += basis_flat.x
	wish.y = 0.0
	if wish.length() > 0.001:
		wish = wish.normalized()
	_moving = wish.length() > 0.001
	var speed: float = Config.SPRINT if Input.is_action_pressed("z_sprint") else Config.WALK
	velocity.x = wish.x * speed
	velocity.z = wish.z * speed
	if not is_on_floor():
		velocity.y -= Config.GRAVITY * delta
	elif Input.is_action_just_pressed("z_jump"):
		velocity.y = Config.JUMP
	else:
		velocity.y = 0.0
	move_and_slide()
	if gun != null and gun.data != null and gun.data.automatic:
		if Input.is_action_pressed("z_fire"):
			try_fire()
	elif Input.is_action_just_pressed("z_fire"):
		try_fire()


func _update_interact() -> void:
	interact_prompt = ""
	if has_meta("interact_node"):
		remove_meta("interact_node")
	if _cam == null:
		return
	var from := _cam.global_position
	var to := from + -_cam.global_transform.basis.z * Config.INTERACT_RANGE
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = Config.LAYER_INTERACT
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return
	var col = hit.get("collider")
	if col != null and col.has_method("try_interact") and col.has_method("get_prompt"):
		set_meta("interact_node", col)
		if col.has_method("prompt_for"):
			var custom = col.call("prompt_for", self)
			interact_prompt = str(custom)
		else:
			interact_prompt = col.get_prompt()
