extends "res://scripts/debug/solver_v1_animation_lab.gd"

func _init() -> void:
	fighter_id = "terere"
	character_label = "TERERÉ"
	pipeline_id = "ACTORCORE_SOLVER_V1"
	target_height = 2.40
	production_glb = "res://assets/fighters/processed/solver_v1/terere/terere_idle_solver_v1.glb"
	benchmark_glb = production_glb
	metrics_json = "res://docs/generated/TERERE_IDLE_SOLVER_V1_METRICS.json"
	solver_version = "solver_v1"
	camera_height = 1.6
	camera_distance = 5.5
