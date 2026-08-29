extends Node3D

## Isolated Clean Rig V1 Idle retarget A/B lab.
## Runtime (F6) only: 1 rest  2 traditional idle  3 semantic idle  4 skeleton  5 bbox  6 camera reset
## Editor 3D viewport number keys are Godot camera views (Emulate Numpad). They are not lab controls.
## Isolated from battle, catalog, V4, FBX, fallback, and battle HUD.

const PIPELINE := "CLEAN_RIG_IDLE_BENCHMARK_V1"
const PIPELINE_POLISH := "SEMANTIC_IDLE_POLISH_V1"
const FORBIDDEN := [
	"game_ready_v4",
	"game_ready_v3",
	"semantic_solver_v2",
	"solver_v1",
	"actorcore_benchmark",
	"source_rigged",
	"native_skin_audit",
]
const ACTION_REST := "benchmark_rest"
const ACTION_TRADITIONAL := "benchmark_traditional"
const ACTION_SEMANTIC := "benchmark_semantic"
const ACTION_SKELETON := "benchmark_skeleton"
const ACTION_BBOX := "benchmark_bbox"
const ACTION_CAMERA_RESET := "benchmark_camera_reset"
const DISPLAY_NAMES := {
	"terere": "TERERÉ",
	"jaguarete": "JAGUARETÉ",
}
const METHOD_TITLES := {
	"CLEAN_REST": "REST",
	"TRADITIONAL": "TRADITIONAL IDLE",
	"SEMANTIC": "SEMANTIC IDLE",
}

@export var fighter_id: String = ""
@export var pipeline_id: String = PIPELINE
@export var target_height: float = 0.0
@export var rest_glb: String = ""
@export var traditional_glb: String = ""
@export var semantic_glb: String = ""
@export var camera_height: float = 1.8
@export var camera_distance: float = 6.0
@export var overlay_title_rest: String = "REST"
@export var overlay_title_b: String = "TRADITIONAL IDLE"
@export var overlay_title_c: String = "SEMANTIC IDLE"
@export var overlay_hint: String = "[1] rest  [2] traditional  [3] semantic"

var _camera: Camera3D
var _status: Label
var _rest_root: Node3D
var _trad_root: Node3D
var _sem_root: Node3D
var _rest: Node3D
var _trad: Node3D
var _sem: Node3D
var _active: Node3D
var _skeleton: Skeleton3D
var _player: AnimationPlayer
var _anim_tree: AnimationTree
var _debug_root: Node3D
var _bbox_debug := false
var _skeleton_debug := false
var _method := "CLEAN_REST"
var _load_ok := false
var _fail_reason := ""
var _metrics := {}
var _orbit_yaw := 0.0
var _orbit_pitch := 0.0
var _orbit_distance := 6.0
var _look_y := 0.8
var _orbiting := false
var _verify_elapsed := -1.0
var _verify_start_pos := 0.0
var _verify_method := ""
var _last_playback := {}
var _handled_frame := -1
var _handled_key := 0
var _playback_paused := false


func _ready() -> void:
	set_process_input(true)
	set_process_unhandled_input(true)
	set_process(true)
	_ensure_benchmark_actions()
	_camera = get_node_or_null("Camera3D") as Camera3D
	_rest_root = get_node_or_null("RestRoot") as Node3D
	_trad_root = get_node_or_null("TraditionalRoot") as Node3D
	_sem_root = get_node_or_null("SemanticRoot") as Node3D
	_ensure_overlay()
	_bind_all()
	_reset_camera()
	if _load_ok:
		_show_method("CLEAN_REST")
	_print_dump()
	_refresh_status()
	if OS.get_environment("SSK_IDLE_BENCHMARK_SELFTEST") == "1":
		await _run_selftest()


