class_name TrackRhythmAnalyzer
extends RefCounted

## Statistics only. Does not rewrite Generator V4. Do not reject tracks from this score.


static func analyze(sequence: Array) -> Dictionary:
	var ids: PackedStringArray = PackedStringArray()
	for item in sequence:
		ids.append(str(item))
	var n := ids.size()
	var straights := 0
	var turns := 0
	var same_side := 0
	var last_side := ""
	var boosts := 0
	var crests := 0
	var chicanes := 0
	var elev := 0
	var straight_run := 0
	var max_straight_run := 0
	var phrases: PackedStringArray = PackedStringArray()
	for i in n:
		var id := ids[i]
		var kind := _kind(id)
		phrases.append(kind)
		match kind:
			"ACCELERATION", "HIGH_SPEED", "RECOVERY":
				straights += 1
				straight_run += 1
				max_straight_run = maxi(max_straight_run, straight_run)
				last_side = ""
			"TURN_TEST":
				turns += 1
				straight_run = 0
				var side := "L" if id.contains("_l_") or id.ends_with("_l_45") or id.ends_with("_l_90") else "R"
				if id.contains("curve_l"):
					side = "L"
				elif id.contains("curve_r"):
					side = "R"
				if side == last_side and not last_side.is_empty():
					same_side += 1
				last_side = side
			"TECHNICAL":
				chicanes += 1
				turns += 1
				straight_run = 0
				last_side = ""
			"SPECTACLE":
				if id.contains("boost"):
					boosts += 1
				if id.contains("crest") or id.contains("slope"):
					crests += 1
					elev += 1
				straight_run = 0
			"FINISH_PUSH":
				straight_run = 0
			_:
				straight_run = 0
	var score := 0.55
	if max_straight_run >= 4:
		score -= 0.08
	if same_side >= 3:
		score -= 0.06
	if boosts >= 1:
		score += 0.05
	if chicanes >= 1:
		score += 0.04
	if crests >= 1:
		score += 0.03
	if turns < 2:
		score -= 0.07
	score = clampf(score, 0.0, 1.0)
	return {
		"n": n,
		"straights": straights,
		"turns": turns,
		"same_side": same_side,
		"boosts": boosts,
		"crests": crests,
		"chicanes": chicanes,
		"elev": elev,
		"max_straight_run": max_straight_run,
		"phrases": phrases,
		"rhythm_score": score,
	}


static func _kind(id: String) -> String:
	if id == "start":
		return "ACCELERATION"
	if id == "finish":
		return "FINISH_PUSH"
	if id.contains("boost"):
		return "SPECTACLE"
	if id.contains("chicane"):
		return "TECHNICAL"
	if id.contains("crest") or id.contains("slope") or id.contains("ramp") or id.contains("jump"):
		return "SPECTACLE"
	if id.contains("curve"):
		return "TURN_TEST"
	if id.contains("landing"):
		return "RECOVERY"
	if id.contains("straight_long"):
		return "HIGH_SPEED"
	if id.contains("straight"):
		return "ACCELERATION"
	return "RECOVERY"
