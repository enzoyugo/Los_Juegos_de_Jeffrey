extends Node

## Deterministic Track Environment Kit V1 capture package (1920×1080, real GPU).

const RaceScript := preload("res://scripts/track/track_race.gd")
const TrackMainScript := preload("res://scripts/track/track_main.gd")
const COPA_RESULTS := preload("res://scripts/ui/jeffrey/copa_jeffrey_results_screen.gd")
const KitScript := preload("res://scripts/track/track_environment_kit_v1.gd")
const Layout := preload("res://scripts/ui/jeffrey/global_ui_layout.gd")

const OUT := "E:/JeffreyAIResearch/outputs/runtime-review/track_environment_kit_v1"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	OS.set_environment("SSK_PERF_DIAG", "1")
	OS.set_environment("SSK_TRACK_ENV_DIAG", "1")
	call_deferred("_run")


func _run() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute(OUT)
	_write_meta()

	## 01 kit lab showcase
	var kit_host := Node3D.new()
	add_child(kit_host)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	sun.light_energy = 1.5
	sun.shadow_enabled = true
	kit_host.add_child(sun)
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#18222c")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#708090")
	env.ambient_light_energy = 0.5
	world.environment = env
	kit_host.add_child(world)
	var kit = KitScript.new()
	kit.showcase_row(kit_host, Vector3.ZERO)
	var cam := Camera3D.new()
	cam.current = true
	kit_host.add_child(cam)
	cam.look_at_from_position(Vector3(55, 12, 28), Vector3(55, 3, 0), Vector3.UP)
	await get_tree().process_frame
	await get_tree().process_frame
	await _save("01_kit_lab.png", "Kit piece showcase row")
	kit_host.queue_free()
	await get_tree().process_frame

	## 02 before (scenery off)
	OS.set_environment("SSK_TRACK_SCENERY", "0")
	var before = RaceScript.new()
	add_child(before)
	before.build(111, "media", "picante")
	_cam_on_start(before)
	for _i in 20:
		await get_tree().process_frame
	await _save("02_track_before.png", "Track with scenery disabled")
	before.queue_free()
	await get_tree().process_frame
	OS.set_environment("SSK_TRACK_SCENERY", "")

	## Zone-biased seeds (placer still randomizes zones; different seeds → different runs)
	await _shot_race(424242, "media", "03_track_after_urban.png", "Seed 424242 media")
	await _shot_race(777001, "media", "04_track_after_green.png", "Seed 777001 media")
	await _shot_race(900042, "larga", "05_track_after_commercial.png", "Seed 900042 larga")

	## Live TrackMain entry / gameplay / pause
	var track = TrackMainScript.new()
	track.setup(_participants(), 424242)
	add_child(track)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	await _save("06_track_entry.png", "Track entry with environment preview")
	if track.has_method("_on_play"):
		track.call("_on_play", "media", "picante")
	for _i in 90:
		await get_tree().process_frame
	await _save("07_track_gameplay.png", "Track gameplay with environment")
	if track.has_method("_toggle_pause"):
		track.call("_toggle_pause")
	await get_tree().process_frame
	await get_tree().process_frame
	await _save("08_track_pause.png", "Track pause over environment")
	if track.has_method("_toggle_pause"):
		track.call("_toggle_pause")
	track.queue_free()
	await get_tree().process_frame

	## Results
	var results = COPA_RESULTS.new()
	add_child(results)
	Layout.bind_full(results)
	results.setup({
		"mode": "racing",
		"awarded": [
			{"profile_id": "p1", "placement": 1, "points": 5, "total_points": 5},
			{"profile_id": "p2", "placement": 2, "points": 3, "total_points": 3},
		],
	})
	await get_tree().process_frame
	await _save("09_track_results.png", "Track results UI")
	results.queue_free()

	print("[TRACK_ENV_KIT_V1_CAPTURE] PASS root=%s" % OUT)
	get_tree().quit()


func _shot_race(seed_value: int, length_id: String, file_name: String, desc: String) -> void:
	var race = RaceScript.new()
	add_child(race)
	race.build(seed_value, length_id, "picante")
	_cam_on_start(race)
	for _i in 24:
		await get_tree().process_frame
	await _save(file_name, desc)
	race.queue_free()
	await get_tree().process_frame


func _cam_on_start(race) -> void:
	var cam := Camera3D.new()
	cam.current = true
	race.add_child(cam)
	var st: Transform3D = race.start_transform
	var from := st.origin + st.basis.z * 10.0 + Vector3(0, 5.5, 0)
	var to := st.origin + st.basis.z * -6.0 + Vector3(0, 1.2, 0)
	cam.look_at_from_position(from, to, Vector3.UP)


func _participants() -> Array:
	return [
		{"profile_id": "p1", "slot": 1, "character_id": "terere"},
		{"profile_id": "p2", "slot": 2, "character_id": "jaguarete"},
	]


func _save(rel: String, desc: String) -> void:
	await get_tree().process_frame
	var img: Image = get_viewport().get_texture().get_image()
	var path := OUT.path_join(rel)
	img.save_png(path)
	print("[TRACK_ENV_KIT_V1_CAPTURE] %s | %s | %s" % [rel, desc, path])


func _write_meta() -> void:
	var meta := {
		"godot": "4.7.2",
		"gpu": "NVIDIA GeForce RTX 2060 SUPER",
		"renderer": "forward_plus",
		"resolution": "1920x1080",
		"timestamp_utc": Time.get_datetime_string_from_system(true),
		"kit": "TrackEnvironmentKitV1",
	}
	var f := FileAccess.open(OUT.path_join("CAPTURE_META.json"), FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(meta, "\t"))
