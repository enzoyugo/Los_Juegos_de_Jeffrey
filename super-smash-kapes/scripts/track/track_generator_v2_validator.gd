class_name TrackGeneratorV2Validator
extends RefCounted

## Simulated-assembly checks for TrackGeneratorV2. No scene tree required.

const Registry := preload("res://scripts/track/track_piece_registry.gd")

const ALLOWED_IDS: PackedStringArray = [
	"start",
	"finish",
	"straight_short",
	"straight_medium",
	"straight_long",
	"curve_l_45",
	"curve_r_45",
	"curve_l_90",
	"curve_r_90",
	"chicane_lr",
	"chicane_rl",
	"boost_straight",
	"landing_straight_long",
	"slope_up_gentle",
	"slope_down_gentle",
	"crest_gentle",
]

const SEAM_POS_LIMIT := 0.0005
const SEAM_YAW_LIMIT := 0.001
const NEIGHBOR_OVERLAP_M := 1.0
const OVERLAP_MIN_M := 0.05
const ELEV_LIMIT_M := 8.0
const LENGTH_BANDS := {
	"SHORT": {"min_path": 210.0, "max_path": 360.0, "min_pieces": 8, "max_pieces": 16},
	"MEDIUM": {"min_path": 460.0, "max_path": 680.0, "min_pieces": 15, "max_pieces": 26},
	"LONG": {"min_path": 820.0, "max_path": 1160.0, "min_pieces": 24, "max_pieces": 42},
}

var _meta_cache: Dictionary = {}


func validate(sequence: Array, length_id: String, difficulty_id: String) -> Dictionary:
	var reasons: PackedStringArray = PackedStringArray()
	var poses: Array = []
	var path_m := 0.0
	var turns := 0
	var elev := 0.0
	if sequence.is_empty():
		_add_reason(reasons, "START/FINISH")
		return _pack(false, reasons, poses, path_m, turns, elev)
	_check_start_finish(sequence, reasons)
	_check_allowed_and_stunts(sequence, reasons)
	_check_driveability(sequence, reasons)
	_check_controller_compat(sequence, reasons)
	_check_variety(sequence, reasons)
	_check_difficulty(sequence, difficulty_id, length_id, reasons)
	var sim: Dictionary = simulate(sequence)
	var poses_raw = sim["poses"]
	if poses_raw is Array:
		poses = poses_raw
	path_m = float(sim["path_m"])
	turns = int(sim["turns"])
	elev = float(sim["elev"])
	_check_seams(poses, reasons)
	_check_elevation(elev, reasons)
	_check_overlap(poses, reasons)
	_check_length_band(sequence.size(), path_m, length_id, reasons)
	return _pack(reasons.is_empty(), reasons, poses, path_m, turns, elev)


func simulate(sequence: Array) -> Dictionary:
	var poses: Array = []
	var cursor := Transform3D.IDENTITY
	var path_m := 0.0
	var turns := 0
	var elev := 0.0
	for raw_id in sequence:
		var piece_id := str(raw_id)
		var meta: Dictionary = meta_for(piece_id)
		var local_exit := local_exit_xform(meta)
		var world_entry := cursor
		var world_exit := cursor * local_exit
		var yaw_d: float = float(meta.get("yaw_delta", 0.0))
		if _is_curve(piece_id):
			turns += 1
		elif is_chicane(piece_id):
			turns += 1
		path_m += float(meta.get("centerline_length", 0.0))
		elev = maxf(elev, absf(world_entry.origin.y))
		elev = maxf(elev, absf(world_exit.origin.y))
		var boxes: Array = _world_boxes(world_entry, meta)
		var union_aabb := _union_aabb(boxes)
		poses.append({
			"id": piece_id,
			"world_entry": world_entry,
			"world_exit": world_exit,
			"yaw_delta": yaw_d,
			"boxes": boxes,
			"aabb": union_aabb,
		})
		cursor = world_exit
	return {
		"poses": poses,
		"path_m": path_m,
		"turns": turns,
		"elev": elev,
	}


