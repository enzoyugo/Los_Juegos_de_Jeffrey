extends Node

## Headless Hotseat last-place simulation. Not TrackMain.

const Hotseat := preload("res://scripts/track/track_hotseat_v2.gd")


func _ready() -> void:
	var hs = Hotseat.new()
	hs.setup([
		{"id": "enzo", "name": "Enzo"},
		{"id": "juan", "name": "Juan"},
		{"id": "santi", "name": "Santi"},
		{"id": "tomi", "name": "Tomi"},
	], 24.0, 2.75)
	## Qualification times.
	var q := [22.5, 24.0, 24.7, 25.0]
	for t in q:
		hs.begin_run()
		hs.record_finish(float(t))
	var last := hs.last_place_id()
	if last != "tomi":
		print("[TRACK_HOTSEAT] FAIL last_after_qual=%s" % last)
		get_tree().quit(1)
		return
	hs.begin_run()
	hs.record_finish(23.8)
	if hs.last_place_id() != "santi":
		print("[TRACK_HOTSEAT] FAIL last_after_tomi=%s" % hs.last_place_id())
		get_tree().quit(1)
		return
	## Fuel + última: drain Tomi analog — Santi fuel to 0 during run.
	var santi = hs.current()
	santi["fuel"] = 0.0
	var begin: Dictionary = hs.begin_run()
	if not bool(begin.get("ultima", false)):
		print("[TRACK_HOTSEAT] FAIL ultima_not_flagged")
		get_tree().quit(1)
		return
	## Tie: millisecond identity.
	if hs._ms(24.0004) != 24000:
		print("[TRACK_HOTSEAT] FAIL ms_round")
		get_tree().quit(1)
		return
	print("[TRACK_HOTSEAT] PASS last=santi ultima=true")
	get_tree().quit(0)
