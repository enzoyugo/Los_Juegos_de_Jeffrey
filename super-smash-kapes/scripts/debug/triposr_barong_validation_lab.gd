extends Node3D

## Isolated TripoSR barong MCP closeout. Not SDS art. Not canonical.

const CANDIDATE := "res://assets/debug/toolchain_candidates/triposr_barong_candidate.glb"
const Probe := preload("res://scripts/debug/jeffrey_resource_probe.gd")


func _ready() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 35, 0)
	sun.light_energy = 1.15
	add_child(sun)
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.16, 0.17, 0.19)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.57, 0.6)
	env.ambient_light_energy = 0.9
	world.environment = env
	add_child(world)
	var floor := MeshInstance3D.new()
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(8, 8)
	floor.mesh = mesh
	add_child(floor)
	if not ResourceLoader.exists(CANDIDATE):
		print("[TRIPOSR_BARONG_LAB] MISSING %s" % CANDIDATE)
	else:
		var packed: PackedScene = load(CANDIDATE) as PackedScene
		if packed != null:
			var inst := packed.instantiate()
			inst.name = "TripoSRBarongCandidate"
			add_child(inst)
			print("[TRIPOSR_BARONG_LAB] loaded=%s" % CANDIDATE)
	var cam := Camera3D.new()
	cam.name = "ReviewCamera"
	cam.fov = 50.0
	cam.current = true
	add_child(cam)
	cam.global_position = Vector3(0.0, 1.4, 4.2)
	cam.look_at(Vector3(0.0, 0.7, 0.0), Vector3.UP)
	Probe.dump("triposr_barong_lab", self)
