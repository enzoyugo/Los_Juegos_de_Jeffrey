class_name TrackGenerationReveal
extends Node3D

## Animate already-generated pieces. Generator stays fast and frozen.

signal finished

var _pieces: Array = []
var _i: int = 0
var _delay: float = 0.08
var _wait: float = 0.0
var playing: bool = false
var camera: Camera3D
var skip: bool = false
var current_index: int = 0


func start(pieces: Array, cam: Camera3D) -> void:
	_pieces = pieces
	camera = cam
	_i = 0
	playing = true
	var instant := skip
	skip = false
	var n: int = maxi(pieces.size(), 1)
	_delay = clampf(2.4 / float(n), 0.05, 0.12)
	for p in pieces:
		if p is Node3D:
			(p as Node3D).visible = false
			(p as Node3D).scale = Vector3(0.92, 0.4, 0.92)
	_wait = 0.0
	if instant:
		_show_all_instant()
		return
	_show_next()


func _show_all_instant() -> void:
	for p in _pieces:
		if p is Node3D:
			(p as Node3D).visible = true
			(p as Node3D).scale = Vector3.ONE
	_i = _pieces.size()
	_done()


func _process(delta: float) -> void:
	if not playing:
		return
	if skip:
		_show_all_instant()
		return
	_wait += delta
	if _wait >= _delay:
		_wait = 0.0
		_show_next()


func _show_next() -> void:
	if _i >= _pieces.size():
		_done()
		return
	var p = _pieces[_i]
	current_index = _i
	if p is Node3D:
		var n := p as Node3D
		n.visible = true
		n.scale = Vector3.ONE
		if camera != null and p.has_method("exit_global"):
			var xf: Transform3D = p.exit_global()
			var desired: Vector3 = xf.origin + xf.basis.y * 8.0 + xf.basis.z * 14.0
			camera.global_position = camera.global_position.lerp(desired, 0.65)
			var look: Vector3 = xf.origin + Vector3(0, 1.2, 0)
			if look.distance_to(camera.global_position) > 0.2:
				camera.look_at(look, Vector3.UP)
	_i += 1
	if _i >= _pieces.size():
		_done()


func _done() -> void:
	if not playing:
		return
	if camera != null and _pieces.size() > 0:
		var aabb := AABB()
		var first := true
		for p in _pieces:
			if not (p is Node3D):
				continue
			var n := p as Node3D
			if first:
				aabb = AABB(n.global_position, Vector3.ZERO)
				first = false
			else:
				aabb = aabb.expand(n.global_position)
			if p.has_method("exit_global"):
				aabb = aabb.expand((p.exit_global() as Transform3D).origin)
		var center: Vector3 = aabb.get_center() + Vector3(0, 2.0, 0)
		var extent: float = maxf(aabb.size.length() * 0.55, 22.0)
		var candidates: Array[Vector3] = [
			center + Vector3(extent * 0.55, extent * 0.42, extent * 0.72),
			center + Vector3(-extent * 0.6, extent * 0.4, extent * 0.55),
			center + Vector3(extent * 0.2, extent * 0.55, -extent * 0.65),
			center + Vector3(-extent * 0.35, extent * 0.38, -extent * 0.7),
		]
		var chosen: Vector3 = candidates[0]
		var world := camera.get_world_3d()
		if world != null:
			for cand in candidates:
				var q := PhysicsRayQueryParameters3D.create(cand, center)
				q.collision_mask = 1 | 128
				var hit := world.direct_space_state.intersect_ray(q)
				if hit.is_empty():
					chosen = cand
					break
				var dist: float = cand.distance_to(hit.get("position", center))
				if dist > 8.0:
					chosen = cand
					break
		camera.global_position = chosen
		if center.distance_to(chosen) > 0.2:
			camera.look_at(center, Vector3.UP)
	playing = false
	finished.emit()
