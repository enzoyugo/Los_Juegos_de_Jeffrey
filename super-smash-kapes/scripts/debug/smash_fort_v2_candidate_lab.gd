extends Node

## Headless Fort V2 candidate smoke. Does not replace production catalog.
## Run: godot --headless --path . --quit-after 4 res://scenes/debug/SmashFortV2CandidateLab.tscn

func _ready() -> void:
	OS.set_environment("SSK_FORT_V2_CANDIDATE", "1")
	var catalog = load("res://scripts/fighters/fighter_catalog.gd")
	var fort = catalog.get_by_id("fort")
	assert(fort != null)
	var path := "res://assets/fighters/processed/fort/fort_stylized_v2_candidate.glb"
	var v1 := "res://assets/fighters/processed/fort/fort_stylized_v1.glb"
	assert(ResourceLoader.exists(v1), "V1 must remain frozen")
	assert(ResourceLoader.exists(path), "V2 candidate GLB missing")
	var packed = load(path)
	assert(packed is PackedScene)
	var inst = (packed as PackedScene).instantiate()
	add_child(inst)
	print("[FORT_V2_CANDIDATE] production_glb_still=", fort.production_glb_path)
	print("[FORT_V2_CANDIDATE] candidate_loaded=", path)
	print("[FORT_V2_CANDIDATE] PASS")
	await get_tree().create_timer(0.2).timeout
	get_tree().quit(0)
