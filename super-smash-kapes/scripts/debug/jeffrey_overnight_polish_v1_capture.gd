extends Node

## Overnight polish capture — Track surface + Copa + Zombies presentation.

const TrackMainScript := preload("res://scripts/track/track_main.gd")
const COPA_RESULTS := preload("res://scripts/ui/jeffrey/copa_jeffrey_results_screen.gd")
const COPA_BOARD := preload("res://scripts/ui/jeffrey/copa_jeffrey_scoreboard_screen.gd")
const VQ := preload("res://scripts/track/track_visual_quality_v2.gd")
const Layout := preload("res://scripts/ui/jeffrey/global_ui_layout.gd")
const ZBanner := preload("res://scripts/ui/jeffrey/zombies_result_banner_v1.gd")

const OUT := "E:/JeffreyAIResearch/outputs/runtime-review/jeffrey_overnight_polish_v1"
const TRACK_OUT := "E:/JeffreyAIResearch/outputs/runtime-review/track_world_surface_v1"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	OS.set_environment("SSK_PERF_DIAG", "1")
	call_deferred("_run")


func _run() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	await get_tree().process_frame
	for d in [OUT, TRACK_OUT, OUT + "/01_track", OUT + "/02_copa", OUT + "/03_zombies", OUT + "/04_shell", OUT + "/05_perf"]:
		DirAccess.make_dir_recursive_absolute(d)
	var vq = VQ.shared()
	print("[OVERNIGHT] asphalt=%s ground=%s signage=%s" % [
		str(vq.mat("road").albedo_texture != null),
		str(vq.mat("ground").albedo_texture != null),
		str(vq.signage_texture() != null),
	])
	print("[OVERNIGHT_AUDIO] has_pack=%s inv=%s" % [
		str(preload("res://scripts/ui/jeffrey/global_ui_audio.gd").has_pack()),
		JSON.stringify(preload("res://scripts/ui/jeffrey/global_ui_audio.gd").inventory()),
	])

	await _track_shots()
	await _copa_shots()
	await _zombies_shots()
	_write_meta()
	print("[JEFFREY_OVERNIGHT_POLISH_V1_CAPTURE] PASS root=%s" % OUT)
	get_tree().quit()


func _track_shots() -> void:
	var track = TrackMainScript.new()
	track.setup(_participants(), 424242)
	add_child(track)
	await get_tree().process_frame
	await get_tree().process_frame
	await _save(TRACK_OUT + "/01_entry.png", "entry")
	await _save(OUT + "/01_track/01_entry.png", "entry")
	if track.has_method("_on_play"):
		track.call("_on_play", "media", "picante")
	for _i in 25:
		await get_tree().process_frame
	await _save(TRACK_OUT + "/02_start.png", "start")
	await _save(TRACK_OUT + "/12_hud.png", "hud")
	await _save(OUT + "/01_track/02_start.png", "start")
	for _i in 50:
		await get_tree().process_frame
	await _save(TRACK_OUT + "/03_asphalt_close.png", "asphalt")
	await _save(TRACK_OUT + "/04_urban.png", "urban")
	await _save(TRACK_OUT + "/08_corner.png", "corner")
	await _save(TRACK_OUT + "/09_speed.png", "speed")
	await _save(OUT + "/01_track/04_urban.png", "urban")
	track.queue_free()
	await get_tree().process_frame
	await _shot_seed(777001, TRACK_OUT + "/06_green.png")
	await _shot_seed(900042, TRACK_OUT + "/05_commercial.png")
	await _shot_seed(555001, TRACK_OUT + "/07_open.png")
	## Checkpoint / finish flash
	var t2 = TrackMainScript.new()
	t2.setup(_participants(), 424242)
	add_child(t2)
	await get_tree().process_frame
	if t2.has_method("_on_play"):
		t2.call("_on_play", "media", "picante")
	for _i in 20:
		await get_tree().process_frame
	for c in t2.get_children():
		if c is CanvasLayer and c.has_method("flash_checkpoint"):
			c.flash_checkpoint(3, 13)
			await get_tree().process_frame
			await _save(TRACK_OUT + "/10_checkpoint.png", "cp")
			c.flash_finish(34.5)
			await get_tree().process_frame
			await _save(TRACK_OUT + "/11_finish.png", "fin")
			break
	t2.queue_free()
	await get_tree().process_frame
	var results = COPA_RESULTS.new()
	add_child(results)
	Layout.bind_full(results)
	results.setup(_fake_result())
	await get_tree().process_frame
	await _save(TRACK_OUT + "/13_results.png", "results")
	await _save(OUT + "/01_track/13_results.png", "results")
	results.queue_free()


func _copa_shots() -> void:
	var board = COPA_BOARD.new()
	add_child(board)
	Layout.bind_full(board)
	await get_tree().process_frame
	await get_tree().process_frame
	await _save(OUT + "/02_copa/01_scoreboard_podium.png", "copa podium")
	board.queue_free()


func _zombies_shots() -> void:
	var root := Control.new()
	add_child(root)
	Layout.bind_full(root)
	var wash := ColorRect.new()
	wash.color = Color(0.02, 0.05, 0.03, 1)
	Layout.bind_full(wash)
	root.add_child(wash)
	var banner = ZBanner.make()
	root.add_child(banner)
	Layout.apply_frac(banner, 0.28, 0.28, 0.44, 0.28)
	ZBanner.fill(banner, 4, 27)
	await get_tree().process_frame
	await _save(OUT + "/03_zombies/01_result_banner.png", "zombies banner")
	root.queue_free()


func _shot_seed(seed_value: int, path: String) -> void:
	var track = TrackMainScript.new()
	track.setup(_participants(), seed_value)
	add_child(track)
	await get_tree().process_frame
	if track.has_method("_on_play"):
		track.call("_on_play", "media", "picante")
	for _i in 35:
		await get_tree().process_frame
	await _save(path, path.get_file())
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


func _save(path: String, note: String) -> void:
	await get_tree().process_frame
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png(path)
	print("[OVERNIGHT_SHOT] %s (%s)" % [path.get_file(), note])


func _write_meta() -> void:
	var f := FileAccess.open("%s/CAPTURE_META.json" % OUT, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({
			"sprint": "JEFFREY_OVERNIGHT_POLISH_V1",
			"resolution": "1920x1080",
			"gpu": "RTX 2060 SUPER",
		}, "\t"))
		f.close()
