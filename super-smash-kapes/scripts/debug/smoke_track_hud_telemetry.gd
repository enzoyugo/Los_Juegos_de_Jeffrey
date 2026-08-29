extends Node

## HUD telemetry must not crash on null / BASELINE missing grounded_n.

const Telemetry := preload("res://scripts/track/track_debug_telemetry.gd")


func _ready() -> void:
	var n := Telemetry.debug_int(null, "debug_grounded_n", 0)
	var f := Telemetry.debug_float(self, "nope", 1.5)
	var b := Telemetry.debug_bool(self, "missing", false)
	var s := Telemetry.debug_string(self, "missing", "-")
	if n != 0 or f != 1.5 or b != false or s != "-":
		print("[TRACK_HUD_TELEMETRY] FAIL defaults")
		get_tree().quit(1)
		return
	var dummy := Node.new()
	add_child(dummy)
	if Telemetry.debug_int(dummy, "debug_grounded_n", 7) != 7:
		print("[TRACK_HUD_TELEMETRY] FAIL missing_int")
		get_tree().quit(1)
		return
	print("[TRACK_HUD_TELEMETRY] PASS")
	get_tree().quit(0)
