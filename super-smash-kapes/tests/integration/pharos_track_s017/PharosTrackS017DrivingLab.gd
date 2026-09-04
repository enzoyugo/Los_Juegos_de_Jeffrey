extends Node3D

## Isolated Sprint 017 lab. Does not touch Track production scenes or controllers.
const GLB_PATH := "res://tests/integration/pharos_track_s017/S016_SHORT_SEED_1601.glb"
const CAR_SCENE := "res://scenes/track/TrackCarWheelPhysics.tscn"
const SCALE_FACTOR := 2.05
const SOURCE_ROAD_WIDTH := 4.0
const TARGET_ROAD_WIDTH_M := 8.20
const ROUTE_LENGTH_DESIGN := 97.13274122871834
const PHYSICS_HZ := 20.0

var _track: Node3D
var _car: RigidBody3D
var _camera: Camera3D
var _hud: Label
var _debug_on := false
var _telemetry_file: FileAccess
var _telemetry_clock := 0.0
var _run_clock := 0.0
var _reset_count := 0
var _checkpoint_index := 0
var _checkpoint_nodes: Array[Area3D] = []
var _spawn_transform := Transform3D.IDENTITY
var _last_position := Vector3.ZERO
var _last_failure := ""
var _capture_stage := 0
const CAPTURE_DIR := "E:/PharosVisualization/experiments/track_generation/sprint_017_runtime_lab/screenshots/"
var _results := {"scale_factor": SCALE_FACTOR, "scale_status":"EXPERIMENTAL", "runs":[], "joints":[]}

func _ready() -> void:
	TrackConfig.ensure_actions()
	_spawn_transform = Transform3D(Basis(Vector3.UP, PI), Vector3(0.0, 1.65, 3.0))
	_load_visual_and_collision()
	_spawn_car()
	_build_checkpoints()
	_build_camera_hud()
	_telemetry_file = FileAccess.open("user://pharos_s017_telemetry.jsonl", FileAccess.WRITE)
	_last_position = _car.global_position
	print("[PHAROS_S017] LAB_ONLY Godot=%s GLB=%s scale=%.3f source_width=%.2f target_width=%.2f" % [Engine.get_version_info().string, GLB_PATH, SCALE_FACTOR, SOURCE_ROAD_WIDTH, TARGET_ROAD_WIDTH_M])

func _load_visual_and_collision() -> void:
	# Runtime GLBDocument avoids changing the production import policy and still loads the real bytes.
	var doc := GLTFDocument.new(); var state := GLTFState.new()
	var err := doc.append_from_file(ProjectSettings.globalize_path(GLB_PATH), state)
	if err != OK:
		push_error("[PHAROS_S017] BLOCKED_INPUT GLB_LOAD_FAILED err=%s path=%s" % [err, GLB_PATH]); return
	_track = doc.generate_scene(state) as Node3D
	if _track == null:
		push_error("[PHAROS_S017] BLOCKED_INPUT GLB_SCENE_GENERATION_FAILED"); return
	_track.name = "PharosShortTrackVisual_REAL_GLB"
	_track.scale = Vector3.ONE * SCALE_FACTOR
	add_child(_track)
	_track.set_meta("source_glb", GLB_PATH)
	_track.set_meta("scale_factor", SCALE_FACTOR)
	var meshes: Array[MeshInstance3D] = []
	_collect_meshes(_track, meshes)
	var n := 0
	for mi in meshes:
		if mi.mesh == null: continue
		var shape := mi.mesh.create_trimesh_shape()
		if shape == null: continue
		var body := StaticBody3D.new()
		body.name = "PharosSemanticCollision_%03d" % n
		body.collision_layer = 1; body.collision_mask = 2
		body.set_meta("collision_kind", "road" if ("ROAD" in mi.name or "road" in mi.name) else "barrier")
		body.set_meta("source_mesh", mi.name)
		add_child(body); body.global_transform = mi.global_transform
		var cs := CollisionShape3D.new(); cs.shape = shape; body.add_child(cs)
		n += 1
	print("[PHAROS_S017] COLLIDER_MODE=GLB_SEMANTIC_COLLISION colliders=%d source_meshes=%d scale=%.3f" % [n, meshes.size(), SCALE_FACTOR])

func _collect_meshes(node: Node, out: Array[MeshInstance3D]) -> void:
	for child in node.get_children():
		if child is MeshInstance3D: out.append(child)
		_collect_meshes(child, out)

func _spawn_car() -> void:
	var packed := load(CAR_SCENE) as PackedScene
	if packed == null: push_error("[PHAROS_S017] BLOCKED_ADAPTER CAR_SCENE_FAILED"); return
	_car = packed.instantiate() as RigidBody3D
	_car.name = "FOUR_WHEEL_V1_LAB_ONLY"
	_car.set_meta("lab_only", true)
	add_child(_car); _car.global_transform = _spawn_transform
	_car.set("control_enabled", true)
	_car.set("debug_enabled", true)
	print("[PHAROS_S017] VEHICLE=FOUR_WHEEL_V1 scene=%s body=%s" % [CAR_SCENE, _car.get_class()])

