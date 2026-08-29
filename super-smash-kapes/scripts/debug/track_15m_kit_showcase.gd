extends Node3D

## 15 m candidate kit sequence. 4WHEEL. No debug HUD. VISUAL_REVIEW_PENDING.

const Config := preload("res://scripts/track/track_config.gd")
const Registry := preload("res://scripts/track/track_piece_registry.gd")
const Assembler := preload("res://scripts/track/track_kit_assembler.gd")
const CamScript := preload("res://scripts/track/track_dynamic_chase_camera.gd")
const Scenery := preload("res://scripts/track/track_scenery_generator.gd")
const TrackProcedural := preload("res://scripts/debug/jeffrey_track_procedural_report.gd")

const SEQ := [
	"start",
	"straight_medium",
	"curve_l_45",
	"straight_short",
	"curve_r_90",
	"chicane_lr",
	"boost_straight",
	"slope_up_gentle",
	"crest_gentle",
	"slope_down_gentle",
	"finish",
]

var jeffrey_debug_state: Dictionary = {}
var _car
var _cam
var _piece_count: int = 0


func _ready() -> void:
	Config.ensure_actions()
	_sun()
	var built: Dictionary = Assembler.assemble(self, SEQ, Registry.CORE_DIR_V8_15M, true)
	var pieces: Array = built["pieces"]
	_piece_count = pieces.size()
	var scenery := Scenery.new()
	scenery.road_clearance = Config.ROAD_WIDTH_CANDIDATE * 0.5 + 1.6
	add_child(scenery)
	scenery.build(pieces)
	var packed: PackedScene = load("res://scenes/track/TrackCarWheelPhysics.tscn") as PackedScene
	_car = packed.instantiate()
	add_child(_car)
	var spawn := Transform3D(Basis.IDENTITY, Vector3(0, 1.15, -2.6))
	if pieces.size() > 0 and pieces[0].player_spawn != null:
		spawn = pieces[0].player_spawn.global_transform
	_car.reset_to(spawn)
	_car.control_enabled = true
	_cam = CamScript.new()
	add_child(_cam)
	_cam.target = _car.camera_target() if _car.has_method("camera_target") else _car
	_cam.current = true
	_cam.snap_to_target()
	print("[TRACK_15M_KIT] pieces=%d kit=%s VISUAL_REVIEW_PENDING" % [pieces.size(), Registry.CORE_DIR_V8_15M])
	_refresh_jeffrey_debug_state()


func _process(_delta: float) -> void:
	_refresh_jeffrey_debug_state()


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
		"scene": "res://scenes/debug/Track15mKitShowcase.tscn",
		"vehicle_node": vehicle_path,
		"piece_sequence": SEQ,
		"piece_count": _piece_count,
		"checkpoint_progress": "UNAVAILABLE",
		"fuel": "UNAVAILABLE",
		"camera_fov": cam_fov,
		"camera_position": cam_pos,
		"procedural_report": TrackProcedural.report_sequence(SEQ, _piece_count),
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
