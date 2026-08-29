extends Node3D

## Windowed D3D12 review stills. Does not import Street View. EEVEE Blender stills disabled on this GPU.

const Assembler := preload("res://scripts/track/track_kit_assembler.gd")
const Registry := preload("res://scripts/track/track_piece_registry.gd")
const Scenery := preload("res://scripts/track/track_scenery_generator.gd")
const Probe := preload("res://scripts/debug/jeffrey_resource_probe.gd")

const ENV_V3 := "res://assets/environments/shopping_del_sol/processed/shopping_del_sol_zombies_environment_v3.glb"
const ENV_V2 := "res://assets/environments/shopping_del_sol/processed/shopping_del_sol_zombies_environment_v2.glb"
const OUT_SHOP := "res://docs/generated/sds_v3_visual_review"
const OUT_TRACK := "res://docs/generated/v9_visual_review/track"

var _cam: Camera3D
var _phase := 0
var _sds: Node
var _track_root: Node3D


func _ready() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_SHOP))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_TRACK))
	_cam = Camera3D.new()
	_cam.current = true
	_cam.fov = 68.0
	add_child(_cam)
	call_deferred("_run")


func _run() -> void:
	await _capture_sds()
	await _capture_track()
	print("[V9_CAPTURE] DONE HUMAN_REVIEW_PENDING")
	get_tree().quit(0)


func _capture_sds() -> void:
	_world_sds()
	var env_path := ENV_V3 if ResourceLoader.exists(ENV_V3) else ENV_V2
	if ResourceLoader.exists(env_path):
		var packed: PackedScene = load(env_path) as PackedScene
		if packed != null:
			_sds = packed.instantiate()
			_sds.name = "BlenderEnv"
			add_child(_sds)
			print("[V9_CAPTURE] sds=%s" % env_path)
	Probe.dump("v9_sds_capture", self)
	var shots: Array = [
		{"name": "sds_beauty_spawn.png", "pos": Vector3(0.0, 1.65, 28.5), "look": Vector3(0.0, 2.6, 8.2)},
		{"name": "sds_beauty_parking.png", "pos": Vector3(0.0, 14.0, 42.0), "look": Vector3(0.0, 0.6, 16.0)},
		{"name": "sds_beauty_entrance.png", "pos": Vector3(0.0, 1.85, 16.5), "look": Vector3(0.0, 3.1, 6.5)},
		{"name": "sds_beauty_facade.png", "pos": Vector3(-18.0, 4.2, 22.0), "look": Vector3(0.0, 6.0, 4.0)},
		{"name": "sds_beauty_side.png", "pos": Vector3(22.0, 3.4, 8.0), "look": Vector3(2.0, 4.0, 2.0)},
		{"name": "sds_beauty_night.png", "pos": Vector3(12.0, 3.2, 30.0), "look": Vector3(0.0, 4.5, 8.0)},
		{"name": "sds_beauty_interior.png", "pos": Vector3(0.0, 1.7, 4.5), "look": Vector3(0.0, 4.5, -12.0)},
	]
	for shot in shots:
		await _snap(OUT_SHOP, shot)


func _capture_track() -> void:
	if _sds != null:
		_sds.queue_free()
		_sds = null
		await get_tree().process_frame
	_world_track()
	_track_root = Node3D.new()
	add_child(_track_root)
	var seq := [
		"start", "straight_medium", "curve_l_90", "straight_short", "curve_r_45",
		"chicane_rl", "straight_long", "finish",
	]
	var built: Dictionary = Assembler.assemble(_track_root, seq, Registry.CORE_DIR_V8_15M, true)
	var sc = Scenery.new()
	_track_root.add_child(sc)
	sc.road_clearance = 7.5 + 1.6
	sc.build(built["pieces"])
	Probe.dump("v9_track_capture", _track_root)
	var shots: Array = [
		{"name": "track_straight_urban.png", "pos": Vector3(8.0, 4.5, 6.0), "look": Vector3(0.0, 0.8, -18.0)},
		{"name": "track_90_curve.png", "pos": Vector3(-6.0, 6.0, -28.0), "look": Vector3(-12.0, 1.0, -42.0)},
		{"name": "track_landmark.png", "pos": Vector3(14.0, 8.0, -20.0), "look": Vector3(0.0, 3.0, -24.0)},
		{"name": "track_finish.png", "pos": Vector3(6.0, 5.0, -70.0), "look": Vector3(0.0, 1.2, -90.0)},
		{"name": "track_wide_overview.png", "pos": Vector3(28.0, 32.0, 18.0), "look": Vector3(0.0, 0.0, -40.0)},
	]
	for shot in shots:
		await _snap(OUT_TRACK, shot)


func _snap(folder: String, shot: Dictionary) -> void:
	_cam.global_position = shot["pos"]
	_cam.look_at(shot["look"], Vector3.UP)
	await get_tree().process_frame
	await get_tree().process_frame
	RenderingServer.force_draw()
	await get_tree().process_frame
	var img: Image = get_viewport().get_texture().get_image()
	var path := "%s/%s" % [folder, str(shot["name"])]
	img.save_png(path)
	print("[V9_CAPTURE] wrote %s" % path)


func _world_sds() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-22, 128, 0)
	sun.light_energy = 0.42
	sun.light_color = Color("#8aa0c8")
	add_child(sun)
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#141c2c")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#6a7488")
	env.ambient_light_energy = 0.85
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment = env
	add_child(world)
	var fill := OmniLight3D.new()
	fill.position = Vector3(0, 5.5, 16.0)
	fill.light_energy = 2.2
	fill.omni_range = 26.0
	fill.light_color = Color("#ffc888")
	add_child(fill)


func _world_track() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, 28, 0)
	sun.light_energy = 1.15
	add_child(sun)
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#6e8aa8")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#c8d4e4")
	env.ambient_light_energy = 0.55
	world.environment = env
	add_child(world)
