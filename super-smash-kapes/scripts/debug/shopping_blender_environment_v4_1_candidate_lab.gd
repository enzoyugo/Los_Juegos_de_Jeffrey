extends Node3D

## SDS V4.1 asset-assisted art CANDIDATE lab. Does not replace V3 or V4.
## State: HUMAN_REVIEW_REQUIRED. Not SDS_V4_1_CANONICAL.

const ENV_V41 := "res://assets/environments/shopping_del_sol/processed/shopping_del_sol_zombies_environment_v4_1_candidate.glb"
const Probe := preload("res://scripts/debug/jeffrey_resource_probe.gd")

const VIEWPOINTS := {
	"01_spawn": [Vector3(0.0, 1.65, 28.5), Vector3(0.0, 3.4, 8.2)],
	"02_parking_left": [Vector3(-22.0, 7.2, 34.0), Vector3(0.0, 3.2, 14.0)],
	"03_parking_right": [Vector3(22.0, 7.2, 34.0), Vector3(0.0, 3.2, 14.0)],
	"04_facade_front": [Vector3(0.0, 2.4, 18.8), Vector3(0.0, 5.4, 8.2)],
	"05_facade_three_quarter": [Vector3(-14.0, 4.8, 20.0), Vector3(0.0, 5.0, 8.5)],
	"06_facade_close": [Vector3(0.0, 2.1, 13.0), Vector3(0.0, 5.0, 8.6)],
	"07_threshold": [Vector3(0.0, 1.6, 8.6), Vector3(0.0, 2.4, 6.0)],
	"08_entry_hall": [Vector3(0.0, 1.7, 4.2), Vector3(0.0, 3.2, -1.5)],
	"09_entry_hall_reverse": [Vector3(0.0, 1.7, -1.2), Vector3(0.0, 3.0, 7.5)],
	"10_atrium_ground": [Vector3(0.0, 1.75, -6.0), Vector3(0.0, 8.0, -16.0)],
	"11_atrium_upper": [Vector3(0.0, 12.4, -6.5), Vector3(0.0, 4.0, -16.0)],
	"12_mezzanine": [Vector3(0.0, 7.5, -20.4), Vector3(0.0, 3.4, -12.0)],
	"13_branch_a": [Vector3(-16.5, 1.7, -14.0), Vector3(-28.0, 2.6, -14.0)],
	"14_branch_b": [Vector3(16.5, 1.7, -14.0), Vector3(28.0, 2.6, -14.0)],
}

const VIEW_ORDER := [
	"01_spawn",
	"02_parking_left",
	"03_parking_right",
	"04_facade_front",
	"05_facade_three_quarter",
	"06_facade_close",
	"07_threshold",
	"08_entry_hall",
	"09_entry_hall_reverse",
	"10_atrium_ground",
	"11_atrium_upper",
	"12_mezzanine",
	"13_branch_a",
	"14_branch_b",
]

const LAB_PROPS := [
	{"path": "res://assets/debug/toolchain_candidates/FireHydrant.glb", "name": "LabHydrant", "pos": Vector3(-7.4, 0.0, 12.2)},
	{"path": "res://assets/debug/toolchain_candidates/ParkingMeter.glb", "name": "LabMeter", "pos": Vector3(7.6, 0.0, 13.4)},
	{"path": "res://assets/debug/toolchain_candidates/Light.glb", "name": "LabLight", "pos": Vector3(-12.5, 0.0, 22.0)},
]

@export var viewpoint: String = "01_spawn"
var _cycle: float = 0.0
var _cycle_armed: bool = false


func _ready() -> void:
	_world()
	_proxies()
	_debug_zombie_visuals()
	_load_env()
	_lab_props()
	_cycle = 0.0
	_cycle_armed = true
	var cam := Camera3D.new()
	cam.name = "ReviewCamera"
	cam.fov = 68.0
	cam.current = true
	add_child(cam)
	var pair: Array = VIEWPOINTS.get(viewpoint, VIEWPOINTS["01_spawn"])
	cam.global_position = pair[0]
	cam.look_at(pair[1], Vector3.UP)
	Probe.dump("sds_v4_1_candidate_lab", self)


