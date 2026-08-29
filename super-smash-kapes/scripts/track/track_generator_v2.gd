class_name TrackGeneratorV2
extends RefCounted

## Incremental constraint-aware assembler. Limited backtracking. Validate → retry.

const Registry := preload("res://scripts/track/track_piece_registry.gd")
const ValidatorScript := preload("res://scripts/track/track_generator_v2_validator.gd")

const MAX_ATTEMPTS := 40
const POOL_IDS: PackedStringArray = [
	"straight_short",
	"straight_medium",
	"straight_long",
	"landing_straight_long",
	"boost_straight",
	"curve_l_45",
	"curve_r_45",
	"curve_l_90",
	"curve_r_90",
	"chicane_lr",
	"chicane_rl",
	"slope_up_gentle",
	"slope_down_gentle",
	"crest_gentle",
]
const LENGTH_SHORT := "SHORT"
const LENGTH_MEDIUM := "MEDIUM"
const LENGTH_LONG := "LONG"
const DIFF_TRANQUI := "TRANQUI"
const DIFF_PICANTE := "PICANTE"
const DIFF_DEMENTE := "DEMENTE"


func generate(seed_value: int, length_id: String, difficulty_id: String) -> Dictionary:
	var quiet := OS.get_environment("SSK_GEN_QUIET").strip_edges() == "1"
	var length := normalize_length(length_id)
	var difficulty := normalize_difficulty(difficulty_id)
	var validator = ValidatorScript.new()
	var accumulated: PackedStringArray = PackedStringArray()
	var last: Dictionary = {}
	for attempt in MAX_ATTEMPTS:
		var rng := RandomNumberGenerator.new()
		rng.seed = int(seed_value) * 10007 + int(attempt) * 17
		var sequence: Array = _compose(rng, length, difficulty, validator)
		if sequence.is_empty():
			# COMPOSE_EMPTY: skip; do not treat as START/FINISH exploration.
			continue
		var checked: Dictionary = validator.validate(sequence, length, difficulty)
		var reasons_raw = checked["reasons"]
		var reasons: PackedStringArray = PackedStringArray()
		if reasons_raw is PackedStringArray:
			reasons = reasons_raw
		elif reasons_raw is Array:
			for item in reasons_raw:
				reasons.append(str(item))
		var ok := bool(checked["ok"])
		var path_m: float = float(checked["path_m"])
		var turns: int = int(checked["turns"])
		var elev: float = float(checked["elev"])
		var reject_str := "" if ok else ",".join(reasons)
		if not quiet:
			print("[TRACK_GENERATOR_V2] seed=%d attempt=%d length=%s difficulty=%s pieces=%d path_m=%.1f turns=%d elev=%.2f reject=%s" % [
				seed_value,
				attempt,
				length,
				difficulty,
				sequence.size(),
				path_m,
				turns,
				elev,
				reject_str,
			])
		for code in reasons:
			if not accumulated.has(code):
				accumulated.append(code)
		last = _pack(
			seed_value,
			attempt,
			length,
			difficulty,
			sequence,
			checked,
			ok,
			accumulated
		)
		if ok:
			if not quiet:
				print("[TRACK_GENERATOR_V2] ACCEPTED")
			return last
	if last.is_empty():
		last = _pack(
			seed_value,
			MAX_ATTEMPTS - 1,
			length,
			difficulty,
			[],
			{"ok": false, "reasons": PackedStringArray(["DRIVEABILITY"]), "path_m": 0.0, "turns": 0, "elev": 0.0, "poses": []},
			false,
			accumulated
		)
	last["accepted"] = false
	last["validation_result"] = "fail"
	return last


func normalize_length(length_id: String) -> String:
	var key := length_id.strip_edges().to_upper()
	if key == "CORTA" or key == "SHORT":
		return LENGTH_SHORT
	if key == "MEDIA" or key == "MEDIUM":
		return LENGTH_MEDIUM
	if key == "LARGA" or key == "LONG":
		return LENGTH_LONG
	var lower := length_id.strip_edges().to_lower()
	if lower == "corta":
		return LENGTH_SHORT
	if lower == "media":
		return LENGTH_MEDIUM
	if lower == "larga":
		return LENGTH_LONG
	return LENGTH_MEDIUM


func normalize_difficulty(difficulty_id: String) -> String:
	var key := difficulty_id.strip_edges().to_upper()
	if key == "TRANQUI":
		return DIFF_TRANQUI
	if key == "PICANTE":
		return DIFF_PICANTE
	if key == "DEMENTE":
		return DIFF_DEMENTE
	var lower := difficulty_id.strip_edges().to_lower()
	if lower == "tranqui":
		return DIFF_TRANQUI
	if lower == "picante":
		return DIFF_PICANTE
	if lower == "demente":
		return DIFF_DEMENTE
	return DIFF_PICANTE


