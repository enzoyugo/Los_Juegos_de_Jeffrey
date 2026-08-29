class_name TrackEnvironmentPlacerV1
extends RefCounted

## Procedural Track environment placement for V1 solids.
## Deterministic from track seed. Visual-only (no vehicle collision).
## Zones: URBAN / COMMERCIAL / GREEN / OPEN — presentation only.

const KitScript := preload("res://scripts/track/track_environment_kit_v1.gd")

const ZONE_URBAN := "urban"
const ZONE_COMMERCIAL := "commercial"
const ZONE_GREEN := "green"
const ZONE_OPEN := "open"

## Near-road clearance past solid half-width (keeps props off driveline).
const CLEAR_NEAR := 1.15
const CLEAR_MID := 6.5
const CLEAR_FAR := 14.0
const CLEAR_SKYLINE := 22.0
const SAMPLE_STRIDE := 2

var enabled: bool = true
var last_stats: Dictionary = {}


func build(host: Node3D, solids: Array, seed_value: int) -> Dictionary:
	last_stats = {
		"enabled": enabled,
		"samples": 0,
		"batches": 0,
		"instances": 0,
		"zones": {},
	}
	if not enabled or host == null:
		return last_stats
	if OS.get_environment("SSK_TRACK_SCENERY") == "0":
		last_stats["enabled"] = false
		return last_stats

	var kit = KitScript.new()
	kit.ensure_built()
	var rng := RandomNumberGenerator.new()
	rng.seed = _scenery_seed(seed_value)

	var samples := _road_samples(solids)
	last_stats["samples"] = samples.size()
	if samples.is_empty():
		_emit_distant_ring(host, kit, Vector3.ZERO, rng)
		return last_stats

	var zones := _assign_zones(samples.size(), rng)
	var buckets: Dictionary = {}
	var zone_counts := {ZONE_URBAN: 0, ZONE_COMMERCIAL: 0, ZONE_GREEN: 0, ZONE_OPEN: 0}

	for i in samples.size():
		var sample: Dictionary = samples[i]
		var zone: String = str(zones[i])
		zone_counts[zone] = int(zone_counts.get(zone, 0)) + 1
		_place_sample(buckets, kit, sample, zone, rng, i)

	_emit_buckets(host, kit, buckets)
	_emit_skyline(host, kit, samples, rng)
	_emit_ground_context(host, kit, samples, zones, rng)
	last_stats["zones"] = zone_counts
	last_stats["promotion"] = kit.promotion_report
	_print_diag()
	return last_stats


func _scenery_seed(track_seed: int) -> int:
	## Derived RNG — does not alter track geometry seed semantics.
	return int((track_seed * 7919) ^ 0x4A3F11) & 0x7FFFFFFF


func _road_samples(solids: Array) -> Array:
	var out: Array = []
	var n := 0
	for item in solids:
		if not _is_road_solid(item):
			continue
		n += 1
		if n % SAMPLE_STRIDE != 0:
			continue
		var xf: Transform3D = item["transform"]
		var size: Vector3 = item["size"]
		var right := xf.basis.x.normalized()
		var forward := (-xf.basis.z).normalized()
		## Prefer kind-aware width; fall back to darker solid size.
		var half_w := maxf(size.x, size.z) * 0.5
		if size.x >= size.z:
			half_w = size.x * 0.5
		else:
			## Long axis along Z — lateral is X still for standard road packing.
			half_w = size.x * 0.5
		out.append({
			"origin": xf.origin,
			"right": right,
			"forward": forward,
			"yaw": atan2(forward.x, forward.z),
			"half_w": half_w,
			"y": xf.origin.y,
		})
	return out


func _is_road_solid(item: Dictionary) -> bool:
	var kind := str(item.get("kind", ""))
	if kind == "road":
		return true
	if kind == "shoulder" or kind == "rail":
		return false
	## Fallback for older data without kind.
	var color: Color = item.get("color", Color.BLACK)
	return color.v <= 0.42


