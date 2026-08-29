class_name TrackSurface
extends RefCounted

## Arcade surface tags. Shared by BASELINE and 4WHEEL lab offtrack.

const KIND_ROAD := "road"
const KIND_SHOULDER := "shoulder"
const KIND_OFFTRACK := "offtrack"
const KIND_RAIL := "rail"

const SHOULDER_GRIP := 0.58
const OFFTRACK_GRIP := 0.24
const OFFTRACK_LONG_SCALE := 0.18
const OFFTRACK_DRAG := 14.0
const SHOULDER_DRAG := 4.5

const FALL_Y := -8.0
const FAR_M := 38.0
const CHECKPOINT_MAX_SPEED := 42.0


static func grip_scale(kind: String) -> float:
	if kind == KIND_SHOULDER:
		return SHOULDER_GRIP
	if kind == KIND_OFFTRACK:
		return OFFTRACK_GRIP
	return 1.0


static func majority_kind(kinds: PackedStringArray, grounded_n: int) -> String:
	if grounded_n <= 0:
		return KIND_ROAD
	var off_n := 0
	var sh_n := 0
	var road_n := 0
	for k in kinds:
		if k == KIND_OFFTRACK:
			off_n += 1
		elif k == KIND_SHOULDER:
			sh_n += 1
		elif k == KIND_ROAD:
			road_n += 1
	if off_n >= 3:
		return KIND_OFFTRACK
	if off_n >= 1 or sh_n >= 2:
		return KIND_SHOULDER
	if road_n > 0:
		return KIND_ROAD
	if off_n > 0:
		return KIND_OFFTRACK
	return KIND_ROAD