func search_accepted_seed(length_id: String, difficulty_id: String, start_from: int, limit: int) -> Dictionary:
	var begin: int = maxi(start_from, 1)
	var cap: int = maxi(limit, 1)
	for offset in cap:
		var seed_n: int = begin + offset
		var result: Dictionary = generate(seed_n, length_id, difficulty_id)
		if bool(result.get("accepted", false)):
			return result
	return {}


func search_accepted_seed_containing(length_id: String, difficulty_id: String, start_from: int, limit: int, need_any: PackedStringArray, need_all: PackedStringArray) -> Dictionary:
	var begin: int = maxi(start_from, 1)
	var cap: int = maxi(limit, 1)
	for offset in cap:
		var seed_n: int = begin + offset
		var result: Dictionary = generate(seed_n, length_id, difficulty_id)
		if not bool(result.get("accepted", false)):
			continue
		var seq_raw = result.get("piece_sequence", [])
		var seq: Array = seq_raw if seq_raw is Array else []
		if not _seq_has_any(seq, need_any):
			continue
		if not _seq_has_all(seq, need_all):
			continue
		return result
	return {}


func _seq_has_any(seq: Array, ids: PackedStringArray) -> bool:
	if ids.is_empty():
		return true
	for pid in seq:
		if ids.has(str(pid)):
			return true
	return false


func _seq_has_all(seq: Array, ids: PackedStringArray) -> bool:
	for want in ids:
		var found := false
		for pid in seq:
			if str(pid) == want:
				found = true
				break
		if not found:
			return false
	return true


func _compose(rng: RandomNumberGenerator, length: String, difficulty: String, validator) -> Array:
	var bands_raw = ValidatorScript.LENGTH_BANDS[length]
	var band: Dictionary = {}
	if bands_raw is Dictionary:
		band = bands_raw
	if band.is_empty():
		return []
	var min_path: float = float(band["min_path"])
	var max_path: float = float(band["max_path"])
	var min_pieces: int = int(band["min_pieces"])
	var max_pieces: int = int(band["max_pieces"])
	var seq: Array = ["start"]
	var tried_at: Dictionary = {}
	var guard := 0
	var consecutive_backtracks := 0
	while guard < 48:
		guard += 1
		var path_m: float = _path_of(seq, validator)
		var last_id := str(seq[seq.size() - 1])
		var last_straight := ValidatorScript.is_straight(last_id)
		var finish_extra_path: float = _len_of(validator, "finish")
		var finish_extra_pieces := 1
		if not last_straight:
			finish_extra_path += _len_of(validator, "straight_medium")
			finish_extra_pieces += 1
		var projected_path: float = path_m + finish_extra_path
		var projected_n: int = seq.size() + finish_extra_pieces
		var can_finish := projected_path >= min_path and projected_n >= min_pieces and projected_path <= max_path and projected_n <= max_pieces
		var must_finish := projected_n >= max_pieces - 1 or projected_path >= max_path * 0.92
		if can_finish and (must_finish or _meets_difficulty_preview(seq, difficulty, length) or rng.randf() < 0.22):
			var closed: Array = _close_track(seq, length, difficulty, validator)
			if not closed.is_empty():
				return closed
		if seq.size() + 2 >= max_pieces or path_m + finish_extra_path > max_path:
			var closed_cap: Array = _close_track(seq, length, difficulty, validator)
			if not closed_cap.is_empty():
				return closed_cap
			if not _backtrack_seq(seq, tried_at, mini(3, seq.size() - 1)):
				return []
			consecutive_backtracks += 1
			if consecutive_backtracks > 5:
				return []
			continue
		var depth: int = seq.size()
		if not tried_at.has(depth):
			tried_at[depth] = {}
		var used: Dictionary = tried_at[depth]
		var cands: Array = _legal_candidates(rng, seq, length, difficulty, validator, used, max_path - path_m)
		if cands.is_empty():
			var nback: int = 1 if consecutive_backtracks == 0 else mini(3, seq.size() - 1)
			if not _backtrack_seq(seq, tried_at, nback):
				return []
			consecutive_backtracks += 1
			if consecutive_backtracks > 5:
				return []
			continue
		var pid := str(_weighted_pick(rng, seq, cands, validator, difficulty, length))
		used[pid] = true
		if not _try_append(seq, pid, difficulty, validator, false):
			continue
		consecutive_backtracks = 0
	return []


