class_name TrackWidthPolicy
extends RefCounted

## Kit modules are authored at 11 m. Candidate arcade width is measured in lab, not canonicalized.

const KIT_WIDTH := 11.0
const CANDIDATE := 15.0


static func scale_for(width_m: float) -> float:
	return width_m / KIT_WIDTH


static func apply_local_x(piece: Node3D, width_m: float) -> void:
	if piece == null:
		return
	var s := scale_for(width_m)
	piece.scale = Vector3(s, 1.0, 1.0)
