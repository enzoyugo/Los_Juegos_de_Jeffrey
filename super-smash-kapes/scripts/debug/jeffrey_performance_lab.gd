extends Node

## Deterministic Jeffrey performance scenarios.
## Run windowed for meaningful FPS:
##   Godot --path project --resolution 1920x1080 res://scenes/debug/JeffreyPerformanceLab.tscn
## Env: SSK_PERF_SCENARIO=HUB|CHAR_SELECT|TRACK_EMPTY|TRACK_GENERATED|TRACK_RACE|NAV_LEAK|ALL

const Sampler := preload("res://scripts/debug/jeffrey_perf_sampler.gd")
const HubScript := preload("res://scripts/ui/jeffrey/hub_screen.gd")
const CharScript := preload("res://scripts/ui/jeffrey/character_select_screen.gd")
const TrackMainScript := preload("res://scripts/track/track_main.gd")
const RaceScript := preload("res://scripts/track/track_race.gd")
const ShellTransition := preload("res://scripts/ui/jeffrey/system/jeffrey_shell_transition.gd")
const UILayout := preload("res://scripts/ui/kapes_ui_layout.gd")

const WARMUP_FRAMES := 20
const SAMPLE_FRAMES := 60

var _results: Array[Dictionary] = []
var _scenario_queue: Array[String] = []
var _phase := "setup"
var _frame := 0
var _samples: Array = []
var _scenario := ""
var _host: Control
var _track_host: Node
var _track_race: Node
var _track_built := false
var _nav_iter := 0
var _nav_phase := ""
var _nav_t0 := 0
var _nav_alive := 0


func _ready() -> void:
	_emit_gpu_authority()
	_host = Control.new()
	_host.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_host)
	var wanted := OS.get_environment("SSK_PERF_SCENARIO").strip_edges().to_upper()
	if wanted.is_empty() or wanted == "ALL":
		_scenario_queue = [
			"EMPTY",
			"HUB",
			"CHAR_SELECT",
			"TRACK_EMPTY",
			"TRACK_GENERATED",
			"TRACK_RACE",
			"NAV_LEAK",
		]
	else:
		_scenario_queue = [wanted]
	_start_next_scenario()


func _start_next_scenario() -> void:
	if _scenario_queue.is_empty():
		_finish_all()
		return
	_scenario = _scenario_queue.pop_front()
	_phase = "setup"
	_frame = 0
	_samples.clear()
	_track_built = false
	_track_race = null
	_clear_host()
	match _scenario:
		"EMPTY":
			_phase = "warmup"
		"HUB":
			_host.add_child(HubScript.new())
			_phase = "warmup"
		"CHAR_SELECT":
			var chars = CharScript.new()
			_host.add_child(chars)
			if chars.has_method("configure"):
				chars.call("configure", _mock_roster(), "racing")
			_phase = "warmup"
		"TRACK_EMPTY", "TRACK_GENERATED", "TRACK_RACE":
			OS.set_environment("SSK_PERF_DIAG", "1")
			_track_host = TrackMainScript.new()
			add_child(_track_host)
			if _track_host.has_method("setup"):
				_track_host.call("setup", _mock_roster(), 424242)
			_phase = "track_ready_wait"
		"NAV_LEAK":
			_nav_iter = 0
			_nav_phase = "hub"
			_nav_t0 = Time.get_ticks_usec()
			_host.add_child(_wrap_screen(HubScript.new()))
			_phase = "nav"
		_:
			push_error("Unknown scenario: %s" % _scenario)


func _clear_host() -> void:
	for child in _host.get_children():
		child.queue_free()
	if _track_host != null and is_instance_valid(_track_host):
		_track_host.queue_free()
	_track_host = null


func _process(_delta: float) -> void:
	if _phase == "nav":
		_process_nav_leak()
		return
	if _phase == "track_ready_wait":
		_frame += 1
		if _frame >= 3:
			_track_race = _find_race_node()
			if _scenario != "TRACK_EMPTY" and not _track_built and _track_race != null:
				_track_race.build(424242, "media", "picante")
				_track_built = true
				if _scenario == "TRACK_RACE" and _track_host.has_method("_start_turn"):
					_track_host.call("_start_turn")
			_phase = "warmup"
			_frame = 0
		return
	_frame += 1
	if _phase == "warmup":
		if _frame >= WARMUP_FRAMES:
			_phase = "sample"
			_frame = 0
		return
	if _phase == "sample":
		_samples.append(Sampler.snapshot(_scenario))
		if _frame >= SAMPLE_FRAMES:
			_emit_scenario_result()
			_start_next_scenario()


