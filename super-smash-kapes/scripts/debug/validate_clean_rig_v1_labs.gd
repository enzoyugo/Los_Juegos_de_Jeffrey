extends Node

const OUT_PATH := "res://docs/generated/CLEAN_RIG_V1_GODOT_LAB_VALIDATION.json"
const LABS := [
	"res://scenes/debug/TerereCleanRigV1Lab.tscn",
	"res://scenes/debug/JaguareteCleanRigV1Lab.tscn",
]


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var report := {
		"godot": Engine.get_version_info(),
		"labs": [],
		"all_ok": true,
	}
	await get_tree().process_frame
	for path in LABS:
		var packed: PackedScene = load(path)
		var row := {"scene": path, "ok": false}
		if packed == null:
			row["error"] = "scene_load_failed"
			report["all_ok"] = false
			report["labs"].append(row)
			continue
		var inst: Node = packed.instantiate()
		add_child(inst)
		await get_tree().process_frame
		await get_tree().process_frame
		if inst.has_method("collect_dump"):
			var dump: Dictionary = inst.call("collect_dump")
			row["dump"] = dump
			var hip: Dictionary = dump.get("bones", {}).get("hip", {})
			var head: Dictionary = dump.get("bones", {}).get("head", {})
			var l_foot: Dictionary = dump.get("bones", {}).get("l_foot", {})
			var upright := bool(head.get("found", false) and hip.get("found", false) and float(head.get("y", 0)) > float(hip.get("y", 0)))
			var feet_below := bool(l_foot.get("found", false) and hip.get("found", false) and float(l_foot.get("y", 0)) < float(hip.get("y", 0)))
			row["upright"] = upright
			row["feet_below_hip"] = feet_below
			row["ok"] = bool(dump.get("load_ok", false)) and int(dump.get("skeleton_count", 0)) == 1 and int(dump.get("bone_count", 0)) >= 90 and not bool(dump.get("fallback", true)) and upright
			if str(dump.get("pipeline", "")) != "CLEAN_RIG_V1":
				row["ok"] = false
				row["error"] = "wrong_pipeline"
			if str(dump.get("asset", "")).find("clean_rig_v1") == -1:
				row["ok"] = false
				row["error"] = "wrong_asset"
			if str(dump.get("asset", "")).find("game_ready") != -1:
				row["ok"] = false
				row["error"] = "v4_dependency"
		else:
			row["error"] = "no_collect_dump"
			report["all_ok"] = false
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
	print("CLEAN_RIG_LAB_VALIDATION_WRITTEN all_ok=%s path=%s" % [report["all_ok"], abs_path])
	get_tree().quit(0 if report["all_ok"] else 2)
