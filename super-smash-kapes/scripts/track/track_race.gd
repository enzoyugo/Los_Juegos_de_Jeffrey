class_name TrackRace
extends Node3D

signal checkpoint_reached(index: int, is_finish: bool)

const Generator := preload("res://scripts/track/track_generator.gd")
const Checkpoint := preload("res://scripts/track/track_checkpoint.gd")
const EnvPlacer := preload("res://scripts/track/track_environment_placer_v1.gd")
const VQ := preload("res://scripts/track/track_visual_quality_v2.gd")

var track_data: Dictionary = {}
var start_transform := Transform3D.IDENTITY
var _mat_cache: Dictionary = {}
var _unit_box: BoxMesh = null
var _last_inventory: Dictionary = {}
var _last_env_stats: Dictionary = {}
var _env_root: Node3D = null
var _vq = null


func build(seed_value: int, length_id: String, difficulty_id: String) -> Dictionary:
	var diag := OS.get_environment("SSK_PERF_DIAG") == "1"
	var t0 := Time.get_ticks_usec() if diag else 0
	for child in get_children():
		remove_child(child)
		child.free()
	_mat_cache.clear()
	_env_root = null
	_vq = VQ.shared()
	_unit_box = BoxMesh.new()
	_unit_box.size = Vector3.ONE
	var t_clear := Time.get_ticks_usec() if diag else 0
	var gen = Generator.new()
	track_data = gen.generate(seed_value, length_id, difficulty_id)
	var t_gen := Time.get_ticks_usec() if diag else 0
	start_transform = track_data.get("start_transform", Transform3D.IDENTITY)
	start_transform.origin.y += 1.1
	var solids: Array = track_data.get("solids", [])
	_place_solids_batched(solids)
	var t_solids := Time.get_ticks_usec() if diag else 0
	_place_checkpoints(track_data.get("checkpoints", []))
	var t_checks := Time.get_ticks_usec() if diag else 0
	_place_environment()
	_place_roadside(solids)
	_place_road_markings(solids)
	_place_environment_kit(solids, seed_value)
	var t_env := Time.get_ticks_usec() if diag else 0
	_last_inventory = inventory_counts()
	if diag:
		print(
			"[TRACK_BUILD] clear_ms=%.2f generate_ms=%.2f solids_ms=%.2f(%d) checkpoints_ms=%.2f env_ms=%.2f total_ms=%.2f nodes=%d draw_batches=%d"
			% [
				float(t_clear - t0) / 1000.0,
				float(t_gen - t_clear) / 1000.0,
				float(t_solids - t_gen) / 1000.0,
				solids.size(),
				float(t_checks - t_solids) / 1000.0,
				float(t_env - t_checks) / 1000.0,
				float(t_env - t0) / 1000.0,
				int(_last_inventory.get("total", 0)),
				int(_last_inventory.get("multimesh", 0)),
			]
		)
		print("[TRACK_NODE_INVENTORY] %s" % JSON.stringify(_last_inventory))
		if not _last_env_stats.is_empty():
			print("[TRACK_ENV_KIT_V1] %s" % JSON.stringify(_last_env_stats))
	return track_data


func inventory_counts() -> Dictionary:
	var counts := {
		"StaticBody3D": 0,
		"CollisionShape3D": 0,
		"MeshInstance3D": 0,
		"MultiMeshInstance3D": 0,
		"WorldEnvironment": 0,
		"DirectionalLight3D": 0,
		"other": 0,
		"total": 0,
		"multimesh": 0,
	}
	_count_nodes(self, counts)
	counts["total"] = get_child_count_recursive()
	counts["multimesh"] = counts["MultiMeshInstance3D"]
	return counts


func get_child_count_recursive() -> int:
	return _count_all(self)


func _count_all(node: Node) -> int:
	var n := 1
	for child in node.get_children():
		n += _count_all(child)
	return n


func _count_nodes(node: Node, counts: Dictionary) -> void:
	for child in node.get_children():
		var cname := child.get_class()
		if counts.has(cname):
			counts[cname] = int(counts[cname]) + 1
		else:
			counts["other"] = int(counts["other"]) + 1
		_count_nodes(child, counts)


