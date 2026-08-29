class_name FighterDefinition
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export var short_name: String = ""
@export var visual_script: Script
@export var fallback_visual_script: Script
@export var fallback_visual_path: String = ""
@export var visual_scene: PackedScene
@export var victory_model_scene: PackedScene
@export var portrait_texture: Texture2D
@export var reference_texture: Texture2D
@export var victory_texture: Texture2D
@export var victory_texture_path: String = ""
@export var production_glb_path: String = ""
@export var pipeline_id: String = "ACTORCORE_V3"
@export var primary_color: Color = Color.WHITE
@export var secondary_color: Color = Color.WHITE
@export var accent_color: Color = Color.WHITE
@export var visual_scale: float = 1.0
@export var visual_offset: Vector3 = Vector3.ZERO
@export var victory_text: String = ""
@export var fighter_tagline: String = ""

## Canonical presentation identity (visual only — not gameplay collider).
@export var size_class: String = "MEDIUM"
@export var target_visual_height: float = 2.75
@export var body_measure_mode: String = "BODY_FRACTION"
@export var body_height_fraction: float = 1.0
@export var fit_ignore_top_ratio: float = 0.0
@export var ground_anchor: float = 0.0

func create_visual():
	if OS.get_environment("SSK_USE_SEMANTIC_V2_CANDIDATE") == "1":
		var candidate_script := _semantic_v2_candidate_script()
		if candidate_script != null and candidate_script.can_instantiate():
			return candidate_script.new()
	if visual_script == null:
		return null
	var script_ref: Script = visual_script
	if script_ref == null or not script_ref.can_instantiate():
		return null
	return script_ref.new()


func _semantic_v2_candidate_script() -> Script:
	if id == "terere":
		return load("res://fighters/terere/terere_semantic_v2_battle_candidate.gd") as Script
	if id == "jaguarete":
		return load("res://fighters/jaguarete/jaguarete_semantic_v2_battle_candidate.gd") as Script
	return null


func load_victory_texture() -> Texture2D:
	if victory_texture != null:
		return victory_texture
	if victory_texture_path.is_empty():
		return null
	return load(victory_texture_path) as Texture2D


func load_fallback_visual_script() -> Script:
	if fallback_visual_script != null:
		return fallback_visual_script
	if fallback_visual_path.is_empty():
		return null
	return load(fallback_visual_path) as Script
