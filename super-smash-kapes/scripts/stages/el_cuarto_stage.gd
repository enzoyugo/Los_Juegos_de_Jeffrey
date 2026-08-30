class_name ElCuartoStage
extends "res://scripts/stages/authored_png_stage.gd"

func _ready() -> void:
	stage_id = "el_cuarto"
	display_name = "EL CUARTO"
	sky_top = Color("#171325")
	sky_bottom = Color("#73544d")
	accent = Color("#e2a83f")
	background_path = "res://assets/stages/smash/el_cuarto/background.png"
	platform_paths = ["res://assets/stages/smash/el_cuarto/platform_table.png", "res://assets/stages/smash/el_cuarto/platform_side_left.png", "res://assets/stages/smash/el_cuarto/platform_side_right.png"]
	super._ready()