func _assign_zones(count: int, rng: RandomNumberGenerator) -> PackedStringArray:
	var zones := PackedStringArray()
	if count <= 0:
		return zones
	var palette: Array = [ZONE_URBAN, ZONE_COMMERCIAL, ZONE_GREEN, ZONE_OPEN]
	## Shuffle once so every zone appears when the track is long enough.
	for i in range(palette.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = palette[i]
		palette[i] = palette[j]
		palette[j] = tmp
	var i := 0
	var palette_i := 0
	while i < count:
		var zone: String = str(palette[palette_i % palette.size()])
		palette_i += 1
		var run := clampi(rng.randi_range(5, 12), 1, count - i)
		for _k in run:
			zones.append(zone)
			i += 1
			if i >= count:
				break
	return zones


func _place_sample(buckets: Dictionary, kit, sample: Dictionary, zone: String, rng: RandomNumberGenerator, index: int) -> void:
	var origin: Vector3 = sample["origin"]
	var right: Vector3 = sample["right"]
	var forward: Vector3 = sample["forward"]
	var yaw: float = sample["yaw"]
	var half_w: float = sample["half_w"]
	var base_y: float = sample["y"]

	for side in [-1.0, 1.0]:
		var lateral: Vector3 = right * side
		var near: Vector3 = origin + lateral * (half_w + CLEAR_NEAR)
		var mid: Vector3 = origin + lateral * (half_w + CLEAR_MID)
		var far: Vector3 = origin + lateral * (half_w + CLEAR_FAR)
		near.y = base_y
		mid.y = base_y
		far.y = base_y

		## Near: curb always; barriers only where zones want them (less rail spam).
		if index % 2 == 0:
			_push(buckets, KitScript.Piece.CURB, _yawed(near + Vector3(0, 0.11, 0) + forward * rng.randf_range(-0.4, 0.4), yaw))
		var want_barrier := false
		match zone:
			ZONE_URBAN:
				want_barrier = index % 5 == 0
			ZONE_COMMERCIAL:
				want_barrier = index % 4 == 0
			ZONE_GREEN:
				want_barrier = index % 8 == 0
			ZONE_OPEN:
				want_barrier = index % 10 == 0
		if want_barrier:
			if kit.uses_promoted(KitScript.Piece.BARRIER_PROMOTED):
				_push_promoted(buckets, kit, KitScript.Piece.BARRIER_PROMOTED, near + lateral * 0.35, yaw)
			else:
				_push(buckets, KitScript.Piece.GUARD_RAIL, _yawed(near + lateral * 0.35 + Vector3(0, 0.35, 0), yaw))

		match zone:
			ZONE_URBAN:
				if index % 2 == 0:
					_push_street_light(buckets, mid + forward * rng.randf_range(-0.8, 0.8), yaw, kit)
				if index % 4 == 0:
					_push(buckets, KitScript.Piece.LOW_WALL, _yawed(mid + lateral * 1.2 + Vector3(0, 0.55, 0), yaw))
				if index % 5 == 0:
					_push(buckets, KitScript.Piece.UTILITY_POLE, _yawed(mid + lateral * 0.8 + Vector3(0, 2.7, 0), yaw))
				if index % 4 == 0:
					if kit.uses_promoted(KitScript.Piece.BUILDING_SMALL_PROMOTED):
						_push_promoted(buckets, kit, KitScript.Piece.BUILDING_SMALL_PROMOTED, far + forward * rng.randf_range(-1.5, 1.5), yaw + (PI if side > 0.0 else 0.0))
					else:
						_push(buckets, KitScript.Piece.BUILDING_SMALL, _yawed(far + Vector3(0, 2.75, 0) + forward * rng.randf_range(-1.5, 1.5), yaw + (PI if side > 0.0 else 0.0)))
				if index % 7 == 0:
					_push(buckets, KitScript.Piece.ROAD_SIGN, _yawed(near + lateral * 0.6 + Vector3(0, 1.2, 0), yaw))
			ZONE_COMMERCIAL:
				if index % 3 == 0:
					_push_street_light(buckets, mid, yaw, kit)
				if index % 3 == 0:
					_push_billboard(buckets, far + lateral * 2.0, yaw + PI * 0.5 * side, kit)
				if index % 3 == 0:
					if kit.uses_promoted(KitScript.Piece.BUILDING_BLOCK_PROMOTED):
						_push_promoted(buckets, kit, KitScript.Piece.BUILDING_BLOCK_PROMOTED, far + lateral * 3.0, yaw)
					else:
						_push(buckets, KitScript.Piece.BUILDING_BLOCK, _yawed(far + lateral * 3.0 + Vector3(0, 4.25, 0), yaw))
				if index % 5 == 0:
					_push(buckets, KitScript.Piece.ROAD_SIGN, _yawed(mid + Vector3(0, 1.4, 0), yaw))
			ZONE_GREEN:
				if index % 2 == 0:
					if rng.randf() < 0.55:
						_push_palm(buckets, mid + forward * rng.randf_range(-1.0, 1.0), yaw, kit)
					else:
						_push_tree(buckets, mid + forward * rng.randf_range(-1.0, 1.0), yaw, kit)
				if index % 6 == 0:
					_push_street_light(buckets, mid + lateral * 1.5, yaw, kit)
				if index % 8 == 0:
					if kit.uses_promoted(KitScript.Piece.BUILDING_SMALL_PROMOTED):
						_push_promoted(buckets, kit, KitScript.Piece.BUILDING_SMALL_PROMOTED, far + lateral * 4.0, yaw)
					else:
						_push(buckets, KitScript.Piece.BUILDING_SMALL, _yawed(far + lateral * 4.0 + Vector3(0, 2.75, 0), yaw))
			ZONE_OPEN:
				if index % 4 == 0:
					_push(buckets, KitScript.Piece.UTILITY_POLE, _yawed(mid + Vector3(0, 2.7, 0), yaw))
				if index % 5 == 0:
					_push(buckets, KitScript.Piece.ROAD_SIGN, _yawed(near + lateral * 0.5 + Vector3(0, 1.2, 0), yaw))
				if index % 6 == 0:
					_push(buckets, KitScript.Piece.LOW_WALL, _yawed(mid + Vector3(0, 0.55, 0), yaw))


func _push_street_light(buckets: Dictionary, pos: Vector3, yaw: float, kit = null) -> void:
	if kit != null and kit.uses_promoted(KitScript.Piece.LAMP_PROMOTED):
		_push_promoted(buckets, kit, KitScript.Piece.LAMP_PROMOTED, pos, yaw)
		return
	_push(buckets, KitScript.Piece.STREET_LIGHT_POLE, _yawed(pos + Vector3(0, 2.1, 0), yaw))
	_push(buckets, KitScript.Piece.STREET_LIGHT_HEAD, _yawed(pos + Vector3(0, 4.35, 0.2), yaw))


func _push_tree(buckets: Dictionary, pos: Vector3, yaw: float, kit = null) -> void:
	if kit != null and kit.uses_promoted(KitScript.Piece.TREE_PROMOTED):
		_push_promoted(buckets, kit, KitScript.Piece.TREE_PROMOTED, pos, yaw)
		return
	_push(buckets, KitScript.Piece.TREE_TRUNK, _yawed(pos + Vector3(0, 1.2, 0), yaw))
	_push(buckets, KitScript.Piece.TREE_CROWN, _yawed(pos + Vector3(0, 3.4, 0), yaw))


func _push_palm(buckets: Dictionary, pos: Vector3, yaw: float, kit = null) -> void:
	if kit != null and kit.uses_promoted(KitScript.Piece.PALM_PROMOTED):
		_push_promoted(buckets, kit, KitScript.Piece.PALM_PROMOTED, pos, yaw)
		return
	_push(buckets, KitScript.Piece.PALM_TRUNK, _yawed(pos + Vector3(0, 2.0, 0), yaw))
	_push(buckets, KitScript.Piece.PALM_CROWN, _yawed(pos + Vector3(0, 4.2, 0), yaw))


func _push_billboard(buckets: Dictionary, pos: Vector3, yaw: float, kit = null) -> void:
	## Always use pole + face boxes so signage atlas UVs are correct.
	_push(buckets, KitScript.Piece.BILLBOARD_POLE, _yawed(pos + Vector3(0, 2.25, 0), yaw))
	_push(buckets, KitScript.Piece.BILLBOARD_FACE, _yawed(pos + Vector3(0, 4.2, 0), yaw))


func _push_promoted(buckets: Dictionary, kit, piece: int, pos: Vector3, yaw: float) -> void:
	var s: float = kit.promo_scale(piece)
	var lift: float = kit.ground_lift(piece)
	var basis := Basis.from_euler(Vector3(0.0, yaw, 0.0)).scaled(Vector3(s, s, s))
	_push(buckets, piece, Transform3D(basis, pos + Vector3(0, lift, 0)))


func _yawed(pos: Vector3, yaw: float) -> Transform3D:
	return Transform3D(Basis.from_euler(Vector3(0.0, yaw, 0.0)), pos)


func _push(buckets: Dictionary, piece: int, xf: Transform3D) -> void:
	if not buckets.has(piece):
		buckets[piece] = []
	buckets[piece].append(xf)


func _emit_buckets(host: Node3D, kit, buckets: Dictionary) -> void:
	var instances := 0
	var batches := 0
	for piece in buckets.keys():
		var xfs: Array = buckets[piece]
		if xfs.is_empty():
			continue
		kit.emit_batch(host, int(piece), xfs)
		batches += 1
		instances += xfs.size()
	last_stats["batches"] = int(last_stats.get("batches", 0)) + batches
	last_stats["instances"] = int(last_stats.get("instances", 0)) + instances


func _emit_skyline(host: Node3D, kit, samples: Array, rng: RandomNumberGenerator) -> void:
	if samples.is_empty():
		return
	var mid: Dictionary = samples[int(samples.size() * 0.5)]
	var center: Vector3 = mid["origin"]
	center.y = 0.0
	var blocks: Array = []
	var sils: Array = []
	var use_promo: bool = kit.uses_promoted(KitScript.Piece.SKYLINE_PROMOTED)
	var s: float = kit.promo_scale(KitScript.Piece.SKYLINE_PROMOTED) if use_promo else 1.0
	var lift: float = kit.ground_lift(KitScript.Piece.SKYLINE_PROMOTED) if use_promo else 7.0
	for i in 18:
		var ang := float(i) / 18.0 * TAU + rng.randf_range(-0.04, 0.04)
		var radius := CLEAR_SKYLINE + rng.randf_range(0.0, 18.0)
		var pos := center + Vector3(cos(ang) * radius, 0.0, sin(ang) * radius)
		var h_scale := rng.randf_range(0.9, 2.4)
		var yaw := ang + PI
		if use_promo:
			var basis := Basis.from_euler(Vector3(0, yaw, 0)).scaled(Vector3(s * h_scale, s * h_scale * 1.05, s * h_scale))
			blocks.append(Transform3D(basis, pos + Vector3(0, lift * h_scale, 0)))
		else:
			var block_pos := pos + Vector3(0, 7.0 * h_scale, 0)
			blocks.append(Transform3D(Basis.from_euler(Vector3(0, yaw, 0)).scaled(Vector3(1.0, h_scale, 1.0)), block_pos))
		var sil_pos := center + Vector3(cos(ang + 0.1) * (radius + 8.0), 6.0 + rng.randf_range(0.0, 5.0), sin(ang + 0.1) * (radius + 8.0))
		sils.append(Transform3D(Basis.from_euler(Vector3(0, yaw, 0)).scaled(Vector3(1.5, rng.randf_range(0.9, 1.8), 1.0)), sil_pos))
	if use_promo:
		kit.emit_batch(host, KitScript.Piece.SKYLINE_PROMOTED, blocks)
	else:
		kit.emit_batch(host, KitScript.Piece.SKYLINE_BLOCK, blocks)
	kit.emit_batch(host, KitScript.Piece.SKYLINE_SILHOUETTE, sils)
	last_stats["batches"] = int(last_stats.get("batches", 0)) + 2
	last_stats["instances"] = int(last_stats.get("instances", 0)) + blocks.size() + sils.size()


func _emit_distant_ring(host: Node3D, kit, center: Vector3, rng: RandomNumberGenerator) -> void:
	_emit_skyline(host, kit, [{"origin": center}], rng)


func _emit_ground_context(host: Node3D, kit, samples: Array, zones: PackedStringArray, rng: RandomNumberGenerator) -> void:
	var patches: Array = []
	var green: Array = []
	var parking: Array = []
	var stride := maxi(int(samples.size() / 28.0), 2)
	for i in range(0, samples.size(), stride):
		var sample: Dictionary = samples[i]
		var zone := str(zones[i]) if i < zones.size() else ZONE_OPEN
		var origin: Vector3 = sample["origin"]
		var right: Vector3 = sample["right"]
		for side in [-1.0, 1.0]:
			var dist: float = sample["half_w"] + rng.randf_range(7.0, 14.0)
			var p: Vector3 = origin + right * side * dist
			p.y = sample["y"] - 0.18
			var sc: float = rng.randf_range(1.1, 1.8)
			var xf := Transform3D(Basis.from_euler(Vector3(0, sample["yaw"], 0)).scaled(Vector3(sc, 1.0, sc)), p)
			match zone:
				ZONE_GREEN:
					green.append(xf)
				ZONE_COMMERCIAL:
					parking.append(xf)
				ZONE_URBAN:
					patches.append(xf)
				_:
					if rng.randf() < 0.5:
						green.append(xf)
					else:
						patches.append(xf)
	if not patches.is_empty():
		kit.emit_batch(host, KitScript.Piece.GROUND_PATCH, patches)
		last_stats["batches"] = int(last_stats.get("batches", 0)) + 1
		last_stats["instances"] = int(last_stats.get("instances", 0)) + patches.size()
	if not green.is_empty():
		_emit_ground_mat(host, kit, green, KitScript.COLORS["ground_green"])
	if not parking.is_empty():
		_emit_ground_mat(host, kit, parking, Color("#323840"))


func _emit_ground_mat(host: Node3D, kit, xfs: Array, color: Color) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = kit.mesh_for(KitScript.Piece.GROUND_PATCH)
	mm.instance_count = xfs.size()
	for gi in xfs.size():
		mm.set_instance_transform(gi, xfs[gi])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	var vq = preload("res://scripts/track/track_visual_quality_v2.gd").shared()
	if color.is_equal_approx(KitScript.COLORS["ground_green"]):
		mmi.material_override = vq.mat("ground_grass")
	else:
		mmi.material_override = vq.mat("ground_parking")
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	host.add_child(mmi)
	last_stats["batches"] = int(last_stats.get("batches", 0)) + 1
	last_stats["instances"] = int(last_stats.get("instances", 0)) + xfs.size()


func _print_diag() -> void:
	if OS.get_environment("SSK_PERF_DIAG") != "1" and OS.get_environment("SSK_TRACK_ENV_DIAG") != "1":
		return
	print(
		"[TRACK_ENV_KIT_V1] samples=%d batches=%d instances=%d zones=%s"
		% [
			int(last_stats.get("samples", 0)),
			int(last_stats.get("batches", 0)),
			int(last_stats.get("instances", 0)),
			JSON.stringify(last_stats.get("zones", {})),
		]
	)