func _place_solids_batched(solids: Array) -> void:
	## Collision stays per-solid (physics fidelity). Visuals batch by kind via MultiMesh.
	## visual_only solids skip collision bodies.
	var by_key: Dictionary = {}
	for item in solids:
		var kind := str(item.get("kind", ""))
		var color: Color = item.get("color", Color("#2a3038"))
		var key := "%s:%s" % [kind, color.to_html(true)]
		if not by_key.has(key):
			by_key[key] = {"kind": kind, "color": color, "items": []}
		by_key[key]["items"].append(item)
		if bool(item.get("visual_only", false)):
			continue
		var body := StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		body.transform = item["transform"]
		var col := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = item["size"]
		col.shape = shape
		body.add_child(col)
		add_child(body)
	for key in by_key.keys():
		var bucket: Dictionary = by_key[key]
		var items: Array = bucket["items"]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = _unit_box
		mm.instance_count = items.size()
		var i := 0
		for item in items:
			var xf: Transform3D = item["transform"]
			var size: Vector3 = item["size"]
			var scaled := Transform3D(xf.basis.scaled(size), xf.origin)
			mm.set_instance_transform(i, scaled)
			i += 1
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = _vq.material_for_solid_kind(str(bucket["kind"]), bucket["color"])
		mmi.cast_shadow = (
			GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			if str(bucket["kind"]) in ["road", "rail"]
			else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		)
		add_child(mmi)


func _shared_color(color: Color) -> StandardMaterial3D:
	var key := color.to_html(true)
	if _mat_cache.has(key):
		return _mat_cache[key]
	if _vq == null:
		_vq = VQ.shared()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.82
	mat.metallic = 0.04
	_mat_cache[key] = mat
	return mat


func _place_checkpoints(marks: Array) -> void:
	var i := 0
	for mark in marks:
		var gate = Checkpoint.new()
		add_child(gate)
		var finish := bool(mark.get("is_finish", false))
		gate.setup(i, mark["transform"], finish)
		gate.reached.connect(func(index, fin): checkpoint_reached.emit(index, fin))
		## Authored gantry / markers — collision Area stays on Checkpoint.
		if _vq == null:
			_vq = VQ.shared()
		_vq.attach_checkpoint_markers(self, mark["transform"], finish or i == 0)
		i += 1


func _place_environment() -> void:
	var sun := DirectionalLight3D.new()
	## Lower sun for longer readable shadows / building facade contrast.
	sun.rotation_degrees = Vector3(-42, 36, 0)
	sun.light_energy = 1.62
	sun.light_color = Color("#ffe6c8")
	sun.shadow_enabled = true
	sun.shadow_blur = 1.35
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 180.0
	add_child(sun)
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	## Asunción late afternoon — warmer horizon, cooler zenith, less dead sky.
	sky_mat.sky_top_color = Color("#07101c")
	sky_mat.sky_horizon_color = Color("#d0a878")
	sky_mat.ground_bottom_color = Color("#1c2618")
	sky_mat.ground_horizon_color = Color("#5a6848")
	sky_mat.sun_angle_max = 26.0
	sky_mat.sun_curve = 0.09
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.40
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.04
	env.fog_enabled = true
	env.fog_light_color = Color("#b89870")
	env.fog_density = 0.0009
	env.fog_aerial_perspective = 0.48
	env.fog_sky_affect = 0.35
	world.environment = env
	add_child(world)
	_place_horizon()


func _place_horizon() -> void:
	if _vq == null:
		_vq = VQ.shared()
	## Layered ground with grain materials — not a single editor floor.
	var layers := [
		{"size": Vector2(900, 900), "y": -0.58, "mat": "ground_concrete"},
		{"size": Vector2(720, 720), "y": -0.44, "mat": "ground"},
		{"size": Vector2(480, 480), "y": -0.36, "mat": "ground_grass"},
	]
	for layer in layers:
		var ground := MeshInstance3D.new()
		var plane := PlaneMesh.new()
		plane.size = layer["size"]
		ground.mesh = plane
		ground.position = Vector3(0.0, float(layer["y"]), 0.0)
		ground.set_surface_override_material(0, _vq.mat(str(layer["mat"])))
		ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(ground)
	## Dense midground patches — dirt / grass / parking breakup.
	var patch_mm := MultiMesh.new()
	patch_mm.transform_format = MultiMesh.TRANSFORM_3D
	var patch_mesh := BoxMesh.new()
	patch_mesh.size = Vector3(11.0, 0.05, 11.0)
	patch_mm.mesh = patch_mesh
	patch_mm.instance_count = 14
	for i in 14:
		var ang := float(i) / 14.0 * TAU
		var r := 20.0 + float(i % 4) * 10.0
		var xf := Transform3D(
			Basis.from_euler(Vector3(0, ang * 0.4, 0)).scaled(Vector3(rng_scale(i), 1.0, rng_scale(i + 3))),
			Vector3(cos(ang) * r, -0.30, sin(ang) * r)
		)
		patch_mm.set_instance_transform(i, xf)
	var patch_mmi := MultiMeshInstance3D.new()
	patch_mmi.multimesh = patch_mm
	patch_mmi.material_override = _vq.mat("ground_parking")
	patch_mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(patch_mmi)
	var grass_mm := MultiMesh.new()
	grass_mm.transform_format = MultiMesh.TRANSFORM_3D
	grass_mm.mesh = patch_mesh
	grass_mm.instance_count = 10
	for i in 10:
		var ang := float(i) / 10.0 * TAU + 0.4
		var r := 34.0 + float(i % 3) * 12.0
		grass_mm.set_instance_transform(i, Transform3D(
			Basis.from_euler(Vector3(0, ang, 0)).scaled(Vector3(1.3, 1.0, 1.3)),
			Vector3(cos(ang) * r, -0.29, sin(ang) * r)
		))
	var grass_mmi := MultiMeshInstance3D.new()
	grass_mmi.multimesh = grass_mm
	grass_mmi.material_override = _vq.mat("ground_grass")
	grass_mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(grass_mmi)