func _build_checkpoints() -> void:
	# Endpoints derived from the V1 track sequence, converted from Pharos X/Y design plane to Godot X/Z.
	var design_points := [Vector2(0,0),Vector2(0,-12),Vector2(0,-24),Vector2(-8,-32),Vector2(-8,-44),Vector2(-8,-56),Vector2(-16,-64),Vector2(-16,-76),Vector2(-16,-88),Vector2(-24,-96),Vector2(-32,-96),Vector2(-40,-88),Vector2(-40,-76),Vector2(-40,-64),Vector2(-40,-52),Vector2(-40,-40),Vector2(-40,-28),Vector2(-40,-16),Vector2(-40,0)]
	for i in design_points.size():
		var p: Vector2 = design_points[i]
		var area := Area3D.new(); area.name = "Checkpoint_%02d" % i; area.collision_layer=0; area.collision_mask=2; area.set_meta("checkpoint_index", i)
		var cs:=CollisionShape3D.new(); var sh:=SphereShape3D.new(); sh.radius=4.0; cs.shape=sh; area.add_child(cs)
		add_child(area); area.position=Vector3(p.x*SCALE_FACTOR,1.0,-p.y*SCALE_FACTOR); area.body_entered.connect(_on_checkpoint_body.bind(i)); _checkpoint_nodes.append(area)
	print("[PHAROS_S017] CHECKPOINTS=%d ordered_from_track_spec=true finish_requires_all=true" % _checkpoint_nodes.size())

func _on_checkpoint_body(body: Node3D, index: int) -> void:
	if body != _car or index != _checkpoint_index: return
	_checkpoint_index += 1
	print("[PHAROS_S017] CHECKPOINT index=%d/%d" % [_checkpoint_index, _checkpoint_nodes.size()])

func _build_camera_hud() -> void:
	_camera=Camera3D.new(); _camera.name="PharosS017ChaseCamera"; add_child(_camera); _camera.current=true
	_hud=Label.new(); _hud.name="PharosS017DiagnosticHUD"; _hud.position=Vector2(24,24); _hud.add_theme_font_size_override("font_size",20); add_child(_hud)
	_hud.text="PHAROS S017 LAB — NO PRODUCCIÓN\nW acelerar · S frenar · A/D giro · C reset · F4 colliders · F9 auto";
	_build_label("PHAROS S017 LAB — NO PRODUCCIÓN",Vector3(-10,5,0),Color(1.0,0.25,0.1))

func _build_label(text: String, pos: Vector3, color: Color) -> void:
	var l:=Label3D.new(); l.text=text; l.position=pos; l.modulate=color; l.font_size=48; l.outline_size=12; add_child(l)

func _process(delta: float) -> void:
	if _car == null: return
	_run_clock += delta; _telemetry_clock += delta
	if _telemetry_clock >= 1.0/PHYSICS_HZ:
		_telemetry_clock=0.0; _write_telemetry()
	var fwd := -_car.global_transform.basis.z.normalized(); _camera.global_position=_car.global_position-fwd*11.0+Vector3.UP*6.0; _camera.look_at(_car.global_position+fwd*7.0+Vector3.UP*1.5)
	_hud.text="PHAROS S017 LAB — NO PRODUCCIÓN\n4WHEEL_V1 | %.1f km/h | ruedas=%d/4 | cp=%d/%d\nposición=%s\nF4 colliders · C reset · F9 auto" % [_car.get("debug_speed")*3.6, _grounded_count(), _checkpoint_index, _checkpoint_nodes.size(), str(_car.global_position)]
	if _car.global_position.y < -5.0: _last_failure="FAIL_OFFTRACK"; reset_lab("fall")
	if _capture_stage == 0 and _run_clock > 2.5:
		_capture_view("runtime_spawn.png"); _capture_stage=1
	if _capture_stage == 1 and _run_clock > 3.5:
		_set_debug_colliders(true); _capture_view("runtime_colliders.png"); _capture_stage=2
	if Input.is_action_just_pressed("track_reset"): reset_lab("manual")
	if Input.is_key_pressed(KEY_F4): _set_debug_colliders(true)

func _grounded_count() -> int:
	var n:=0
	for w in _car.get("_wheels") if _car.get("_wheels") != null else []:
		if w != null and w.get("is_grounded"): n+=1
	return n

func _set_debug_colliders(on: bool) -> void:
	_debug_on=on; get_tree().debug_collisions_hint=on

func reset_lab(reason: String) -> void:
	if _car == null: return
	_car.call("reset_to", _spawn_transform); _checkpoint_index=0; _reset_count+=1; print("[PHAROS_S017] RESET count=%d reason=%s" % [_reset_count,reason])

func _write_telemetry() -> void:
	if _telemetry_file == null: return
	var wheels:=[]
	for w in _car.get("_wheels") if _car.get("_wheels") != null else []:
		if w != null: wheels.append({"id":str(w.get("wheel_id")),"grounded":bool(w.get("is_grounded")),"compression":float(w.get("compression")),"contact":str(w.get("contact_collider_name"))})
	_telemetry_file.store_line(JSON.stringify({"timestamp":Time.get_ticks_msec()/1000.0,"position":_car.global_position,"rotation":_car.global_rotation,"linear_velocity":_car.linear_velocity,"angular_velocity":_car.angular_velocity,"checkpoint":_checkpoint_index,"wheels":wheels,"reset_count":_reset_count,"failure":_last_failure}))

func _capture_view(filename: String) -> void:
	var image := get_viewport().get_texture().get_image()
	var err := image.save_png(CAPTURE_DIR + filename)
	print("[PHAROS_S017] VIEWPORT_CAPTURE path=%s err=%s" % [CAPTURE_DIR + filename, err])

func _exit_tree() -> void:
	if _telemetry_file != null: _telemetry_file.close()
