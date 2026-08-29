extends Node3D

class_name V5AnimationCompatibilityLab

## Isolated V5 vs V1 Idle/Reaction comparison lab.
## Does not inherit production animation stack, battle, or catalog.
## 1 V1 APPROVED IDLE  2 V5 IDLE  3 V1 REACTION  4 V5 REACTION V1
## 5 skeleton  6 bbox  7 camera reset
## 8 V5 REACTION MEDIUM CANDIDATE (not frozen)
## F front  G 3/4  H side
## Camera does not move when switching 1/2/3/4/8.

const PIPELINE := "V5_ANIMATION_COMPATIBILITY"
const FORBIDDEN := [
	"game_ready_v4",
	"game_ready_v3",
	"semantic_solver_v2",
	"solver_v1",
	"actorcore_benchmark",
	"source_rigged",
	"native_skin_audit",
]

@export var fighter_id: String = "terere"
@export var pipeline_id: String = PIPELINE
@export var target_height: float = 2.40
@export var v1_idle_glb: String = ""
@export var v5_idle_glb: String = ""
@export var v1_reaction_glb: String = ""
@export var v5_reaction_glb: String = ""
@export var v5_reaction_medium_glb: String = ""
@export var camera_height: float = 1.6
@export var camera_distance: float = 5.5

const TITLES := {
	"V1_IDLE": "V1 APPROVED IDLE",
	"V5_IDLE": "V5 IDLE",
	"V1_REACTION": "V1 REACTION (FROZEN AUTHORITY)",
	"V5_REACTION": "V5 REACTION V1",
	"V5_REACTION_MEDIUM": "V5 REACTION MEDIUM CANDIDATE (NOT FROZEN)",
}

var _camera: Camera3D
var _overlay: Label
var _candidates: Dictionary = {}
var _players: Dictionary = {}
var _scales: Dictionary = {}
var _active: String = "V1_IDLE"
var _load_ok := false
var _fail_reason := ""
var _skel_on := false
var _bbox_on := false
var _debug_root: Node3D
var _bbox_node: MeshInstance3D
var _handled_frame := -1
var _orbit_yaw := 0.0
var _orbit_pitch := -0.25
var _orbit_dist := 6.0
var _orbit_target := Vector3(0.0, 1.0, 0.0)
var _view := "front"


func _ready() -> void:
	set_process_input(true)
	set_process_unhandled_input(true)
	set_process(true)
	_camera = get_node_or_null("Camera3D") as Camera3D
	_overlay = get_node_or_null("CanvasLayer/Overlay") as Label
	_orbit_dist = camera_distance
	_orbit_target = Vector3(0.0, max(target_height * 0.45, 0.8), 0.0)
	_bind()
	if _load_ok:
		_show("V1_IDLE")
		_reset_camera()
	_refresh_overlay()


func _bind() -> void:
	if pipeline_id != PIPELINE:
		_fail("pipeline_id must be %s" % PIPELINE)
		return
	var paths := {
		"V1_IDLE": v1_idle_glb,
		"V5_IDLE": v5_idle_glb,
		"V1_REACTION": v1_reaction_glb,
		"V5_REACTION": v5_reaction_glb,
		"V5_REACTION_MEDIUM": v5_reaction_medium_glb,
	}
	var roots := {
		"V1_IDLE": get_node_or_null("V1IdleRoot") as Node3D,
		"V5_IDLE": get_node_or_null("V5IdleRoot") as Node3D,
		"V1_REACTION": get_node_or_null("V1ReactionRoot") as Node3D,
		"V5_REACTION": get_node_or_null("V5ReactionRoot") as Node3D,
		"V5_REACTION_MEDIUM": get_node_or_null("V5ReactionMediumRoot") as Node3D,
	}
	for id in paths.keys():
		var path: String = String(paths[id])
		for token in FORBIDDEN:
			if path.find(token) != -1:
				_fail("refused non-lab asset %s" % path)
				return
		if path.find("FighterCatalog") != -1 or path.find("battle") != -1:
			_fail("refused production path %s" % path)
			return
		if not ResourceLoader.exists(path):
			_fail("missing %s" % path)
			return
		var root := roots[id] as Node3D
		if root == null:
			_fail("missing root for %s" % id)
			return
		var inst := _instantiate(path, root)
		if inst == null:
			_fail("failed to instance %s" % path)
			return
		_candidates[id] = inst
		_players[id] = _find_player(inst)
		_apply_presentation_scale(root, inst, id)
		root.visible = false
	_load_ok = true


func _instantiate(path: String, parent: Node3D) -> Node3D:
	var packed: PackedScene = load(path) as PackedScene
	if packed == null:
		return null
	var inst := packed.instantiate()
	if not (inst is Node3D):
		inst.free()
		return null
	parent.add_child(inst)
	return inst as Node3D


