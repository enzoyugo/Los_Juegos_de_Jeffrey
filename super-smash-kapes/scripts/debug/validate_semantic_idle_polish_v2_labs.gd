extends Node

const OUT_PATH := "res://docs/generated/SEMANTIC_IDLE_POLISH_V2_GODOT.json"
const LABS := [
	"res://scenes/debug/TerereSemanticIdlePolishV2Lab.tscn",
]
const FORBIDDEN := [
	"game_ready_v4",
	"game_ready_v3",
	"semantic_solver_v2",
	"solver_v1",
	"actorcore_benchmark",
	"source_rigged",
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
			row["ok"] = bool(dump.get("load_ok", false)) and str(dump.get("pipeline", "")) == "SEMANTIC_IDLE_POLISH_V2"
			for token in FORBIDDEN:
				for key in ["baseline_glb", "v1_glb", "v2a_glb", "v2b_glb", "v2c_glb"]:
					if str(dump.get(key, "")).find(token) != -1:
						row["ok"] = false
						row["error"] = "forbidden_asset_%s" % token
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
	print("SEMANTIC_IDLE_POLISH_V2_LAB_VALIDATION_WRITTEN all_ok=%s path=%s" % [report["all_ok"], abs_path])
	get_tree().quit(0 if report["all_ok"] else 2)
