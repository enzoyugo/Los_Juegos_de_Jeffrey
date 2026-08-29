extends Node3D

## SDS V4.3 reference-locked Tripo reconstruction CANDIDATE. Does not replace V3/V4/V4.1/V4.2.
## HUMAN_REVIEW_REQUIRED. Not SDS_V4_3_CANONICAL.
## Cameras stay on facade_front until hold elapses, then advance one named view per interval.

const ENV_V43 := "res://assets/environments/shopping_del_sol/processed/shopping_del_sol_zombies_environment_v4_3_candidate.glb"
const Probe := preload("res://scripts/debug/jeffrey_resource_probe.gd")

const VIEWPOINTS := {
	"01_parking_approach": [Vector3(0.0, 3.4, 36.0), Vector3(0.0, 5.6, 9.0)],
	"02_facade_front": [Vector3(0.0, 4.4, 30.0), Vector3(0.0, 5.8, 9.2)],
	"03_three_quarter_left": [Vector3(-24.0, 5.6, 32.0), Vector3(1.5, 5.2, 9.0)],
	"04_three_quarter_right": [Vector3(24.0, 5.6, 32.0), Vector3(-1.5, 5.2, 9.0)],
	"05_facade_close": [Vector3(0.0, 2.6, 17.5), Vector3(0.0, 5.0, 8.8)],
	"06_threshold": [Vector3(0.0, 1.8, 13.2), Vector3(0.0, 3.0, 7.2)],
	"07_interior_from_outside": [Vector3(0.0, 2.2, 16.0), Vector3(0.0, 4.0, 5.5)],
}

const VIEW_ORDER := [
	"03_three_quarter_left",
	"04_three_quarter_right",
	"05_facade_close",
	"01_parking_approach",
	"06_threshold",
	"07_interior_from_outside",
]

@export var viewpoint: String = "02_facade_front"
var _cycle: float = 0.0
var _armed: bool = false


func _ready() -> void:
	_world()
	_proxies()
	_load_env()
	_armed = true
	_cycle = 0.0
	var cam := Camera3D.new()
	cam.name = "ReviewCamera"
	cam.fov = 55.0
	cam.current = true
	add_child(cam)
	_apply("02_facade_front")
	Probe.dump("sds_v4_3_candidate_lab", self)


func _process(delta: float) -> void:
	if not _armed:
		return
	_cycle += delta
	if _cycle <= 8.0:
		_apply("02_facade_front")
		return
	var i := int((_cycle - 8.0) / 3.2) % VIEW_ORDER.size()
	_apply(VIEW_ORDER[i])


func _apply(key: String) -> void:
	var cam := get_node_or_null("ReviewCamera") as Camera3D
	if cam == null:
		return
	var pair: Array = VIEWPOINTS.get(key, VIEWPOINTS["02_facade_front"])
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
		print("[SDS_V4_3_CANDIDATE_LAB] MISSING glb")
		return
	var packed: PackedScene = load(ENV_V43) as PackedScene
	if packed == null:
		print("[SDS_V4_3_CANDIDATE_LAB] FAIL instantiate")
		return
	var inst := packed.instantiate()
	inst.name = "BlenderEnvV4_3Candidate"
	add_child(inst)
	_strip(inst)
	print("[SDS_V4_3_CANDIDATE_LAB] loaded=%s HUMAN_REVIEW_REQUIRED canonical=false" % ENV_V43)


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