func _model_aabb(node: Node) -> AABB:
	var combined := AABB()
	var first := true
	var stack: Array[Node] = [node]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
			var mi := n as MeshInstance3D
			var local: AABB = mi.mesh.get_aabb()
			for i in 8:
				var pt: Vector3 = mi.global_transform * local.get_endpoint(i)
				if first:
					combined = AABB(pt, Vector3.ZERO)
					first = false
				else:
					combined = combined.expand(pt)
		for child in n.get_children():
			stack.append(child)
	return combined


func _apply_presentation_scale(root: Node3D, inst: Node3D, id: String) -> void:
	root.scale = Vector3.ONE
	inst.scale = Vector3.ONE
	var aabb := _model_aabb(inst)
	var native: float = maxf(aabb.size.y, 0.01)
	var s: float = target_height / native
	root.scale = Vector3(s, s, s)
	_scales[id] = {
		"native_height": native,
		"presentation_height": target_height,
		"scale": s,
		"presentation_only": true,
		"mesh_geometry_unmodified": true,
		"rig_rest_unmodified": true,
	}


func _fail(reason: String) -> void:
	_load_ok = false
	_fail_reason = reason
	push_error("[V5_ANIM_COMPAT_LAB] FAIL fighter=%s %s" % [fighter_id, reason])


func _input(event: InputEvent) -> void:
	if _handle(event):
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if _handle(event):
		get_viewport().set_input_as_handled()


func _handle(event: InputEvent) -> bool:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return false
	var key_event := event as InputEventKey
	if Engine.get_process_frames() == _handled_frame:
		return true
	var ident: int = key_event.keycode if key_event.keycode != KEY_NONE else key_event.physical_keycode
	if _apply_key(ident):
		_handled_frame = Engine.get_process_frames()
		return true
	return false


func _apply_key(ident: int) -> bool:
	if ident == KEY_1 or ident == KEY_KP_1:
		_show("V1_IDLE")
		return true
	if ident == KEY_2 or ident == KEY_KP_2:
		_show("V5_IDLE")
		return true
	if ident == KEY_3 or ident == KEY_KP_3:
		_show("V1_REACTION")
		return true
	if ident == KEY_4 or ident == KEY_KP_4:
		_show("V5_REACTION")
		return true
	if ident == KEY_5 or ident == KEY_KP_5:
		_skel_on = not _skel_on
		_rebuild_skeleton_debug()
		return true
	if ident == KEY_6 or ident == KEY_KP_6:
		_bbox_on = not _bbox_on
		_rebuild_bbox()
		return true
	if ident == KEY_7 or ident == KEY_KP_7:
		_reset_camera()
		return true
	if ident == KEY_8 or ident == KEY_KP_8:
		_show("V5_REACTION_MEDIUM")
		return true
	if ident == KEY_F:
		_set_view("front")
		return true
	if ident == KEY_G:
		_set_view("three_quarter")
		return true
	if ident == KEY_H:
		_set_view("side")
		return true
	return false


func _show(id: String) -> void:
	_active = id
	for key in _candidates.keys():
		var root := _root_of(String(key))
		if root:
			root.visible = String(key) == id
		var stop_player := _players.get(key) as AnimationPlayer
		if _live(stop_player):
			stop_player.stop()
			stop_player.active = false
	var play := _players.get(id) as AnimationPlayer
	if _live(play):
		play.active = true
		play.speed_scale = 1.0
		var token := "idle" if id.ends_with("IDLE") else "reaction"
		var clip := _clip_name(play, token)
		if not clip.is_empty():
			var anim: Animation = play.get_animation(clip)
			if anim and token == "idle":
				anim.loop_mode = Animation.LOOP_LINEAR
			play.play(clip)
	if _skel_on:
		_rebuild_skeleton_debug()
	if _bbox_on:
		_rebuild_bbox()
	_refresh_overlay()


func _root_of(id: String) -> Node3D:
	var map := {
		"V1_IDLE": "V1IdleRoot",
		"V5_IDLE": "V5IdleRoot",
		"V1_REACTION": "V1ReactionRoot",
		"V5_REACTION": "V5ReactionRoot",
		"V5_REACTION_MEDIUM": "V5ReactionMediumRoot",
	}
	return get_node_or_null(String(map.get(id, ""))) as Node3D


func _clip_name(player: AnimationPlayer, token: String) -> String:
	if not _live(player):
		return ""
	var names := player.get_animation_list()
	for n in names:
		if String(n).to_lower().contains(token):
			return n
	return names[0] if names.size() > 0 else ""


func _live(node: Object) -> bool:
	if node == null or not is_instance_valid(node):
		return false
	if node is Node:
		var as_node := node as Node
		return (not as_node.is_queued_for_deletion()) and as_node.is_inside_tree()
	return false


func _set_view(view: String) -> void:
	_view = view
	if view == "front":
		_orbit_yaw = 0.0
	elif view == "three_quarter":
		_orbit_yaw = 0.7
	elif view == "side":
		_orbit_yaw = 1.5708
	_orbit_pitch = -0.25
	_apply_orbit()
	_refresh_overlay()


func _reset_camera() -> void:
	_view = "front"
	_orbit_yaw = 0.0
	_orbit_pitch = -0.25
	_orbit_dist = camera_distance
	_orbit_target = Vector3(0.0, max(target_height * 0.45, 0.8), 0.0)
	_apply_orbit()
	_refresh_overlay()


