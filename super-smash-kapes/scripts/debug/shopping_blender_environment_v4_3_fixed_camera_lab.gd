extends Node3D

## SDS V4.3 FIXED-CAMERA review lab. Does not modify candidate art.
## HUMAN_REVIEW_REQUIRED. Not SDS_V4_3_CANONICAL.
## Camera selection is input-driven (KEY_N), never time-cycled.

const ENV_V43 := "res://assets/environments/shopping_del_sol/processed/shopping_del_sol_zombies_environment_v4_3_candidate.glb"
const Probe := preload("res://scripts/debug/jeffrey_resource_probe.gd")

## Each name maps to exactly one (eye, target). FOV 55 unless noted in comments.
const VIEWPOINTS := {
	"01_REFERENCE_STYLE_STRAIGHT_ON": [Vector3(0.0, 4.8, 34.0), Vector3(0.0, 5.6, 9.2)],
	"02_PARKING_APPROACH": [Vector3(0.0, 3.4, 36.0), Vector3(0.0, 5.6, 9.0)],
	"03_FACADE_FRONT": [Vector3(0.0, 4.4, 30.0), Vector3(0.0, 5.8, 9.2)],
	"04_FACADE_LEFT_3Q": [Vector3(-24.0, 5.6, 32.0), Vector3(1.5, 5.2, 9.0)],
	"05_FACADE_RIGHT_3Q": [Vector3(24.0, 5.6, 32.0), Vector3(-1.5, 5.2, 9.0)],
	"06_CENTER_ARCH_CLOSE": [Vector3(0.0, 2.6, 17.5), Vector3(0.0, 5.0, 8.8)],
	"07_GLASS_AND_LOGO": [Vector3(0.0, 6.0, 16.0), Vector3(0.0, 6.4, 8.6)],
	"08_LEFT_WING": [Vector3(-13.0, 3.4, 22.0), Vector3(-12.4, 3.6, 10.4)],
	"09_RIGHT_WING": [Vector3(13.0, 3.4, 22.0), Vector3(12.4, 3.6, 10.4)],
	"10_THRESHOLD": [Vector3(0.0, 1.8, 13.2), Vector3(0.0, 3.0, 7.2)],
	"11_INTERIOR_FROM_OUTSIDE": [Vector3(0.0, 2.2, 16.0), Vector3(0.0, 4.0, 5.5)],
	"12_ENTRY_INSIDE_LOOKING_OUT": [Vector3(0.0, 2.0, 4.2), Vector3(0.0, 2.8, 10.4)],
	"13_ATRIUM_GROUND": [Vector3(0.0, 1.8, -8.5), Vector3(0.0, 3.4, -14.0)],
	"14_ATRIUM_UPPER": [Vector3(0.0, 7.4, -18.5), Vector3(0.0, 5.2, -14.0)],
}

const VIEW_ORDER := [
	"01_REFERENCE_STYLE_STRAIGHT_ON",
	"02_PARKING_APPROACH",
	"03_FACADE_FRONT",
	"04_FACADE_LEFT_3Q",
	"05_FACADE_RIGHT_3Q",
	"06_CENTER_ARCH_CLOSE",
	"07_GLASS_AND_LOGO",
	"08_LEFT_WING",
	"09_RIGHT_WING",
	"10_THRESHOLD",
	"11_INTERIOR_FROM_OUTSIDE",
	"12_ENTRY_INSIDE_LOOKING_OUT",
	"13_ATRIUM_GROUND",
	"14_ATRIUM_UPPER",
]

@export var viewpoint: String = "01_REFERENCE_STYLE_STRAIGHT_ON"
var _index: int = 0


func _ready() -> void:
	_world()
	_proxies()
	_load_env()
	var cam := Camera3D.new()
	cam.name = "ReviewCamera"
	cam.fov = 55.0
	cam.current = true
	add_child(cam)
	_index = 0
	_apply(VIEW_ORDER[0])
	set_process_unhandled_input(true)
	Probe.dump("sds_v4_3_fixed_camera_lab", self)
	print("[SDS_V4_3_FIXED_CAM] view=%s HUMAN_REVIEW_REQUIRED canonical=false" % viewpoint)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.keycode != KEY_N:
		return
	_index = mini(_index + 1, VIEW_ORDER.size() - 1)
	_apply(VIEW_ORDER[_index])
	print("[SDS_V4_3_FIXED_CAM] advance index=%d view=%s" % [_index, viewpoint])


func _apply(key: String) -> void:
	viewpoint = key
	var cam := get_node_or_null("ReviewCamera") as Camera3D
	if cam == null:
		return
	var pair: Array = VIEWPOINTS[key]
	cam.global_position = pair[0]
	cam.look_at(pair[1], Vector3.UP)


func _world() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-22, 140, 0)
	sun.light_energy = 0.28
	sun.light_color = Color("#8aa0c4")
	add_child(sun)
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#0c1420")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#3d4c62")
	env.ambient_light_energy = 0.62
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment = env
	add_child(world)
	_omni(Vector3(0, 4.4, 11.0), 1.15, 14.0, Color("#ffc070"))
	_omni(Vector3(0, 7.2, 8.4), 0.85, 8.0, Color("#ffd050"))
	_omni(Vector3(-12.4, 2.2, 11.2), 0.9, 8.0, Color("#ffb060"))
	_omni(Vector3(12.4, 2.2, 11.2), 0.7, 8.0, Color("#ffb060"))
	_omni(Vector3(-6.4, 0.4, 10.6), 0.35, 4.0, Color("#4dff4a"))
	_omni(Vector3(6.4, 0.4, 10.6), 0.25, 4.0, Color("#4dff4a"))
	_omni(Vector3(0, 11.5, -14.0), 2.0, 20.0, Color("#ffe8c0"))


func _omni(pos: Vector3, energy: float, rng: float, color: Color) -> void:
	var light := OmniLight3D.new()
	light.position = pos
	light.light_energy = energy
	light.omni_range = rng
	light.light_color = color
	add_child(light)


func _proxies() -> void:
	_box(Vector3(0, -0.5, 26.0), Vector3(48, 1, 34))
	_box(Vector3(0, -0.5, 8.9), Vector3(6.2, 1, 2.4))
	_box(Vector3(0, -0.5, -8.0), Vector3(16, 1, 28))


func _load_env() -> void:
	if not ResourceLoader.exists(ENV_V43):
		print("[SDS_V4_3_FIXED_CAM] MISSING glb")
		return
	var packed: PackedScene = load(ENV_V43) as PackedScene
	if packed == null:
		print("[SDS_V4_3_FIXED_CAM] FAIL instantiate")
		return
	var inst := packed.instantiate()
	inst.name = "BlenderEnvV4_3Candidate"
	add_child(inst)
	_strip(inst)
	print("[SDS_V4_3_FIXED_CAM] loaded=%s" % ENV_V43)


func _box(pos: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	add_child(body)


func _strip(node: Node) -> void:
	for child in node.get_children():
		_strip(child)
	if node is AnimationPlayer:
		node.queue_free()
