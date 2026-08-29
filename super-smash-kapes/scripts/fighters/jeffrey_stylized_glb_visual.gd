class_name JeffreyStylizedGlbVisual
extends "res://scripts/fighters/jeffrey_stylized_fighter_visual.gd"

## Loads first-party stylized production GLB when present; otherwise builds procedural mesh.
## Optional Fort V2 candidate: set env SSK_FORT_V2_CANDIDATE=1 (does not change production catalog).

const FORT_V2_CANDIDATE_GLB := "res://assets/fighters/processed/fort/fort_stylized_v2_candidate.glb"

var _glb_root: Node3D
var _used_glb: bool = false


func bind(fighter_ref, fighter_definition) -> void:
	## Always bind fighter identity; prefer production GLB when present.
	fighter = fighter_ref
	definition = fighter_definition
	scale = Vector3.ONE * definition.visual_scale
	position = definition.visual_offset
	if body_pivot != null:
		return
	if _try_load_glb():
		_used_glb = true
		_collect_materials(_glb_root)
		return
	## Procedural fallback (parent builds named limbs for motion).
	super.bind(fighter_ref, fighter_definition)


func _collect_materials(node: Node) -> void:
	for child in node.find_children("*", "MeshInstance3D", true, false):
		var mi := child as MeshInstance3D
		if mi == null:
			continue
		if mi.material_override is StandardMaterial3D:
			_materials.append(mi.material_override as StandardMaterial3D)
		elif mi.get_active_material(0) is StandardMaterial3D:
			_materials.append(mi.get_active_material(0) as StandardMaterial3D)


func _resolve_glb_path() -> String:
	if definition != null and str(definition.id) == "fort":
		if OS.get_environment("SSK_FORT_V2_CANDIDATE") == "1" and ResourceLoader.exists(FORT_V2_CANDIDATE_GLB):
			return FORT_V2_CANDIDATE_GLB
	if definition == null:
		return ""
	return str(definition.production_glb_path)


func _try_load_glb() -> bool:
	var path := _resolve_glb_path()
	if path.is_empty() or not ResourceLoader.exists(path):
		return false
	var packed = load(path)
	if packed == null or not (packed is PackedScene):
		return false
	_glb_root = (packed as PackedScene).instantiate() as Node3D
	if _glb_root == null:
		return false
	_glb_root.name = "StylizedGlbRoot"
	## Blender +Y forward → glTF −Z; rotate so default facing matches FighterVisual (+X).
	_glb_root.rotation_degrees.y = 90.0
	add_child(_glb_root)
	_fit_height(_glb_root, float(definition.target_visual_height) if definition.target_visual_height > 0.0 else 2.75)
	body_pivot = _glb_root
	arm_l = _find_named(_glb_root, "ArmL")
	arm_r = _find_named(_glb_root, "ArmR")
	leg_l = _find_named(_glb_root, "LegL")
	leg_r = _find_named(_glb_root, "LegR")
	accent_node = _find_named(_glb_root, "Star")
	return true


func _fit_height(node: Node3D, target_h: float) -> void:
	var aabb := _mesh_aabb(node)
	var h := aabb.size.y
	if h < 0.01:
		return
	var s := target_h / h
	node.scale = Vector3.ONE * s
	## Keep feet near y=0.
	var aabb2 := _mesh_aabb(node)
	node.position.y -= aabb2.position.y


func _mesh_aabb(node: Node) -> AABB:
	var first := true
	var result := AABB()
	for child in node.find_children("*", "MeshInstance3D", true, false):
		var mi := child as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		var local := mi.get_aabb()
		var xf := mi.global_transform
		if node is Node3D:
			xf = (node as Node3D).global_transform.affine_inverse() * mi.global_transform
		var world := _xform_aabb(local, xf)
		if first:
			result = world
			first = false
		else:
			result = result.merge(world)
	return result


func _xform_aabb(aabb: AABB, xf: Transform3D) -> AABB:
	var pts: Array[Vector3] = []
	for i in range(8):
		pts.append(xf * aabb.get_endpoint(i))
	var out := AABB(pts[0], Vector3.ZERO)
	for p in pts:
		out = out.expand(p)
	return out


func _find_named(root: Node, needle: String) -> Node3D:
	for child in root.find_children(needle, "", true, false):
		if child is Node3D:
			return child as Node3D
	return null
