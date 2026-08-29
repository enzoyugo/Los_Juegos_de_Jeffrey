extends Node3D

## Track Visual Quality V2 lab — palette, signage, facades, road, HUD chips.

const KitScript := preload("res://scripts/track/track_environment_kit_v1.gd")
const RaceScript := preload("res://scripts/track/track_race.gd")
const VQ := preload("res://scripts/track/track_visual_quality_v2.gd")
const Chrome := preload("res://scripts/track/track_hud_chrome_v1.gd")
const Layout := preload("res://scripts/ui/jeffrey/global_ui_layout.gd")

var _label: Label


func _ready() -> void:
	OS.set_environment("SSK_PERF_DIAG", "1")
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	var vq = VQ.shared()
	_lights()
	_hud_sample()
	## Building material row
	var row := Node3D.new()
	row.position = Vector3(-40, 0, 18)
	add_child(row)
	for i in 8:
		var mi := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(4.5, 6.0, 4.0)
		mi.mesh = box
		mi.position = Vector3(i * 6.5, 3.0, 0)
		mi.material_override = vq.building_material(i)
		row.add_child(mi)
	## Signage boards
	for i in 8:
		var board := MeshInstance3D.new()
		var face := BoxMesh.new()
		face.size = Vector3(3.2, 1.8, 0.12)
		board.mesh = face
		board.position = Vector3(i * 6.5, 7.5, -3)
		board.material_override = vq.signage_material(i)
		row.add_child(board)
	var kit = KitScript.new()
	kit.showcase_row(row, Vector3(0, 0, 14))
	## Live track sample
	var race = RaceScript.new()
	add_child(race)
	race.build(424242, "media", "picante")
	var cam := Camera3D.new()
	add_child(cam)
	cam.current = true
	cam.look_at_from_position(Vector3(6, 5.5, 14), Vector3(0, 1.2, -4), Vector3.UP)
	## Gantry demo near camera
	vq.attach_start_finish_gantry(self, Transform3D(Basis.IDENTITY, Vector3(0, 0, 2)), false)
	vq.attach_checkpoint_markers(self, Transform3D(Basis.IDENTITY, Vector3(8, 0, 2)), false)
	call_deferred("_pass", vq, race)


func _lights() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42, 36, 0)
	sun.light_energy = 1.6
	sun.light_color = Color("#ffe6c8")
	sun.shadow_enabled = true
	add_child(sun)
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#1a2218")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#809070")
	env.ambient_light_energy = 0.45
	world.environment = env
	add_child(world)


func _hud_sample() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_label = Label.new()
	_label.position = Vector2(20, 20)
	_label.add_theme_font_size_override("font_size", 15)
	layer.add_child(_label)
	var chip = Chrome.make_side_chip()
	layer.add_child(chip)
	chip.position = Vector2(20, 200)
	chip.add_child(Layout.outlined_label("P1  ·  TERERÉ", 14, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT))
	var hint = Chrome.make_hint_strip()
	layer.add_child(hint)
	hint.position = Vector2(520, 1000)
	hint.custom_minimum_size = Vector2(880, 36)
	hint.add_child(Layout.outlined_label("W acelera   A/D dirige   Shift drift   Esc pausa", 12, Color("#8b93a7"), HORIZONTAL_ALIGNMENT_CENTER))


func _pass(vq, race) -> void:
	var inv: Dictionary = race.inventory_counts()
	var ok := vq.signage_texture() != null and vq.facade_texture() != null
	var text := "[TRACK_VISUAL_QUALITY_V2_LAB]\n"
	text += "signage=%s facade=%s\n" % [str(vq.signage_texture() != null), str(vq.facade_texture() != null)]
	text += "nodes=%d multimesh=%d\n" % [int(inv.get("total", 0)), int(inv.get("multimesh", 0))]
	text += "PASS" if ok else "FAIL"
	_label.text = text
	print(text)
	if ok:
		print("[TRACK_VISUAL_QUALITY_V2_LAB] PASS")
	else:
		print("[TRACK_VISUAL_QUALITY_V2_LAB] FAIL")