func _section_plan(rng: RandomNumberGenerator, length: String, difficulty: String) -> Array:
	var plan: Array = []
	if difficulty == DIFF_TRANQUI:
		plan = ["RECOVERY", "FLOW", "SPEED", "RECOVERY", "FLOW"]
		if length == LENGTH_MEDIUM:
			plan.append_array(["RECOVERY", "FLOW", "SPEED", "RECOVERY"])
		elif length == LENGTH_LONG:
			plan.append_array(["SPEED", "FLOW", "RECOVERY", "SPEED", "FLOW", "RECOVERY", "SPEED"])
	elif difficulty == DIFF_PICANTE:
		plan = ["SPEED", "TECH", "FLOW", "RECOVERY"]
		if length == LENGTH_MEDIUM:
			plan.append_array(["FLOW", "TECH", "SPEED", "RECOVERY"])
		elif length == LENGTH_LONG:
			plan.append_array(["SPEED", "FLOW", "RECOVERY", "TECH", "SPEED", "RECOVERY"])
	else:
		plan = ["SPEED", "TECH", "FLOW", "RECOVERY"]
		if length == LENGTH_MEDIUM:
			plan.append_array(["TECH", "FLOW", "SPEED", "RECOVERY"])
		elif length == LENGTH_LONG:
			plan.append_array(["SPEED", "FLOW", "TECH", "RECOVERY", "SPEED", "FLOW"])
	if plan.size() > 2:
		var i: int = rng.randi_range(1, plan.size() - 2)
		var j: int = rng.randi_range(1, plan.size() - 2)
		var tmp = plan[i]
		plan[i] = plan[j]
		plan[j] = tmp
	return plan


func _extra_section(rng: RandomNumberGenerator, seq: Array, difficulty: String, remaining: float) -> String:
	if remaining > 90.0:
		if difficulty == DIFF_TRANQUI:
			return "RECOVERY" if rng.randf() < 0.55 else "SPEED"
		return "SPEED" if rng.randf() < 0.5 else "FLOW"
	if remaining > 50.0:
		return "FLOW" if rng.randf() < 0.4 else "RECOVERY"
	return "RECOVERY"


func _expand_section(rng: RandomNumberGenerator, kind: String, seq: Array, difficulty: String, length: String, validator) -> Array:
	var dir := _pick_dir(rng, seq, validator)
	if kind == "SPEED":
		var boosts := _count_id(seq, "boost_straight")
		var allow_boost := true
		if difficulty == DIFF_TRANQUI and boosts >= 1:
			allow_boost = false
		if difficulty == DIFF_PICANTE and boosts >= 2:
			allow_boost = false
		if difficulty == DIFF_DEMENTE and boosts >= 2:
			allow_boost = false
		if allow_boost and (difficulty != DIFF_TRANQUI or rng.randf() < 0.45):
			if rng.randf() < 0.55 or boosts == 0:
				return ["straight_medium", "boost_straight", "straight_short"]
		return ["straight_long"]
	if kind == "FLOW":
		var a := "curve_l_45" if dir == "L" else "curve_r_45"
		var rec := "straight_long" if length == LENGTH_LONG or difficulty == DIFF_TRANQUI else "straight_medium"
		if rng.randf() < 0.35:
			rec = "straight_short"
		return [a, "straight_short", a, rec]
	if kind == "TECH":
		if difficulty == DIFF_TRANQUI:
			var mild := "curve_l_45" if dir == "L" else "curve_r_45"
			return ["straight_short", mild, "straight_short"]
		var ninety := "curve_l_90" if dir == "L" else "curve_r_90"
		var out: Array = ["straight_short", ninety, "straight_short"]
		var want_chicane := false
		if difficulty == DIFF_PICANTE:
			want_chicane = rng.randf() < 0.55 or _count_prefix(seq, "chicane_") == 0
		elif difficulty == DIFF_DEMENTE:
			want_chicane = rng.randf() < 0.72
		if want_chicane and not ValidatorScript.is_chicane(str(seq[seq.size() - 1])):
			out.append("chicane_lr" if rng.randf() < 0.5 else "chicane_rl")
		if length != LENGTH_SHORT and _count_id(seq, "landing_straight_long") == 0 and rng.randf() < 0.22:
			out.append("landing_straight_long")
		return out
	if kind == "RECOVERY":
		if _count_id(seq, "landing_straight_long") == 0 and _has_recent_tech(seq) and rng.randf() < 0.28:
			return ["landing_straight_long"]
		if rng.randf() < 0.22:
			if _exit_height(seq, validator) > 0.8:
				return ["slope_down_gentle"]
			if rng.randf() < 0.45:
				return ["crest_gentle"]
			return ["slope_up_gentle", "straight_short"]
		if difficulty == DIFF_DEMENTE:
			return ["straight_medium" if rng.randf() < 0.6 else "straight_short"]
		if length == LENGTH_LONG or rng.randf() < 0.55:
			return ["straight_long"]
		return ["straight_medium"]
	return ["straight_medium"]


