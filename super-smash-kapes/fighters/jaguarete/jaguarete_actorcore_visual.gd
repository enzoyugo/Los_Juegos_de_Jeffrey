extends "res://scripts/fighters/actorcore_fighter_visual.gd"

func _init() -> void:
	const GLB_FIGHTER_CONFIG := preload("res://scripts/fighters/glb_fighter_config.gd")
	const SIZE := preload("res://scripts/fighters/fighter_size_class.gd")
	var cfg = GLB_FIGHTER_CONFIG.new()
	cfg.glb_path = "res://assets/fighters/processed/jaguarete/jaguarete_game_ready_v4.glb"
	cfg.fallback_visual_path = "res://fighters/jaguarete/jaguarete_visual.gd"
	cfg.size_class = SIZE.TALL
	cfg.target_visual_height = 3.15
	cfg.body_measure_mode = GLB_FIGHTER_CONFIG.BODY_MEASURE_FRACTION
	cfg.body_height_fraction = 0.95
	cfg.fit_ignore_top_ratio = 0.0
	cfg.body_anchor_y_fraction = 0.46
	cfg.horizontal_anchor_fraction = 0.48
	cfg.ground_anchor = 0.0
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
