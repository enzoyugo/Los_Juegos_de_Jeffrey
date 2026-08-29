extends Node

## Track Art Assets V1 capture — 1920×1080 RTX Forward+.

const RaceScript := preload("res://scripts/track/track_race.gd")
const TrackMainScript := preload("res://scripts/track/track_main.gd")
const COPA_RESULTS := preload("res://scripts/ui/jeffrey/copa_jeffrey_results_screen.gd")
const KitScript := preload("res://scripts/track/track_environment_kit_v1.gd")
const RuntimeMeshes := preload("res://scripts/track/track_env_runtime_meshes_v1.gd")
const Layout := preload("res://scripts/ui/jeffrey/global_ui_layout.gd")

const OUT := "E:/JeffreyAIResearch/outputs/runtime-review/track_art_assets_v1"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	OS.set_environment("SSK_PERF_DIAG", "1")
	call_deferred("_run")


func _run() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute(OUT)
	_write_meta()
	var runtime = RuntimeMeshes.new()
	print("[TRACK_ART_BAKE] %s" % JSON.stringify(runtime.bake_all_to_disk()))

	## Art lab showcase
	var kit_host := Node3D.new()
	add_child(kit_host)
	_basic_env(kit_host)
	var kit = KitScript.new()
	kit.showcase_row(kit_host, Vector3.ZERO)
	var cam := Camera3D.new()
	kit_host.add_child(cam)
	cam.current = true
	cam.look_at_from_position(Vector3(55, 12, 28), Vector3(55, 3, 0), Vector3.UP)
	await get_tree().process_frame
	await get_tree().process_frame
	await _save("15_art_lab.png", "Promoted kit showcase")
	kit_host.queue_free()
	await get_tree().process_frame

	## Before = scenery off
	OS.set_environment("SSK_TRACK_SCENERY", "0")
	await _shot_race(424242, "media", "01_track_entry_before.png", "Entry-like before (scenery off)")
	await _shot_race(424242, "media", "03_urban_before.png", "Urban before (scenery off)")
	await _shot_race(424242, "media", "08_hud_before.png", "HUD context before")
	OS.set_environment("SSK_TRACK_SCENERY", "")

	## After
	var track = TrackMainScript.new()
	track.setup(_participants(), 424242)
	add_child(track)
	await get_tree().process_frame
	await get_tree().process_frame
	await _save("02_track_entry_after.png", "Track entry after art")
	if track.has_method("_on_play"):
		track.call("_on_play", "media", "picante")
	for _i in 50:
		await get_tree().process_frame
	await _save("10_countdown.png", "Countdown / DALE")
	await _save("09_hud_after.png", "HUD frame after")
	for _i in 40:
		await get_tree().process_frame
	await _save("04_urban_after.png", "Gameplay urban-ish")
	await _save("07_open_after.png", "Gameplay open horizon")
	track.queue_free()
	await get_tree().process_frame

	await _shot_race(777001, "media", "06_green_after.png", "Green-biased seed")
	await _shot_race(900042, "larga", "05_commercial_after.png", "Commercial-biased larga")

	## Results before/after (after = Track banner)
	var results = COPA_RESULTS.new()
	add_child(results)
	Layout.bind_full(results)
	results.setup(_fake_result())
	await get_tree().process_frame
	await _save("14_results_after.png", "Track results with banner")
	await _save("13_results_before.png", "Results reference (same)")
	results.queue_free()

	## Placeholder checkpoint/finish stills from HUD status injection via TrackMain hard — use race HUD alone
	await _hud_status_shot("11_checkpoint.png", "CHECK  3 / 13", false)
	await _hud_status_shot("12_finish.png", "FINISH", true)

	print("[TRACK_ART_ASSETS_V1_CAPTURE] PASS root=%s" % OUT)
	get_tree().quit()


func _hud_status_shot(file_name: String, status: String, finish: bool) -> void:
	var track = TrackMainScript.new()
	track.setup(_participants(), 424242)
	add_child(track)
	await get_tree().process_frame
	if track.has_method("_on_play"):
		track.call("_on_play", "media", "picante")
	for _i in 30:
		await get_tree().process_frame
	var hud = null
	for c in track.get_children():
		if c is CanvasLayer and c.has_method("set_status"):
			hud = c
			break
	if hud != null:
		if finish and hud.has_method("flash_finish"):
			hud.flash_finish(34.56)
		elif hud.has_method("flash_checkpoint"):
			hud.flash_checkpoint(3, 13)
		else:
			hud.set_status(status)
	await get_tree().process_frame
	await get_tree().process_frame
	await _save(file_name, status)
	track.queue_free()
	await get_tree().process_frame


func _shot_race(seed_value: int, length_id: String, file_name: String, desc: String) -> void:
	var race = RaceScript.new()
	add_child(race)
	race.build(seed_value, length_id, "picante")
	var cam := Camera3D.new()
	race.add_child(cam)
	cam.current = true
	var st: Transform3D = race.start_transform
	cam.look_at_from_position(st.origin + st.basis.z * 10.0 + Vector3(0, 5.5, 0), st.origin + st.basis.z * -6.0 + Vector3(0, 1.2, 0), Vector3.UP)
	for _i in 20:
		await get_tree().process_frame
	await _save(file_name, desc)
	race.queue_free()
	await get_tree().process_frame


func _basic_env(host: Node3D) -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, 30, 0)
	sun.light_energy = 1.5
	sun.shadow_enabled = true
	host.add_child(sun)
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#18222c")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#708090")
	env.ambient_light_energy = 0.5
	world.environment = env
	host.add_child(world)


func _participants() -> Array:
	return [
		{"profile_id": "p1", "slot": 1, "character_id": "terere"},
		{"profile_id": "p2", "slot": 2, "character_id": "jaguarete"},
	]


func _fake_result() -> Dictionary:
	return {
		"mode": "racing",
		"awarded": [
			{"profile_id": "p1", "placement": 1, "points": 5, "total_points": 5},
			{"profile_id": "p2", "placement": 2, "points": 3, "total_points": 3},
		],
	}


func _save(rel: String, desc: String) -> void:
	await get_tree().process_frame
	var img: Image = get_viewport().get_texture().get_image()
	var path := OUT.path_join(rel)
	img.save_png(path)
	print("[TRACK_ART_ASSETS_V1_CAPTURE] %s | %s | %s" % [rel, desc, path])


func _write_meta() -> void:
	var meta := {
		"godot": "4.7.2",
		"gpu": "NVIDIA GeForce RTX 2060 SUPER",
		"renderer": "forward_plus",
		"resolution": "1920x1080",
		"timestamp_utc": Time.get_datetime_string_from_system(true),
		"sprint": "TRACK_ART_ASSETS_V1",
	}
	var f := FileAccess.open(OUT.path_join("CAPTURE_META.json"), FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(meta, "\t"))
