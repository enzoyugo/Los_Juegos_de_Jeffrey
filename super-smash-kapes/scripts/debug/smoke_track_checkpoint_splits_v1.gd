extends Node

## Split arithmetic vs Hotseat storage. Headless.

const Hotseat := preload("res://scripts/track/track_hotseat_v2.gd")


func _ready() -> void:
	var hs = Hotseat.new()
	hs.setup([
		{"id": "enzo", "name": "Enzo"},
		{"id": "juan", "name": "Juan"},
	], 24.0, 2.75)
	hs.begin_run()
	for t in [10.821, 18.441, 27.915, 36.180, 44.501, 51.068]:
		hs.record_split(float(t))
	if not hs.splits_valid(hs.current(), 51.068, 6):
		print("[TRACK_SPLITS] FAIL qualify_valid")
		get_tree().quit(1)
		return
	hs.record_finish(51.068)
	hs.begin_run()
	hs.record_split(10.821)
	var d := 10.821 - hs.target_split_sec(0)
	if absf(d + 0.0) > 0.0001:
		## Enzo is first; after qualify Juan is last if Enzo has only time... 
		pass
	## After one qualifier, phase still qualify until both finish.
	hs.record_finish(22.0)
	## Now last-place phase. Target for last is the other player's splits.
	var last_id := hs.last_place_id()
	hs.begin_run()
	hs.record_split(10.403)
	var tgt := hs.target_split_sec(0)
	if tgt < 0.0:
		print("[TRACK_SPLITS] FAIL missing_target last=%s" % last_id)
		get_tree().quit(1)
		return
	var delta := 10.403 - tgt
	print("[TRACK_SPLITS] last=%s cp1_target=%.3f delta=%.3f" % [last_id, tgt, delta])
	if hs.target_final_ms() < 0:
		print("[TRACK_SPLITS] FAIL no_final_target")
		get_tree().quit(1)
		return
	print("[TRACK_SPLITS] PASS")
	get_tree().quit(0)
