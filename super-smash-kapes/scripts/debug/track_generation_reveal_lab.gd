extends Node3D

const Assembler := preload("res://scripts/track/track_kit_assembler.gd")
const Reveal := preload("res://scripts/track/track_generation_reveal.gd")
const Gen := preload("res://scripts/track/track_generator_v2.gd")


func _ready() -> void:
	var g = Gen.new()
	var row: Dictionary = g.generate(12, "SHORT", "PICANTE")
	var seq: Array = row.get("piece_sequence", [])
	var built: Dictionary = Assembler.assemble(self, seq)
	var pieces: Array = built["pieces"]
	var cam := Camera3D.new()
	cam.current = true
	add_child(cam)
	var rev = Reveal.new()
	add_child(rev)
	rev.finished.connect(func():
		if pieces.size() != seq.size():
			print("[TRACK_REVEAL] FAIL count")
			get_tree().quit(1)
			return
		print("[TRACK_REVEAL] PASS n=%d" % pieces.size())
		get_tree().quit(0)
	)
	rev.skip = OS.get_environment("SSK_REVEAL_SKIP").strip_edges() == "1"
	rev.start(pieces, cam)