func _find_race_node() -> Node:
	if _track_host == null:
		return null
	for child in _track_host.get_children():
		if child.get_script() == RaceScript:
			return child
	return null


func _wrap_screen(screen: Control) -> Control:
	var root := Control.new()
	root.name = "ScreenRoot"
	UILayout.bind_full_rect(root)
	UILayout.bind_full_rect(screen)
	root.add_child(screen)
	return root


func _process_nav_leak() -> void:
	_frame += 1
	if _nav_phase == "hub" and _frame >= 18:
		_nav_phase = "char"
		_frame = 0
		var prev := _host.get_child(_host.get_child_count() - 1)
		var wrapped := _wrap_screen(CharScript.new())
		_host.add_child(wrapped)
		ShellTransition.present(self, wrapped, wrapped.get_child(0), prev)
	elif _nav_phase == "char" and _frame >= 22:
		_nav_phase = "hub"
		_frame = 0
		_nav_iter += 1
		if _nav_iter >= 10:
			var elapsed_ms := float(Time.get_ticks_usec() - _nav_t0) / 1000.0
			_nav_alive = _host.get_child_count()
			var row := Sampler.summarize([Sampler.snapshot("NAV_LEAK")])
			row["scenario"] = "NAV_LEAK"
			row["nav_iterations"] = 10
			row["nav_elapsed_ms"] = elapsed_ms
			row["ui_roots_alive"] = _nav_alive
			row["static_mb"] = float(OS.get_static_memory_usage()) / 1048576.0
			row["peak_mb"] = float(OS.get_static_memory_peak_usage()) / 1048576.0
			row["orphans"] = int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
			_results.append(row)
			Sampler.print_line("[JEFFREY_PERF]", row)
			print("[JEFFREY_PERF_JSON] %s" % JSON.stringify(row))
			print(
				"[JEFFREY_PERF] nav_leak iterations=10 elapsed_ms=%.1f ui_roots=%d orphans=%d static=%.1fMB"
				% [elapsed_ms, _nav_alive, row["orphans"], row["static_mb"]]
			)
			_start_next_scenario()
			return
		var prev := _host.get_child(_host.get_child_count() - 1)
		var wrapped := _wrap_screen(HubScript.new())
		_host.add_child(wrapped)
		ShellTransition.present(self, wrapped, wrapped.get_child(0), prev)


func _emit_scenario_result() -> void:
	var summary := Sampler.summarize(_samples)
	summary["scenario"] = _scenario
	if not _samples.is_empty():
		var last: Dictionary = _samples[_samples.size() - 1]
		summary["orphans"] = last.get("orphans", 0)
		summary["gpu"] = last.get("gpu", "")
		summary["physics_ms"] = last.get("physics_ms", 0.0)
	_results.append(summary)
	Sampler.print_line("[JEFFREY_PERF]", summary)
	print("[JEFFREY_PERF_JSON] %s" % JSON.stringify(summary))


func _finish_all() -> void:
	print("[JEFFREY_PERF_LAB] PASS scenarios=%d" % _results.size())
	get_tree().quit(0)


func _mock_roster() -> Array:
	return [
		{"profile_id": "p1", "display_name": "Jeffrey", "character_id": "terere"},
		{"profile_id": "p2", "display_name": "Kape", "character_id": "jaguarete"},
	]


func _emit_gpu_authority() -> void:
	var adapter := str(RenderingServer.get_video_adapter_name())
	var method := str(ProjectSettings.get_setting("rendering/renderer/rendering_method", ""))
	var expected := OS.get_environment("SSK_EXPECTED_GPU").strip_edges()
	if expected.is_empty():
		expected = "NVIDIA"
	var authority_ok := not _is_software_adapter(adapter)
	if authority_ok:
		var upper := adapter.to_upper()
		authority_ok = false
		for token in expected.split(",", false):
			var needle := token.strip_edges().to_upper()
			if not needle.is_empty() and needle in upper:
				authority_ok = true
				break
	print("[GPU_PROBE] label=performance_lab adapter=%s renderer=%s" % [adapter, method])
	print("[GPU_AUTHORITY] adapter=%s pass=%s" % [adapter, str(authority_ok).to_lower()])
	print("GPU_AUTHORITY=%s" % ("PASS" if authority_ok else "FAIL"))


func _is_software_adapter(adapter: String) -> bool:
	var upper := adapter.to_upper()
	var markers := [
		"MICROSOFT BASIC RENDER DRIVER",
		"LLVMPipe",
		"SOFTWARE RASTERIZER",
		"SWIFTSHADER",
		"ANGLE (MICROSOFT, MICROSOFT BASIC RENDER DRIVER",
	]
	for marker in markers:
		if marker.to_upper() in upper:
			return true
	return false
