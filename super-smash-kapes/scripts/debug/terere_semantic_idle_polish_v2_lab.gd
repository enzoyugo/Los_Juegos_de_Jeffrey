extends Node3D

## Terere Semantic Idle Polish V2 comparison lab.
## Runtime (F6): 1 BASELINE  2 REJECTED V1  3 V2_A  4 V2_B  5 V2_C  6 camera reset
## Isolated from battle, catalog, V4, FBX, fallback, and battle HUD.

const PIPELINE := "SEMANTIC_IDLE_POLISH_V2"
const FORBIDDEN := [
	"game_ready_v4",
	"game_ready_v3",
	"semantic_solver_v2",
	"solver_v1",
	"actorcore_benchmark",
	"source_rigged",
	"native_skin_audit",
]
const CANDIDATES := ["BASELINE", "V1", "V2_A", "V2_B", "V2_C"]
const TITLES := {
	"BASELINE": "BASELINE  frozen semantic",
	"V1": "REJECTED V1  do not ship",
	"V2_A": "V2_A  MINIMAL",
	"V2_B": "V2_B  MODERATE",
	"V2_C": "V2_C  COMPACT",
}

@export var fighter_id: String = "terere"
@export var pipeline_id: String = PIPELINE
@export var camera_height: float = 1.6
@export var camera_distance: float = 5.5
@export var baseline_glb: String = "res://assets/fighters/processed/idle_benchmark_v1/terere/terere_idle_semantic_clean_v1.glb"
@export var v1_glb: String = "res://assets/fighters/processed/semantic_idle_polish_v1/terere/terere_idle_semantic_polished_v1.glb"
@export var v2a_glb: String = "res://assets/fighters/processed/semantic_idle_polish_v2/terere/terere_idle_semantic_polished_v2_a.glb"
@export var v2b_glb: String = "res://assets/fighters/processed/semantic_idle_polish_v2/terere/terere_idle_semantic_polished_v2_b.glb"
@export var v2c_glb: String = "res://assets/fighters/processed/semantic_idle_polish_v2/terere/terere_idle_semantic_polished_v2_c.glb"

var _camera: Camera3D
var _status: Label
var _roots: Dictionary = {}
var _nodes: Dictionary = {}
var _paths: Dictionary = {}
var _active_id: String = "BASELINE"
var _player: AnimationPlayer
var _load_ok := false
var _fail_reason := ""
var _orbit_yaw := 0.0
var _orbit_pitch := 0.0
var _orbit_distance := 5.5
var _look_y := 0.8
var _orbiting := false
var _handled_frame := -1
var _playback_paused := false
var _shared_time := 0.0


func _ready() -> void:
	set_process_input(true)
	set_process_unhandled_input(true)
	set_process(true)
	_ensure_actions()
	_camera = get_node_or_null("Camera3D") as Camera3D
	_paths = {
		"BASELINE": baseline_glb,
		"V1": v1_glb,
		"V2_A": v2a_glb,
		"V2_B": v2b_glb,
		"V2_C": v2c_glb,
	}
	_roots = {
		"BASELINE": get_node_or_null("BaselineRoot") as Node3D,
		"V1": get_node_or_null("V1Root") as Node3D,
		"V2_A": get_node_or_null("V2ARoot") as Node3D,
		"V2_B": get_node_or_null("V2BRoot") as Node3D,
		"V2_C": get_node_or_null("V2CRoot") as Node3D,
	}
	_ensure_overlay()
	_bind_all()
	_reset_camera()
	if _load_ok:
		_show("BASELINE")
	_refresh_status()


func _ensure_actions() -> void:
	for i in range(1, 7):
		var action := "polish_v2_%d" % i
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for key in [KEY_0 + i, KEY_KP_0 + i]:
			var ev := InputEventKey.new()
			ev.keycode = key
			ev.physical_keycode = key
			if not InputMap.action_has_event(action, ev):
				InputMap.action_add_event(action, ev)


func _input(event: InputEvent) -> void:
	if _handle(event):
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if _handle(event):
		get_viewport().set_input_as_handled()


