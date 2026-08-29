extends Node

## HUD + F2 BASELINE + regen + difficulty. Must not Invalid-call int(null).

const Telemetry := preload("res://scripts/track/track_debug_telemetry.gd")


func _ready() -> void:
	var packed: PackedScene = load("res://scenes/debug/TrackGeneratorV2Lab.tscn") as PackedScene
	var lab = packed.instantiate()
	add_child(lab)
	await get_tree().create_timer(0.8).timeout
	var sec := 12.0
	var env := OS.get_environment("SSK_HUD_STRESS_SEC").strip_edges()
	if not env.is_empty():
		sec = maxf(float(env), 1.0)
	var elapsed := 0.0
	var cycles := 0
	while elapsed < sec:
		if lab.has_method("_toggle_controller"):
			lab.call("_toggle_controller")
		await get_tree().process_frame
		await get_tree().process_frame
		var car = lab.get("_car")
		var gnd := Telemetry.debug_int(car, "debug_grounded_n", 0)
		var spd := Telemetry.debug_float(car, "debug_speed", 0.0)
		if lab.has_method("_cycle_difficulty"):
			lab.call("_cycle_difficulty")
			lab.call("_rebuild")
			lab.call("_reset_car")
		await get_tree().create_timer(1.2).timeout
		elapsed += 1.2
		cycles += 1
		print("[TRACK_HUD_STRESS] cycle=%d mode=%s grounded_n=%d speed=%.1f t=%.1f" % [
			cycles,
			str(lab.get("_mode")),
			gnd,
			spd,
			elapsed,
		])
	print("[TRACK_HUD_STRESS] PASS cycles=%d sec=%.1f" % [cycles, sec])
	get_tree().quit(0)
