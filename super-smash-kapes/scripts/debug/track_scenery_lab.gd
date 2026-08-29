extends Node3D

const Assembler := preload("res://scripts/track/track_kit_assembler.gd")
const Scenery := preload("res://scripts/track/track_scenery_generator.gd")
const Signage := preload("res://scripts/track/track_signage.gd")
const Gen := preload("res://scripts/track/track_generator_v2.gd")


func _ready() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 20, 0)
	add_child(sun)
	var g = Gen.new()
	var row: Dictionary = g.generate(21, "MEDIUM", "PICANTE")
	var seq: Array = row.get("piece_sequence", [])
	var built: Dictionary = Assembler.assemble(self, seq)
	var sc = Scenery.new()
	add_child(sc)
	sc.build(built["pieces"])
	Signage.decorate(self, built["pieces"])
	var cam := Camera3D.new()
	cam.current = true
	cam.position = Vector3(0, 18, 28)
	add_child(cam)
	cam.look_at(Vector3(0, 0, -20), Vector3.UP)
	var bodies := 0
	for child in sc.get_children():
		if child is StaticBody3D:
			bodies += 1
	if bodies > 0:
		print("[TRACK_SCENERY] FAIL collision_bodies=%d" % bodies)
		get_tree().quit(1)
		return
	print("[TRACK_SCENERY] PASS landmarks=%d mm=%d VISUAL_REVIEW_PENDING" % [
		sc.landmarks.size(), sc.get_child_count()
	])
	if OS.get_environment("SSK_SCENERY_QUIT").strip_edges() == "1":
		get_tree().quit(0)
