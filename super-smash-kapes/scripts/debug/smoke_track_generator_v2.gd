extends SceneTree

## Headless: generate the three frozen showcases, write smoke JSON, quit.

const GenScript := preload("res://scripts/track/track_generator_v2.gd")
const SHOWCASES_PATH := "res://data/track/generator_v2_showcases.json"
const SMOKE_PATH := "res://docs/generated/track_generator_v2/smoke.json"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var parse_paths: PackedStringArray = [
		"res://scripts/track/track_generator_v2.gd",
		"res://scripts/track/track_generator_v2_validator.gd",
		"res://scripts/track/track_generator_v2_lab.gd",
		"res://scripts/track/track_surface.gd",
		"res://scripts/debug/track_boost_reset_lab.gd",
		"res://scripts/track/track_piece.gd",
		"res://scripts/track/track_wheel_car.gd",
		"res://scripts/track/track_jump_trajectory_lab.gd",
		"res://scripts/debug/smoke_track_generator_v4_batch.gd",
		"res://scripts/debug/smoke_track_4wheel_module_compat.gd",
	]
	for path in parse_paths:
		var loaded: Resource = load(path)
		if loaded == null:
			print("[TRACK_GENERATOR_V2] SCRIPT ERROR load_failed %s" % path)
			quit(1)
			return
		print("[TRACK_GENERATOR_V2] parse_ok %s" % path)
	var gen = GenScript.new()
	if OS.get_environment("SSK_GEN_FIND_SEEDS").strip_edges() == "1":
		_find_seeds(gen)
		quit(0)
		return
	var showcases: Dictionary = _load_showcases()
	var payload := {"showcases": {}, "accepted": true}
	var keys: PackedStringArray = ["SHORT_SHOWCASE", "MEDIUM_SHOWCASE", "LONG_SHOWCASE"]
	var all_ok := true
	for key in keys:
		var row_raw = showcases.get(key, {})
		var row: Dictionary = {}
		if row_raw is Dictionary:
			row = row_raw
		var seed_n: int = int(row.get("seed", 1))
		var length := str(row.get("length", "SHORT"))
		var difficulty := str(row.get("difficulty", "PICANTE"))
		var result: Dictionary = gen.generate(seed_n, length, difficulty)
		var ok := bool(result.get("accepted", false))
		if not ok:
			all_ok = false
		payload["showcases"][key] = _plain(result)
		if ok:
			print("[TRACK_GENERATOR_V2] ACCEPTED")
	payload["accepted"] = all_ok
	_write_json(SMOKE_PATH, payload)
	if all_ok:
		print("[TRACK_GENERATOR_V2] ACCEPTED")
		quit(0)
	else:
		print("[TRACK_GENERATOR_V2] SMOKE_FAIL")
		quit(1)


func _find_seeds(gen) -> void:
	var specs := [
		{
			"key": "SHORT_SHOWCASE",
			"length": "SHORT",
			"difficulty": "PICANTE",
			"start": 11,
			"limit": 80,
			"need_any": PackedStringArray(["curve_l_90", "curve_r_90"]),
			"need_all": PackedStringArray(["straight_short", "boost_straight"]),
		},
		{
			"key": "MEDIUM_SHOWCASE",
			"length": "MEDIUM",
			"difficulty": "PICANTE",
			"start": 21,
			"limit": 80,
			"need_any": PackedStringArray(["chicane_lr", "chicane_rl"]),
			"need_all": PackedStringArray(["boost_straight"]),
		},
		{
			"key": "LONG_SHOWCASE",
			"length": "LONG",
			"difficulty": "DEMENTE",
			"start": 31,
			"limit": 150,
			"need_any": PackedStringArray(["boost_straight"]),
			"need_all": PackedStringArray(["straight_long", "straight_short"]),
		},
	]
	var out := {}
	for spec in specs:
		var key := str(spec["key"])
		var length := str(spec["length"])
		var difficulty := str(spec["difficulty"])
		var start_n: int = int(spec["start"])
		var limit_n: int = int(spec["limit"])
		var need_any: PackedStringArray = PackedStringArray()
		var need_all: PackedStringArray = PackedStringArray()
		var need_any_raw = spec["need_any"]
		var need_all_raw = spec["need_all"]
		if need_any_raw is PackedStringArray:
			need_any = need_any_raw
		elif need_any_raw is Array:
			for item in need_any_raw:
				need_any.append(str(item))
		if need_all_raw is PackedStringArray:
			need_all = need_all_raw
		elif need_all_raw is Array:
			for item in need_all_raw:
				need_all.append(str(item))
		print("[TRACK_GENERATOR_V2] FIND %s length=%s" % [key, length])
		var found: Dictionary = gen.search_accepted_seed_containing(length, difficulty, start_n, limit_n, need_any, need_all)
		if found.is_empty():
			found = gen.search_accepted_seed(length, difficulty, start_n, limit_n)
		if found.is_empty():
			print("[TRACK_GENERATOR_V2] FIND_FAIL %s" % key)
			out[key] = {"seed": start_n, "length": length, "difficulty": difficulty, "accepted": false}
			continue
		var seq_raw = found.get("piece_sequence", [])
		var seq: Array = []
		if seq_raw is Array:
			for item in seq_raw:
				seq.append(str(item))
		out[key] = {
			"seed": int(found.get("seed", start_n)),
			"length": length,
			"difficulty": difficulty,
			"piece_count": int(found.get("piece_count", 0)),
			"path_m": float(found.get("path_m", 0.0)),
			"turns": int(found.get("turns", 0)),
			"attempt": int(found.get("attempt", 0)),
			"piece_sequence": seq,
		}
		print("[TRACK_GENERATOR_V2] FIND_OK %s seed=%d pieces=%d path=%.1f" % [
			key, int(found.get("seed", 0)), int(found.get("piece_count", 0)), float(found.get("path_m", 0.0))
		])
	_write_json(SHOWCASES_PATH, out)
	_write_json(SMOKE_PATH, {"showcases": out, "accepted": true})


func _load_showcases() -> Dictionary:
	if not FileAccess.file_exists(SHOWCASES_PATH):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(SHOWCASES_PATH))
	if parsed is Dictionary:
		return parsed
	return {}


func _plain(row: Dictionary) -> Dictionary:
	var seq_raw = row.get("piece_sequence", [])
	var seq: Array = []
	if seq_raw is Array:
		for item in seq_raw:
			seq.append(str(item))
	return {
		"seed": int(row.get("seed", 0)),
		"length": str(row.get("length", "")),
		"difficulty": str(row.get("difficulty", "")),
		"accepted": bool(row.get("accepted", false)),
		"piece_count": int(row.get("piece_count", 0)),
		"path_m": float(row.get("path_m", 0.0)),
		"turns": int(row.get("turns", 0)),
		"attempt": int(row.get("attempt", 0)),
		"piece_sequence": seq,
	}


func _write_json(path: String, payload: Dictionary) -> void:
	var dir_path := path.get_base_dir()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir_path))
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(payload, "  "))