func _ensure_benchmark_actions() -> void:
	_bind_action(ACTION_REST, [KEY_1, KEY_KP_1])
	_bind_action(ACTION_TRADITIONAL, [KEY_2, KEY_KP_2])
	_bind_action(ACTION_SEMANTIC, [KEY_3, KEY_KP_3])
	_bind_action(ACTION_SKELETON, [KEY_4, KEY_KP_4])
	_bind_action(ACTION_BBOX, [KEY_5, KEY_KP_5])
	_bind_action(ACTION_CAMERA_RESET, [KEY_6, KEY_KP_6])


func _bind_action(action: String, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for key in keys:
		var ev := InputEventKey.new()
		ev.keycode = key
		ev.physical_keycode = key
		if not InputMap.action_has_event(action, ev):
			InputMap.action_add_event(action, ev)


func _input(event: InputEvent) -> void:
	if _handle_benchmark_event(event):
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if _handle_benchmark_event(event):
		get_viewport().set_input_as_handled()


func _handle_benchmark_event(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		return _handle_camera_mouse(event as InputEventMouseButton)
	if event is InputEventMouseMotion and _orbiting:
		var motion := event as InputEventMouseMotion
		_orbit_yaw -= motion.relative.x * 0.005
		_orbit_pitch = clampf(_orbit_pitch - motion.relative.y * 0.005, -0.65, 0.65)
		_apply_camera()
		return true
	if not (event is InputEventKey and event.pressed and not event.echo):
		return false
	var key_event := event as InputEventKey
	var key_id := _event_key_id(key_event)
	if Engine.get_process_frames() == _handled_frame and key_id == _handled_key:
		return true
	var handled := false
	if _is_action_or_digit(key_event, ACTION_REST, 1):
		apply_benchmark_method("CLEAN_REST")
		handled = true
	elif _is_action_or_digit(key_event, ACTION_TRADITIONAL, 2):
		apply_benchmark_method("TRADITIONAL")
		handled = true
	elif _is_action_or_digit(key_event, ACTION_SEMANTIC, 3):
		apply_benchmark_method("SEMANTIC")
		handled = true
	elif _is_action_or_digit(key_event, ACTION_SKELETON, 4):
		_skeleton_debug = not _skeleton_debug
		_rebuild_skeleton_debug()
		_refresh_status()
		handled = true
	elif _is_action_or_digit(key_event, ACTION_BBOX, 5):
		_bbox_debug = not _bbox_debug
		_rebuild_bbox_debug()
		_refresh_status()
		handled = true
	elif _is_action_or_digit(key_event, ACTION_CAMERA_RESET, 6):
		_reset_camera()
		_refresh_status()
		handled = true
	elif key_id == KEY_SPACE:
		_toggle_playback()
		handled = true
	if handled:
		_handled_frame = Engine.get_process_frames()
		_handled_key = key_id
	return handled


func _event_key_id(event: InputEventKey) -> int:
	if event.keycode != KEY_NONE:
		return event.keycode
	if event.physical_keycode != KEY_NONE:
		return event.physical_keycode
	if event.key_label != KEY_NONE:
		return event.key_label
	return KEY_NONE


func _is_action_or_digit(event: InputEventKey, action: String, digit: int) -> bool:
	if event.is_action_pressed(action, false, true) or event.is_action_pressed(action, false, false):
		return true
	var top := KEY_0 + digit
	var pad := KEY_KP_0 + digit
	var ident := _event_key_id(event)
	if ident == top or ident == pad:
		return true
	if event.physical_keycode == top or event.physical_keycode == pad:
		return true
	if event.unicode == (48 + digit):
		return true
	return false


func _handle_camera_mouse(event: InputEventMouseButton) -> bool:
	if event.button_index == MOUSE_BUTTON_RIGHT:
		_orbiting = event.pressed
		return true
	if not event.pressed:
		return false
	if event.button_index == MOUSE_BUTTON_WHEEL_UP:
		_orbit_distance = clampf(_orbit_distance - 0.35, 2.0, 16.0)
		_apply_camera()
		return true
	if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		_orbit_distance = clampf(_orbit_distance + 0.35, 2.0, 16.0)
		_apply_camera()
		return true
	return false


func _process(delta: float) -> void:
	_handle_camera_wasd(delta)
	if _verify_elapsed >= 0.0:
		_verify_elapsed += delta
		if _verify_elapsed >= 1.0:
			_verify_elapsed = -1.0
			_finish_playback_verify()
	_refresh_status()


func _handle_camera_wasd(delta: float) -> void:
	if _camera == null:
		return
	var yaw_delta := 0.0
	var zoom_delta := 0.0
	if Input.is_physical_key_pressed(KEY_A):
		yaw_delta += 1.2 * delta
	if Input.is_physical_key_pressed(KEY_D):
		yaw_delta -= 1.2 * delta
	if Input.is_physical_key_pressed(KEY_W):
		zoom_delta -= 2.4 * delta
	if Input.is_physical_key_pressed(KEY_S):
		zoom_delta += 2.4 * delta
	if yaw_delta == 0.0 and zoom_delta == 0.0:
		return
	_orbit_yaw += yaw_delta
	_orbit_distance = clampf(_orbit_distance + zoom_delta, 2.0, 16.0)
	_apply_camera()


func apply_benchmark_method(method: String) -> void:
	_show_method(method)


func _bind_all() -> void:
	if pipeline_id != PIPELINE and pipeline_id != PIPELINE_POLISH:
		_fail("pipeline_id must be %s or %s, got %s" % [PIPELINE, PIPELINE_POLISH, pipeline_id])
		return
	_rest = _bind_one(_rest_root, rest_glb, "rest")
	_trad = _bind_one(_trad_root, traditional_glb, "traditional")
	_sem = _bind_one(_sem_root, semantic_glb, "semantic")
	if _rest == null or _trad == null or _sem == null:
		return
	_load_metrics()
	_load_ok = true


func _bind_one(root: Node3D, path: String, label: String) -> Node3D:
	if path.is_empty():
		_fail("%s path empty" % label)
		return null
	if not ResourceLoader.exists(path):
		_fail("missing %s GLB: %s" % [label, path])
		return null
	for token in FORBIDDEN:
		if path.find(token) != -1:
			_fail("refused non-benchmark asset %s: %s" % [label, path])
			return null
	if root == null:
		_fail("%s root missing" % label)
		return null
	var inst: Node3D = null
	for child in root.get_children():
		if child is Node3D:
			inst = child as Node3D
			break
	if inst == null:
		_fail("no GLB instance under %s" % label)
		return null
	var loaded := inst.scene_file_path
	if loaded.is_empty():
		loaded = path
	if loaded != path:
		_fail("%s instanced %s != %s" % [label, loaded, path])
		return null
	return inst


func _fail(reason: String) -> void:
	_load_ok = false
	_fail_reason = reason
	push_error("[IDLE_RETARGET_LAB] FAIL fighter=%s %s" % [fighter_id, reason])


func _show_method(method: String) -> void:
	_method = method
	_stop_players(_rest)
	_stop_players(_trad)
	_stop_players(_sem)
	if _rest_root:
		_rest_root.visible = method == "CLEAN_REST"
	if _trad_root:
		_trad_root.visible = method == "TRADITIONAL"
	if _sem_root:
		_sem_root.visible = method == "SEMANTIC"
	_anim_tree = null
	match method:
		"CLEAN_REST":
			_active = _rest
			_skeleton = _find_skeleton(_rest)
			_player = null
			_playback_paused = false
			if _skeleton:
				_skeleton.reset_bone_poses()
			_verify_elapsed = -1.0
		"TRADITIONAL":
			_active = _trad
			_skeleton = _find_skeleton(_trad)
			_player = _find_player(_trad)
			_anim_tree = _find_anim_tree(_trad)
			_deactivate_anim_tree(_anim_tree)
			_play_idle(_player, PackedStringArray(["idle_traditional", "idle"]))
			_begin_playback_verify()
		"SEMANTIC":
			_active = _sem
			_skeleton = _find_skeleton(_sem)
			_player = _find_player(_sem)
			_anim_tree = _find_anim_tree(_sem)
			_deactivate_anim_tree(_anim_tree)
			_play_idle(_player, PackedStringArray(["idle_semantic", "idle"]))
			_begin_playback_verify()
	if _skeleton_debug:
		_rebuild_skeleton_debug()
	if _bbox_debug:
		_rebuild_bbox_debug()
	_print_benchmark_switch()
	_refresh_status()


func _print_benchmark_switch() -> void:
	var snap := get_playback_snapshot()
	print("[IDLE_BENCHMARK]")
	print("fighter=%s" % fighter_id)
	print("method=%s" % _method)
	print("asset=%s" % str(snap.get("asset", "")))
	print("animation=%s" % str(snap.get("animation_name", "")))
	print("playing=%s" % str(snap.get("playing", false)))
	print("animation_name=%s" % str(snap.get("animation_name", "")))
	print("animation_length=%s" % str(snap.get("animation_length", 0.0)))
	print("current_position=%s" % str(snap.get("current_position", 0.0)))
	print("animation_list=%s" % str(snap.get("animation_list", PackedStringArray())))
	if _anim_tree:
		print("animation_tree=%s active=%s" % [_anim_tree.get_path(), _anim_tree.active])


func _begin_playback_verify() -> void:
	_verify_method = _method
	_verify_elapsed = 0.0
	_verify_start_pos = 0.0
	if _player:
		_verify_start_pos = _safe_anim_position(_player)


func _finish_playback_verify() -> void:
	var snap := get_playback_snapshot()
	_last_playback = snap
	var pos := float(snap.get("current_position", 0.0))
	var playing := bool(snap.get("playing", false))
	var visible := bool(snap.get("candidate_visible", false))
	var advanced := absf(pos - _verify_start_pos) > 0.02
	print("[IDLE_BENCHMARK] playback_verify fighter=%s method=%s animation_name=%s animation_length=%s start_position=%s current_position=%s playing=%s advanced=%s" % [
		fighter_id,
		_verify_method,
		str(snap.get("animation_name", "")),
		str(snap.get("animation_length", 0.0)),
		str(_verify_start_pos),
		str(pos),
		str(playing),
		str(advanced),
	])
	if visible and _verify_method != "CLEAN_REST" and (not playing or not advanced):
		push_error("[IDLE_BENCHMARK] FAIL fighter=%s method=%s visible but static playing=%s advanced=%s" % [
			fighter_id, _verify_method, playing, advanced
		])


func get_playback_snapshot() -> Dictionary:
	var asset := rest_glb
	if _method == "TRADITIONAL":
		asset = traditional_glb
	elif _method == "SEMANTIC":
		asset = semantic_glb
	var names: PackedStringArray = PackedStringArray()
	var anim_name := ""
	var length := 0.0
	var pos := 0.0
	var playing := false
	if _player:
		names = _player.get_animation_list()
		anim_name = _player.current_animation
		if anim_name.is_empty() and names.size() > 0:
			anim_name = names[0]
		if not anim_name.is_empty() and _player.has_animation(anim_name):
			var anim: Animation = _player.get_animation(anim_name)
			if anim:
				length = anim.length
		pos = _safe_anim_position(_player)
		playing = _player.is_playing() and not _playback_paused
	var rest_vis := _rest_root != null and _rest_root.visible
	var trad_vis := _trad_root != null and _trad_root.visible
	var sem_vis := _sem_root != null and _sem_root.visible
	var vis_count := int(rest_vis) + int(trad_vis) + int(sem_vis)
	var visible := false
	if _method == "CLEAN_REST":
		visible = rest_vis
	elif _method == "TRADITIONAL":
		visible = trad_vis
	elif _method == "SEMANTIC":
		visible = sem_vis
	return {
		"fighter": fighter_id,
		"method": _method,
		"asset": asset,
		"animation_name": anim_name if not anim_name.is_empty() else ("rest" if _method == "CLEAN_REST" else ""),
		"animation_length": length,
		"current_position": pos,
		"playing": playing,
		"animation_list": names,
		"candidate_visible": visible,
		"rest_visible": rest_vis,
		"traditional_visible": trad_vis,
		"semantic_visible": sem_vis,
		"exactly_one_visible": vis_count == 1 and visible,
		"has_animation_tree": _anim_tree != null,
		"camera_position": [
			_camera.global_position.x if _camera else 0.0,
			_camera.global_position.y if _camera else 0.0,
			_camera.global_position.z if _camera else 0.0,
		],
	}


func _stop_players(node: Node) -> void:
	if node == null:
		return
	var trees: Array[AnimationTree] = []
	_collect_anim_trees(node, trees)
	for tree in trees:
		tree.active = false
	var players: Array[AnimationPlayer] = []
	_collect_players(node, players)
	for player in players:
		player.stop()
		player.active = false


func _play_idle(player: AnimationPlayer, preferred: PackedStringArray = PackedStringArray()) -> void:
	if player == null:
		return
	player.active = true
	_playback_paused = false
	var names := player.get_animation_list()
	print("[IDLE_BENCHMARK] enumerate fighter=%s method=%s animations=%s" % [fighter_id, _method, names])
	var idle := ""
	for want in preferred:
		for n in names:
			if String(n) == want:
				idle = n
				break
		if not idle.is_empty():
			break
	if idle.is_empty():
		for n in names:
			if String(n).to_lower().contains("idle"):
				idle = n
				break
	if idle.is_empty() and names.size() > 0:
		idle = names[0]
	if idle.is_empty():
		push_error("[IDLE_BENCHMARK] FAIL fighter=%s method=%s no animation on candidate" % [fighter_id, _method])
		return
	var anim: Animation = player.get_animation(idle)
	if anim:
		anim.loop_mode = Animation.LOOP_LINEAR
	player.play(idle)


func _toggle_playback() -> void:
	if _player == null:
		_refresh_status()
		return
	if _player.is_playing():
		_player.pause()
		_playback_paused = true
	elif _method == "TRADITIONAL":
		_play_idle(_player, PackedStringArray(["idle_traditional", "idle"]))
	elif _method == "SEMANTIC":
		_play_idle(_player, PackedStringArray(["idle_semantic", "idle"]))
	_refresh_status()


func _safe_anim_position(player: AnimationPlayer) -> float:
	if player == null or player.current_animation.is_empty():
		return 0.0
	return player.current_animation_position


func _reset_camera() -> void:
	_orbit_distance = camera_distance
	_look_y = maxf(camera_height * 0.55, 0.8)
	var look := Vector3(0.0, _look_y, 0.0)
	var offset := Vector3(0.0, camera_height, camera_distance) - look
	_orbit_distance = offset.length()
	_orbit_yaw = 0.0
	_orbit_pitch = atan2(offset.y, offset.z)
	_apply_camera()


func _apply_camera() -> void:
	if _camera == null:
		return
	_camera.current = true
	var look := Vector3(0.0, _look_y, 0.0)
	var offset := Vector3(
		sin(_orbit_yaw) * cos(_orbit_pitch),
		sin(_orbit_pitch),
		cos(_orbit_yaw) * cos(_orbit_pitch)
	) * _orbit_distance
	_camera.position = look + offset
	_camera.look_at(look)


func _rebuild_skeleton_debug() -> void:
	if _debug_root != null:
		_debug_root.queue_free()
		_debug_root = null
	if not _skeleton_debug or _skeleton == null or not _load_ok:
		return
	_debug_root = Node3D.new()
	_debug_root.name = "SkeletonDebug"
	add_child(_debug_root)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.15, 1.0, 0.4)
	for i in _skeleton.get_bone_count():
		var marker := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.018
		sphere.height = 0.036
		marker.mesh = sphere
		marker.material_override = mat
		marker.position = _skeleton.to_global(_skeleton.get_bone_global_pose(i).origin)
		_debug_root.add_child(marker)


func _rebuild_bbox_debug() -> void:
	if not _bbox_debug:
		if _debug_root != null and _debug_root.name == "BBoxDebug":
			_debug_root.queue_free()
			_debug_root = null
		return
	if _debug_root != null:
		_debug_root.queue_free()
		_debug_root = null
	if _active == null:
		return
	_debug_root = Node3D.new()
	_debug_root.name = "BBoxDebug"
	add_child(_debug_root)
	var aabb := AABB()
	var first := true
	for mi in _collect_meshes(_active):
		if mi.mesh == null:
			continue
		var local := mi.get_aabb()
		var world := mi.global_transform * local
		if first:
			aabb = world
			first = false
		else:
			aabb = aabb.merge(world)
	var box := MeshInstance3D.new()
	var cube := BoxMesh.new()
	cube.size = aabb.size
	box.mesh = cube
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1.0, 0.85, 0.2, 0.18)
	box.material_override = mat
	box.position = aabb.get_center()
	_debug_root.add_child(box)


