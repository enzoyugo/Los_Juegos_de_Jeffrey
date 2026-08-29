extends "res://scripts/debug/actorcore_animation_lab.gd"

## Isolated Tereré ActorCore idle benchmark lab.
## RUNTIME RETARGET: OFF
## actorcore_benchmark/terere/terere_actorcore_idle.glb

func _init() -> void:
	benchmark_glb = "res://assets/fighters/processed/actorcore_benchmark/terere/terere_actorcore_idle.glb"
	character_label = "TERERÉ"
	camera_height = 1.6
	camera_distance = 5.5
