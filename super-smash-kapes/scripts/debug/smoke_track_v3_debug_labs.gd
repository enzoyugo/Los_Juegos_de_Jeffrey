extends SceneTree

## One-shot parse/load smoke for Track V3 debug labs. Not a gameplay lab.

const SCENES: PackedStringArray = [
	"res://scenes/debug/TrackCarArticulatedIntegrityLab.tscn",
	"res://scenes/debug/TrackCarSemanticOrientationLab.tscn",
	"res://scenes/debug/Track4WheelExtendedPhysicsLab.tscn",
	"res://scenes/debug/TrackCleanGapLandingLab.tscn",
]

const SCRIPTS: PackedStringArray = [
	"res://scripts/debug/track_car_articulated_integrity_lab.gd",
	"res://scripts/debug/track_car_semantic_orientation_lab.gd",
	"res://scripts/track/track_4wheel_extended_physics_lab.gd",
	"res://scripts/track/track_clean_gap_landing_lab.gd",
	"res://scripts/track/track_extended_debug_camera.gd",
]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var errors: PackedStringArray = PackedStringArray()
	for path in SCRIPTS:
		var script: Resource = load(path)
		if script == null:
			errors.append("script load failed: %s" % path)
			print("[TRACK_V3_PARSE_SMOKE] FAIL script=%s" % path)
		else:
			print("[TRACK_V3_PARSE_SMOKE] script_ok %s" % path)
	for path in SCENES:
		var packed: PackedScene = load(path) as PackedScene
		if packed == null:
			errors.append("scene load failed: %s" % path)
			print("[TRACK_V3_PARSE_SMOKE] FAIL scene_load=%s" % path)
			continue
		var inst: Node = packed.instantiate()
		if inst == null:
			errors.append("scene instantiate failed: %s" % path)
			print("[TRACK_V3_PARSE_SMOKE] FAIL scene_instantiate=%s" % path)
			continue
		root.add_child(inst)
		await process_frame
		await process_frame
		print("[TRACK_V3_PARSE_SMOKE] scene_ok %s class=%s" % [path, inst.get_class()])
		root.remove_child(inst)
		inst.free()
		await process_frame
	if errors.is_empty():
		print("[TRACK_V3_PARSE_SMOKE] OK")
		quit(0)
	else:
		for item in errors:
			print("[TRACK_V3_PARSE_SMOKE] FAIL %s" % item)
		quit(1)