func _load_metrics() -> void:
	_metrics = {
		"TRADITIONAL": _read_json("res://docs/generated/%s_IDLE_TRADITIONAL_V1_METRICS.json" % fighter_id.to_upper()),
		"SEMANTIC": _read_json("res://docs/generated/%s_IDLE_SEMANTIC_CLEAN_V1_METRICS.json" % fighter_id.to_upper()),
	}


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var fh := FileAccess.open(path, FileAccess.READ)
	if fh == null:
		return {}
	var parsed: Variant = JSON.parse_string(fh.get_as_text())
	if typeof(parsed) == TYPE_DICTIONARY:
		return parsed
	return {}


func _ensure_overlay() -> void:
	_status = Label.new()
	_status.name = "BenchmarkOverlayLabel"
	_status.position = Vector2(28, 24)
	_status.add_theme_font_size_override("font_size", 36)
	_status.add_theme_color_override("font_color", Color(0.95, 0.96, 0.98))
	_status.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.06, 0.92))
	_status.add_theme_constant_override("outline_size", 8)
	_status.focus_mode = Control.FOCUS_NONE
	_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var layer := CanvasLayer.new()
	layer.name = "BenchmarkOverlay"
	layer.layer = 80
	layer.add_child(_status)
	add_child(layer)


func _print_dump() -> void:
	var dump := collect_dump()
	print("[IDLE_RETARGET_LAB]")
	for key in dump.keys():
		print("%s=%s" % [key, dump[key]])


