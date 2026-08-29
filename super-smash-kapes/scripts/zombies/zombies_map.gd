class_name ZombiesMap
extends Node3D

## Shopping del Sol: parking first act + code-built interior gameplay authority.
## Exterior GLB is visual shell only. Collision stays handmade / existing interior.

signal door_opened
signal shopping_opened

const Config := preload("res://scripts/zombies/zombies_config.gd")
const DoorScript := preload("res://scripts/zombies/zombies_buyable_door.gd")
const WallBuyScript := preload("res://scripts/zombies/zombies_weapon_wall_buy.gd")
const Props := preload("res://scripts/zombies/zombies_mall_props.gd")
const Parking := preload("res://scripts/zombies/zombies_parking.gd")
const ShellScript := preload("res://scripts/zombies/zombies_shopping_shell.gd")
const BLENDER_ENV := "res://assets/environments/shopping_del_sol/processed/shopping_del_sol_zombies_environment_v1.glb"
const BLENDER_ENV_V2 := "res://assets/environments/shopping_del_sol/processed/shopping_del_sol_zombies_environment_v2.glb"
const BLENDER_ENV_V3 := "res://assets/environments/shopping_del_sol/processed/shopping_del_sol_zombies_environment_v3.glb"
const BLENDER_ENV_ALT := "res://assets/environments/shopping_del_sol/blender/exports/shopping_del_sol_zombies_environment_v1.glb"
const BLENDER_ENV_V2_ALT := "res://assets/environments/shopping_del_sol/blender/exports/shopping_del_sol_zombies_environment_v2.glb"
const BLENDER_ENV_V3_ALT := "res://assets/environments/shopping_del_sol/blender/exports/shopping_del_sol_zombies_environment_v3.glb"

var player_spawn: Vector3 = Vector3(0, 0.05, 28.5)
var door
var main_entrance
var wall_buy
var plaza_spawns: Array[Vector3] = []
var gallery_spawns: Array[Vector3] = []
var parking_spawns: Array[Vector3] = []
var gallery_open: bool = false
var shopping_open: bool = false
var nav_ready: bool = false
var nav_mode: String = "direct_chase"
var shell_loaded: bool = false
var blender_env_loaded: bool = false
var shell_node
var _nav_region: NavigationRegion3D
var _floor_mat: StandardMaterial3D
var _shell


func spawn_points() -> Array[Vector3]:
	return spawn_points_for(player_spawn)


func spawn_points_for(player_pos: Vector3) -> Array[Vector3]:
	var out: Array[Vector3] = []
	if not shopping_open:
		for p in parking_spawns:
			out.append(p)
		return out
	var outside: bool = player_pos.z > 9.0
	if outside:
		for p in parking_spawns:
			out.append(p)
		for p in plaza_spawns:
			out.append(p)
	else:
		for p in plaza_spawns:
			out.append(p)
		for p in parking_spawns:
			out.append(p)
		if gallery_open:
			for p in gallery_spawns:
				out.append(p)
	if gallery_open and player_pos.z < -17.0:
		var mix: Array[Vector3] = []
		for p in gallery_spawns:
			mix.append(p)
		for p in plaza_spawns:
			mix.append(p)
		return mix
	return out


