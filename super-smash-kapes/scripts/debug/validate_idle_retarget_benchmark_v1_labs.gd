extends Node

const OUT_PATH := "res://docs/generated/CLEAN_RIG_IDLE_RETARGET_BENCHMARK_V1_GODOT.json"
const LABS := [
	"res://scenes/debug/TerereIdleRetargetBenchmarkV1Lab.tscn",
	"res://scenes/debug/JaguareteIdleRetargetBenchmarkV1Lab.tscn",
]
const FORBIDDEN := [
	"game_ready_v4",
	"game_ready_v3",
	"semantic_solver_v2",
	"solver_v1",
	"actorcore_benchmark",
	"source_rigged",
]
const HUD_SCRIPTS := [
	"m0_hud.gd",
	"kapes_player_hud.gd",
]
const ACTIONS := [
	"benchmark_rest",
	"benchmark_traditional",
	"benchmark_semantic",
	"benchmark_skeleton",
	"benchmark_bbox",
	"benchmark_camera_reset",
]


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var report := {
		"godot": Engine.get_version_info(),
		"labs": [],
		"all_ok": true,
		"input_actions": {},
		"hud_isolation": true,
	}
	await get_tree().process_frame
	for action in ACTIONS:
		report["input_actions"][action] = InputMap.has_action(action)
		if not InputMap.has_action(action):
			report["all_ok"] = false
	for path in LABS:
		var packed: PackedScene = load(path)
		var row := {"scene": path, "ok": false, "methods": {}, "blocking_errors": []}
		if packed == null:
			row["error"] = "scene_load_failed"
			report["all_ok"] = false
			report["labs"].append(row)
			continue
		var inst: Node = packed.instantiate()
		add_child(inst)
		await get_tree().process_frame
		await get_tree().process_frame
		if inst.has_method("tree_has_battle_hud") and inst.call("tree_has_battle_hud"):
			row["blocking_errors"].append("battle_hud_instanced")
			report["hud_isolation"] = false
			report["all_ok"] = false
		var deps_ok := _scene_deps_isolated(path)
		row["hud_script_in_scene"] = not deps_ok
		if not deps_ok:
			row["blocking_errors"].append("hud_script_dependency")
			report["hud_isolation"] = false
			report["all_ok"] = false
		if inst.has_method("collect_dump"):
			var dump: Dictionary = inst.call("collect_dump")
			row["dump"] = dump
			var bones := int(dump.get("bone_count", 0))
			var tracks := int(dump.get("idle_tracks", 0))
			row["ok"] = bool(dump.get("load_ok", false)) and bones >= 90 and tracks >= 8 and not bool(dump.get("fallback", true))
			if str(dump.get("pipeline", "")) != "CLEAN_RIG_IDLE_BENCHMARK_V1":
				row["ok"] = false
				row["error"] = "wrong_pipeline"
			for token in FORBIDDEN:
				for key in ["rest_glb", "traditional_glb", "semantic_glb"]:
					if str(dump.get(key, "")).find(token) != -1:
						row["ok"] = false
						row["error"] = "forbidden_asset_%s" % token
			if bool(dump.get("runtime_retarget", true)) or bool(dump.get("proxy_idle", true)) or bool(dump.get("legacy_orientation_hack", true)):
				row["ok"] = false
				row["error"] = "legacy_runtime_behavior"
		else:
			row["error"] = "no_collect_dump"
			report["all_ok"] = false
		if inst.has_method("apply_benchmark_method") and inst.has_method("get_playback_snapshot"):
			row["methods"] = await _exercise_methods(inst)
			for method_name in row["methods"].keys():
				var method_row: Dictionary = row["methods"][method_name]
				if not bool(method_row.get("ok", false)):
					row["ok"] = false
					row["blocking_errors"].append("method_%s" % method_name)
		else:
			row["ok"] = false
			row["blocking_errors"].append("missing_method_api")
		if not row["ok"]:
			report["all_ok"] = false
		report["labs"].append(row)
		inst.queue_free()
		await get_tree().process_frame
	var abs_path := ProjectSettings.globalize_path(OUT_PATH)
	var fh := FileAccess.open(abs_path, FileAccess.WRITE)
	if fh:
		fh.store_string(JSON.stringify(report, "\t"))
		fh.close()
	print("IDLE_RETARGET_LAB_VALIDATION_WRITTEN all_ok=%s path=%s" % [report["all_ok"], abs_path])
	get_tree().quit(0 if report["all_ok"] else 2)