func collect_dump() -> Dictionary:
	var skel := _find_skeleton(_active if _active else _rest)
	var player := _find_player(_trad)
	var anims: PackedStringArray = player.get_animation_list() if player else PackedStringArray()
	var tracks := 0
	if player and anims.size() > 0:
		var anim := player.get_animation(anims[0])
		if anim:
			tracks = anim.get_track_count()
	var snap := get_playback_snapshot()
	return {
		"fighter": fighter_id,
		"pipeline": pipeline_id,
		"method": _method,
		"rest_glb": rest_glb,
		"traditional_glb": traditional_glb,
		"semantic_glb": semantic_glb,
		"load_ok": _load_ok,
		"fallback": false,
		"fail_reason": _fail_reason,
		"bone_count": skel.get_bone_count() if skel else 0,
		"animation_names": anims,
		"idle_tracks": tracks,
		"runtime_retarget": false,
		"proxy_idle": false,
		"legacy_orientation_hack": false,
		"battle_hud_instanced": _tree_has_battle_hud(self),
		"exactly_one_visible": snap.get("exactly_one_visible", false),
		"playing": snap.get("playing", false),
		"animation_name": snap.get("animation_name", ""),
	}


func tree_has_battle_hud() -> bool:
	return _tree_has_battle_hud(self)