func next_pose(cursor: Transform3D, piece_id: String) -> Dictionary:
	var meta: Dictionary = meta_for(piece_id)
	var local_exit := local_exit_xform(meta)
	var world_entry := cursor
	var world_exit := cursor * local_exit
	var boxes: Array = _world_boxes(world_entry, meta)
	return {
		"id": piece_id,
		"world_entry": world_entry,
		"world_exit": world_exit,
		"yaw_delta": float(meta.get("yaw_delta", 0.0)),
		"boxes": boxes,
		"aabb": _union_aabb(boxes),
		"path_add": float(meta.get("centerline_length", 0.0)),
		"is_turn": is_curve(piece_id) or is_chicane(piece_id),
	}


func meta_for(piece_id: String) -> Dictionary:
	if _meta_cache.has(piece_id):
		return _meta_cache[piece_id]
	var loaded: Dictionary = Registry.meta(piece_id)
	_meta_cache[piece_id] = loaded
	return loaded


func local_exit_xform(meta: Dictionary) -> Transform3D:
	var exit_raw = meta.get("exit", {})
	var exit_d: Dictionary = {}
	if exit_raw is Dictionary:
		exit_d = exit_raw
	var origin_raw = exit_d.get("origin", [0.0, 0.0, 0.0])
	var ox := 0.0
	var oy := 0.0
	var oz := 0.0
	if origin_raw is Array and origin_raw.size() >= 3:
		ox = float(origin_raw[0])
		oy = float(origin_raw[1])
		oz = float(origin_raw[2])
	var yaw_raw = exit_d.get("yaw", 0.0)
	var yaw: float = float(yaw_raw)
	var pitch: float = float(exit_d.get("pitch", 0.0))
	if absf(pitch) < 0.000001:
		pitch = float(meta.get("pitch_delta", 0.0))
	return Transform3D(Basis.from_euler(Vector3(pitch, yaw, 0.0)), Vector3(ox, oy, oz))


func is_allowed(piece_id: String) -> bool:
	return ALLOWED_IDS.has(piece_id)


func is_stunt(piece_id: String) -> bool:
	if piece_id.begins_with("ramp"):
		return true
	if piece_id.begins_with("jump"):
		return true
	if piece_id.contains("gap"):
		return true
	return false


static func is_curve(piece_id: String) -> bool:
	return (
		piece_id == "curve_l_45"
		or piece_id == "curve_r_45"
		or piece_id == "curve_l_90"
		or piece_id == "curve_r_90"
	)


static func is_ninety(piece_id: String) -> bool:
	return piece_id == "curve_l_90" or piece_id == "curve_r_90"


static func is_chicane(piece_id: String) -> bool:
	return piece_id == "chicane_lr" or piece_id == "chicane_rl"


static func is_recovery_straight(piece_id: String) -> bool:
	return piece_id == "straight_short" or piece_id == "straight_medium" or piece_id == "straight_long"


static func is_straight(piece_id: String) -> bool:
	return (
		piece_id == "straight_short"
		or piece_id == "straight_medium"
		or piece_id == "straight_long"
		or piece_id == "boost_straight"
		or piece_id == "landing_straight_long"
	)


static func is_elevation(piece_id: String) -> bool:
	return piece_id == "slope_up_gentle" or piece_id == "slope_down_gentle" or piece_id == "crest_gentle"


static func is_slope_up(piece_id: String) -> bool:
	return piece_id == "slope_up_gentle"


static func is_slope_down(piece_id: String) -> bool:
	return piece_id == "slope_down_gentle"


static func curve_dir(piece_id: String) -> String:
	if piece_id.contains("_l_"):
		return "L"
	if piece_id.contains("_r_"):
		return "R"
	if piece_id.ends_with("_lr"):
		return "L"
	if piece_id.ends_with("_rl"):
		return "R"
	return ""


func _is_curve(piece_id: String) -> bool:
	return is_curve(piece_id)


func _check_start_finish(sequence: Array, reasons: PackedStringArray) -> void:
	if str(sequence[0]) != "start":
		_add_reason(reasons, "START/FINISH")
	if str(sequence[sequence.size() - 1]) != "finish":
		_add_reason(reasons, "START/FINISH")


func _check_allowed_and_stunts(sequence: Array, reasons: PackedStringArray) -> void:
	for raw_id in sequence:
		var piece_id := str(raw_id)
		if is_stunt(piece_id):
			_add_reason(reasons, "NO_STUNT")
		elif not is_allowed(piece_id):
			_add_reason(reasons, "NO_STUNT")