func _exercise_methods(inst: Node) -> Dictionary:
	var cam_before: Array = []
	var out := {}
	for method in ["CLEAN_REST", "TRADITIONAL", "SEMANTIC"]:
		inst.call("apply_benchmark_method", method)
		await get_tree().process_frame
		await get_tree().process_frame
		var snap: Dictionary = inst.call("get_playback_snapshot")
		if method == "CLEAN_REST":
			cam_before = snap.get("camera_position", [0.0, 0.0, 0.0])
		var row := {
			"snapshot_start": snap.duplicate(true),
			"exactly_one_visible": bool(snap.get("exactly_one_visible", false)),
			"rest_visible": bool(snap.get("rest_visible", false)),
			"traditional_visible": bool(snap.get("traditional_visible", false)),
			"semantic_visible": bool(snap.get("semantic_visible", false)),
			"camera_unchanged": true,
			"animation_name": str(snap.get("animation_name", "")),
			"animation_length": snap.get("animation_length", 0.0),
			"start_position": snap.get("current_position", 0.0),
			"end_position": snap.get("current_position", 0.0),
			"playing": bool(snap.get("playing", false)),
			"advanced": false,
			"ok": false,
		}
		var expect_rest: bool = String(method) == "CLEAN_REST"
		var expect_trad: bool = String(method) == "TRADITIONAL"
		var expect_sem: bool = String(method) == "SEMANTIC"
		var vis_ok: bool = (
			bool(row["rest_visible"]) == expect_rest
			and bool(row["traditional_visible"]) == expect_trad
			and bool(row["semantic_visible"]) == expect_sem
			and bool(row["exactly_one_visible"])
		)
		if String(method) == "CLEAN_REST":
			row["ok"] = vis_ok and not bool(row["playing"])
		else:
			await get_tree().create_timer(1.0).timeout
			var later: Dictionary = inst.call("get_playback_snapshot")
			row["snapshot_end"] = later.duplicate(true)
			row["end_position"] = later.get("current_position", 0.0)
			row["playing"] = bool(later.get("playing", false))
			row["advanced"] = absf(float(row["end_position"]) - float(row["start_position"])) > 0.02
			row["camera_unchanged"] = _cam_close(later.get("camera_position", [0.0, 0.0, 0.0]), cam_before)
			var has_idle: bool = str(later.get("animation_name", "")).to_lower().contains("idle")
			row["ok"] = vis_ok and bool(row["playing"]) and bool(row["advanced"]) and has_idle and bool(row["camera_unchanged"])
		out[method] = row
	return out


func _cam_close(a: Variant, b: Variant) -> bool:
	if typeof(a) != TYPE_ARRAY or typeof(b) != TYPE_ARRAY:
		return false
	if a.size() < 3 or b.size() < 3:
		return false
	var dx := float(a[0]) - float(b[0])
	var dy := float(a[1]) - float(b[1])
	var dz := float(a[2]) - float(b[2])
	return (dx * dx + dy * dy + dz * dz) < 0.000001


func _scene_deps_isolated(path: String) -> bool:
	var abs_path := ProjectSettings.globalize_path(path)
	if not FileAccess.file_exists(abs_path):
		return false
	var fh := FileAccess.open(abs_path, FileAccess.READ)
	if fh == null:
		return false
	var text := fh.get_as_text()
	for token in HUD_SCRIPTS:
		if text.find(token) != -1:
			return false
	return true
