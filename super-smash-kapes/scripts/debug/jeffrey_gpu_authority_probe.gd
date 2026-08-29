extends Node

## Emits GPU authority markers for the perf runner.
## Run with display-backed Windows driver (not headless).

const Sampler := preload("res://scripts/debug/jeffrey_perf_sampler.gd")

@export var probe_label: String = "PROBE"


func _ready() -> void:
	var adapter := str(RenderingServer.get_video_adapter_name())
	var method := str(ProjectSettings.get_setting("rendering/renderer/rendering_method", ""))
	var expected := OS.get_environment("SSK_EXPECTED_GPU").strip_edges()
	if expected.is_empty():
		expected = "NVIDIA"
	var upper := adapter.to_upper()
	var authority_ok := false
	for token in expected.split(",", false):
		var needle := token.strip_edges().to_upper()
		if not needle.is_empty() and needle in upper:
			authority_ok = true
			break
	if _is_software_adapter(adapter):
		authority_ok = false
	var label := OS.get_environment("SSK_GPU_PROBE_LABEL").strip_edges()
	if label.is_empty():
		label = probe_label
	print("[GPU_PROBE] label=%s adapter=%s renderer=%s" % [label, adapter, method])
	print("[GPU_AUTHORITY] adapter=%s pass=%s" % [adapter, str(authority_ok).to_lower()])
	if authority_ok:
		print("GPU_AUTHORITY=PASS")
	else:
		print("GPU_AUTHORITY=FAIL")
	get_tree().quit(0 if authority_ok else 2)


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