func _alt_id(piece_id: String) -> String:
	if piece_id == "curve_l_45":
		return "curve_r_45"
	if piece_id == "curve_r_45":
		return "curve_l_45"
	if piece_id == "curve_l_90":
		return "curve_r_90"
	if piece_id == "curve_r_90":
		return "curve_l_90"
	if piece_id == "chicane_lr":
		return "chicane_rl"
	if piece_id == "chicane_rl":
		return "chicane_lr"
	return piece_id


func _pick_dir(rng: RandomNumberGenerator, seq: Array, validator) -> String:
	var cum := 0.0
	for raw_id in seq:
		var meta: Dictionary = validator.meta_for(str(raw_id))
		cum += float(meta.get("yaw_delta", 0.0))
	if absf(cum) > 0.7:
		return "R" if cum > 0.0 else "L"
	return "L" if rng.randf() < 0.5 else "R"


func _try_append(seq: Array, piece_id: String, difficulty: String, validator, check_spatial: bool = true) -> bool:
	if not _can_place(seq, piece_id, difficulty):
		return false
	if check_spatial and not _fits_spatial(seq, piece_id, validator):
		return false
	seq.append(piece_id)
	return true


func _can_place(seq: Array, piece_id: String, difficulty: String) -> bool:
	if piece_id == "start":
		return false
	if piece_id == "finish":
		return seq.size() > 1
	if seq.is_empty():
		return true
	var last := str(seq[seq.size() - 1])
	if seq.size() >= 2:
		var prev := str(seq[seq.size() - 2])
		if last == piece_id and prev == piece_id:
			return false
	if ValidatorScript.is_elevation(piece_id) and ValidatorScript.is_elevation(last):
		if ValidatorScript.is_slope_up(last) and ValidatorScript.is_slope_up(piece_id):
			return false
		if seq.size() >= 2 and ValidatorScript.is_elevation(str(seq[seq.size() - 2])):
			return false
	if ValidatorScript.is_elevation(piece_id):
		var elev_n := 0
		for raw_id in seq:
			if ValidatorScript.is_elevation(str(raw_id)):
				elev_n += 1
		if elev_n >= 3:
			return false
	if piece_id == "landing_straight_long":
		if _count_id(seq, "landing_straight_long") >= 1:
			return false
		if not _has_recent_tech(seq) and not _has_any_tech(seq):
			return false
	if ValidatorScript.is_chicane(piece_id) and ValidatorScript.is_chicane(last):
		return false
	if ValidatorScript.is_chicane(piece_id) and not ValidatorScript.is_straight(last):
		return false
	if last == "boost_straight" and piece_id == "boost_straight":
		return false
	if last == "boost_straight" and not ValidatorScript.is_straight(piece_id):
		return false
	if last == "boost_straight" and ValidatorScript.is_ninety(piece_id):
		return false
	if last == "boost_straight" and ValidatorScript.is_chicane(piece_id):
		return false
	if ValidatorScript.is_ninety(piece_id) and last == "boost_straight":
		return false
	if ValidatorScript.is_ninety(last) and ValidatorScript.is_ninety(piece_id):
		if ValidatorScript.curve_dir(last) != ValidatorScript.curve_dir(piece_id):
			return false
	if ValidatorScript.is_curve(last) and ValidatorScript.is_curve(piece_id):
		if difficulty == DIFF_TRANQUI:
			return false
		if ValidatorScript.curve_dir(last) != ValidatorScript.curve_dir(piece_id):
			return false
		if seq.size() >= 2 and ValidatorScript.is_curve(str(seq[seq.size() - 2])):
			return false
	if difficulty == DIFF_TRANQUI:
		if ValidatorScript.is_chicane(piece_id):
			return false
		if ValidatorScript.is_ninety(piece_id) and _count_nineties(seq) >= 1:
			return false
		if piece_id == "boost_straight" and _count_id(seq, "boost_straight") >= 1:
			return false
	return true


