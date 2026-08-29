extends Node3D

## V2 vs V3 articulated integrity. Isolate Body/wheels. Spin stress. No gameplay.

const VisualConfig := preload("res://scripts/track/track_car_visual_config.gd")
const VisualScript := preload("res://scripts/track/track_car_visual.gd")

var _v2: Node
var _v3: Node
var _show_v2: bool = false
var _spin: float = 0.0
var _spin_on: bool = false
var _label: Label
var _cam: Camera3D
var _view_i: int = 0
var _iso: String = "all"


func _ready() -> void:
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-42, -28, 0)
	add_child(light)
	_cam = Camera3D.new()
	_cam.current = true
	add_child(_cam)
	_cam.look_at_from_position(Vector3(3.8, 2.2, 5.4), Vector3(0, 0.5, 0), Vector3.UP)
	_v2 = _make_visual("V2", true, VisualConfig.PROCESSED_ARTICULATED_V2_GLB, Vector3(-3.4, 0, 0))
	_v3 = _make_visual("V3", true, VisualConfig.PROCESSED_ARTICULATED_GLB, Vector3(3.4, 0, 0))
	_apply_iso()
	_hud()
	print("[TRACK_INTEGRITY_LAB] 1-5 isolate 6 rest 7 steer 8 spin 9 susp 0 full  K cam  V v2/v3")


func _make_visual(vname: String, articulated: bool, path: String, origin: Vector3) -> Node:
	var vis: Node = VisualScript.new()
	vis.name = vname
	vis.set("articulated_override_path", path)
	vis.set("use_articulated", articulated)
	vis.set("apply_runtime_transform", true)
	(vis as Node3D).position = origin
	add_child(vis)
	return vis


func _hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_label = Label.new()
	_label.position = Vector2(14, 10)
	_label.add_theme_font_size_override("font_size", 15)
	layer.add_child(_label)
	_refresh_hud()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_1:
			_iso = "Body"; _apply_iso()
		KEY_2:
			_iso = "Wheel_FL"; _apply_iso()
		KEY_3:
			_iso = "Wheel_FR"; _apply_iso()
		KEY_4:
			_iso = "Wheel_RL"; _apply_iso()
		KEY_5:
			_iso = "Wheel_RR"; _apply_iso()
		KEY_6:
			_iso = "all"; _spin_on = false; _pose(0.0, 0.0, 0.0)
		KEY_7:
			_iso = "all"; _spin_on = false; _pose(0.44, 0.0, 0.0)
		KEY_8:
			_iso = "wheels"; _spin_on = true
		KEY_9:
			_iso = "all"; _spin_on = false; _pose(0.0, 0.0, 0.08)
		KEY_0:
			_iso = "all"; _spin_on = false; _pose(0.35, 1.2, 0.06)
		KEY_K:
			_view_i = (_view_i + 1) % 4
			_apply_cam()
		KEY_V:
			_show_v2 = not _show_v2
			if _v2 is Node3D:
				(_v2 as Node3D).visible = _show_v2
	_refresh_hud()
	get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if _spin_on:
		_spin += delta * 8.0
		_pose(0.0, _spin, 0.0)


func _pose(steer: float, spin: float, susp: float) -> void:
	var wheel_ids: PackedStringArray = ["FL", "FR", "RL", "RR"]
	for vis in [_v3, _v2]:
		if vis == null or not vis.has_method("debug_apply_wheel_pose"):
			continue
		for wid in wheel_ids:
			var front_steer: float = steer if wid.begins_with("F") else 0.0
			vis.call("debug_apply_wheel_pose", wid, front_steer, spin, susp)


func _apply_iso() -> void:
	var names: PackedStringArray = ["Body", "Wheel_FL", "Wheel_FR", "Wheel_RL", "Wheel_RR"]
	for vis in [_v3, _v2]:
		if vis == null or not vis.has_method("set_named_visible"):
			continue
		for n in names:
			var on: bool = _iso == "all" or _iso == n or (_iso == "wheels" and n.begins_with("Wheel_"))
			vis.call("set_named_visible", n, on)
	_refresh_hud()


func _apply_cam() -> void:
	var positions: Array[Vector3] = [
		Vector3(3.8, 2.2, 5.4),
		Vector3(0, 1.6, -7.2),
		Vector3(7.5, 1.6, 0),
		Vector3(0, 9.5, 0.2),
	]
	_cam.look_at_from_position(positions[_view_i], Vector3(0, 0.5, 0), Vector3.UP)


func _refresh_hud() -> void:
	if _label == null:
		return
	_label.text = "ARTICULATED INTEGRITY LAB\nV3 right  V2 left (V toggle %s)\niso=%s spin=%s\n1 Body 2 FL 3 FR 4 RL 5 RR  6 rest 7 steer 8 spin 9 susp 0 full\nK camera" % [
		"V2 ON" if _show_v2 else "V2 hidden",
		_iso,
		"ON" if _spin_on else "off",
	]
