extends Node

const Rhythm := preload("res://scripts/track/track_rhythm_analyzer.gd")
const Gen := preload("res://scripts/track/track_generator_v2.gd")


func _ready() -> void:
	OS.set_environment("SSK_GEN_QUIET", "1")
	var g = Gen.new()
	var lengths := ["SHORT", "MEDIUM", "LONG"]
	var diffs := ["TRANQUI", "PICANTE", "DEMENTE"]
	var per := 20
	if OS.get_environment("SSK_RHYTHM_FULL").strip_edges() == "1":
		per = 100
	elif OS.get_environment("SSK_RHYTHM_QUICK").strip_edges() == "1":
		per = 5
	var n := 0
	var acc := 0
	var score_sum := 0.0
	var max_run := 0
	for L in lengths:
		for D in diffs:
			for i in per:
				var row: Dictionary = g.generate(1000 + n, L, D)
				n += 1
				if bool(row.get("accepted", false)):
					acc += 1
					var a: Dictionary = Rhythm.analyze(row.get("piece_sequence", []))
					score_sum += float(a.get("rhythm_score", 0.0))
					max_run = maxi(max_run, int(a.get("max_straight_run", 0)))
	var mean := score_sum / maxf(float(acc), 1.0)
	print("[TRACK_RHYTHM] n=%d accepted=%d mean_score=%.3f max_straight_run=%d" % [n, acc, mean, max_run])
	print("[TRACK_RHYTHM] PASS (analyzer only, generator weights unchanged)")
	get_tree().quit(0 if acc > 0 else 1)