func build() -> void:
	_add_world()
	_nav_region = NavigationRegion3D.new()
	var nm := NavigationMesh.new()
	nm.agent_radius = 0.5
	nm.agent_height = 1.75
	nm.agent_max_climb = 0.25
	nm.cell_size = 0.25
	nm.cell_height = 0.25
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	_nav_region.navigation_mesh = nm
	add_child(_nav_region)
	var env_path := blender_env_path()
	var park: Dictionary = Parking.add_lot(self, _nav_region, env_path.is_empty())
	var sp_raw = park.get("spawns", [])
	if sp_raw is Array:
		for item in sp_raw:
			parking_spawns.append(item)
	_add_floor(_nav_region, Vector3(0, -0.5, 0), Vector3(20, 1, 16), Config.COLOR_FLOOR)
	_add_floor(_nav_region, Vector3(0, -0.5, -13), Vector3(5, 1, 10), Config.COLOR_FLOOR)
	_add_floor(_nav_region, Vector3(0, -0.5, -25), Vector3(20, 1, 14), Config.COLOR_FLOOR)
	_add_walls()
	_add_dressing()
	_add_main_entrance()
	_add_door()
	_add_wall_buy()
	_add_lights()
	_add_sign()
	if env_path.is_empty():
		_try_shell()
	else:
		_try_blender_env(env_path)
	plaza_spawns = [
		Vector3(-8.5, 0.05, -6.5),
		Vector3(8.5, 0.05, -6.5),
		Vector3(0, 0.05, -7.2),
	]
	gallery_spawns = [
		Vector3(-8.0, 0.05, -30.0),
		Vector3(8.0, 0.05, -30.0),
		Vector3(0.0, 0.05, -30.5),
		Vector3(7.5, 0.05, -21.5),
	]
	_bake_nav()


func rebake_after_door() -> void:
	gallery_open = true
	_bake_nav()


func rebake_after_shopping() -> void:
	shopping_open = true
	_bake_nav()


func _bake_nav() -> void:
	nav_ready = false
	nav_mode = "direct_chase"
	if _nav_region == null:
		return
	_nav_region.bake_navigation_mesh(false)
	var mesh: NavigationMesh = _nav_region.navigation_mesh
	if mesh != null and mesh.get_polygon_count() > 0:
		nav_ready = true
		nav_mode = "navigation_mesh"
	print("[ZOMBIES] nav_mode=%s polygons=%d shopping_open=%s gallery_open=%s" % [
		nav_mode, mesh.get_polygon_count() if mesh != null else 0, str(shopping_open), str(gallery_open)
	])


func _add_world() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-28, 130, 0)
	sun.light_energy = 0.42
	sun.light_color = Color("#9ab0d0")
	sun.shadow_enabled = false
	add_child(sun)
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#2a3854")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#7a8498")
	env.ambient_light_energy = 1.05
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.12
	env.fog_enabled = true
	env.fog_light_color = Color(0.32, 0.36, 0.46)
	env.fog_density = 0.0035
	env.fog_sky_affect = 0.35
	world.environment = env
	add_child(world)


func _add_walls() -> void:
	var t: Color = Config.COLOR_TERRACOTTA
	var c: Color = Config.COLOR_CREAM
	_add_box(self, Vector3(-7.7, 2, 8.2), Vector3(5.4, 4, 0.4), t)
	_add_box(self, Vector3(7.7, 2, 8.2), Vector3(5.4, 4, 0.4), t)
	_add_box(self, Vector3(-10.2, 2, 0), Vector3(0.4, 4, 16.4), t)
	_add_box(self, Vector3(10.2, 2, 0), Vector3(0.4, 4, 16.4), t)
	_add_box(self, Vector3(-6.25, 2, -8.2), Vector3(7.5, 4, 0.4), t)
	_add_box(self, Vector3(6.25, 2, -8.2), Vector3(7.5, 4, 0.4), t)
	_add_box(self, Vector3(-2.7, 2, -13), Vector3(0.4, 4, 10.4), t)
	_add_box(self, Vector3(2.7, 2, -13), Vector3(0.4, 4, 10.4), t)
	_add_box(self, Vector3(-6.25, 2, -17.8), Vector3(7.5, 4, 0.4), t)
	_add_box(self, Vector3(6.25, 2, -17.8), Vector3(7.5, 4, 0.4), t)
	_add_box(self, Vector3(-10.2, 2, -25), Vector3(0.4, 4, 14.4), t)
	_add_box(self, Vector3(10.2, 2, -25), Vector3(0.4, 4, 14.4), t)
	_add_box(self, Vector3(0, 2, -32.2), Vector3(20.8, 4, 0.4), t)
	_add_box(self, Vector3(0, 4.15, -16.2), Vector3(21.2, 0.35, 31.6), c)
	_add_box(self, Vector3(-2.95, 2, -8.2), Vector3(0.5, 4, 0.5), c)
	_add_box(self, Vector3(2.95, 2, -8.2), Vector3(0.5, 4, 0.5), c)
	_add_box(self, Vector3(0, 3.85, -8.2), Vector3(6.4, 0.4, 0.5), c)
	_add_box(self, Vector3(-2.95, 2, 8.2), Vector3(0.5, 4, 0.5), c)
	_add_box(self, Vector3(2.95, 2, 8.2), Vector3(0.5, 4, 0.5), c)
	_add_box(self, Vector3(0, 3.85, 8.2), Vector3(6.4, 0.4, 0.5), c)


