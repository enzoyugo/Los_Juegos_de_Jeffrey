class_name ColegioInternacionalStage
extends "res://scripts/stages/authored_png_stage.gd"

func _ready() -> void:
	stage_id = "colegio_internacional"
	display_name = "COLEGIO INTERNACIONAL"
	sky_top = Color("#2f65b5")
	sky_bottom = Color("#d9b875")
	accent = Color("#e19b45")
	background_path = "res://assets/stages/smash/colegio_internacional/background.png"
	platform_paths = ["res://assets/stages/smash/colegio_internacional/platform_central.png", "res://assets/stages/smash/colegio_internacional/platform_side_left.png", "res://assets/stages/smash/colegio_internacional/platform_side_right.png"]
	super._ready()
