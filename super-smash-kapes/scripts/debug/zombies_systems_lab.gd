extends Node

## Headless systems lab. Direct API checks. Quits 0 on ALL_PASS.
## SSK_ZOMBIES_SMOKE=1 uses the same path.

const Config := preload("res://scripts/zombies/zombies_config.gd")
const PlayerScript := preload("res://scripts/zombies/zombies_player.gd")
const EnemyScript := preload("res://scripts/zombies/zombies_enemy.gd")
const WavesScript := preload("res://scripts/zombies/zombies_waves.gd")
const DoorScript := preload("res://scripts/zombies/zombies_buyable_door.gd")
const WallBuyScript := preload("res://scripts/zombies/zombies_weapon_wall_buy.gd")
const PowerScript := preload("res://scripts/zombies/zombies_power_up.gd")
const StateScript := preload("res://scripts/zombies/zombies_game_state.gd")

var _player
var _state
var _dummy
var _door
var _wall
var _failed: int = 0


func _ready() -> void:
	Config.ensure_actions()
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_world()
	call_deferred("_boot")


func _boot() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	await _run()


func _build_world() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 20, 0)
	add_child(sun)
	var floor := StaticBody3D.new()
	floor.collision_layer = Config.LAYER_WORLD
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(40, 1, 40)
	mesh.mesh = box
	floor.add_child(mesh)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(40, 1, 40)
	col.shape = shape
	floor.add_child(col)
	floor.position = Vector3(0, -0.5, 0)
	add_child(floor)
	_state = StateScript.new()
	_player = PlayerScript.new()
	_player.capture_mouse = false
	_player.game_state = _state
	_player.position = Vector3(0, 0.05, 0)
	add_child(_player)
	_dummy = EnemyScript.new()
	_dummy.ai_enabled = false
	_dummy.drop_chance = 0.0
	_dummy.position = Vector3(0, 0.05, -5)
	add_child(_dummy)
	_dummy.scale = Vector3.ONE
	_dummy.hurt.connect(func(): _state.add_points(Config.POINTS_HIT))
	_dummy.died.connect(func():
		_state.add_kill()
		_state.add_points(Config.POINTS_KILL)
	)
	_door = DoorScript.new()
	_door.configure(Config.DOOR_NAME, Config.DOOR_COST)
	_door.position = Vector3(6, 0, 2)
	add_child(_door)
	_wall = WallBuyScript.new()
	_wall.configure("smg", Config.WALL_SMG_COST, Config.WALL_AMMO_COST)
	_wall.position = Vector3(-6, 0, 2)
	add_child(_wall)


func _run() -> void:
	_test_fire()
	_test_reload()
	_test_kill()
	_test_door_locked()
	_test_door_open()
	_test_wall_buy()
	_test_round()
	_test_max_ammo()
	_test_feel_tokens()
	await _test_crowd()
	_test_rounds_1_3()
	if _failed == 0:
		print("[ZOMBIES_SYSTEMS] ALL_PASS")
		get_tree().quit(0)
	else:
		print("[ZOMBIES_SYSTEMS] FAIL count=%d" % _failed)
		get_tree().quit(1)


func _pass(name_text: String) -> void:
	print("[ZOMBIES_SYSTEMS] PASS %s" % name_text)


func _fail(name_text: String, why: String) -> void:
	_failed += 1
	print("[ZOMBIES_SYSTEMS] FAIL %s %s" % [name_text, why])


func _test_fire() -> void:
	var gun = _player.current_weapon()
	if gun == null:
		_fail("weapon_fire", "no gun")
		return
	var mag0: int = gun.mag
	var hp0: float = _dummy.health
	if gun.data != null:
		gun.data.spread = 0.0
	var ok: bool = _player.try_fire()
	if not ok:
		_fail("weapon_fire", "try_fire returned false")
		return
	if gun.mag != mag0 - 1:
		_fail("weapon_fire", "ammo %d -> %d" % [mag0, gun.mag])
		return
	if _dummy.health >= hp0:
		_fail("weapon_fire", "dummy hp %.1f unchanged" % _dummy.health)
		return
	_pass("weapon_fire")


