extends Node3D

## SDS V4 structural-identity CANDIDATE lab. Does not replace V3 canonical.
## State: HUMAN_REVIEW_REQUIRED. Not SDS_V4_CANONICAL.

const ENV_V4 := "res://assets/environments/zombies/shopping_del_sol/runtime/shopping_del_sol_v4_candidate.glb"
const ENV_V3 := "res://assets/environments/shopping_del_sol/processed/shopping_del_sol_zombies_environment_v3.glb"
const Probe := preload("res://scripts/debug/jeffrey_resource_probe.gd")

const VIEWPOINTS := {
	"01_spawn": [Vector3(0.0, 1.65, 28.5), Vector3(0.0, 3.4, 8.2)],
	"02_parking_mid": [Vector3(-18.0, 8.0, 36.0), Vector3(0.0, 3.0, 16.0)],
	"03_facade": [Vector3(0.0, 2.2, 16.0), Vector3(0.0, 4.5, 8.2)],
	"04_door_threshold": [Vector3(0.0, 1.6, 8.6), Vector3(0.0, 2.2, 6.2)],
	"05_entry_hall": [Vector3(0.0, 1.7, 4.0), Vector3(0.0, 3.0, -2.0)],
	"06_main_atrium": [Vector3(0.0, 1.7, -8.0), Vector3(0.0, 6.0, -14.0)],
	"07_mezzanine": [Vector3(0.0, 7.6, -21.2), Vector3(0.0, 4.0, -14.0)],
	"08_branch": [Vector3(-18.0, 1.7, -14.0), Vector3(-24.0, 2.4, -14.0)],
}

@export var viewpoint: String = "01_spawn"
var _cycle: float = 0.0


func _ready() -> void:
	_world()
	_proxies()
	var path := ENV_V4 if ResourceLoader.exists(ENV_V4) else ENV_V3
	if ResourceLoader.exists(path):
		var packed: PackedScene = load(path) as PackedScene
		if packed != null:
			var inst := packed.instantiate()
			inst.name = "BlenderEnvV4Candidate"
			add_child(inst)
			_strip(inst)
			print("[SDS_V4_CANDIDATE_LAB] loaded=%s HUMAN_REVIEW_REQUIRED canonical=false" % path)
		else:
			print("[SDS_V4_CANDIDATE_LAB] FAIL instantiate %s" % path)
	else:
		print("[SDS_V4_CANDIDATE_LAB] MISSING glb")
	var cam := Camera3D.new()
	cam.name = "ReviewCamera"
	cam.fov = 68.0
	cam.current = true
	add_child(cam)
	var pair: Array = VIEWPOINTS.get(viewpoint, VIEWPOINTS["01_spawn"])
	cam.global_position = pair[0]
	cam.look_at(pair[1], Vector3.UP)
	Probe.dump("sds_v4_candidate_lab", self)


func _process(delta: float) -> void:
	_cycle += delta
	var keys: Array = VIEWPOINTS.keys()
	var i: int = int(_cycle / 2.4) % keys.size()
	var cam := get_node_or_null("ReviewCamera") as Camera3D
	if cam == null:
		return
	var pair: Array = VIEWPOINTS[keys[i]]
	cam.global_position = pair[0]
	cam.look_at(pair[1], Vector3.UP)


func _world() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-18, 128, 0)
	sun.light_energy = 0.22
	sun.light_color = Color("#6a7a98")
	add_child(sun)
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#121820")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#4a5568")
	env.ambient_light_energy = 0.72
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment = env
	add_child(world)
	var fill := OmniLight3D.new()
	fill.position = Vector3(0, 5.5, 16.0)
	fill.light_energy = 2.6
	fill.omni_range = 28.0
	fill.light_color = Color("#ffc070")
	add_child(fill)
	var arch := OmniLight3D.new()
	arch.position = Vector3(0, 6.5, 10.0)
	arch.light_energy = 3.0
	arch.omni_range = 16.0
	arch.light_color = Color("#ffe0a0")
	add_child(arch)
	var atrium := OmniLight3D.new()
	atrium.position = Vector3(0, 11.0, -14.0)
	atrium.light_energy = 2.2
	atrium.omni_range = 22.0
	atrium.light_color = Color("#d8ecff")
	add_child(atrium)


func _proxies() -> void:
	_box(Vector3(0, -0.5, 26.0), Vector3(48, 1, 34))
	_box(Vector3(0, -0.5, 8.9), Vector3(6.2, 1, 2.4))
	_box(Vector3(0, -0.5, -8.0), Vector3(16, 1, 28))


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
