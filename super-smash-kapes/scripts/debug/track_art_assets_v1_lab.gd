extends Node3D

## Track Art Assets V1 lab — bake runtime meshes, showcase promotions, HUD chrome.

const KitScript := preload("res://scripts/track/track_environment_kit_v1.gd")
const RuntimeMeshes := preload("res://scripts/track/track_env_runtime_meshes_v1.gd")
const RaceScript := preload("res://scripts/track/track_race.gd")
const Chrome := preload("res://scripts/track/track_hud_chrome_v1.gd")
const Layout := preload("res://scripts/ui/jeffrey/global_ui_layout.gd")

var _label: Label


func _ready() -> void:
	OS.set_environment("SSK_PERF_DIAG", "1")
	OS.set_environment("SSK_TRACK_ENV_DIAG", "1")
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	_lights()
	_hud()
	var runtime = RuntimeMeshes.new()
	var bake: Dictionary = runtime.bake_all_to_disk()
	print("[TRACK_ART_BAKE] %s" % JSON.stringify(bake))
	var kit = KitScript.new()
	var row := Node3D.new()
	row.position = Vector3(-50, 0, 12)
	add_child(row)
	kit.showcase_row(row)
	print("[TRACK_ART_PROMOTE] %s" % JSON.stringify(kit.promotion_report))
	var race = RaceScript.new()
	add_child(race)
	race.build(424242, "media", "picante")
	var cam := Camera3D.new()
	add_child(cam)
	cam.current = true
	cam.look_at_from_position(Vector3(8, 7, 16), Vector3(0, 2, 0), Vector3.UP)
	## HUD chrome sample overlay
	var layer := CanvasLayer.new()
	add_child(layer)
	var frame = Chrome.make_timer_frame()
	layer.add_child(frame)
	frame.position = Vector2(700, 24)
	frame.custom_minimum_size = Vector2(480, 110)
	var col := VBoxContainer.new()
	frame.add_child(col)
	col.add_child(Layout.outlined_label("TRACK", 15, Color("#3db8c9"), HORIZONTAL_ALIGNMENT_CENTER))
	col.add_child(Layout.outlined_label("0:12.34", 36, Color("#3db8c9"), HORIZONTAL_ALIGNMENT_CENTER))
	col.add_child(Layout.outlined_label("MEJOR  0:11.90", 13, Color("#8b93a7"), HORIZONTAL_ALIGNMENT_CENTER))
	call_deferred("_pass", bake, kit, race)


func _lights() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, 28, 0)
	sun.light_energy = 1.5
	sun.shadow_enabled = true
	add_child(sun)
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#18222c")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#708090")
	env.ambient_light_energy = 0.5
	world.environment = env
	add_child(world)


func _hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_label = Label.new()
	_label.position = Vector2(20, 20)
	_label.add_theme_font_size_override("font_size", 16)
	layer.add_child(_label)


func _pass(bake: Dictionary, kit, race) -> void:
	var inv: Dictionary = race.inventory_counts()
	var env: Dictionary = race.environment_stats()
	var text := "[TRACK_ART_ASSETS_V1_LAB]\n"
	text += "bake_ok=%d bake_fail=%d\n" % [bake.get("ok", []).size(), bake.get("fail", []).size()]
	text += "promoted=%s\n" % JSON.stringify(kit.promotion_report.get("promoted", []))
	text += "nodes=%d multimesh=%d\n" % [int(inv.get("total", 0)), int(inv.get("multimesh", 0))]
	text += "env=%s\n" % JSON.stringify(env)
	text += "PASS"
	_label.text = text
	print(text)
	print("[TRACK_ART_ASSETS_V1_LAB] PASS")
