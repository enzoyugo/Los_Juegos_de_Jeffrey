class_name TrackGenerator
extends RefCounted

## Seeded greybox assembler. Point-to-point. Same seed → same signature.
## New requests must pass a new seed; this class never caches a previous route.

const Config := preload("res://scripts/track/track_config.gd")


func generate(seed_value: int, length_id: String, difficulty_id: String) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var length := length_id if Config.LENGTH_PIECES.has(length_id) else Config.LENGTH_MEDIA
	var difficulty := difficulty_id if Config.DIFF_TIME_MULT.has(difficulty_id) else Config.DIFF_PICANTE
	var count: int = int(Config.LENGTH_PIECES[length])
	var types: Array[String] = _sequence(rng, count, difficulty)
	var estimated := 0.0
	var built: Array = []
	var cursor := Transform3D(Basis.IDENTITY, Vector3(0, 0.5, 0))
	var checkpoints: Array = []
	var start_xform := cursor
	var index := 0
	for piece_type in types:
		var chunk: Dictionary = _emit_piece(piece_type, cursor)
		cursor = chunk["exit"]
		estimated += float(Config.PIECE_TIME.get(piece_type, 1.0))
		var solids: Array = chunk["solids"]
		built.append({
			"type": piece_type,
			"solids": solids,
			"checkpoint": bool(chunk.get("checkpoint", false)),
			"finish": bool(chunk.get("finish", false)),
			"has_left_guardrail": bool(chunk.get("has_left_guardrail", true)),
			"has_right_guardrail": bool(chunk.get("has_right_guardrail", true)),
		})
		if bool(chunk.get("checkpoint", false)) or bool(chunk.get("finish", false)):
			checkpoints.append({
				"index": index,
				"transform": chunk.get("mark", cursor),
				"is_finish": bool(chunk.get("finish", false)),
			})
		index += 1
	estimated *= float(Config.DIFF_TIME_MULT.get(difficulty, 1.0))
	return {
		"seed": seed_value,
		"track_seed": seed_value,
		"length_category": length,
		"difficulty": difficulty,
		"piece_sequence": types,
		"signature": signature_of(types),
		"estimated_time": estimated,
		"validation_result": "pass",
		"solids": _flatten_solids(built),
		"checkpoints": checkpoints,
		"start_transform": start_xform,
		"finish_transform": cursor,
		"piece_count": types.size(),
		"road_width": Config.ROAD_WIDTH,
		"car_to_road_ratio": Config.ROAD_WIDTH / 2.14,
	}


static func signature_of(types: Array) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for piece in types:
		parts.append(str(piece).to_upper())
	return "-".join(parts)


func _sequence(rng: RandomNumberGenerator, count: int, difficulty: String) -> Array[String]:
	var types: Array[String] = ["start"]
	var inner := maxi(count - 3, 3)
	var recent: Array[String] = ["start"]
	for _i in inner:
		var pick := _pick(rng, difficulty, recent)
		types.append(pick)
		recent.append(pick)
		if recent.size() > 3:
			recent.remove_at(0)
	types.append("finish_approach")
	types.append("finish")
	return types


func _pick(rng: RandomNumberGenerator, difficulty: String, recent: Array[String]) -> String:
	var pool: Array[String] = _pool(difficulty)
	var last := str(recent[recent.size() - 1]) if not recent.is_empty() else ""
	var last_family := _family(last)
	for _try in 8:
		var pick := str(pool[rng.randi() % pool.size()])
		if _family(pick) == last_family and last_family != "tech":
			continue
		if recent.has(pick) and pick.begins_with("straight"):
			continue
		if pick == last:
			continue
		return pick
	return "straight"


func _pool(difficulty: String) -> Array[String]:
	var pool: Array[String] = ["straight", "gentle_left", "gentle_right", "medium_left", "medium_right"]
	if difficulty == Config.DIFF_TRANQUI:
		pool.append_array(["straight", "gentle_left", "gentle_right"])
	if difficulty == Config.DIFF_PICANTE or difficulty == Config.DIFF_DEMENTE:
		pool.append_array(["chicane", "hill", "medium_left", "medium_right"])
	if difficulty == Config.DIFF_DEMENTE:
		pool.append_array(["hairpin_left", "hairpin_right", "jump", "chicane", "hairpin_left"])
	return pool