func _add_dressing() -> void:
	Props.add_column_wrap(self, Vector3(-5.0, 0, -3.0))
	Props.add_column_wrap(self, Vector3(5.0, 0, -3.0))
	Props.add_kiosk(self, Vector3(0, 0, -4.2))
	_add_box(self, Vector3(-6.4, 0.45, -6.1), Vector3(6.6, 0.9, 0.28), Config.COLOR_DOOR)
	_add_box(self, Vector3(6.4, 0.45, -6.1), Vector3(6.6, 0.9, 0.28), Config.COLOR_DOOR)
	_add_box(self, Vector3(-8.2, 1.0, -28.5), Vector3(2.2, 2.0, 1.4), Color("#5a4038"))
	Props.add_planter(self, Vector3(-4.6, 0, -4.2))
	Props.add_planter(self, Vector3(4.6, 0, -4.2))
	Props.add_planter(self, Vector3(-3.4, 0, 4.2))
	Props.add_planter(self, Vector3(3.4, 0, 4.2))
	Props.add_bench(self, Vector3(-4.4, 0, 2.4), 0.0)
	Props.add_bench(self, Vector3(4.4, 0, 2.4), 0.0)
	Props.add_trash(self, Vector3(8.4, 0, 6.4))
	Props.add_directory(self, Vector3(7.2, 0, 5.0))
	Props.add_storefront(self, Vector3(-9.85, 0, 2.2), PI * 0.5, 3.4, "")
	Props.add_storefront(self, Vector3(9.85, 0, 2.2), -PI * 0.5, 3.4, "")
	Props.add_storefront(self, Vector3(-9.85, 0, -22.0), PI * 0.5, 3.6, "TERERÉ MARKET")
	Props.add_storefront(self, Vector3(-9.85, 0, -29.2), PI * 0.5, 3.4, "CHIPÁ EXPRESS")
	Props.add_storefront(self, Vector3(9.85, 0, -21.2), -PI * 0.5, 3.2, "KAPE SPORT")
	Props.add_storefront(self, Vector3(9.85, 0, -30.0), -PI * 0.5, 3.2, "SOL FOTO")
	Props.add_strip_light(self, Vector3(0, 3.95, 2.0), Vector3(12.0, 0.06, 0.28))
	Props.add_strip_light(self, Vector3(0, 3.95, -4.0), Vector3(12.0, 0.06, 0.28))
	Props.add_strip_light(self, Vector3(0, 3.95, -13.0), Vector3(3.4, 0.06, 0.22))
	Props.add_strip_light(self, Vector3(0, 3.95, -22.0), Vector3(12.0, 0.06, 0.28))
	Props.add_strip_light(self, Vector3(0, 3.95, -28.0), Vector3(12.0, 0.06, 0.28))