func _handle(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			_orbiting = mb.pressed
			return true
		if mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_orbit_distance = clampf(_orbit_distance - 0.35, 2.0, 16.0)
			_apply_camera()
			return true
		if mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_orbit_distance = clampf(_orbit_distance + 0.35, 2.0, 16.0)
			_apply_camera()
			return true
		return false
	if event is InputEventMouseMotion and _orbiting:
		var motion := event as InputEventMouseMotion
		_orbit_yaw -= motion.relative.x * 0.005
		_orbit_pitch = clampf(_orbit_pitch - motion.relative.y * 0.005, -0.65, 0.65)
		_apply_camera()
		return true
	if not (event is InputEventKey and event.pressed and not event.echo):
		return false
	var key_event := event as InputEventKey
	if Engine.get_process_frames() == _handled_frame:
		return true
	var ident := key_event.keycode if key_event.keycode != KEY_NONE else key_event.physical_keycode
	var handled := false
	if ident == KEY_1 or ident == KEY_KP_1:
		_show("BASELINE"); handled = true
	elif ident == KEY_2 or ident == KEY_KP_2:
		_show("V1"); handled = true
	elif ident == KEY_3 or ident == KEY_KP_3:
		_show("V2_A"); handled = true
	elif ident == KEY_4 or ident == KEY_KP_4:
		_show("V2_B"); handled = true
	elif ident == KEY_5 or ident == KEY_KP_5:
		_show("V2_C"); handled = true
	elif ident == KEY_6 or ident == KEY_KP_6:
		_reset_camera(); handled = true
	elif ident == KEY_SPACE:
		_toggle_playback(); handled = true
	if handled:
		_handled_frame = Engine.get_process_frames()
	return handled


func _process(delta: float) -> void:
	if _camera:
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
		if yaw_delta != 0.0 or zoom_delta != 0.0:
			_orbit_yaw += yaw_delta
			_orbit_distance = clampf(_orbit_distance + zoom_delta, 2.0, 16.0)
			_apply_camera()
	if _player and _player.is_playing():
		_shared_time = _player.current_animation_position
	_refresh_status()


func _bind_all() -> void:
	if pipeline_id != PIPELINE:
		_fail("pipeline_id must be %s" % PIPELINE)
		return
	for id in CANDIDATES:
		var path: String = String(_paths[id])
		for token in FORBIDDEN:
			if path.find(token) != -1:
				_fail("refused non-lab asset %s" % path)
				return
		var root: Node3D = _roots.get(id)
		if root == null:
			_fail("missing root %s" % id)
			return
		var inst: Node3D = null
		for child in root.get_children():
			if child is Node3D:
				inst = child as Node3D
				break
		if inst == null:
			_fail("no GLB under %s" % id)
			return
		_nodes[id] = inst
	_load_ok = true


func _fail(reason: String) -> void:
	_load_ok = false
	_fail_reason = reason
	push_error("[POLISH_V2_LAB] FAIL %s" % reason)


func _show(cand_id: String) -> void:
	if _player:
		_shared_time = _player.current_animation_position
	_active_id = cand_id
	for id in CANDIDATES:
		var root: Node3D = _roots.get(id)
		if root:
			root.visible = id == cand_id
		_stop_players(_nodes.get(id))
	var node: Node3D = _nodes.get(cand_id)
	_player = _find_player(node)
	if _player:
		_play_idle(_player)
		if _shared_time > 0.0 and _player.current_animation != "":
			_player.seek(_shared_time, true)
	_refresh_status()


func _stop_players(node: Node) -> void:
	if node == null:
		return
	var player := _find_player(node)
	if player:
		player.stop()
		player.active = false


func _play_idle(player: AnimationPlayer) -> void:
	player.active = true
	_playback_paused = false
	var names := player.get_animation_list()
	var idle := ""
	for n in names:
		if String(n).to_lower().contains("idle"):
			idle = n
			break
	if idle.is_empty() and names.size() > 0:
		idle = names[0]
	if idle.is_empty():
		return
	var anim: Animation = player.get_animation(idle)
	if anim:
		anim.loop_mode = Animation.LOOP_LINEAR
	player.play(idle)


func _toggle_playback() -> void:
	if _player == null:
		return
	if _player.is_playing():
		_player.pause()
		_playback_paused = true
	else:
		_play_idle(_player)
		_player.seek(_shared_time, true)


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


func _ensure_overlay() -> void:
	_status = Label.new()
	_status.name = "PolishV2Overlay"
	_status.position = Vector2(28, 24)
	_status.add_theme_font_size_override("font_size", 34)
	_status.add_theme_color_override("font_color", Color(0.95, 0.96, 0.98))
	_status.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.06, 0.92))
	_status.add_theme_constant_override("outline_size", 8)
	_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var layer := CanvasLayer.new()
	layer.layer = 80
	layer.add_child(_status)
	add_child(layer)


func _refresh_status() -> void:
	if _status == null:
		return
	if not _load_ok:
		_status.text = "POLISH V2 LAB FAILED | %s" % _fail_reason
		return
	var title := String(TITLES.get(_active_id, _active_id))
	var pos := _player.current_animation_position if _player else 0.0
	var length := 0.0
	if _player and _player.current_animation != "" and _player.has_animation(_player.current_animation):
		var anim: Animation = _player.get_animation(_player.current_animation)
		if anim:
			length = anim.length
	var play_state := "PAUSED" if _playback_paused or _player == null or not _player.is_playing() else "PLAYING"
	_status.text = (
		"TERERE SEMANTIC IDLE POLISH V2\nNOW SHOWING: %s\nRun scene (F6) for controls\nSPACEBAR / %s  t=%.2f / %.2f\n[1] BASELINE  [2] REJECTED V1  [3] V2_A  [4] V2_B  [5] V2_C\n[6] reset camera   RMB orbit   wheel zoom   WASD\nHuman chooses A/B/C. Do not auto-pick. Jaguarete is frozen."
		% [title, play_state, pos, length]
	)


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


func collect_dump() -> Dictionary:
	return {
		"fighter": fighter_id,
		"pipeline": pipeline_id,
		"method": _active_id,
		"load_ok": _load_ok,
		"fallback": false,
		"fail_reason": _fail_reason,
		"baseline_glb": baseline_glb,
		"v1_glb": v1_glb,
		"v2a_glb": v2a_glb,
		"v2b_glb": v2b_glb,
		"v2c_glb": v2c_glb,
		"battle_hud_instanced": false,
	}

