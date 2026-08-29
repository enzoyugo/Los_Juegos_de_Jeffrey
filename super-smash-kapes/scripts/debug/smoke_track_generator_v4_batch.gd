extends SceneTree

## 100 seeds x 9 length/difficulty configs. Writes batch metrics JSON.

const GenScript := preload("res://scripts/track/track_generator_v2.gd")
const OUT_PATH := "res://docs/generated/track_generator_v4/batch_metrics.json"

const LENGTHS: PackedStringArray = ["SHORT", "MEDIUM", "LONG"]
const DIFFS: PackedStringArray = ["TRANQUI", "PICANTE", "DEMENTE"]
const SEEDS := 100


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	OS.set_environment("SSK_GEN_QUIET", "1")
	var gen = GenScript.new()
	var configs: Dictionary = {}
	var all_ok := true
	for length in LENGTHS:
		for diff in DIFFS:
			var key := "%s_%s" % [length, diff]
			var attempts: Array = []
			var reasons: Dictionary = {}
			var accepted_n := 0
			for i in SEEDS:
				var seed_n: int = 1000 + i
				var row: Dictionary = gen.generate(seed_n, length, diff)
				var ok := bool(row.get("accepted", false))
				var att: int = int(row.get("attempt", 0))
				if ok:
					accepted_n += 1
					attempts.append(att)
				else:
					attempts.append(40)
					var rr = row.get("rejection_reasons", [])
					if rr is Array or rr is PackedStringArray:
						for code in rr:
							var c := str(code)
							reasons[c] = int(reasons.get(c, 0)) + 1
			attempts.sort()
			var rate: float = float(accepted_n) / float(SEEDS)
			var median: float = _pct(attempts, 0.5)
			var p95: float = _pct(attempts, 0.95)
			var top := ""
			var top_n := -1
			for rk in reasons.keys():
				if int(reasons[rk]) > top_n:
					top_n = int(reasons[rk])
					top = str(rk)
			configs[key] = {
				"success_rate": rate,
				"median_attempt": median,
				"p95_attempt": p95,
				"accepted": accepted_n,
				"top_rejection": top,
				"reasons": reasons,
			}
			print("[TRACK_GENERATOR_V4] %s rate=%.3f median=%.1f p95=%.1f top=%s" % [
				key, rate, median, p95, top
			])
			if rate < 0.95:
				all_ok = false
	var payload := {"configs": configs, "ok": all_ok, "seeds": SEEDS}
	_write(OUT_PATH, payload)
	print("[TRACK_GENERATOR_V4] BATCH %s" % ("PASS" if all_ok else "PARTIAL"))
	quit(0 if all_ok else 1)


func _pct(sorted_vals: Array, p: float) -> float:
	if sorted_vals.is_empty():
		return 0.0
	var i: int = clampi(int(round(p * float(sorted_vals.size() - 1))), 0, sorted_vals.size() - 1)
	return float(sorted_vals[i])


func _write(path: String, payload: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(payload, "  "))
