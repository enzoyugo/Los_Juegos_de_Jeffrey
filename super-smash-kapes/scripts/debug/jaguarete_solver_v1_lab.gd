extends "res://scripts/debug/solver_v1_animation_lab.gd"

func _init() -> void:
	fighter_id = "jaguarete"
	character_label = "JAGUARETÉ"
	pipeline_id = "ACTORCORE_SOLVER_V1"
	target_height = 3.15
	production_glb = "res://assets/fighters/processed/solver_v1/jaguarete/jaguarete_idle_solver_v1.glb"
	benchmark_glb = production_glb
	metrics_json = "res://docs/generated/JAGUARETE_IDLE_SOLVER_V1_METRICS.json"
	solver_version = "solver_v1"
	camera_height = 2.1
	camera_distance = 6.4