func _has_recent_tech(seq: Array) -> bool:
	var n: int = seq.size()
	var start_i: int = maxi(n - 4, 0)
	for i in range(start_i, n):
		var pid := str(seq[i])
		if ValidatorScript.is_ninety(pid) or ValidatorScript.is_chicane(pid):
			return true
	return false


func _has_any_tech(seq: Array) -> bool:
	for raw_id in seq:
		var pid := str(raw_id)
		if ValidatorScript.is_ninety(pid) or ValidatorScript.is_chicane(pid):
			return true
	return false


func _count_id(seq: Array, piece_id: String) -> int:
	var n := 0
	for raw_id in seq:
		if str(raw_id) == piece_id:
			n += 1
	return n


func _count_prefix(seq: Array, prefix: String) -> int:
	var n := 0
	for raw_id in seq:
		if str(raw_id).begins_with(prefix):
			n += 1
	return n


func _fits_spatial(seq: Array, piece_id: String, validator) -> bool:
	var sim: Dictionary = validator.simulate(seq)
	var poses_raw = sim["poses"]
	var poses: Array = []
	if poses_raw is Array:
		poses = poses_raw
	if poses.is_empty():
		return true
	var last: Dictionary = poses[poses.size() - 1]
	var cursor_raw = last["world_exit"]
	var cursor: Transform3D = cursor_raw
	var nxt: Dictionary = validator.next_pose(cursor, piece_id)
	var aabb_last_raw = nxt["aabb"]
	var aabb_last: AABB = aabb_last_raw
	if poses.size() < 2:
		return true
	var grid := OccupancyIndex.new()
	for i in poses.size():
		var prev: Dictionary = poses[i]
		var aabb_prev_raw = prev["aabb"]
		var aabb_prev: AABB = aabb_prev_raw
		grid.insert(i, aabb_prev)
	var nearby: Dictionary = grid.nearby(aabb_last)
	var n_trial: int = poses.size() + 1
	for key in nearby.keys():
		var i: int = int(key)
		if i >= n_trial - 2:
			continue
		var prev2: Dictionary = poses[i]
		var aabb_prev2_raw = prev2["aabb"]
		var aabb_prev2: AABB = aabb_prev2_raw
		if validator.xz_overlap(aabb_last, aabb_prev2) and not validator.y_ranges_overlap(aabb_last, aabb_prev2):
			return false
		if not aabb_last.intersects(aabb_prev2):
			continue
		var last_boxes_raw = nxt["boxes"]
		var prev_boxes_raw = prev2["boxes"]
		var last_boxes: Array = last_boxes_raw if last_boxes_raw is Array else []
		var prev_boxes: Array = prev_boxes_raw if prev_boxes_raw is Array else []
		if validator.boxes_overlap(last_boxes, prev_boxes):
			return false
	return true


func _path_of(seq: Array, validator) -> float:
	var total := 0.0
	for raw_id in seq:
		total += _len_of(validator, str(raw_id))
	return total


func _count_nineties(seq: Array) -> int:
	var n := 0
	for raw_id in seq:
		if ValidatorScript.is_ninety(str(raw_id)):
			n += 1
	return n


func _backtrack_seq(seq: Array, tried_at: Dictionary, count: int) -> bool:
	var n: int = maxi(count, 1)
	var popped := 0
	while popped < n and seq.size() > 1:
		seq.pop_back()
		tried_at.erase(seq.size() + 1)
		popped += 1
	return seq.size() > 0 and str(seq[0]) == "start"


func _legal_candidates(rng: RandomNumberGenerator, seq: Array, length: String, difficulty: String, validator, used: Dictionary, remaining: float) -> Array:
	var preferred: Array = _expand_section(rng, _extra_section(rng, seq, difficulty, remaining), seq, difficulty, length, validator)
	var base_sim: Dictionary = validator.simulate(seq)
	var pool: Array = []
	for pid in preferred:
		var id := str(pid)
		if used.has(id):
			continue
		if _can_place(seq, id, difficulty) and _fits_from_sim(base_sim, id, validator):
			pool.append(id)
	for id in POOL_IDS:
		if used.has(id) or pool.has(id):
			continue
		if remaining < 18.0 and ValidatorScript.is_ninety(id):
			continue
		if remaining < 22.0 and ValidatorScript.is_chicane(id):
			continue
		if _can_place(seq, id, difficulty) and _fits_from_sim(base_sim, id, validator):
			pool.append(id)
	return pool


