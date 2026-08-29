extends Node3D

## Isolated observational lab. Does not retune Track physics, steering, grip, or fuel.
## Crash barrier is debug-only geometry. Drift uses the same car/camera as the 15m kit.

const Config := preload("res://scripts/track/track_config.gd")
const Registry := preload("res://scripts/track/track_piece_registry.gd")
const Assembler := preload("res://scripts/track/track_kit_assembler.gd")
const CamScript := preload("res://scripts/track/track_dynamic_chase_camera.gd")

@export var barrier_enabled: bool = true
@export var barrier_distance_m: float = 16.0

const SEQ := ["start", "straight_medium", "straight_medium", "finish"]

var jeffrey_debug_state: Dictionary = {}
var _car
var _cam
var _piece_count: int = 0
var _barrier: StaticBody3D


func _ready() -> void:
	Config.ensure_actions()
	_sun()
	var built: Dictionary = Assembler.assemble(self, SEQ, Registry.CORE_DIR_V8_15M, true)
	var pieces: Array = built["pieces"]
	_piece_count = pieces.size()
	var packed: PackedScene = load("res://scenes/track/TrackCarWheelPhysics.tscn") as PackedScene
	_car = packed.instantiate()
	add_child(_car)
	var spawn := Transform3D(Basis.IDENTITY, Vector3(0, 1.15, -2.6))
	if pieces.size() > 0 and pieces[0].player_spawn != null:
		spawn = pieces[0].player_spawn.global_transform
	_car.reset_to(spawn)
	_car.control_enabled = true
	if barrier_enabled:
		_spawn_barrier(spawn)
	_cam = CamScript.new()
	add_child(_cam)
	_cam.target = _car.camera_target() if _car.has_method("camera_target") else _car
	_cam.current = true
	_cam.snap_to_target()
	_refresh_jeffrey_debug_state()


func _process(_delta: float) -> void:
	_refresh_jeffrey_debug_state()


func _spawn_barrier(spawn: Transform3D) -> void:
	_barrier = StaticBody3D.new()
	_barrier.name = "CrashBarrier"
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(8.0, 3.0, 1.2)
	col.shape = box
	_barrier.add_child(col)
	var mesh := MeshInstance3D.new()
	var visual := BoxMesh.new()
	visual.size = Vector3(8.0, 3.0, 1.2)
	mesh.mesh = visual
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("#c44b3a")
	mesh.material_override = mat
	_barrier.add_child(mesh)
	var forward := -spawn.basis.z
	_barrier.global_transform = Transform3D(spawn.basis, spawn.origin + forward * barrier_distance_m + Vector3(0, 1.2, 0))
	add_child(_barrier)


func _refresh_jeffrey_debug_state() -> void:
	var cam_fov: Variant = "UNAVAILABLE"
	var cam_pos: Variant = "UNAVAILABLE"
	if _cam != null and is_instance_valid(_cam):
		cam_fov = _cam.last_fov if "last_fov" in _cam else _cam.fov
		var gp: Vector3 = _cam.global_position
		cam_pos = [gp.x, gp.y, gp.z]
	var vehicle_path: Variant = "UNAVAILABLE"
	if _car != null and is_instance_valid(_car):
		vehicle_path = str(_car.get_path())
	jeffrey_debug_state = {
		"scene": scene_file_path,
		"vehicle_node": vehicle_path,
		"piece_sequence": SEQ,
		"piece_count": _piece_count,
		"barrier_enabled": barrier_enabled,
		"checkpoint_progress": "UNAVAILABLE",
		"fuel": "UNAVAILABLE",
		"camera_fov": cam_fov,
		"camera_position": cam_pos,
		"mutating": false,
	}


func _sun() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	sun.light_energy = 1.2
	add_child(sun)
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#5e7a90")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#c8d4e0")
	env.ambient_light_energy = 0.55
	world.environment = env
	add_child(world)
