extends RefCounted

## Read-only technical report for a Track piece sequence.
## Does not change generator rules. Design quality is NOT_EVALUATED.

const KNOWN := [
	"start",
	"finish",
	"finish_runoff",
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


static func report_sequence(sequence: Array, piece_count: int = -1) -> Dictionary:
	var errors: PackedStringArray = PackedStringArray()
	if sequence.is_empty():
		errors.append("empty_sequence")
	else:
		if str(sequence[0]) != "start":
			errors.append("missing_start")
		var last := str(sequence[sequence.size() - 1])
		if last != "finish" and last != "finish_runoff":
			errors.append("missing_finish")
	for item in sequence:
		if not KNOWN.has(str(item)):
			errors.append("unknown_piece:%s" % str(item))
			break
	var count := piece_count if piece_count >= 0 else sequence.size()
	return {
		"technical_validity": "PASS" if errors.is_empty() else "FAIL",
		"design_quality": "NOT_EVALUATED",
		"segment_count": sequence.size(),
		"piece_count": count,
		"start_exists": (not sequence.is_empty()) and str(sequence[0]) == "start",
		"finish_exists": sequence.has("finish"),
		"technical_errors": errors,
		"mutating": false,
	}