func _add_main_entrance() -> void:
	main_entrance = DoorScript.new()
	main_entrance.configure(Config.MAIN_ENTRANCE_NAME, Config.MAIN_ENTRANCE_COST)
	main_entrance.position = Vector3(0, 0, 8.2)
	add_child(main_entrance)
	main_entrance.opened.connect(func():
		shopping_open = true
		shopping_opened.emit()
		rebake_after_shopping()
	)
	var glow := OmniLight3D.new()
	glow.position = Vector3(0, 3.4, 9.3)
	glow.light_energy = 1.55
	glow.omni_range = 14.0
	glow.light_color = Color("#ffe0a8")
	glow.shadow_enabled = false
	add_child(glow)
	var glow2 := OmniLight3D.new()
	glow2.position = Vector3(0, 5.6, 8.9)
	glow2.light_energy = 1.05
	glow2.omni_range = 10.0
	glow2.light_color = Color("#fff0c8")
	glow2.shadow_enabled = false
	add_child(glow2)
	var tag := Label3D.new()
	tag.text = "SHOPPING del SOL"
	tag.position = Vector3(0, 7.15, 8.95)
	tag.font_size = 96
	tag.modulate = Config.COLOR_CREAM
	tag.outline_size = 14
	tag.outline_modulate = Color(0, 0, 0, 0.92)
	tag.visible = blender_env_path().is_empty()
	add_child(tag)


func _add_door() -> void:
	door = DoorScript.new()
	door.configure(Config.DOOR_NAME, Config.DOOR_COST)
	door.position = Vector3(0, 0, -18)
	add_child(door)
	door.opened.connect(func():
		gallery_open = true
		door_opened.emit()
		rebake_after_door()
	)


func _add_wall_buy() -> void:
	wall_buy = WallBuyScript.new()
	wall_buy.configure("smg", Config.WALL_SMG_COST, Config.WALL_AMMO_COST)
	wall_buy.position = Vector3(9.55, 0, -25)
	wall_buy.rotation.y = PI * 0.5
	add_child(wall_buy)


func _add_lights() -> void:
	_omni(Vector3(0, 3.4, 1.6), 1.05, 14.0, Color("#f0d4a8"))
	_omni(Vector3(5.5, 3.2, -3.2), 0.55, 9.0, Color("#e8cda0"))
	_omni(Vector3(0, 3.0, -13.0), 0.48, 8.0, Config.COLOR_CREAM)
	_omni(Vector3(0, 3.2, -25.0), 0.88, 12.0, Color("#b8c8d8"))


func _omni(pos: Vector3, energy: float, rng: float, color: Color) -> void:
	var light := OmniLight3D.new()
	light.position = pos
	light.light_energy = energy * 1.35
	light.omni_range = rng
	light.light_color = color
	light.shadow_enabled = false
	add_child(light)


func _add_sign() -> void:
	var sign := Label3D.new()
	sign.text = "PLAZA"
	sign.position = Vector3(0, 3.45, -7.55)
	sign.font_size = 48
	sign.modulate = Config.COLOR_CREAM
	sign.outline_size = 8
	sign.outline_modulate = Color(0, 0, 0, 0.85)
	add_child(sign)


func blender_env_path() -> String:
	## Production authority: V3. V4.x candidates stay lab-only (firewall + NOT_CANONICAL).
	if ResourceLoader.exists(BLENDER_ENV_V3):
		return BLENDER_ENV_V3
	if ResourceLoader.exists(BLENDER_ENV_V3_ALT):
		return BLENDER_ENV_V3_ALT
	if ResourceLoader.exists(BLENDER_ENV_V2):
		return BLENDER_ENV_V2
	if ResourceLoader.exists(BLENDER_ENV_V2_ALT):
		return BLENDER_ENV_V2_ALT
	if ResourceLoader.exists(BLENDER_ENV):
		return BLENDER_ENV
	if ResourceLoader.exists(BLENDER_ENV_ALT):
		return BLENDER_ENV_ALT
	return ""


func _try_blender_env(path: String) -> void:
	var packed: PackedScene = load(path) as PackedScene
	if packed == null:
		print("[ZOMBIES_BLENDER] FAIL load %s" % path)
		_try_shell()
		return
	var inst := packed.instantiate()
	inst.name = "ShoppingBlenderEnvV1"
	add_child(inst)
	_strip_visual_collision(inst)
	_spawn_lights_from_markers(inst)
	blender_env_loaded = true
	_hide_codebuilt_visuals()
	print("[ZOMBIES_BLENDER] loaded=%s HUMAN_REVIEW_PENDING" % path)


