extends Node

const OUT_PATH := "res://docs/generated/V5_ANIMATION_COMPATIBILITY_GODOT_LAB_VALIDATION.json"
const LABS := [
	"res://scenes/debug/TerereV5AnimationCompatibilityLab.tscn",
	"res://scenes/debug/JaguareteV5AnimationCompatibilityLab.tscn",
]


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var report := {
		"godot": Engine.get_version_info(),
		"labs": [],
		"all_ok": true,
		"pipeline": "V5_ANIMATION_COMPATIBILITY",
		"v5_is_canonical": false,
		"production_untouched": true,
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
			var cands: Dictionary = dump.get("candidates", {})
			var needed := ["V1_IDLE", "V5_IDLE", "V1_REACTION", "V5_REACTION", "V5_REACTION_MEDIUM"]
			var all_loaded := true
			for id in needed:
				var cand: Dictionary = cands.get(id, {})
				if not bool(cand.get("loaded", false)) or int(cand.get("bone_count", 0)) < 80:
					all_loaded = false
			var height_ok := true
			for id in needed:
				var pres: Dictionary = cands.get(id, {}).get("presentation", {})
				var got := float(pres.get("presentation_height", 0.0))
				var native := float(pres.get("native_height", 0.0))
				if abs(got - float(dump.get("target_height", 0.0))) > 0.01 or native < 0.4:
					height_ok = false
			row["ok"] = bool(dump.get("load_ok", false)) and all_loaded and height_ok and str(dump.get("pipeline", "")) == "V5_ANIMATION_COMPATIBILITY"
			if not row["ok"] and not row.has("error"):
				row["error"] = "candidate_or_scale_failed"
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
	print("V5_ANIM_COMPAT_LAB_VALIDATION_WRITTEN all_ok=%s path=%s" % [report["all_ok"], abs_path])
	get_tree().quit(0 if report["all_ok"] else 2)
