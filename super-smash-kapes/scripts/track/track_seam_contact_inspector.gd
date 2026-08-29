class_name TrackSeamContactInspector
extends RefCounted

## Ray samples adjacent piece seams. Does not retune suspension.


static func inspect(pieces: Array, half_width: float = 7.5) -> Dictionary:
	var gaps := 0
	var dy_fail := 0
	var samples := 0
	var worst_gap := 0.0
	var worst_dy := 0.0
	var notes: PackedStringArray = PackedStringArray()
	var laterals: Array = [0.0, half_width * 0.25, -half_width * 0.25, half_width * 0.5, -half_width * 0.5, half_width * 0.72, -half_width * 0.72]
	for i in range(pieces.size() - 1):
		var a = pieces[i]
		var b = pieces[i + 1]
		if a == null or b == null or not a.has_method("exit_global"):
			continue
		var xf: Transform3D = a.exit_global()
		var space: PhysicsDirectSpaceState3D = (a as Node3D).get_world_3d().direct_space_state
		if space == null:
			continue
		for lat in laterals:
			samples += 1
			var origin: Vector3 = xf.origin + xf.basis.x * float(lat) + xf.basis.y * 3.2
			var hit_a := _down(space, origin + xf.basis.z * 0.35)
			var hit_b := _down(space, origin + xf.basis.z * -0.35)
			if hit_a.is_empty() or hit_b.is_empty():
				gaps += 1
				notes.append("GAP %s->%s lat=%.1f" % [str(a.piece_id), str(b.piece_id), float(lat)])
				continue
			var pa: Vector3 = hit_a.get("position", origin)
			var pb: Vector3 = hit_b.get("position", origin)
			var dy: float = absf(pa.y - pb.y)
			worst_dy = maxf(worst_dy, dy)
			if dy > 0.12:
				dy_fail += 1
				notes.append("STEP %s->%s dy=%.3f" % [str(a.piece_id), str(b.piece_id), dy])
	var ok := gaps == 0 and dy_fail == 0
	print("[TRACK_SEAM] samples=%d gaps=%d steps=%d worst_gap=%.3f worst_dy=%.3f ok=%s" % [
		samples, gaps, dy_fail, worst_gap, worst_dy, str(ok)
	])
	for n in notes:
		print("[TRACK_SEAM_NOTE] %s" % n)
	return {
		"ok": ok,
		"samples": samples,
		"gaps": gaps,
		"steps": dy_fail,
		"worst_gap": worst_gap,
		"worst_dy": worst_dy,
		"notes": notes,
	}


static func _down(space: PhysicsDirectSpaceState3D, from: Vector3) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(from, from + Vector3(0, -8.0, 0))
	q.collision_mask = 1
	q.collide_with_bodies = true
	q.hit_from_inside = true
	return space.intersect_ray(q)
