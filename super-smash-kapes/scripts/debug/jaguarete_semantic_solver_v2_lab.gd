extends "res://scripts/debug/semantic_solver_v2_lab.gd"

func _init() -> void:
	fighter_id = "jaguarete"
	character_label = "JAGUARETÉ"
	pipeline_id = "ACTORCORE_SEMANTIC_SOLVER_V2"
	target_height = 3.15
	production_glb = "res://assets/fighters/processed/semantic_solver_v2/jaguarete/jaguarete_idle_semantic_v2.glb"
	benchmark_glb = production_glb
	metrics_json = "res://docs/generated/JAGUARETE_IDLE_SEMANTIC_V2_METRICS.json"
	solver_version = "semantic_idle_solver_v2"
	idle_source = "assets/fighters/animations/Idle.fbx"
	camera_height = 2.1
	camera_distance = 6.4
