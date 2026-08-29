extends "res://scripts/fighters/glb_fighter_visual.gd"

func _init() -> void:
	const GLB_FIGHTER_CONFIG := preload("res://scripts/fighters/glb_fighter_config.gd")
	const SIZE := preload("res://scripts/fighters/fighter_size_class.gd")
	var cfg = GLB_FIGHTER_CONFIG.new()
	cfg.glb_path = "res://assets/fighters/models/jaguarete/jaguarete_glb_1.glb"
	cfg.fallback_visual_script = load("res://fighters/jaguarete/jaguarete_visual.gd")
	cfg.size_class = SIZE.TALL
	cfg.target_visual_height = 3.15
	cfg.body_measure_mode = GLB_FIGHTER_CONFIG.BODY_MEASURE_FRACTION
	cfg.body_height_fraction = 0.95
	cfg.fit_ignore_top_ratio = 0.0
	cfg.body_anchor_y_fraction = 0.46
	cfg.horizontal_anchor_fraction = 0.48
	cfg.ground_anchor = 0.0
	cfg.model_yaw_offset = -PI * 0.5
	cfg.shadow_width = 1.55
	cfg.shadow_depth = 0.78
	config = cfg

func _apply_motion(delta: float) -> void:
	super._apply_motion(delta)
	if motion_root == null:
		return
	if _state_label == "ATTACK":
		motion_root.rotation.x = lerpf(motion_root.rotation.x, -0.18, minf(delta * 16.0, 1.0))
	elif _state_label == "VICTORY":
		motion_root.rotation.z = lerpf(motion_root.rotation.z, 0.1 * facing, minf(delta * 6.0, 1.0))
