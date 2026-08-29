extends "res://scripts/fighters/glb_fighter_visual.gd"

func _init() -> void:
	const GLB_FIGHTER_CONFIG := preload("res://scripts/fighters/glb_fighter_config.gd")
	const SIZE := preload("res://scripts/fighters/fighter_size_class.gd")
	var cfg = GLB_FIGHTER_CONFIG.new()
	cfg.glb_path = "res://assets/fighters/models/terere/terere_glb_1.glb"
	cfg.fallback_visual_script = load("res://fighters/terere/terere_visual.gd")
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

func _apply_motion(delta: float) -> void:
	super._apply_motion(delta)
	if motion_root == null:
		return
	if _state_label == "ATTACK":
		motion_root.rotation.y = lerpf(motion_root.rotation.y, 0.12 * facing, minf(delta * 14.0, 1.0))
	else:
		motion_root.rotation.y = lerpf(motion_root.rotation.y, 0.0, minf(delta * 10.0, 1.0))