func _family(piece_type: String) -> String:
	if piece_type.ends_with("_left"):
		return "left"
	if piece_type.ends_with("_right"):
		return "right"
	if piece_type == "straight" or piece_type == "start" or piece_type == "finish" or piece_type == "finish_approach":
		return "straight"
	return "tech"


func _flatten_solids(built: Array) -> Array:
	var solids: Array = []
	for piece in built:
		for solid in piece["solids"]:
			solids.append(solid)
	return solids


func _emit_piece(piece_type: String, cursor: Transform3D) -> Dictionary:
	var w := Config.ROAD_WIDTH
	match piece_type:
		"start":
			return _box_run(cursor, w, 8.0, 0.0, true, false, true)
		"straight":
			return _box_run(cursor, w, Config.STRAIGHT_LENGTH, 0.0, false, false, true)
		"gentle_left":
			return _arc(cursor, 5, 5.2, 0.20, false, true)
		"gentle_right":
			return _arc(cursor, 5, 5.2, -0.20, false, true)
		"medium_left":
			return _arc(cursor, 6, 4.8, 0.30, true, true)
		"medium_right":
			return _arc(cursor, 6, 4.8, -0.30, true, true)
		"hairpin_left":
			return _arc(cursor, 8, 3.8, 0.42, true, true)
		"hairpin_right":
			return _arc(cursor, 8, 3.8, -0.42, true, true)
		"chicane":
			return _chicane(cursor)
		"hill":
			return _hill(cursor)
		"jump":
			return _jump(cursor)
		"finish_approach":
			return _box_run(cursor, w, 12.0, 0.0, true, false, true)
		"finish":
			return _box_run(cursor, w + 1.5, 12.0, 0.0, false, true, true)
		_:
			return _box_run(cursor, w, 10.0, 0.0, false, false, true)


func _box_run(cursor: Transform3D, width: float, length: float, pitch: float, checkpoint: bool, finish: bool, rails: bool = true) -> Dictionary:
	var xform := cursor
	if pitch != 0.0:
		xform.basis = xform.basis.rotated(xform.basis.x, pitch)
	var center := xform * Transform3D(Basis.IDENTITY, Vector3(0, 0, -length * 0.5))
	## Visual albedo only — collision sizes unchanged.
	var color := Color("#c4a24a") if finish else Color("#1c2128")
	var solids: Array = _pack_road(center, width, length, color, rails)
	var exit_xform := cursor
	exit_xform.origin += -cursor.basis.z * length
	if pitch != 0.0:
		exit_xform.basis = xform.basis
		exit_xform.origin = xform.origin + -xform.basis.z * length
	return {
		"solids": solids,
		"exit": exit_xform,
		"checkpoint": checkpoint,
		"finish": finish,
		"mark": exit_xform,
		"has_left_guardrail": rails,
		"has_right_guardrail": rails,
	}


func _arc(cursor: Transform3D, steps: int, step_len: float, yaw: float, checkpoint: bool, rails: bool = true) -> Dictionary:
	var solids: Array = []
	var xform := cursor
	var w := Config.ROAD_WIDTH
	for _i in steps:
		xform.basis = xform.basis.rotated(Vector3.UP, yaw)
		var center := xform * Transform3D(Basis.IDENTITY, Vector3(0, 0, -step_len * 0.5))
		solids.append_array(_pack_road(center, w, step_len + 0.35, Color("#242830"), rails))
		xform.origin += -xform.basis.z * step_len
	return {
		"solids": solids,
		"exit": xform,
		"checkpoint": checkpoint,
		"finish": false,
		"mark": xform,
		"has_left_guardrail": rails,
		"has_right_guardrail": rails,
	}


