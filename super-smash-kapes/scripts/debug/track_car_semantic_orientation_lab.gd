extends Node3D

## Side-by-side SOURCE (legacy 180° yaw) vs V3 articulated. Diagnostic only.

const VisualConfig := preload("res://scripts/track/track_car_visual_config.gd")
const VisualScript := preload("res://scripts/track/track_car_visual.gd")

const VIEWS: PackedStringArray = ["FRONT", "REAR", "LEFT", "RIGHT", "TOP", "Q3_FRONT", "Q3_REAR"]

var _cam: Camera3D
var _view_i: int = 0
var _label: Label


func _ready() -> void:
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40, -30, 0)
	light.light_energy = 1.2
	add_child(light)
	_cam = Camera3D.new()
	_cam.current = true
	add_child(_cam)
	_place_car("SourceCar", VisualConfig.SOURCE_GLB, false, Vector3(-3.2, 0, 0))
	_place_car("V3Car", VisualConfig.PROCESSED_ARTICULATED_GLB, true, Vector3(3.2, 0, 0))
	_place_labels()
	_apply_view()
	print("[TRACK_ORIENT_LAB] views=%s K=cycle" % ",".join(VIEWS))


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if event.keycode == KEY_K:
		_view_i = (_view_i + 1) % VIEWS.size()
		_apply_view()
		get_viewport().set_input_as_handled()


func _place_car(cname: String, _path: String, articulated: bool, origin: Vector3) -> void:
	var vis: Node3D = VisualScript.new()
	vis.name = cname
	vis.set("use_articulated", articulated)
	vis.set("apply_runtime_transform", true)
	vis.position = origin
	add_child(vis)


func _place_labels() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_label = Label.new()
	_label.position = Vector2(16, 12)
	_label.add_theme_font_size_override("font_size", 16)
	layer.add_child(_label)
	_world_label("SOURCE", Vector3(-3.2, 2.4, 0))
	_world_label("V3", Vector3(3.2, 2.4, 0))
	_world_label("TRACK_FORWARD -Z", Vector3(0, 2.8, -2.0))


func _world_label(text: String, pos: Vector3) -> void:
	var lab := Label3D.new()
	lab.text = text
	lab.position = pos
	lab.font_size = 42
	lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(lab)


func _apply_view() -> void:
	var view_name: String = VIEWS[_view_i]
	var pos: Vector3 = Vector3(0, 1.6, 8)
	match view_name:
		"FRONT":
			pos = Vector3(0, 1.4, -7.5)
		"REAR":
			pos = Vector3(0, 1.4, 7.5)
		"LEFT":
			pos = Vector3(-7.5, 1.4, 0)
		"RIGHT":
			pos = Vector3(7.5, 1.4, 0)
		"TOP":
			pos = Vector3(0, 10.0, 0.01)
		"Q3_FRONT":
			pos = Vector3(-5.2, 3.2, -5.2)
		"Q3_REAR":
			pos = Vector3(5.2, 3.2, 5.2)
	_cam.look_at_from_position(pos, Vector3(0, 0.6, 0), Vector3.UP)
	if _label != null:
		_label.text = "SEMANTIC ORIENTATION LAB\nVIEW %s\nLeft=SOURCE (yaw 180)  Right=V3 (authored -Z)\nK cycle view" % view_name
	print("[TRACK_ORIENT_LAB] view=%s" % view_name)