func _weighted_pick(rng: RandomNumberGenerator, seq: Array, pool: Array, validator, difficulty: String, length: String) -> String:
	if pool.is_empty():
		return "straight_medium"
	var sim: Dictionary = validator.simulate(seq)
	var total := 0.0
	var weights: Array = []
	for raw in pool:
		var w: float = _cheap_score(seq, str(raw), sim, validator, difficulty, length)
		weights.append(w)
		total += w
	if total <= 0.0001:
		return str(pool[rng.randi_range(0, pool.size() - 1)])
	var r: float = rng.randf() * total
	var acc := 0.0
	for i in pool.size():
		acc += float(weights[i])
		if r <= acc:
			return str(pool[i])
	return str(pool[pool.size() - 1])


func _cheap_score(seq: Array, piece_id: String, sim: Dictionary, validator, difficulty: String, length: String) -> float:
	var w := _candidate_score(seq, piece_id, validator, difficulty, length)
	var frac: float = _curve_frac(seq)
	var target := 0.22
	if difficulty == DIFF_PICANTE:
		target = 0.38
	elif difficulty == DIFF_DEMENTE:
		target = 0.42
	if frac < target - 0.04 and ValidatorScript.is_curve(piece_id) and not ValidatorScript.is_ninety(piece_id):
		w += 2.4
	if frac < target - 0.10 and ValidatorScript.is_ninety(piece_id) and difficulty != DIFF_TRANQUI:
		w += 1.6
	if frac > target + 0.10 and ValidatorScript.is_curve(piece_id):
		w *= 0.22
	if frac < 0.12 and ValidatorScript.is_recovery_straight(piece_id) and seq.size() > 4:
		w *= 0.45
	if difficulty == DIFF_DEMENTE and not _has_any_tech(seq):
		if ValidatorScript.is_ninety(piece_id) or ValidatorScript.is_chicane(piece_id):
			w += 2.8
	if difficulty == DIFF_DEMENTE and length == LENGTH_LONG and _count_id(seq, "boost_straight") < 1:
		if piece_id == "boost_straight":
			w += 2.2
	w *= 1.0 + 0.55 * _heading_from_sim(sim, piece_id, validator)
	if difficulty == DIFF_TRANQUI:
		if piece_id == "straight_long":
			w += 2.6
		elif piece_id == "straight_medium":
			w += 1.2
		if ValidatorScript.is_ninety(piece_id) or ValidatorScript.is_chicane(piece_id):
			w *= 0.12
	return maxf(w, 0.01)


func _candidate_score(seq: Array, piece_id: String, validator, difficulty: String, length: String) -> float:
	var w := 1.0
	if ValidatorScript.is_recovery_straight(piece_id):
		w = 1.15
	if piece_id == "straight_long" and length == LENGTH_LONG:
		w = 1.25
	if ValidatorScript.is_curve(piece_id) and not ValidatorScript.is_ninety(piece_id):
		w = 1.05
	if ValidatorScript.is_ninety(piece_id):
		w = 0.52 if difficulty != DIFF_TRANQUI else 0.08
	if ValidatorScript.is_chicane(piece_id):
		w = 0.0 if difficulty == DIFF_TRANQUI else (0.48 if difficulty == DIFF_PICANTE else 0.62)
	if piece_id == "boost_straight":
		var boosts := _count_id(seq, "boost_straight")
		w = 0.42
		if difficulty == DIFF_TRANQUI and boosts >= 1:
			w = 0.0
		if difficulty != DIFF_TRANQUI and boosts >= 2:
			w = 0.05
	if ValidatorScript.is_elevation(piece_id):
		w = 0.28
		if ValidatorScript.is_slope_down(piece_id) and _count_id(seq, "slope_up_gentle") == 0:
			w = 0.08
	if piece_id == "landing_straight_long":
		w = 0.18
	return w


func _curve_frac(seq: Array) -> float:
	var body := 0
	var curves := 0
	for raw_id in seq:
		var pid := str(raw_id)
		if pid == "start" or pid == "finish":
			continue
		body += 1
		if ValidatorScript.is_curve(pid):
			curves += 1
	if body <= 0:
		return 0.0
	return float(curves) / float(body)


func _meets_difficulty_preview(seq: Array, difficulty: String, length: String) -> bool:
	var frac: float = _curve_frac(seq)
	if _count_curves(seq) <= 0:
		return false
	if difficulty == DIFF_TRANQUI:
		return frac <= 0.42 and _count_id(seq, "boost_straight") <= 1 and _count_nineties(seq) <= 1 and _count_prefix(seq, "chicane_") == 0
	if difficulty == DIFF_PICANTE:
		return frac >= 0.20 and frac <= 0.64
	if _count_nineties(seq) + _count_prefix(seq, "chicane_") < 1:
		return false
	if length == LENGTH_LONG and _count_id(seq, "boost_straight") < 1:
		return false
	return frac >= 0.24 and frac <= 0.78