func _apply_orbit() -> void:
	if _camera == null:
		return
	var cp := cos(_orbit_pitch)
	var offset := Vector3(
		sin(_orbit_yaw) * cp * _orbit_dist,
		sin(_orbit_pitch) * _orbit_dist,
		cos(_orbit_yaw) * cp * _orbit_dist
	)
	_camera.current = true
	_camera.position = _orbit_target + offset
	_camera.look_at(_orbit_target)


func _active_node() -> Node3D:
	return _candidates.get(_active) as Node3D


func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node as Skeleton3D
	for child in node.get_children():
		var found := _find_skeleton(child)
		if found:
			return found
	return null


func _find_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var found := _find_player(child)
		if found:
			return found
	return null


func _rebuild_skeleton_debug() -> void:
	if _debug_root != null:
		_debug_root.queue_free()
		_debug_root = null
	if not _skel_on or not _load_ok:
		return
	var model := _active_node()
	var skel := _find_skeleton(model)
	var root := _root_of(_active)
	if skel == null or root == null:
		return
	_debug_root = Node3D.new()
	_debug_root.name = "SkeletonDebug"
	root.add_child(_debug_root)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.15, 1.0, 0.4)
	for i in skel.get_bone_count():
		var marker := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.018
		sphere.height = 0.036
		marker.mesh = sphere
		marker.material_override = mat
		marker.position = skel.to_global(skel.get_bone_global_pose(i).origin)
		_debug_root.add_child(marker)


func _rebuild_bbox() -> void:
	if _bbox_node != null:
		_bbox_node.queue_free()
		_bbox_node = null
	if not _bbox_on or not _load_ok:
		return
	var model := _active_node()
	var root := _root_of(_active)
	if model == null or root == null:
		return
	var aabb := _model_aabb(model)
	if aabb.size.length() < 0.0001:
		return
	_bbox_node = MeshInstance3D.new()
	_bbox_node.name = "BBoxDebug"
	var box := BoxMesh.new()
	box.size = aabb.size
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1.0, 0.85, 0.2, 0.18)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_bbox_node.mesh = box
	_bbox_node.material_override = mat
	_bbox_node.global_position = aabb.position + aabb.size * 0.5
	root.add_child(_bbox_node)


func _process(_delta: float) -> void:
	if not _load_ok:
		return
	if _skel_on:
		_update_skeleton_markers()
	_refresh_overlay()


func _update_skeleton_markers() -> void:
	if _debug_root == null:
		_rebuild_skeleton_debug()
		return
	var model := _active_node()
	var skel := _find_skeleton(model)
	if skel == null:
		return
	var i := 0
	for child in _debug_root.get_children():
		if i >= skel.get_bone_count():
			break
		if child is Node3D:
			(child as Node3D).position = skel.to_global(skel.get_bone_global_pose(i).origin)
		i += 1


func _refresh_overlay() -> void:
	if _overlay == null:
		return
	if not _load_ok:
		_overlay.text = "V5 ANIM COMPAT LAB FAILED | fighter=%s | %s" % [fighter_id, _fail_reason]
		return
	var scale_row: Dictionary = _scales.get(_active, {})
	_overlay.text = "%s V5 ANIMATION COMPATIBILITY\n\nNOW: %s\nview=%s | presentation_height=%.2f | native=%.3f | scale=%.3f (presentation only)\nV5 gray PBR expected (missing source textures)\nReaction V1.1 MEDIUM is NOT frozen\n\n1 V1 APPROVED IDLE\n2 V5 IDLE\n3 V1 REACTION\n4 V5 REACTION V1\n5 skeleton %s\n6 bbox %s\n7 camera reset\n8 V5 REACTION MEDIUM CANDIDATE\nF front  G 3/4  H side" % [
		fighter_id.to_upper(),
		String(TITLES.get(_active, _active)),
		_view,
		target_height,
		float(scale_row.get("native_height", 0.0)),
		float(scale_row.get("scale", 0.0)),
		"ON" if _skel_on else "off",
		"ON" if _bbox_on else "off",
	]


func collect_dump() -> Dictionary:
	var rows := {}
	for id in _candidates.keys():
		var node := _candidates[id] as Node3D
		var player := _players.get(id) as AnimationPlayer
		var skel := _find_skeleton(node)
		var anims: PackedStringArray = player.get_animation_list() if _live(player) else PackedStringArray()
		rows[id] = {
			"loaded": node != null,
			"bone_count": skel.get_bone_count() if skel else 0,
			"animations": Array(anims),
			"presentation": _scales.get(id, {}),
		}
	return {
		"fighter": fighter_id,
		"pipeline": pipeline_id,
		"target_height": target_height,
		"load_ok": _load_ok,
		"fail_reason": _fail_reason,
		"fallback": false,
		"active": _active,
		"candidates": rows,
		"v5_is_canonical": false,
		"reaction_medium_frozen": false,
		"production_untouched": true,
	}
