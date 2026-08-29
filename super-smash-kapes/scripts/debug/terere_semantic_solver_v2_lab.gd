extends "res://scripts/debug/semantic_solver_v2_lab.gd"

func _init() -> void:
	fighter_id = "terere"
	character_label = "TERERÉ"
	pipeline_id = "ACTORCORE_SEMANTIC_SOLVER_V2"
	target_height = 2.40
	production_glb = "res://assets/fighters/processed/semantic_solver_v2/terere/terere_idle_semantic_v2.glb"
	benchmark_glb = production_glb
	metrics_json = "res://docs/generated/TERERE_IDLE_SEMANTIC_V2_METRICS.json"
	solver_version = "semantic_idle_solver_v2"
	idle_source = "assets/fighters/animations/Idle.fbx"
	camera_height = 1.6
	camera_distance = 5.5