func _pack_road(center: Transform3D, width: float, length: float, color: Color, rails: bool) -> Array:
	var solids: Array = []
	solids.append({
		"transform": center,
		"size": Vector3(width, 1.0, length),
		"color": color,
		"kind": "road",
	})
	var sh := Config.ROAD_SHOULDER
	var left_sh := center * Transform3D(Basis.IDENTITY, Vector3(-(width * 0.5 + sh * 0.5), 0.02, 0.0))
	var right_sh := center * Transform3D(Basis.IDENTITY, Vector3(width * 0.5 + sh * 0.5, 0.02, 0.0))
	solids.append({
		"transform": left_sh,
		"size": Vector3(sh, 0.96, length),
		"color": Color("#6a655c"),
		"kind": "shoulder",
	})
	solids.append({
		"transform": right_sh,
		"size": Vector3(sh, 0.96, length),
		"color": Color("#6a655c"),
		"kind": "shoulder",
	})
	## Painted curb — visual only (no collision body).
	var curb_w := 0.28
	var curb_h := 0.14
	var left_curb := center * Transform3D(Basis.IDENTITY, Vector3(-(width * 0.5 + curb_w * 0.5), 0.48, 0.0))
	var right_curb := center * Transform3D(Basis.IDENTITY, Vector3(width * 0.5 + curb_w * 0.5, 0.48, 0.0))
	solids.append({
		"transform": left_curb,
		"size": Vector3(curb_w, curb_h, length),
		"color": Color("#c9b89a"),
		"kind": "curb",
		"visual_only": true,
	})
	solids.append({
		"transform": right_curb,
		"size": Vector3(curb_w, curb_h, length),
		"color": Color("#c9b89a"),
		"kind": "curb",
		"visual_only": true,
	})
	if not rails:
		return solids
	var th := Config.GUARDRAIL_THICKNESS
	var hh := Config.GUARDRAIL_HEIGHT
	var rail_y := 0.5 + hh * 0.5 - 0.04
	var left_x := -(width * 0.5 + sh + th * 0.5)
	var right_x := width * 0.5 + sh + th * 0.5
	## Darker concrete barrier — collision unchanged.
	solids.append({
		"transform": center * Transform3D(Basis.IDENTITY, Vector3(left_x, rail_y, 0.0)),
		"size": Vector3(th, hh, length),
		"color": Color("#5a5e58"),
		"kind": "rail",
		"has_left_guardrail": true,
	})
	solids.append({
		"transform": center * Transform3D(Basis.IDENTITY, Vector3(right_x, rail_y, 0.0)),
		"size": Vector3(th, hh, length),
		"color": Color("#5a5e58"),
		"kind": "rail",
		"has_right_guardrail": true,
	})
	return solids


func _chicane(cursor: Transform3D) -> Dictionary:
	var a := _arc(cursor, 3, 4.6, 0.28, false, true)
	var b := _arc(a["exit"], 5, 4.6, -0.34, true, true)
	var solids: Array = []
	solids.append_array(a["solids"])
	solids.append_array(b["solids"])
	return {
		"solids": solids,
		"exit": b["exit"],
		"checkpoint": true,
		"finish": false,
		"mark": b["exit"],
		"has_left_guardrail": true,
		"has_right_guardrail": true,
	}


func _hill(cursor: Transform3D) -> Dictionary:
	var w := Config.ROAD_WIDTH
	var up := _box_run(cursor, w, 8.0, -0.18, false, false, true)
	var crest := _box_run(up["exit"], w, 6.0, 0.0, true, false, true)
	var down := _box_run(crest["exit"], w, 8.0, 0.18, false, false, true)
	var solids: Array = []
	solids.append_array(up["solids"])
	solids.append_array(crest["solids"])
	solids.append_array(down["solids"])
	return {
		"solids": solids,
		"exit": down["exit"],
		"checkpoint": true,
		"finish": false,
		"mark": crest["exit"],
		"has_left_guardrail": true,
		"has_right_guardrail": true,
	}


func _jump(cursor: Transform3D) -> Dictionary:
	var w := Config.ROAD_WIDTH
	var ramp := _box_run(cursor, w, 8.0, -0.28, false, false, true)
	var gap_cursor: Transform3D = ramp["exit"]
	gap_cursor.origin += -gap_cursor.basis.z * 6.0
	var land := _box_run(gap_cursor, w + 1.5, 11.0, 0.12, true, false, true)
	var solids: Array = []
	solids.append_array(ramp["solids"])
	solids.append_array(land["solids"])
	return {
		"solids": solids,
		"exit": land["exit"],
		"checkpoint": true,
		"finish": false,
		"mark": land["exit"],
		"has_left_guardrail": true,
		"has_right_guardrail": true,
	}