func rng_scale(i: int) -> float:
	return 0.85 + float((i * 17) % 7) * 0.08


func _place_environment_kit(solids: Array, seed_value: int) -> void:
	_env_root = Node3D.new()
	_env_root.name = "TrackEnvironmentKitV1"
	add_child(_env_root)
	var placer = EnvPlacer.new()
	_last_env_stats = placer.build(_env_root, solids, seed_value)


func set_environment_visible(on: bool) -> void:
	if _env_root != null:
		_env_root.visible = on


func environment_stats() -> Dictionary:
	return _last_env_stats.duplicate(true)


func _place_roadside(solids: Array) -> void:
	## Sparse posts only — avoid doubling guardrail visual noise (rails already on solids).
	var posts: Array = []
	var n := 0
	for item in solids:
		if str(item.get("kind", "")) != "road":
			continue
		n += 1
		if n % 5 != 0:
			continue
		var xf: Transform3D = item["transform"]
		var size: Vector3 = item["size"]
		var right := xf.basis.x.normalized()
		var half_w := size.x * 0.55 + 0.55
		for side_f in [-1.0, 1.0]:
			var origin: Vector3 = xf.origin + right * half_w * side_f + Vector3.UP * 0.9
			posts.append(Transform3D(Basis.IDENTITY, origin))
	if posts.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var post_mesh := BoxMesh.new()
	post_mesh.size = Vector3(0.14, 1.6, 0.14)
	mm.mesh = post_mesh
	mm.instance_count = posts.size()
	for i in posts.size():
		mm.set_instance_transform(i, posts[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = _vq.mat("rail_metal") if _vq != null else _shared_color(Color("#3a424c"))
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)


func _place_road_markings(solids: Array) -> void:
	## Center dashes + edge lines for asphalt readability.
	var dashes: Array = []
	var edges: Array = []
	var n := 0
	for item in solids:
		if str(item.get("kind", "")) != "road":
			continue
		n += 1
		var xf: Transform3D = item["transform"]
		var size: Vector3 = item["size"]
		if size.z < 2.5 and size.x < 2.5:
			continue
		var up := xf.basis.y.normalized()
		var right := xf.basis.x.normalized()
		if n % 2 == 0:
			var mark := Transform3D(xf.basis, xf.origin + up * (size.y * 0.5 + 0.04))
			dashes.append({"xf": mark, "size": Vector3(0.18, 0.03, mini(size.z, size.x) * 0.32)})
		## Edge lines every road slab
		var edge_y := xf.origin + up * (size.y * 0.5 + 0.035)
		var half := size.x * 0.5 - 0.35
		for side in [-1.0, 1.0]:
			var exf := Transform3D(xf.basis, edge_y + right * half * side)
			edges.append({"xf": exf, "size": Vector3(0.12, 0.025, size.z * 0.92)})
	if not dashes.is_empty():
		_emit_mark_batch(dashes, "marking")
	if not edges.is_empty():
		_emit_mark_batch(edges, "edge")


func _emit_mark_batch(items: Array, mat_key: String) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _unit_box
	mm.instance_count = items.size()
	for i in items.size():
		var d: Dictionary = items[i]
		var xf: Transform3D = d["xf"]
		var size: Vector3 = d["size"]
		mm.set_instance_transform(i, Transform3D(xf.basis.scaled(size), xf.origin))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = _vq.mat(mat_key) if _vq != null else _shared_color(Color("#e8f0f6"))
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