func _check_driveability(sequence: Array, reasons: PackedStringArray) -> void:
	var n: int = sequence.size()
	if n < 2:
		_add_reason(reasons, "DRIVEABILITY")
		return
	var before_finish := str(sequence[n - 2])
	if not is_straight(before_finish):
		_add_reason(reasons, "DRIVEABILITY")
	var consec_curves := 0
	var landing_n := 0
	for i in n:
		var pid := str(sequence[i])
		if pid == "landing_straight_long":
			landing_n += 1
			if landing_n > 1:
				_add_reason(reasons, "DRIVEABILITY")
		if is_chicane(pid) and i > 0 and is_chicane(str(sequence[i - 1])):
			_add_reason(reasons, "DRIVEABILITY")
		if is_ninety(pid) and i > 0:
			var prev_b := str(sequence[i - 1])
			if prev_b == "boost_straight":
				_add_reason(reasons, "DRIVEABILITY")
			if is_ninety(prev_b) and curve_dir(prev_b) != curve_dir(pid):
				_add_reason(reasons, "DRIVEABILITY")
		if is_curve(pid):
			consec_curves += 1
			if consec_curves >= 2 and i + 1 < n:
				var nxt := str(sequence[i + 1])
				if not is_straight(nxt) and nxt != "finish":
					_add_reason(reasons, "DRIVEABILITY")
			if i > 0:
				var prev := str(sequence[i - 1])
				if is_curve(prev):
					var a := curve_dir(prev)
					var b := curve_dir(pid)
					if a != "" and b != "" and a != b:
						_add_reason(reasons, "DRIVEABILITY")
		else:
			consec_curves = 0
		if is_elevation(pid):
			if i > 0 and str(sequence[i - 1]) == "boost_straight":
				_add_reason(reasons, "CONTROLLER_COMPAT")
			if i > 1 and is_elevation(str(sequence[i - 1])) and is_elevation(str(sequence[i - 2])):
				_add_reason(reasons, "ELEVATION")


func _check_controller_compat(sequence: Array, reasons: PackedStringArray) -> void:
	var n: int = sequence.size()
	for i in n:
		var pid := str(sequence[i])
		if i <= 0:
			continue
		var prev := str(sequence[i - 1])
		if prev == "boost_straight":
			if pid == "boost_straight":
				_add_reason(reasons, "CONTROLLER_COMPAT")
			if is_ninety(pid) or is_chicane(pid) or is_elevation(pid):
				_add_reason(reasons, "CONTROLLER_COMPAT")
			if not is_straight(pid) and pid != "finish":
				_add_reason(reasons, "CONTROLLER_COMPAT")
		if is_chicane(pid) and not is_straight(prev):
			_add_reason(reasons, "CONTROLLER_COMPAT")


func _check_variety(sequence: Array, reasons: PackedStringArray) -> void:
	var curves := 0
	var body := 0
	var run_id := ""
	var run_n := 0
	var run_dir := ""
	var run_dir_n := 0
	for raw_id in sequence:
		var pid := str(raw_id)
		if pid != "start" and pid != "finish":
			body += 1
			if is_curve(pid):
				curves += 1
		if pid == run_id:
			run_n += 1
		else:
			run_id = pid
			run_n = 1
		if run_n >= 3:
			_add_reason(reasons, "VARIETY")
		if is_curve(pid):
			var d := curve_dir(pid)
			if d == run_dir:
				run_dir_n += 1
			else:
				run_dir = d
				run_dir_n = 1
			if run_dir_n > 3:
				_add_reason(reasons, "VARIETY")
		else:
			run_dir = ""
			run_dir_n = 0
	if body > 0 and curves == 0:
		_add_reason(reasons, "VARIETY")