func _hide_codebuilt_visuals() -> void:
	## Keep collision / doors / wall-buy. Hide greybox meshes so the Blender shell can read.
	_hide_code_meshes(self)


func _hide_code_meshes(node: Node) -> void:
	if node == null:
		return
	if node is ZombiesBuyableDoor or node is ZombiesWeaponWallBuy:
		return
	var nm := str(node.name)
	if nm.begins_with("ShoppingBlender") or nm.begins_with("BlenderEnv"):
		return
	if node is Label3D:
		(node as Label3D).visible = false
	if node is MeshInstance3D:
		var parent := node.get_parent()
		if parent is StaticBody3D:
			(node as MeshInstance3D).visible = false
	for child in node.get_children():
		_hide_code_meshes(child)


func _strip_visual_collision(node: Node) -> void:
	if node is CollisionObject3D:
		(node as CollisionObject3D).collision_layer = 0
		(node as CollisionObject3D).collision_mask = 0
	if node is CollisionShape3D:
		(node as CollisionShape3D).disabled = true
	for child in node.get_children():
		_strip_visual_collision(child)


func _spawn_lights_from_markers(node: Node) -> void:
	var n := str(node.name)
	if n.begins_with("LIGHT_") and node is Node3D:
		var omni := OmniLight3D.new()
		omni.light_color = Color("#ffe0b0")
		omni.light_energy = 1.35 if n.contains("ENTRANCE") else 0.85
		omni.omni_range = 16.0 if n.contains("ENTRANCE") else 11.0
		omni.shadow_enabled = false
		(node as Node3D).add_child(omni)
	for child in node.get_children():
		_spawn_lights_from_markers(child)


func _try_shell() -> void:
	_shell = ShellScript.new()
	_shell.name = "ShoppingShell"
	add_child(_shell)
	shell_node = _shell
	## Facade modules only (volumes hidden). Near-real scale; thin pieces already.
	_shell.scale = Vector3(1.15, 1.35, 1.0)
	_shell.rotation_degrees = Vector3(0, 180, 0)
	_shell.position = Vector3(0.0, 0.0, 10.8)
	shell_loaded = _shell.load_shell()
	if not shell_loaded:
		print("[ZOMBIES_SHELL] fallback code-built facade")
		_add_box(self, Vector3(0, 6.5, 8.6), Vector3(22.0, 9.0, 1.2), Config.COLOR_TERRACOTTA)
		_add_box(self, Vector3(0, 8.2, 9.2), Vector3(8.0, 2.2, 1.6), Config.COLOR_CREAM)
	else:
		var box: AABB = _shell.aabb
		_shell.position.y -= box.position.y
		print("[ZOMBIES_SHELL] facade_slab scale=%s pos=%s aabb_size=%s" % [str(_shell.scale), str(_shell.position), str(box.size)])


func _add_floor(parent: Node, pos: Vector3, size: Vector3, color: Color) -> void:
	var body := _add_box(parent, pos, size, color)
	if _floor_mat == null:
		_floor_mat = Props.floor_material()
	if body.get_child_count() > 0:
		var mesh = body.get_child(0)
		if mesh is MeshInstance3D:
			mesh.set_surface_override_material(0, _floor_mat)


func _add_box(parent: Node, pos: Vector3, size: Vector3, color: Color) -> StaticBody3D:
	if _floor_mat == null:
		_floor_mat = Props.floor_material()
	var body := StaticBody3D.new()
	body.collision_layer = Config.LAYER_WORLD
	body.collision_mask = 0
	body.position = pos
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.set_surface_override_material(0, Props.color_material(color))
	body.add_child(mesh)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	parent.add_child(body)
	return body
