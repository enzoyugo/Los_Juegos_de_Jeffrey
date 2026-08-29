extends Node3D

## V4 baseline capture for SDS V4.1 comparison. Loads V4 candidate GLB only.
## Does not overwrite V4 files. HUMAN_REVIEW_REQUIRED.

const ENV_V4 := "res://assets/environments/shopping_del_sol/processed/shopping_del_sol_zombies_environment_v4_candidate.glb"
const Probe := preload("res://scripts/debug/jeffrey_resource_probe.gd")

const VIEWPOINTS := {
	"01_spawn": [Vector3(0.0, 1.65, 28.5), Vector3(0.0, 3.4, 8.2)],
	"02_parking_mid": [Vector3(-18.0, 8.0, 36.0), Vector3(0.0, 3.0, 16.0)],
	"03_facade_front": [Vector3(0.0, 2.2, 18.5), Vector3(0.0, 5.2, 8.2)],
	"04_facade_close": [Vector3(0.0, 2.0, 13.2), Vector3(0.0, 4.8, 8.5)],
	"05_threshold": [Vector3(0.0, 1.6, 8.6), Vector3(0.0, 2.2, 6.2)],
	"06_entry_hall": [Vector3(0.0, 1.7, 4.0), Vector3(0.0, 3.0, -2.0)],
	"07_atrium": [Vector3(0.0, 1.7, -6.5), Vector3(0.0, 8.0, -14.0)],
	"08_mezzanine_or_upper_view_if_available": [Vector3(0.0, 7.6, -21.2), Vector3(0.0, 4.0, -14.0)],
}

@export var viewpoint: String = "01_spawn"
var _cycle: float = 0.0


func _ready() -> void:
	_world()
	var path := ENV_V4
	if ResourceLoader.exists(path):
		var packed: PackedScene = load(path) as PackedScene
		if packed != null:
			var inst := packed.instantiate()
			inst.name = "BlenderEnvV4Baseline"
			add_child(inst)
			_strip(inst)
			print("[SDS_V4_BASELINE_LAB] loaded=%s" % path)
	var cam := Camera3D.new()
	cam.name = "ReviewCamera"
	cam.fov = 68.0
	cam.current = true
	add_child(cam)
	var pair: Array = VIEWPOINTS.get(viewpoint, VIEWPOINTS["01_spawn"])
	cam.global_position = pair[0]
	cam.look_at(pair[1], Vector3.UP)
	Probe.dump("sds_v4_baseline_for_v4_1", self)


func _process(delta: float) -> void:
	_cycle += delta
	var keys: Array = VIEWPOINTS.keys()
	var i: int = int(_cycle / 2.6) % keys.size()
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


func _strip(node: Node) -> void:
	for child in node.get_children():
		_strip(child)
	if node is AnimationPlayer:
		node.queue_free()
