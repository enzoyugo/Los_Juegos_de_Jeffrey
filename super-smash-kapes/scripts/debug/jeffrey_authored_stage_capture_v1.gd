extends Node

const OUT := "E:/JeffreyAIResearch/outputs/runtime-review/jeffrey_typography_migration_v1/RENDERED_SMOKE/SMASH"
const PLAYGROUND := preload("res://scenes/core/M0Playground.tscn")

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	DirAccess.make_dir_recursive_absolute(OUT)
	for item in [["el_cuarto", "el_cuarto.png"], ["colegio_internacional", "colegio_internacional.png"]]:
		await _capture(str(item[0]), str(item[1]))
	print("JEFFREY_AUTHORED_STAGE_CAPTURE PASS")
	get_tree().quit(0)

func _capture(stage_id: String, file_name: String) -> void:
	OS.set_environment("SSK_STAGE_ID", stage_id)
	OS.set_environment("SSK_CAPTURE_STAGE_OVERRIDE", "1")
	OS.set_environment("SSK_AUTO_START_BATTLE", "1")
	var host := PLAYGROUND.instantiate()
	if host.get("match_setup") != null:
		host.match_setup.stage_id = stage_id
		host.match_setup.player_1_fighter_id = "terere"
		host.match_setup.player_2_fighter_id = "jaguarete"
	add_child(host)
	for _i in 45:
		await get_tree().process_frame
	var image := get_viewport().get_texture().get_image()
	image.save_png("%s/%s" % [OUT, file_name])
	host.queue_free()
	await get_tree().process_frame
	OS.set_environment("SSK_STAGE_ID", "")
	OS.set_environment("SSK_CAPTURE_STAGE_OVERRIDE", "")
	OS.set_environment("SSK_AUTO_START_BATTLE", "")
