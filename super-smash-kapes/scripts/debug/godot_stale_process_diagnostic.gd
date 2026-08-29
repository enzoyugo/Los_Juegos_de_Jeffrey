extends Node

## Read-only Godot process diagnostic. Never kills the editor.

func _ready() -> void:
	var editor_pid := OS.get_process_id()
	print("[PROCESS_GUARD] editor_pid=%d" % editor_pid)
	print("[PROCESS_GUARD] executable=%s" % OS.get_executable_path())
	var mem := OS.get_static_memory_usage()
	var peak := OS.get_static_memory_peak_usage()
	print("[PROCESS_GUARD] static=%d peak=%d" % [mem, peak])
	if OS.has_feature("windows"):
		var out: Array = []
		OS.execute("cmd", PackedStringArray(["/c", "tasklist | findstr /I Godot"]), out, true, false)
		for line in out:
			var s := str(line).strip_edges()
			if not s.is_empty():
				print("[PROCESS_GUARD] tasklist %s" % s)
		var mem_out: Array = []
		OS.execute("cmd", PackedStringArray(["/c", "wmic OS get FreePhysicalMemory,TotalVisibleMemorySize /VALUE"]), mem_out, true, false)
		for line2 in mem_out:
			var s2 := str(line2).strip_edges()
			if not s2.is_empty():
				print("[PROCESS_GUARD] %s" % s2)
	print("[PROCESS_GUARD] stale candidates are extra Godot PIDs besides editor_pid=%d — human closes them. never auto-kill." % editor_pid)
	get_tree().quit(0)
