extends Node3D

## Headless V7 systems: reveal count, scenery corridor, camera FOV, checkpoints.

const Gen := preload("res://scripts/track/track_generator_v2.gd")
const Assembler := preload("res://scripts/track/track_kit_assembler.gd")
const Reveal := preload("res://scripts/track/track_generation_reveal.gd")
const Scenery := preload("res://scripts/track/track_scenery_generator.gd")
const Signage := preload("res://scripts/track/track_signage.gd")
const Checkpoints := preload("res://scripts/track/track_checkpoint_layout.gd")
const CamScript := preload("res://scripts/track/track_dynamic_chase_camera.gd")
const Hotseat := preload("res://scripts/track/track_hotseat_v2.gd")
const Telemetry := preload("res://scripts/track/track_debug_telemetry.gd")
const Config := preload("res://scripts/track/track_config.gd")


func _ready() -> void:
	Config.ensure_actions()
	var g = Gen.new()
	var row: Dictionary = g.generate(77, "SHORT", "PICANTE")
	if not bool(row.get("accepted", false)):
		print("[TRACK_V7_SYS] FAIL generate")
		get_tree().quit(1)
		return
	var seq: Array = row.get("piece_sequence", [])
	var built: Dictionary = Assembler.assemble(self, seq)
	var pieces: Array = built["pieces"]
	if pieces.size() != seq.size():
		print("[TRACK_V7_SYS] FAIL assemble_count")
		get_tree().quit(1)
		return
	var sc = Scenery.new()
	add_child(sc)
	sc.build(pieces)
	if _count_class(sc, "StaticBody3D") > 0:
		print("[TRACK_V7_SYS] FAIL scenery_collision")
		get_tree().quit(1)
		return
	Signage.decorate(self, pieces)
	var idxs := Checkpoints.plan(seq, "SHORT")
	if idxs.size() < 3:
		print("[TRACK_V7_SYS] FAIL checkpoint_count=%d" % idxs.size())
		get_tree().quit(1)
		return
	var prev := -1
	for i in idxs.size():
		if idxs[i] <= prev:
			print("[TRACK_V7_SYS] FAIL checkpoint_order")
			get_tree().quit(1)
			return
		prev = idxs[i]
	Checkpoints.build_gates(self, pieces, idxs, Config.ROAD_WIDTH)
	var cam = CamScript.new()
	cam.current = true
	add_child(cam)
	var packed: PackedScene = load("res://scenes/track/TrackCarWheelPhysics.tscn") as PackedScene
	var car = packed.instantiate()
	add_child(car)
	car.reset_to(built["spawn"])
	cam.target = car.camera_target() if car.has_method("camera_target") else car
	cam.snap_to_target()
	for _i in 8:
		await get_tree().physics_frame
	if not is_finite(cam.last_fov) or cam.last_fov < 60.0 or cam.last_fov > 92.0:
		print("[TRACK_V7_SYS] FAIL fov=%.1f" % cam.last_fov)
		get_tree().quit(1)
		return
	if not is_finite(cam.global_position.x):
		print("[TRACK_V7_SYS] FAIL cam_nan")
		get_tree().quit(1)
		return
	var rev = Reveal.new()
	add_child(rev)
	var done := false
	rev.finished.connect(func():
		done = true
	)
	rev.skip = true
	rev.start(pieces, cam)
	var guard := 0
	while rev.playing and guard < 24:
		await get_tree().process_frame
		guard += 1
	if rev.playing or pieces.size() != seq.size():
		print("[TRACK_V7_SYS] FAIL reveal playing=%s n=%d seq=%d" % [str(rev.playing), pieces.size(), seq.size()])
		get_tree().quit(1)
		return
	var n := Telemetry.debug_int(null, "debug_grounded_n", 4)
	if n != 4:
		print("[TRACK_V7_SYS] FAIL telemetry")
		get_tree().quit(1)
		return
	var hs = Hotseat.new()
	hs.setup([{"id": "a"}, {"id": "b"}], 20.0, 2.75)
	hs.begin_run()
	hs.record_finish(21.0)
	hs.begin_run()
	hs.record_finish(22.0)
	if hs.last_place_id() != "b":
		print("[TRACK_V7_SYS] FAIL last_place")
		get_tree().quit(1)
		return
	print("[TRACK_V7_SYS] PASS pieces=%d cp=%d fov=%.1f landmarks=%d" % [
		pieces.size(),
		idxs.size(),
		cam.last_fov,
		sc.landmarks.size(),
	])
	get_tree().quit(0)


func _count_class(node: Node, cname: String) -> int:
	var n := 1 if node.get_class() == cname else 0
	for child in node.get_children():
		n += _count_class(child, cname)
	return n