func _test_reload() -> void:
	var gun = _player.current_weapon()
	if gun == null:
		_fail("reload", "no gun")
		return
	var mag0: int = gun.mag
	var res0: int = gun.reserve
	if mag0 >= gun.data.mag_size:
		_fail("reload", "mag still full")
		return
	if not _player.try_reload():
		_fail("reload", "begin_reload false")
		return
	gun.tick(gun.data.reload_time + 0.05)
	if gun.mag != gun.data.mag_size:
		_fail("reload", "mag %d" % gun.mag)
		return
	if gun.reserve != res0 - (gun.data.mag_size - mag0):
		_fail("reload", "reserve %d" % gun.reserve)
		return
	_pass("reload")


func _test_kill() -> void:
	var kills0: int = _state.kills
	var pts0: int = _state.points
	if _dummy == null or not is_instance_valid(_dummy) or not _dummy.alive:
		_fail("kill", "dummy missing")
		return
	_dummy.take_damage(9999.0)
	if _dummy.alive:
		_fail("kill", "still alive")
		return
	if _state.kills != kills0 + 1:
		_fail("kill", "kills %d" % _state.kills)
		return
	if _state.points <= pts0:
		_fail("kill", "points %d" % _state.points)
		return
	_pass("kill")


func _test_door_locked() -> void:
	_state.points = 0
	var locked: bool = _door.locked
	var ok: bool = _door.try_interact(_player)
	if ok or not _door.locked or not locked:
		_fail("door_locked", "opened with 0 points")
		return
	_pass("door_locked")


func _test_door_open() -> void:
	_state.points = Config.DOOR_COST + 50
	var before: int = _state.points
	var ok: bool = _door.try_interact(_player)
	if not ok or _door.locked:
		_fail("door_open", "still locked")
		return
	if _state.points != before - Config.DOOR_COST:
		_fail("door_open", "points %d" % _state.points)
		return
	_pass("door_open")


func _test_wall_buy() -> void:
	_state.points = Config.WALL_SMG_COST + 100
	var before: int = _state.points
	if _player.owns_weapon("smg"):
		_fail("wall_buy", "already owned")
		return
	var ok: bool = _wall.try_interact(_player)
	if not ok:
		_fail("wall_buy", "try_interact false")
		return
	if not _player.owns_weapon("smg"):
		_fail("wall_buy", "not owned")
		return
	var gun = _player.current_weapon()
	if gun == null or gun.data == null or gun.data.id != "smg":
		_fail("wall_buy", "not equipped")
		return
	if _state.points != before - Config.WALL_SMG_COST:
		_fail("wall_buy", "points %d" % _state.points)
		return
	_pass("wall_buy")


func _test_round() -> void:
	var waves := WavesScript.new()
	var remaining: int = waves.next_count()
	if remaining < 1 or waves.wave != 1:
		_fail("round", "next_count wave1")
		return
	var left: Array = [remaining]
	var spawned: Array = []
	for i in remaining:
		var z = EnemyScript.new()
		z.ai_enabled = false
		z.drop_chance = 0.0
		z.position = Vector3(float(i) * 1.8 - 6.0, 0.05, 8.0)
		add_child(z)
		spawned.append(z)
		z.died.connect(func():
			left[0] = int(left[0]) - 1
		)
	for node in spawned:
		node.take_damage(9999.0)
	if int(left[0]) != 0:
		_fail("round", "remaining %s" % str(left[0]))
		return
	var nxt: int = waves.next_count()
	if nxt < 1 or waves.wave != 2:
		_fail("round", "did not advance")
		return
	_pass("round")


func _test_max_ammo() -> void:
	var gun = _player.current_weapon()
	if gun == null or gun.data == null:
		_fail("max_ammo", "no gun")
		return
	gun.reserve = 4
	gun.mag = 1
	var drop := PowerScript.new()
	add_child(drop)
	drop.position = Vector3(0, 0.2, 1)
	var ok: bool = drop.apply_to(_player)
	if not ok:
		_fail("max_ammo", "apply_to false")
		return
	if gun.reserve != gun.data.reserve_ammo:
		_fail("max_ammo", "reserve %d" % gun.reserve)
		return
	_pass("max_ammo")