func _process(delta: float) -> void:
	if not _cycle_armed:
		return
	_cycle += delta
	var i: int = 0
	if _cycle > 3.0:
		i = int((_cycle - 3.0) / 2.6) % VIEW_ORDER.size()
	var cam := get_node_or_null("ReviewCamera") as Camera3D
	if cam == null:
		return
	var pair: Array = VIEWPOINTS[VIEW_ORDER[i]]
	cam.global_position = pair[0]
	cam.look_at(pair[1], Vector3.UP)


func _world() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-16, 132, 0)
	sun.light_energy = 0.18
	sun.light_color = Color("#5c6a86")
	add_child(sun)
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#10161e")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#4e5a6c")
	env.ambient_light_energy = 0.78
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment = env
	add_child(world)
	_omni(Vector3(0, 5.6, 16.0), 2.4, 30.0, Color("#ffc070"))
	_omni(Vector3(0, 6.8, 10.2), 3.2, 18.0, Color("#ffe2a8"))
	_omni(Vector3(0, 9.6, 8.4), 2.1, 10.0, Color("#ffd060"))
	_omni(Vector3(0, 7.4, 2.0), 1.8, 16.0, Color("#fff0c8"))
	_omni(Vector3(0, 12.4, -14.0), 2.6, 24.0, Color("#dcecff"))
	_omni(Vector3(0, 8.4, -22.0), 1.6, 14.0, Color("#ffe8c0"))
	_omni(Vector3(-23.0, 5.6, -14.0), 1.3, 12.0, Color("#ffcc88"))
	_omni(Vector3(23.0, 5.6, -14.0), 1.3, 12.0, Color("#c8dcff"))
	_omni(Vector3(-12.4, 3.4, -24.8), 0.55, 6.0, Color("#ff4a32"))


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
	_box(Vector3(-23.0, -0.5, -14.0), Vector3(18, 1, 12))
	_box(Vector3(23.0, -0.5, -14.0), Vector3(18, 1, 12))


func _debug_zombie_visuals() -> void:
	## Art-only presence for review screenshots. Does not touch spawn science.
	var spots := [
		Vector3(-3.2, 1.0, 22.4),
		Vector3(4.1, 1.0, 19.6),
		Vector3(1.4, 1.0, 12.8),
		Vector3(-2.2, 1.0, 4.6),
		Vector3(6.4, 1.0, -12.2),
	]
	for i in spots.size():
		var body := MeshInstance3D.new()
		body.name = "DebugZombieVisual_%02d" % i
		var cap := CapsuleMesh.new()
		cap.radius = 0.32
		cap.height = 1.7
		body.mesh = cap
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.42, 0.48, 0.36)
		body.set_surface_override_material(0, mat)
		body.position = spots[i]
		add_child(body)


func _load_env() -> void:
	var path := ENV_V41
	if not ResourceLoader.exists(path):
		print("[SDS_V4_1_CANDIDATE_LAB] MISSING glb")
		return
	var packed: PackedScene = load(path) as PackedScene
	if packed == null:
		print("[SDS_V4_1_CANDIDATE_LAB] FAIL instantiate %s" % path)
		return
	var inst := packed.instantiate()
	inst.name = "BlenderEnvV4_1Candidate"
	add_child(inst)
	_strip(inst)
	print("[SDS_V4_1_CANDIDATE_LAB] loaded=%s HUMAN_REVIEW_REQUIRED canonical=false meshes_ok" % path)


func _lab_props() -> void:
	for item in LAB_PROPS:
		var path := str(item["path"])
		if not ResourceLoader.exists(path):
			print("[SDS_V4_1_CANDIDATE_LAB] skip missing lab prop %s" % path)
			continue
		var packed: PackedScene = load(path) as PackedScene
		if packed == null:
			continue
		var inst := packed.instantiate()
		inst.name = str(item["name"])
		inst.position = item["pos"]
		add_child(inst)


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
