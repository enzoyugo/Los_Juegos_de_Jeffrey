extends Node

## Capture Zombies menu + loading at 1920x1080 and 1280x720. Presentation only.

const MENU := preload("res://scripts/ui/jeffrey/zombies_menu_screen.gd")
const LOADING := preload("res://scripts/ui/jeffrey/zombies_loading_screen.gd")
const Layout := preload("res://scripts/ui/jeffrey/global_ui_layout.gd")
const ZAssets := preload("res://scripts/ui/jeffrey/zombies_ui_assets.gd")

const OUT_DIR := "res://docs/generated/zombies_ui_v1"
const SIZES := [
	Vector2i(1920, 1080),
	Vector2i(1280, 720),
]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_run")


func _run() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	for path in ZAssets.expected_paths():
		if not ResourceLoader.exists(path) and not FileAccess.file_exists(path):
			push_error("[ZOMBIES_UI_CAPTURE] missing %s" % path)
			get_tree().quit(1)
			return
	for size in SIZES:
		DisplayServer.window_set_size(size)
		await get_tree().process_frame
		await get_tree().process_frame
		var menu = MENU.new()
		await _capture(menu, "zombies_menu_%dx%d" % [size.x, size.y])
		var loading = LOADING.new()
		add_child(loading)
		Layout.bind_full(loading)
		loading.freeze_for_capture(0.85)
		await get_tree().process_frame
		await get_tree().process_frame
		_save("zombies_loading_%dx%d" % [size.x, size.y])
		loading.queue_free()
		await get_tree().process_frame
	print("[ZOMBIES_UI_CAPTURE] wrote %s" % OUT_DIR)
	print("JEFFREY_ZOMBIES_UI_ASSET_INTEGRATION_V1_CAPTURE_OK")
	get_tree().quit(0)


func _capture(screen: Control, name: String) -> void:
	add_child(screen)
	Layout.bind_full(screen)
	await get_tree().process_frame
	await get_tree().process_frame
	_save(name)
	screen.queue_free()
	await get_tree().process_frame


func _save(name: String) -> void:
	var image := get_viewport().get_texture().get_image()
	if image == null:
		push_error("[ZOMBIES_UI_CAPTURE] no viewport image for %s" % name)
		return
	var path := "%s/%s.png" % [OUT_DIR, name]
	image.save_png(path)
	print("[ZOMBIES_UI_CAPTURE] %s" % path)