func _tree_has_battle_hud(node: Node) -> bool:
	var script: Script = node.get_script()
	if script:
		var path := String(script.resource_path)
		if path.find("m0_hud.gd") != -1 or path.find("kapes_player_hud.gd") != -1:
			return true
	for child in node.get_children():
		if _tree_has_battle_hud(child):
			return true
	return false


func _refresh_status() -> void:
	if _status == null:
		return
	if not _load_ok:
		_status.text = "IDLE RETARGET LAB FAILED | fighter=%s | %s" % [fighter_id, _fail_reason]
		return
	var display := String(DISPLAY_NAMES.get(fighter_id, fighter_id.to_upper()))
	var title := overlay_title_rest
	if _method == "TRADITIONAL":
		title = overlay_title_b
	elif _method == "SEMANTIC":
		title = overlay_title_c
	var snap := get_playback_snapshot()
	var playing := bool(snap.get("playing", false))
	var play_state := "PLAYING" if playing else "PAUSED"
	if _method == "CLEAN_REST":
		play_state = "REST / NOT PLAYING"
	var anim := str(snap.get("animation_name", "rest"))
	var pos := float(snap.get("current_position", 0.0))
	var length := float(snap.get("animation_length", 0.0))
	_status.text = (
		"%s\n%s\nRun scene (F6) for controls\nSPACEBAR / %s\nanimation %s  t=%.2f / %.2f\nFPS %.0f\n%s\n[4] skeleton  [5] bbox  [6] reset camera\nRMB orbit  wheel zoom  WASD move camera\nEditor 3D view: number keys move the camera. F6 is authority."
		% [
			display,
			title,
			play_state,
			anim,
			pos,
			length,
			Engine.get_frames_per_second(),
			overlay_hint,
		]
	)