func _check_difficulty(sequence: Array, difficulty_id: String, length_id: String, reasons: PackedStringArray) -> void:
	var body := 0
	var curves := 0
	var boosts := 0
	var nineties := 0
	var chicanes := 0
	var consec_curve := false
	for i in sequence.size():
		var pid := str(sequence[i])
		if pid == "start" or pid == "finish":
			continue
		body += 1
		if is_curve(pid):
			curves += 1
			if i > 0 and is_curve(str(sequence[i - 1])):
				consec_curve = true
		if is_ninety(pid):
			nineties += 1
		if is_chicane(pid):
			chicanes += 1
		if pid == "boost_straight":
			boosts += 1
	var frac := 0.0
	if body > 0:
		frac = float(curves) / float(body)
	if difficulty_id == "TRANQUI":
		if frac > 0.42:
			_add_reason(reasons, "DIFFICULTY")
		if consec_curve:
			_add_reason(reasons, "DIFFICULTY")
		if boosts > 1:
			_add_reason(reasons, "DIFFICULTY")
		if nineties > 1:
			_add_reason(reasons, "DIFFICULTY")
		if chicanes > 0:
			_add_reason(reasons, "DIFFICULTY")
	elif difficulty_id == "PICANTE":
		if frac < 0.20 or frac > 0.64:
			_add_reason(reasons, "DIFFICULTY")
		if boosts > 2:
			_add_reason(reasons, "DIFFICULTY")
	elif difficulty_id == "DEMENTE":
		if frac < 0.24 or frac > 0.78:
			_add_reason(reasons, "DIFFICULTY")
		if nineties + chicanes < 1:
			_add_reason(reasons, "DIFFICULTY")
		if length_id == "LONG" and boosts < 1:
			_add_reason(reasons, "DIFFICULTY")


func _check_seams(poses: Array, reasons: PackedStringArray) -> void:
	for i in range(1, poses.size()):
		var prev: Dictionary = poses[i - 1]
		var nxt: Dictionary = poses[i]
		var a_raw = prev["world_exit"]
		var b_raw = nxt["world_entry"]
		var a: Transform3D = a_raw
		var b: Transform3D = b_raw
		var pos: float = a.origin.distance_to(b.origin)
		if pos > SEAM_POS_LIMIT:
			_add_reason(reasons, "SEAM_POS")
		var fwd_a: Vector3 = -a.basis.z
		var fwd_b: Vector3 = -b.basis.z
		if fwd_a.length() < 0.0001 or fwd_b.length() < 0.0001:
			continue
		var yaw: float = absf(fwd_a.normalized().angle_to(fwd_b.normalized()))
		if yaw > SEAM_YAW_LIMIT:
			_add_reason(reasons, "SEAM_ROT")


func _check_elevation(elev: float, reasons: PackedStringArray) -> void:
	if elev > ELEV_LIMIT_M:
		_add_reason(reasons, "ELEVATION")


func _check_overlap(poses: Array, reasons: PackedStringArray) -> void:
	var n: int = poses.size()
	for i in n:
		var a: Dictionary = poses[i]
		var aabb_a_raw = a["aabb"]
		var aabb_a: AABB = aabb_a_raw
		for j in range(i + 2, n):
			var b: Dictionary = poses[j]
			var aabb_b_raw = b["aabb"]
			var aabb_b: AABB = aabb_b_raw
			if xz_overlap(aabb_a, aabb_b) and not y_ranges_overlap(aabb_a, aabb_b):
				_add_reason(reasons, "SELF_CROSS")
				_add_reason(reasons, "HEADING")
				return
			if not aabb_a.intersects(aabb_b):
				continue
			var a_boxes_raw = a["boxes"]
			var b_boxes_raw = b["boxes"]
			var a_boxes: Array = a_boxes_raw if a_boxes_raw is Array else []
			var b_boxes: Array = b_boxes_raw if b_boxes_raw is Array else []
			if boxes_overlap(a_boxes, b_boxes):
				_add_reason(reasons, "OVERLAP")
				_add_reason(reasons, "SELF_CROSS")
				_add_reason(reasons, "HEADING")
				return


func _check_length_band(piece_n: int, path_m: float, length_id: String, reasons: PackedStringArray) -> void:
	if not LENGTH_BANDS.has(length_id):
		return
	var band: Dictionary = LENGTH_BANDS[length_id]
	var min_path: float = float(band["min_path"])
	var max_path: float = float(band["max_path"])
	var min_pieces: int = int(band["min_pieces"])
	var max_pieces: int = int(band["max_pieces"])
	if path_m < min_path or path_m > max_path:
		_add_reason(reasons, "LENGTH")
	if piece_n < min_pieces or piece_n > max_pieces:
		_add_reason(reasons, "LENGTH")


