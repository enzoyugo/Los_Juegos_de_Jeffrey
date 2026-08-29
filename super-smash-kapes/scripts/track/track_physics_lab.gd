class_name TrackPhysicsLab
extends Node3D

## Fixed greybox course for handling work. No procedural generator.

const Config := preload("res://scripts/track/track_config.gd")
const CAR_SCENE_PATH := "res://scenes/track/TrackCar.tscn"
const CamScript := preload("res://scripts/track/track_camera.gd")
const HudScript := preload("res://scripts/track/track_debug_hud.gd")

var _car
var _mat_cache: Dictionary = {}


func _ready() -> void:
	Config.ensure_actions()
	_place_world()
	var CarScene: PackedScene = load(CAR_SCENE_PATH) as PackedScene
	_car = CarScene.instantiate()
	add_child(_car)
	_car.global_position = Vector3(0, 1.2, 4)
	_car.control_enabled = true
	var cam = CamScript.new()
	cam.current = true
	cam.target = _car.camera_target() if _car.has_method("camera_target") else _car
	add_child(cam)
	var hud = HudScript.new()
	hud.target = _car
	hud.visible = true
	add_child(hud)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 35, 0)
	sun.light_energy = 1.2
	add_child(sun)
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#7a93a8")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#c8d4e0")
	env.ambient_light_energy = 0.55
	world.environment = env
	add_child(world)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F4:
		if _car != null and _car.has_method("set_collider_visible"):
			var debug_node = _car.get_node_or_null("ColliderDebug")
			var on := true
			if debug_node != null:
				on = not bool(debug_node.visible)
			_car.call("set_collider_visible", on)
		get_viewport().set_input_as_handled()


func _place_world() -> void:
	var w := Config.ROAD_WIDTH
	## Launch straight + braking zone
	_road_box(Vector3(0, -0.4, 28), Vector3(w, 0.8, 56), true)
	## 90-degree right
	_arc("right", Vector3(8, 0, 62), 12.0, 6, PI * 0.5)
	## Short accel
	_road_box(Vector3(18, -0.4, 72), Vector3(w, 0.8, 18), true)
	## Hairpin left
	_arc("left", Vector3(8, 0, 88), 11.0, 8, PI * 0.85)
	## Fast sweeper
	_arc("right", Vector3(-6, 0, 108), 18.0, 8, PI * 0.45)
	## S / chicane
	_road_box(Vector3(-2, -0.15, 128), Vector3(w, 0.7, 8), true)
	_road_box(Vector3(3, -0.15, 138), Vector3(w, 0.7, 8), true)
	_road_box(Vector3(-2, -0.15, 148), Vector3(w, 0.7, 8), true)
	## Drift initiation + exit
	_road_box(Vector3(0, -0.4, 168), Vector3(w, 0.8, 28), true)
	_arc("right", Vector3(10, 0, 188), 13.0, 7, PI * 0.6)
	_road_box(Vector3(22, -0.4, 204), Vector3(w, 0.8, 22), true)
	## Collision recovery corridor
	_road_box(Vector3(22, -0.4, 238), Vector3(w, 0.8, 24), true)


func _arc(kind: String, origin: Vector3, radius: float, steps: int, span: float) -> void:
	for i in range(steps):
		var t := float(i) / float(maxi(steps - 1, 1))
		var ang := lerpf(0.0, span, t)
		if kind == "left":
			ang = -ang
		var pos := origin + Vector3(sin(ang) * radius, -0.4, cos(ang) * radius)
		var xform := Transform3D(Basis.from_euler(Vector3(0, ang, 0)), pos)
		_box_at(xform, Vector3(Config.ROAD_WIDTH, 0.8, 6.5), Color("#414650"))
		_rails_at(xform, Config.ROAD_WIDTH, 6.5)


func _road_box(origin: Vector3, size: Vector3, rails: bool) -> void:
	_box(origin, size, Color("#3d424c"))
	if rails:
		var xform := Transform3D(Basis.IDENTITY, origin)
		_rails_at(xform, size.x, size.z)


func _rails_at(xform: Transform3D, width: float, length: float) -> void:
	var sh := Config.ROAD_SHOULDER
	var th := Config.GUARDRAIL_THICKNESS
	var hh := Config.GUARDRAIL_HEIGHT
	var y := 0.4 + hh * 0.5
	var left := xform * Transform3D(Basis.IDENTITY, Vector3(-(width * 0.5 + sh + th * 0.5), y, 0.0))
	var right := xform * Transform3D(Basis.IDENTITY, Vector3(width * 0.5 + sh + th * 0.5, y, 0.0))
	_box_at(left, Vector3(th, hh, length), Color("#9aa0aa"))
	_box_at(right, Vector3(th, hh, length), Color("#9aa0aa"))
	_box_at(xform * Transform3D(Basis.IDENTITY, Vector3(-(width * 0.5 + sh * 0.5), 0.02, 0.0)), Vector3(sh, 0.7, length), Color("#4d5460"))
	_box_at(xform * Transform3D(Basis.IDENTITY, Vector3(width * 0.5 + sh * 0.5, 0.02, 0.0)), Vector3(sh, 0.7, length), Color("#4d5460"))


func _box(origin: Vector3, size: Vector3, color: Color) -> void:
	_box_at(Transform3D(Basis.IDENTITY, origin), size, color)


func _shared_color(color: Color) -> StandardMaterial3D:
	var key := color.to_html(true)
	if _mat_cache.has(key):
		return _mat_cache[key]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	_mat_cache[key] = mat
	return mat


func _box_at(xform: Transform3D, size: Vector3, color: Color) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.transform = xform
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.set_surface_override_material(0, _shared_color(color))
	body.add_child(mesh)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	add_child(body)
