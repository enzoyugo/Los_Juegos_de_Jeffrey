extends "res://scripts/fighters/actorcore_fighter_visual.gd"

## Isolated semantic V2 battle candidate. Not production authority.
## Activated only via SSK_USE_SEMANTIC_V2_CANDIDATE=1.

const CANDIDATE_PIPELINE := "ACTORCORE_SEMANTIC_V2_CANDIDATE"
const CANDIDATE_GLB := "res://assets/fighters/processed/semantic_solver_v2/jaguarete/jaguarete_idle_semantic_v2.glb"


func _init() -> void:
	const GLB_FIGHTER_CONFIG := preload("res://scripts/fighters/glb_fighter_config.gd")
	const SIZE := preload("res://scripts/fighters/fighter_size_class.gd")
	var cfg = GLB_FIGHTER_CONFIG.new()
	cfg.glb_path = CANDIDATE_GLB
	cfg.fallback_visual_path = "res://fighters/jaguarete/jaguarete_visual.gd"
	cfg.size_class = SIZE.TALL
	cfg.target_visual_height = 3.15
	cfg.body_measure_mode = GLB_FIGHTER_CONFIG.BODY_MEASURE_FRACTION
	cfg.body_height_fraction = 0.95
	cfg.fit_ignore_top_ratio = 0.0
	cfg.body_anchor_y_fraction = 0.46
	cfg.horizontal_anchor_fraction = 0.48
	cfg.ground_anchor = 0.0
	## Semantic V2 GLB is Blender Z-up. V4 yaw-only would map height onto X.
	cfg.model_pitch_offset = -PI * 0.5
	cfg.model_yaw_offset = -PI * 0.5
	cfg.shadow_enabled = true
	cfg.shadow_width = 1.55
	cfg.shadow_depth = 0.78
	config = cfg
	clip_speed_scale = {
		"idle": 0.90,
		"jump": 1.05,
		"attack_neutral": 2.20,
		"hit_light": 1.10,
		"ko": 0.92,
	}


func pipeline_name() -> String:
	return CANDIDATE_PIPELINE