func _count_curves(seq: Array) -> int:
	var n := 0
	for raw_id in seq:
		if ValidatorScript.is_curve(str(raw_id)):
			n += 1
	return n


func _fits_from_sim(sim: Dictionary, piece_id: String, validator) -> bool:
	var poses_raw = sim.get("poses", [])
	var poses: Array = poses_raw if poses_raw is Array else []
	if poses.is_empty():
		return true
	var last: Dictionary = poses[poses.size() - 1]
	var cursor_raw = last["world_exit"]
	var cursor: Transform3D = cursor_raw
	var nxt: Dictionary = validator.next_pose(cursor, piece_id)
	var aabb_last_raw = nxt["aabb"]
	var aabb_last: AABB = aabb_last_raw
	if poses.size() < 2:
		return true
	var grid := OccupancyIndex.new()
	for i in poses.size():
		var prev: Dictionary = poses[i]
		var aabb_prev_raw = prev["aabb"]
		grid.insert(i, aabb_prev_raw)
	var nearby: Dictionary = grid.nearby(aabb_last)
	var n_trial: int = poses.size() + 1
	for key in nearby.keys():
		var i: int = int(key)
		if i >= n_trial - 2:
			continue
		var prev2: Dictionary = poses[i]
		var aabb_prev2_raw = prev2["aabb"]
		var aabb_prev2: AABB = aabb_prev2_raw
		if validator.xz_overlap(aabb_last, aabb_prev2) and not validator.y_ranges_overlap(aabb_last, aabb_prev2):
			return false
		if not aabb_last.intersects(aabb_prev2):
			continue
		var last_boxes_raw = nxt["boxes"]
		var prev_boxes_raw = prev2["boxes"]
		var last_boxes: Array = last_boxes_raw if last_boxes_raw is Array else []
		var prev_boxes: Array = prev_boxes_raw if prev_boxes_raw is Array else []
		if validator.boxes_overlap(last_boxes, prev_boxes):
			return false
	return true


func _exit_height(seq: Array, validator) -> float:
	var sim: Dictionary = validator.simulate(seq)
	var poses_raw = sim["poses"]
	if not (poses_raw is Array) or poses_raw.is_empty():
		return 0.0
	var last: Dictionary = poses_raw[poses_raw.size() - 1]
	var xf_raw = last["world_exit"]
	var xf: Transform3D = xf_raw
	return xf.origin.y


func _heading_openness(seq: Array, piece_id: String, validator) -> float:
	var sim: Dictionary = validator.simulate(seq)
	return _heading_from_sim(sim, piece_id, validator)


func _heading_from_sim(sim: Dictionary, piece_id: String, validator) -> float:
	var poses_raw = sim.get("poses", [])
	if not (poses_raw is Array) or poses_raw.size() < 2:
		return 0.0
	var poses: Array = poses_raw
	var last: Dictionary = poses[poses.size() - 1]
	var cursor_raw = last["world_exit"]
	var cursor: Transform3D = cursor_raw
	var nxt: Dictionary = validator.next_pose(cursor, piece_id)
	var exit_raw = nxt["world_exit"]
	var exit_xf: Transform3D = exit_raw
	var centroid := Vector3.ZERO
	var n: int = poses.size()
	for i in n:
		var row: Dictionary = poses[i]
		var xf_raw = row["world_exit"]
		var xf: Transform3D = xf_raw
		centroid += xf.origin
	centroid /= float(n)
	var away: Vector3 = exit_xf.origin - centroid
	away.y = 0.0
	if away.length() < 0.001:
		return 0.0
	var fwd: Vector3 = -exit_xf.basis.z
	fwd.y = 0.0
	if fwd.length() < 0.001:
		return 0.0
	return clampf(fwd.normalized().dot(away.normalized()), -1.0, 1.0)


func _close_track(seq: Array, length: String, difficulty: String, validator) -> Array:
	var repaired: Array = _repair_close(seq, length, difficulty, validator)
	if not repaired.is_empty():
		return repaired
	var out: Array = seq.duplicate()
	if not ValidatorScript.is_straight(str(out[out.size() - 1])):
		if not _try_append(out, "straight_medium", difficulty, validator):
			if not _try_append(out, "straight_short", difficulty, validator):
				return []
	if not _try_append(out, "finish", difficulty, validator):
		return []
	var checked: Dictionary = validator.validate(out, length, difficulty)
	if bool(checked["ok"]):
		return out
	return []


