class_name FighterCatalog
extends RefCounted

const MATCH_SETUP := preload("res://scripts/core/match_setup.gd")
const FIGHTER_DEFINITION := preload("res://scripts/fighters/fighter_definition.gd")
const SIZE := preload("res://scripts/fighters/fighter_size_class.gd")

static var _definitions: Dictionary = {}

static func get_all_fighters() -> Array:
	_ensure_loaded()
	var fighters: Array = []
	for key in _definitions.keys():
		fighters.append(_definitions[key])
	fighters.sort_custom(func(a, b) -> bool:
		return a.id < b.id
	)
	return fighters

static func get_by_id(id: String):
	_ensure_loaded()
	return _definitions.get(id, null)

static func default_match_setup():
	var setup = MATCH_SETUP.new()
	setup.player_1_fighter_id = "terere"
	setup.player_2_fighter_id = "jaguarete"
	return setup

static func _ensure_loaded() -> void:
	if not _definitions.is_empty():
		return
	_definitions["terere"] = _make_terere()
	_definitions["jaguarete"] = _make_jaguarete()

static func _make_terere():
	var def = FIGHTER_DEFINITION.new()
	def.id = "terere"
	def.display_name = "TERERÉ"
	def.short_name = "TERERÉ"
	def.visual_script = load("res://fighters/terere/terere_actorcore_visual.gd")
	def.fallback_visual_path = "res://fighters/terere/terere_visual.gd"
	def.production_glb_path = "res://assets/fighters/processed/terere/terere_game_ready_v4.glb"
	def.pipeline_id = "ACTORCORE_V4"
	def.portrait_texture = load("res://assets/ui/portraits/terere_portrait.png")
	def.victory_texture_path = "res://assets/ui/victory/terere/terere_victory.png"
	def.primary_color = Color("#b86a2d")
	def.secondary_color = Color("#e7a05a")
	def.accent_color = Color("#2f8f4b")
	def.visual_scale = 1.0
	def.visual_offset = Vector3(0.0, 0.0, 0.0)
	def.victory_text = "¡TERERÉ GANA!"
	def.fighter_tagline = "Frío, firme y picante."
	def.size_class = SIZE.SHORT
	def.target_visual_height = 2.40
	def.body_measure_mode = "IGNORE_TOP"
	def.fit_ignore_top_ratio = 0.18
	def.body_height_fraction = 0.82
	def.ground_anchor = 0.0
	return def

static func _make_jaguarete():
	var def = FIGHTER_DEFINITION.new()
	def.id = "jaguarete"
	def.display_name = "JAGUARETÉ"
	def.short_name = "JAGUARETÉ"
	def.visual_script = load("res://fighters/jaguarete/jaguarete_actorcore_visual.gd")
	def.fallback_visual_path = "res://fighters/jaguarete/jaguarete_visual.gd"
	def.production_glb_path = "res://assets/fighters/processed/jaguarete/jaguarete_game_ready_v4.glb"
	def.pipeline_id = "ACTORCORE_V4"
	def.portrait_texture = load("res://assets/ui/portraits/jaguarete_portrait.png")
	def.victory_texture_path = "res://assets/ui/victory/jaguarete/jaguarete_victory.png"
	def.primary_color = Color("#d89a2d")
	def.secondary_color = Color("#f5e8c8")
	def.accent_color = Color("#1f1f1f")
	def.visual_scale = 1.0
	def.visual_offset = Vector3(0.0, 0.0, 0.0)
	def.victory_text = "¡JAGUARETÉ GANA!"
	def.fighter_tagline = "Garra, salto y bandera."
	def.size_class = SIZE.TALL
	def.target_visual_height = 3.15
	def.body_measure_mode = "BODY_FRACTION"
	def.fit_ignore_top_ratio = 0.0
	def.body_height_fraction = 0.95
	def.ground_anchor = 0.0
	return def
