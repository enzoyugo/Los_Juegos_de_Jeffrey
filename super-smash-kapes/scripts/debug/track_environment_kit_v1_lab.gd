extends Node3D

## Track Environment Kit V1 lab — kit showcase + zone demos + MultiMesh stats.
## Run: Godot --path . --display-driver windows --rendering-method forward_plus
##   --rendering-driver d3d12 --gpu-index 0 res://scenes/debug/TrackEnvironmentKitV1Lab.tscn

const KitScript := preload("res://scripts/track/track_environment_kit_v1.gd")
const PlacerScript := preload("res://scripts/track/track_environment_placer_v1.gd")
const RaceScript := preload("res://scripts/track/track_race.gd")
const Layout := preload("res://scripts/ui/jeffrey/global_ui_layout.gd")

var _label: Label
var _race


func _ready() -> void:
	OS.set_environment("SSK_TRACK_ENV_DIAG", "1")
	OS.set_environment("SSK_PERF_DIAG", "1")
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	_build_lights()
	_build_hud()
	var kit = KitScript.new()
	var showcase := Node3D.new()
	showcase.name = "KitShowcase"
	showcase.position = Vector3(-40, 0, 20)
	add_child(showcase)
	kit.showcase_row(showcase, Vector3.ZERO)

	_race = RaceScript.new()
	add_child(_race)
	_race.position = Vector3(0, 0, -8)
	_race.build(424242, "media", "picante")

	var cam := Camera3D.new()
	cam.current = true
	add_child(cam)
	cam.position = Vector3(0, 8, 18)
	cam.look_at(Vector3(0, 2, 0))

	call_deferred("_report")


func _build_lights() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, 28, 0)
	sun.light_energy = 1.5
	sun.shadow_enabled = true
	add_child(sun)
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#1a2430")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#6a7a88")
	env.ambient_light_energy = 0.45
	world.environment = env
	add_child(world)


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 18)
	_label.position = Vector2(24, 24)
	layer.add_child(_label)


func _report() -> void:
	var inv: Dictionary = _race.inventory_counts() if _race != null else {}
	var env_stats: Dictionary = _race.environment_stats() if _race != null else {}
	var text := "[TRACK_ENV_KIT_V1_LAB]\n"
	text += "kit_pieces=%s\n" % ",".join(PackedStringArray(KitScript.new().piece_names()))
	text += "nodes=%d multimesh=%d\n" % [int(inv.get("total", 0)), int(inv.get("multimesh", 0))]
	text += "env=%s\n" % JSON.stringify(env_stats)
	text += "toggle: SSK_TRACK_SCENERY=0 disables live scenery\n"
	text += "PASS"
	_label.text = text
	print(text)
	print("[TRACK_ENV_KIT_V1_LAB] PASS")