func _repair_close(seq: Array, length: String, difficulty: String, validator) -> Array:
	var work: Array = seq.duplicate()
	var band: Dictionary = ValidatorScript.LENGTH_BANDS[length]
	var max_path: float = float(band["max_path"])
	var max_pieces: int = int(band["max_pieces"])
	var pad := 0
	while pad < 8:
		pad += 1
		if work.size() + 4 > max_pieces:
			break
		if _path_of(work, validator) + 40.0 > max_path:
			break
		if _meets_difficulty_preview(work, difficulty, length) and ValidatorScript.is_straight(str(work[work.size() - 1])):
			break
		var frac: float = _curve_frac(work)
		if difficulty == DIFF_DEMENTE and not _has_any_tech(work):
			_try_append(work, "straight_short", difficulty, validator)
			if not _try_append(work, "curve_l_90", difficulty, validator):
				_try_append(work, "curve_r_90", difficulty, validator)
			_try_append(work, "straight_short", difficulty, validator)
			continue
		if difficulty == DIFF_DEMENTE and length == LENGTH_LONG and _count_id(work, "boost_straight") < 1:
			_try_append(work, "straight_medium", difficulty, validator)
			_try_append(work, "boost_straight", difficulty, validator)
			_try_append(work, "straight_short", difficulty, validator)
			continue
		if (difficulty == DIFF_PICANTE and frac < 0.22) or (difficulty == DIFF_DEMENTE and frac < 0.26) or (difficulty == DIFF_TRANQUI and _count_curves(work) == 0):
			var dir := _pick_dir(RandomNumberGenerator.new(), work, validator)
			var mild := "curve_l_45" if dir == "L" else "curve_r_45"
			if not _try_append(work, mild, difficulty, validator):
				_try_append(work, _alt_id(mild), difficulty, validator)
			_try_append(work, "straight_short", difficulty, validator)
			continue
		if difficulty == DIFF_PICANTE and frac > 0.62:
			_try_append(work, "straight_medium", difficulty, validator)
			continue
		break
	if not ValidatorScript.is_straight(str(work[work.size() - 1])):
		if not _try_append(work, "straight_medium", difficulty, validator):
			_try_append(work, "straight_short", difficulty, validator)
	_try_append(work, "finish", difficulty, validator)
	if str(work[work.size() - 1]) != "finish":
		return []
	var checked: Dictionary = validator.validate(work, length, difficulty)
	if bool(checked["ok"]):
		return work
	return []


func _len_of(validator, piece_id: String) -> float:
	var meta: Dictionary = validator.meta_for(piece_id)
	return float(meta.get("centerline_length", 0.0))


func _pack(seed_value: int, attempt: int, length: String, difficulty: String, sequence: Array, checked: Dictionary, ok: bool, accumulated: PackedStringArray) -> Dictionary:
	var poses_raw = checked.get("poses", [])
	var poses: Array = []
	if poses_raw is Array:
		poses = poses_raw
	return {
		"seed": seed_value,
		"attempt": attempt,
		"length": length,
		"length_id": length,
		"difficulty": difficulty,
		"piece_sequence": sequence,
		"piece_count": sequence.size(),
		"path_m": float(checked.get("path_m", 0.0)),
		"turns": int(checked.get("turns", 0)),
		"elev": float(checked.get("elev", 0.0)),
		"accepted": ok,
		"validation_result": "pass" if ok else "fail",
		"rejection_reasons": accumulated,
		"poses": poses,
	}


class OccupancyIndex:
	var cell := 10.0
	var buckets: Dictionary = {}

	func insert(idx: int, aabb: AABB) -> void:
		for key in _keys(aabb):
			if not buckets.has(key):
				buckets[key] = []
			(buckets[key] as Array).append(idx)

	func nearby(aabb: AABB) -> Dictionary:
		var seen: Dictionary = {}
		for key in _keys(aabb):
			var rows = buckets.get(key, [])
			if rows is Array:
				for idx in rows:
					seen[int(idx)] = true
		return seen

	func _keys(aabb: AABB) -> PackedStringArray:
		var out := PackedStringArray()
		var x0: int = int(floor(aabb.position.x / cell))
		var z0: int = int(floor(aabb.position.z / cell))
		var x1: int = int(floor((aabb.end.x) / cell))
		var z1: int = int(floor((aabb.end.z) / cell))
		for x in range(mini(x0, x1), maxi(x0, x1) + 1):
			for z in range(mini(z0, z1), maxi(z0, z1) + 1):
				out.append("%d:%d" % [x, z])
		return out
