extends Node

## Side-by-side authority compare: Shopping V3 production vs V4.3 candidate (lab only).

const OUT := "E:/JeffreyAIResearch/outputs/runtime-review/jeffrey_overnight_total_repair_v1/DEEP_POLISH/COMPARE"
const V3 := "res://assets/environments/shopping_del_sol/processed/shopping_del_sol_zombies_environment_v3.glb"
const V43 := "res://assets/environments/shopping_del_sol/processed/shopping_del_sol_zombies_environment_v4_3_candidate.glb"

var _cam: Camera3D


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_run")


func _run() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute(OUT)
	var env := WorldEnvironment.new()
	var we := Environment.new()
	we.background_mode = Environment.BG_COLOR
	we.background_color = Color(0.05, 0.07, 0.1)
	we.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	we.ambient_light_color = Color(0.55, 0.55, 0.6)
	we.ambient_light_energy = 0.85
	env.environment = we
	add_child(env)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-42, 35, 0)
	light.light_energy = 1.15
	add_child(light)
	_cam = Camera3D.new()
	_cam.name = "CompareCam"
	_cam.current = true
	_cam.fov = 60
	add_child(_cam)
	await _shot(V3, OUT + "/v3_facade.png", Vector3(0, 8, 42), Vector3(0, 4, 0))
	await _shot(V3, OUT + "/v3_parking.png", Vector3(12, 6, 28), Vector3(0, 2, 8))
	await _shot(V43, OUT + "/v4_3_facade.png", Vector3(0, 8, 42), Vector3(0, 4, 0))
	await _shot(V43, OUT + "/v4_3_parking.png", Vector3(12, 6, 28), Vector3(0, 2, 8))
	_write_md()
	print("[SDS_COMPARE] PASS %s" % OUT)
	get_tree().quit(0)


func _shot(path: String, out_path: String, cam_pos: Vector3, look: Vector3) -> void:
	for c in get_children():
		if str(c.name).begins_with("EnvInst"):
			c.queue_free()
	await get_tree().process_frame
	if not ResourceLoader.exists(path):
		print("[SDS_COMPARE] missing %s" % path)
		return
	var packed := load(path) as PackedScene
	if packed == null:
		return
	var inst := packed.instantiate()
	inst.name = "EnvInst"
	add_child(inst)
	_cam.global_position = cam_pos
	_cam.look_at(look, Vector3.UP)
	for _i in 20:
		await get_tree().process_frame
	RenderingServer.force_draw()
	await get_tree().process_frame
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png(out_path)
	print("[SDS_COMPARE] %s bytes=%d" % [out_path.get_file(), FileAccess.get_file_as_bytes(out_path).size()])
	inst.queue_free()
	await get_tree().process_frame


func _write_md() -> void:
	var body := """# Zombies V3 vs V4.3 visual authority

## Decision rule
Prefer human-recognizable Shopping del Sol + stable gameplay nav over raw version number.

## Assets
- V3 (production): `shopping_del_sol_zombies_environment_v3.glb`
- V4.3 (candidate / NOT_CANONICAL): `shopping_del_sol_zombies_environment_v4_3_candidate.glb`

## Screenshots
- `v3_facade.png` / `v3_parking.png`
- `v4_3_facade.png` / `v4_3_parking.png`

## Verdict
Inspect PNGs in this folder. Production stays on V3 unless V4.3 is clearly superior AND navigation-safe.
Firewall tests forbid wiring V4.3 into `zombies_map.gd` until human approval.
"""
	var f := FileAccess.open(OUT + "/ZOMBIES_AUTHORITY_COMPARISON.md", FileAccess.WRITE)
	if f:
		f.store_string(body)
		f.close()
