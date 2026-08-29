extends Node3D

## ASUNCION_URBAN_V1 scenery judgment. No giant debug text.

const Config := preload("res://scripts/track/track_config.gd")
const Registry := preload("res://scripts/track/track_piece_registry.gd")
const Assembler := preload("res://scripts/track/track_kit_assembler.gd")
const Scenery := preload("res://scripts/track/track_scenery_generator.gd")

const SEQ := [
	"start",
	"straight_long",
	"curve_r_45",
	"straight_medium",
	"curve_l_90",
	"straight_short",
	"finish",
]

var _cam: Camera3D
var _t: float = 0.0
var _pieces: Array = []


func _ready() -> void:
	_sun()
	var built: Dictionary = Assembler.assemble(self, SEQ, Registry.CORE_DIR_V8_15M)
	_pieces = built["pieces"]
	var scenery := Scenery.new()
	scenery.road_clearance = Config.ROAD_WIDTH_CANDIDATE * 0.5 + 1.6
	add_child(scenery)
	scenery.build(_pieces)
	_cam = Camera3D.new()
	_cam.fov = 68.0
	_cam.current = true
	add_child(_cam)
	print("[TRACK_URBAN_V1] landmarks=%s VISUAL_REVIEW_PENDING" % str(scenery.landmarks))


func _process(delta: float) -> void:
	_t += delta * 0.22
	if _pieces.is_empty():
		return
	var i := clampi(int(_t) % _pieces.size(), 0, _pieces.size() - 1)
	var piece = _pieces[i]
	if piece == null or not piece.has_method("entry_global"):
		return
	var xf: Transform3D = piece.entry_global()
	var look: Vector3 = xf.origin + Vector3(0, 1.4, 0)
	_cam.global_position = look + xf.basis.x * 6.0 + Vector3(0, 3.2, 0) + xf.basis.z * 10.0
	if look.distance_to(_cam.global_position) > 0.2:
		_cam.look_at(look, Vector3.UP)


func _sun() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, 40, 0)
	sun.light_energy = 1.15
	add_child(sun)
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#6a8496")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#c4d0dc")
	env.ambient_light_energy = 0.6
	world.environment = env
	add_child(world)
