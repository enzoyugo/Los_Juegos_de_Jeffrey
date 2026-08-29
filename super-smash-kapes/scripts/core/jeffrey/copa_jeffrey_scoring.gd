class_name CopaJeffreyScoring
extends RefCounted

## Default placement points for Copa Jeffrey V1.

const PLACEMENT_POINTS: Array[int] = [5, 3, 2, 1]


static func points_for_placement(placement: int) -> int:
	if placement < 1 or placement > PLACEMENT_POINTS.size():
		return 0
	return PLACEMENT_POINTS[placement - 1]


static func award_points_for_count(player_count: int) -> Array[int]:
	var out: Array[int] = []
	for i in range(mini(player_count, PLACEMENT_POINTS.size())):
		out.append(PLACEMENT_POINTS[i])
	return out