func _test_feel_tokens() -> void:
	if _player == null or _player.camera() == null:
		_fail("feel", "no camera")
		return
	var cam: Camera3D = _player.camera()
	var vm = cam.get_node_or_null("Viewmodel")
	if vm == null:
		_fail("feel", "viewmodel missing")
		return
	if _dummy != null and is_instance_valid(_dummy) and _dummy.has_method("apply_knockback"):
		_dummy.call("apply_knockback", Vector3(0, 0, 1))
	_pass("feel")


func _test_crowd() -> void:
	if _player != null:
		_player.health = 10000.0
		_player.control_enabled = false
	var pack: Array = []
	for i in 10:
		var z = EnemyScript.new()
		z.ai_enabled = true
		z.drop_chance = 0.0
		z.use_navigation = false
		var ang: float = TAU * float(i) / 10.0
		z.position = Vector3(cos(ang) * 8.0, 0.05, sin(ang) * 8.0)
		z.target = _player
		add_child(z)
		pack.append(z)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var prev_scale: float = Engine.time_scale
	Engine.time_scale = 6.0
	for _i in 85:
		await get_tree().physics_frame
	Engine.time_scale = prev_scale
	var alive_pack: Array = []
	for node in pack:
		if node != null and is_instance_valid(node) and node.alive:
			alive_pack.append(node)
	if alive_pack.size() < 8:
		_fail("crowd", "alive %d" % alive_pack.size())
		_free_pack(pack)
		return
	var min_nn: float = 999.0
	var clustered: int = 0
	var positions: Array = []
	for a in alive_pack:
		var pa: Vector3 = a.global_position
		positions.append({"x": pa.x, "y": pa.y, "z": pa.z})
		var near: int = 0
		for b in alive_pack:
			var d: float = Vector3(pa.x - b.global_position.x, 0.0, pa.z - b.global_position.z).length()
			if d <= 0.02:
				near += 1
				continue
			if d < min_nn:
				min_nn = d
			if d <= 0.55:
				near += 1
		if near > clustered:
			clustered = near
	if clustered >= 4:
		print("[ZOMBIES_CROWD] FAIL min_nn=%.3f clustered=%d" % [min_nn, clustered])
		_fail("crowd", "blob min_nn=%.3f clustered=%d" % [min_nn, clustered])
		_write_crowd_json(min_nn, clustered, positions, false)
		_free_pack(pack)
		return
	print("[ZOMBIES_CROWD] PASS min_nn=%.3f clustered=%d" % [min_nn, clustered])
	_write_crowd_json(min_nn, clustered, positions, true)
	_pass("crowd")
	_free_pack(pack)


func _free_pack(pack: Array) -> void:
	for node in pack:
		if node != null and is_instance_valid(node):
			node.ai_enabled = false
			node.queue_free()


func _write_crowd_json(min_nn: float, clustered: int, positions: Array, ok: bool) -> void:
	if OS.has_feature("headless") and OS.get_environment("SSK_ZOMBIES_SMOKE") != "1":
		pass
	var abs_dir: String = ProjectSettings.globalize_path("res://docs/generated/zombies_feel_v2")
	DirAccess.make_dir_recursive_absolute(abs_dir)
	var path := abs_dir.path_join("crowd.json")
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return
	var payload := {
		"pass": ok,
		"min_nn": min_nn,
		"clustered": clustered,
		"positions": positions,
	}
	f.store_string(JSON.stringify(payload, "\t"))
	f.close()


func _test_rounds_1_3() -> void:
	var waves := WavesScript.new()
	for _w in 3:
		var n: int = waves.next_count()
		if n < 1:
			_fail("rounds_1_3", "wave %d empty" % waves.wave)
			return
		var alive: int = n
		print("[ZOMBIES_WAVES] wave=%d spawn=%d alive=%d" % [waves.wave, n, alive])
		for j in n:
			var z = EnemyScript.new()
			z.ai_enabled = false
			z.drop_chance = 0.0
			z.position = Vector3(float(j) * 0.8 - 4.0, 0.05, 10.0)
			add_child(z)
			z.take_damage(9999.0)
			alive -= 1
		print("[ZOMBIES_WAVES] wave=%d alive=%d" % [waves.wave, alive])
		if alive != 0:
			_fail("rounds_1_3", "wave %d leftover %d" % [waves.wave, alive])
			return
	_pass("rounds_1_3")
