extends Node

## Track Visual Quality V2 capture — 1920×1080 RTX Forward+.

const TrackMainScript := preload("res://scripts/track/track_main.gd")
const COPA_RESULTS := preload("res://scripts/ui/jeffrey/copa_jeffrey_results_screen.gd")
const VQ := preload("res://scripts/track/track_visual_quality_v2.gd")
const Layout := preload("res://scripts/ui/jeffrey/global_ui_layout.gd")

const OUT := "E:/JeffreyAIResearch/outputs/runtime-review/track_visual_quality_v2"


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
	var vq = VQ.shared()
	print("[TRACK_VQ2] signage=%s facade=%s" % [str(vq.signage_texture() != null), str(vq.facade_texture() != null)])

	await _capture_lab()
	await _capture_entry_and_race()
	await _capture_zones()
	await _capture_results()
	await _hud_status_shot("10_checkpoint.png", false)
	await _hud_status_shot("12_finish.png", true)

	print("[TRACK_VISUAL_QUALITY_V2_CAPTURE] PASS root=%s" % OUT)
	get_tree().quit()


func _capture_lab() -> void:
	## Inline lab composition for screenshot stability.
	var host := Node3D.new()
	add_child(host)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42, 36, 0)
	sun.light_energy = 1.6
	host.add_child(sun)
	var vq = VQ.shared()
	for i in 8:
		var mi := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(4.5, 6.0, 4.0)
		mi.mesh = box
		mi.position = Vector3(i * 6.5 - 24, 3.0, 0)
		mi.material_override = vq.building_material(i)
		host.add_child(mi)
		var board := MeshInstance3D.new()
		var face := BoxMesh.new()
		face.size = Vector3(3.2, 1.8, 0.12)
		board.mesh = face
		board.position = Vector3(i * 6.5 - 24, 7.5, -3)
		board.material_override = vq.signage_material(i)
		host.add_child(board)
	vq.attach_start_finish_gantry(host, Transform3D(Basis.IDENTITY, Vector3(0, 0, 6)), true)
	var cam := Camera3D.new()
	host.add_child(cam)
	cam.current = true
	cam.look_at_from_position(Vector3(0, 10, 22), Vector3(0, 3, 0), Vector3.UP)
	await get_tree().process_frame
	await get_tree().process_frame
	await _save("14_art_lab.png", "VQ2 art lab")
	host.queue_free()
	await get_tree().process_frame


func _capture_entry_and_race() -> void:
	var track = TrackMainScript.new()
	track.setup(_participants(), 424242)
	add_child(track)
	await get_tree().process_frame
	await get_tree().process_frame
	await _save("01_track_entry.png", "Track entry V2")
	if track.has_method("_on_play"):
		track.call("_on_play", "media", "picante")
	for _i in 20:
		await get_tree().process_frame
	await _save("02_start_line.png", "Start gantry")
	await _save("09_countdown.png", "Countdown")
	for _i in 45:
		await get_tree().process_frame
	await _save("08_hud.png", "HUD V2")
	await _save("03_urban_straight.png", "Urban straight")
	await _save("11_midrace.png", "Midrace")
	for _i in 60:
		await get_tree().process_frame
	await _save("04_urban_corner.png", "Corner")
	track.queue_free()
	await get_tree().process_frame


func _capture_zones() -> void:
	await _shot_race(777001, "media", "06_green.png", "Green zone")
	await _shot_race(900042, "larga", "05_commercial.png", "Commercial")
	await _shot_race(555001, "media", "07_open.png", "Open horizon")


func _capture_results() -> void:
	var results = COPA_RESULTS.new()
	add_child(results)
	Layout.bind_full(results)
	results.setup(_fake_result())
	await get_tree().process_frame
	await _save("13_results.png", "Track results compact")
	results.queue_free()
	await get_tree().process_frame


func _hud_status_shot(file_name: String, finish: bool) -> void:
	var track = TrackMainScript.new()
	track.setup(_participants(), 424242)
	add_child(track)
	await get_tree().process_frame
	if track.has_method("_on_play"):
		track.call("_on_play", "media", "picante")
	for _i in 25:
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
	await get_tree().process_frame
	await get_tree().process_frame
	await _save(file_name, file_name)
	track.queue_free()
	await get_tree().process_frame


func _shot_race(seed_value: int, length_id: String, file_name: String, note: String) -> void:
	var track = TrackMainScript.new()
	track.setup(_participants(), seed_value)
	add_child(track)
	await get_tree().process_frame
	if track.has_method("_on_play"):
		track.call("_on_play", length_id, "picante")
	for _i in 40:
		await get_tree().process_frame
	await _save(file_name, note)
	track.queue_free()
	await get_tree().process_frame


func _participants() -> Array:
	return [
		{"profile_id": "p1", "character_id": "terere", "player_slot": 1, "display_name": "P1"},
		{"profile_id": "p2", "character_id": "gallo", "player_slot": 2, "display_name": "P2"},
	]


func _fake_result() -> Dictionary:
	return {
		"mode": "racing",
		"awarded": [
			{"profile_id": "p1", "placement": 1, "points": 5, "total_points": 5},
			{"profile_id": "p2", "placement": 2, "points": 3, "total_points": 3},
		],
	}


func _save(file_name: String, note: String) -> void:
	await get_tree().process_frame
	var img: Image = get_viewport().get_texture().get_image()
	var path := "%s/%s" % [OUT, file_name]
	img.save_png(path)
	print("[TRACK_VQ2_SHOT] %s (%s)" % [file_name, note])


func _write_meta() -> void:
	var f := FileAccess.open("%s/CAPTURE_META.json" % OUT, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({
			"sprint": "TRACK_VISUAL_QUALITY_V2",
			"resolution": "1920x1080",
			"renderer": "forward_plus/d3d12",
		}, "\t"))
		f.close()