func _world_boxes(world_entry: Transform3D, meta: Dictionary) -> Array:
	var out: Array = []
	var raw = meta.get("collision", [])
	if not (raw is Array):
		return out
	for item in raw:
		if not (item is Dictionary):
			continue
		var box_d: Dictionary = item
		var kind := str(box_d.get("kind", "road"))
		out.append({
			"kind": kind,
			"aabb": _box_aabb(world_entry, box_d),
		})
	return out


func _box_aabb(world_entry: Transform3D, box_d: Dictionary) -> AABB:
	var origin_raw = box_d.get("origin", [0.0, 0.0, 0.0])
	var ox := 0.0
	var oy := 0.0
	var oz := 0.0
	if origin_raw is Array and origin_raw.size() >= 3:
		ox = float(origin_raw[0])
		oy = float(origin_raw[1])
		oz = float(origin_raw[2])
	var yaw: float = float(box_d.get("yaw", 0.0))
	var pitch: float = float(box_d.get("pitch", 0.0))
	var size_raw = box_d.get("size", [11.0, 0.12, 2.0])
	var sx := 11.0
	var sy := 0.12
	var sz := 2.0
	if size_raw is Array and size_raw.size() >= 3:
		sx = float(size_raw[0])
		sy = float(size_raw[1])
		sz = float(size_raw[2])
	var local_xf := Transform3D(Basis.from_euler(Vector3(pitch, yaw, 0.0)), Vector3(ox, oy, oz))
	var world_xf: Transform3D = world_entry * local_xf
	var hx := sx * 0.5
	var hy := sy * 0.5
	var hz := sz * 0.5
	var first := true
	var aabb := AABB()
	for ix in [-1.0, 1.0]:
		for iy in [-1.0, 1.0]:
			for iz in [-1.0, 1.0]:
				var corner: Vector3 = world_xf * Vector3(ix * hx, iy * hy, iz * hz)
				if first:
					aabb = AABB(corner, Vector3.ZERO)
					first = false
				else:
					aabb = aabb.expand(corner)
	return aabb


func _union_aabb(boxes: Array) -> AABB:
	var first := true
	var aabb := AABB()
	for item in boxes:
		if not (item is Dictionary):
			continue
		var box_aabb_raw = item["aabb"]
		var box_aabb: AABB = box_aabb_raw
		if first:
			aabb = box_aabb
			first = false
		else:
			aabb = aabb.merge(box_aabb)
	return aabb


func xz_overlap(a: AABB, b: AABB) -> bool:
	var aa := AABB(Vector3(a.position.x, 0.0, a.position.z), Vector3(a.size.x, 2.0, a.size.z))
	var bb := AABB(Vector3(b.position.x, 0.0, b.position.z), Vector3(b.size.x, 2.0, b.size.z))
	if not aa.intersects(bb):
		return false
	var hit: AABB = aa.intersection(bb)
	return hit.size.x > OVERLAP_MIN_M and hit.size.z > OVERLAP_MIN_M


func y_ranges_overlap(a: AABB, b: AABB) -> bool:
	var a0: float = a.position.y
	var a1: float = a.position.y + a.size.y
	var b0: float = b.position.y
	var b1: float = b.position.y + b.size.y
	return a0 <= b1 + 0.05 and b0 <= a1 + 0.05


func boxes_overlap(a_boxes: Array, b_boxes: Array) -> bool:
	for aa in a_boxes:
		if not (aa is Dictionary):
			continue
		var aabb_a_raw = aa["aabb"]
		var aabb_a: AABB = aabb_a_raw
		for bb in b_boxes:
			if not (bb is Dictionary):
				continue
			var aabb_b_raw = bb["aabb"]
			var aabb_b: AABB = aabb_b_raw
			if not aabb_a.intersects(aabb_b):
				continue
			var hit: AABB = aabb_a.intersection(aabb_b)
			if hit.size.x > OVERLAP_MIN_M and hit.size.y > OVERLAP_MIN_M and hit.size.z > OVERLAP_MIN_M:
				return true
	return false


func _add_reason(reasons: PackedStringArray, code: String) -> void:
	if not reasons.has(code):
		reasons.append(code)


func _pack(ok: bool, reasons: PackedStringArray, poses: Array, path_m: float, turns: int, elev: float) -> Dictionary:
	return {
		"ok": ok,
		"reasons": reasons,
		"poses": poses,
		"path_m": path_m,
		"turns": turns,
		"elev": elev,
	}
