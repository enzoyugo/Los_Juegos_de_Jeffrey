extends "res://scripts/fighters/actorcore_fighter_visual.gd"

func _init() -> void:
	const GLB_FIGHTER_CONFIG := preload("res://scripts/fighters/glb_fighter_config.gd")
	const SIZE := preload("res://scripts/fighters/fighter_size_class.gd")
	var cfg = GLB_FIGHTER_CONFIG.new()
	cfg.glb_path = "res://assets/fighters/processed/terere/terere_game_ready_v4.glb"
	cfg.fallback_visual_path = "res://fighters/terere/terere_visual.gd"
	cfg.size_class = SIZE.SHORT
	cfg.target_visual_height = 2.40
	cfg.body_measure_mode = GLB_FIGHTER_CONFIG.BODY_MEASURE_IGNORE_TOP
	cfg.fit_ignore_top_ratio = 0.18
	cfg.body_height_fraction = 0.82
	cfg.body_anchor_y_fraction = 0.44
	cfg.horizontal_anchor_fraction = 0.5
	cfg.ground_anchor = 0.0
	cfg.model_yaw_offset = -PI * 0.5
	cfg.shadow_width = 1.35
	cfg.shadow_depth = 0.68
	config = cfg
	clip_speed_scale = {
		"idle": 1.10,
		"jump": 1.18,
		"attack_neutral": 2.35,
		"hit_light": 1.20,
		"ko": 1.0,
	}