func _find_skeleton(node: Node) -> Skeleton3D:
	if node == null:
		return null
	if node is Skeleton3D:
		return node as Skeleton3D
	for child in node.get_children():
		var found := _find_skeleton(child)
		if found:
			return found
	return null


func _find_player(node: Node) -> AnimationPlayer:
	if node == null:
		return null
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var found := _find_player(child)
		if found:
			return found
	return null


func _find_anim_tree(node: Node) -> AnimationTree:
	if node == null:
		return null
	if node is AnimationTree:
		return node as AnimationTree
	for child in node.get_children():
		var found := _find_anim_tree(child)
		if found:
			return found
	return null


func _deactivate_anim_tree(tree: AnimationTree) -> void:
	if tree:
		tree.active = false


func _collect_meshes(node: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if node == null:
		return out
	var stack: Array[Node] = [node]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is MeshInstance3D:
			out.append(n as MeshInstance3D)
		for child in n.get_children():
			stack.append(child)
	return out


func _collect_players(node: Node, out: Array[AnimationPlayer]) -> void:
	if node is AnimationPlayer:
		out.append(node as AnimationPlayer)
	for child in node.get_children():
		_collect_players(child, out)


func _collect_anim_trees(node: Node, out: Array[AnimationTree]) -> void:
	if node is AnimationTree:
		out.append(node as AnimationTree)
	for child in node.get_children():
		_collect_anim_trees(child, out)


func _run_selftest() -> void:
	var ok := true
	for method in ["CLEAN_REST", "TRADITIONAL", "SEMANTIC"]:
		apply_benchmark_method(method)
		await get_tree().process_frame
		await get_tree().process_frame
		var snap := get_playback_snapshot()
		if not bool(snap.get("exactly_one_visible", false)):
			ok = false
			push_error("[IDLE_BENCHMARK] SELFTEST visibility fail method=%s" % method)
		if method == "CLEAN_REST":
			continue
		var start := float(snap.get("current_position", 0.0))
		await get_tree().create_timer(1.0).timeout
		snap = get_playback_snapshot()
		var pos := float(snap.get("current_position", 0.0))
		if not bool(snap.get("playing", false)) or absf(pos - start) <= 0.02:
			ok = false
			push_error("[IDLE_BENCHMARK] SELFTEST static fail method=%s" % method)
	print("[IDLE_BENCHMARK] SELFTEST fighter=%s ok=%s hud=%s" % [fighter_id, ok, tree_has_battle_hud()])
	get_tree().quit(0 if ok else 2)
