extends Node3D

## Developer lab — Jaguareté offline-baked idle.
## 1 = bind pose (stop animation) | 2 = baked idle

const VISUAL_SCRIPT := preload("res://fighters/jaguarete/jaguarete_rigged_visual.gd")

var _visual
var _status: Label


func _ready() -> void:
	_build_environment()
	_visual = VISUAL_SCRIPT.new()
	_visual.name = "JaguareteRiggedVisual"
	add_child(_visual)
	_status = Label.new()
	_status.name = "LabStatus"
	_status.position = Vector2(24, 24)
	_status.add_theme_font_size_override("font_size", 22)
	add_child(_make_canvas(_status))
	call_deferred("_refresh_status")


func _make_canvas(control: Control) -> CanvasLayer:
	var layer := CanvasLayer.new()
	layer.layer = 20
	layer.add_child(control)
	return layer


func _build_environment() -> void:
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-42, 35, 0)
	light.light_energy = 1.15
	add_child(light)
	var cam := Camera3D.new()
	add_child(cam)
	cam.position = Vector3(0.0, 2.2, 7.5)
	cam.look_at(Vector3(0.0, 1.4, 0.0), Vector3.UP)
	cam.current = true
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(20, 20)
	floor_mesh.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.12, 0.14, 0.18)
	floor_mesh.material_override = mat
	add_child(floor_mesh)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match (event as InputEventKey).keycode:
		KEY_1:
			if _visual != null and _visual.get("animation_player"):
				var p: AnimationPlayer = _visual.animation_player
				if p != null:
					p.stop()
		KEY_2:
			if _visual != null and _visual.has_method("play_idle"):
				_visual.play_idle(true)
		KEY_R:
			if _visual != null and _visual.has_method("play_idle"):
				_visual.play_idle(true)
	_refresh_status()


func _refresh_status() -> void:
	if _status == null or _visual == null:
		return
	var model := "?"
	var skel := "MISSING"
	var bones := 0
	var anim := "NONE"
	var source := "NONE"
	var retarget := "OFF"
	var fallback := "NO"
	if _visual.has_method("get_model_label"):
		model = str(_visual.get_model_label())
	if _visual.has_method("get_skeleton"):
		var sk = _visual.get_skeleton()
		if sk != null:
			skel = "FOUND"
			bones = sk.get_bone_count()
	if _visual.has_method("get_animation_source"):
		source = str(_visual.get_animation_source())
	if _visual.has_method("get_retarget_mode"):
		retarget = str(_visual.get_retarget_mode())
	if _visual.has_method("is_using_fallback") and _visual.is_using_fallback():
		fallback = "YES"
		model = "FALLBACK"
	if source == "BAKED":
		anim = "idle"
	_status.text = (
		"MODEL: %s | SKELETON: %s (%d) | ANIMATION: %s | SOURCE: %s | "
		+ "RUNTIME RETARGET: %s | FALLBACK: %s | [1] bind [2] baked idle"
		% [model, skel, bones, anim, source, retarget, fallback]
	)
