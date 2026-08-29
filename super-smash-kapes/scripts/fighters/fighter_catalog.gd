class_name FighterCatalog
extends RefCounted

const MATCH_SETUP := preload("res://scripts/core/match_setup.gd")
const FIGHTER_DEFINITION := preload("res://scripts/fighters/fighter_definition.gd")
const SIZE := preload("res://scripts/fighters/fighter_size_class.gd")
const STYLIZED_GLB := preload("res://scripts/fighters/jeffrey_stylized_glb_visual.gd")
## Procedural builder remains available via fallback_visual_path.

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
	setup.stage_id = "defensores"
	return setup


static func gameplay_profile(fighter_id: String) -> Dictionary:
	## Movement / attack identity (combat feel). Does not invent new systems.
	match fighter_id:
		"cartes":
			return {
				"walk_speed": 7.5,
				"jump_velocity": 14.5,
				"double_jump_velocity": 13.5,
				"weight": 128.0,
				"attack_damage": 10.0,
				"attack_base_knockback": 8.5,
				"attack_knockback_growth": 0.12,
				"startup_seconds": 0.14,
				"active_seconds": 0.12,
				"recovery_seconds": 0.32,
			}
		"fort":
			return {
				"walk_speed": 9.5,
				"jump_velocity": 15.5,
				"double_jump_velocity": 14.5,
				"weight": 112.0,
				"attack_damage": 9.0,
				"attack_base_knockback": 8.0,
				"attack_knockback_growth": 0.11,
				"startup_seconds": 0.12,
				"active_seconds": 0.14,
				"recovery_seconds": 0.30,
			}
		"pajaro_campana":
			return {
				"walk_speed": 12.5,
				"jump_velocity": 18.0,
				"double_jump_velocity": 17.0,
				"weight": 78.0,
				"attack_damage": 6.5,
				"attack_base_knockback": 5.5,
				"attack_knockback_growth": 0.09,
				"startup_seconds": 0.06,
				"active_seconds": 0.09,
				"recovery_seconds": 0.16,
			}
		_:
			return {}


static func _ensure_loaded() -> void:
	if not _definitions.is_empty():
		return
	_definitions["terere"] = _make_terere()
	_definitions["jaguarete"] = _make_jaguarete()
	_definitions["cartes"] = _make_cartes()
	_definitions["fort"] = _make_fort()
	_definitions["pajaro_campana"] = _make_pajaro()


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


static func _make_stylized(id: String, display: String, tagline: String, victory: String, primary: Color, secondary: Color, accent: Color, height: float):
	var def = FIGHTER_DEFINITION.new()
	def.id = id
	def.display_name = display
	def.short_name = display
	def.visual_script = STYLIZED_GLB
	def.fallback_visual_path = "res://scripts/fighters/jeffrey_stylized_fighter_visual.gd"
	def.production_glb_path = "res://assets/fighters/processed/%s/%s_stylized_v1.glb" % [id, id]
	def.pipeline_id = "JEFFREY_STYLIZED_BLENDER_V1_INTERIM"
	def.portrait_texture = _load_texture("res://assets/ui/portraits/%s_portrait.png" % id)
	def.victory_texture_path = "res://assets/ui/victory/%s/%s_victory.png" % [id, id]
	def.primary_color = primary
	def.secondary_color = secondary
	def.accent_color = accent
	def.visual_scale = 1.0
	def.visual_offset = Vector3.ZERO
	def.victory_text = victory
	def.fighter_tagline = tagline
	def.size_class = SIZE.MEDIUM if height < 2.9 else SIZE.TALL
	def.target_visual_height = height
	def.body_measure_mode = "BODY_FRACTION"
	def.body_height_fraction = 1.0
	def.ground_anchor = 0.0
	return def


static func _load_texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		var loaded = load(path)
		if loaded is Texture2D:
			return loaded
	if FileAccess.file_exists(path):
		var img := Image.new()
		if img.load(path) == OK:
			return ImageTexture.create_from_image(img)
	return null


static func _make_cartes():
	return _make_stylized(
		"cartes",
		"HORACIO CARTES",
		"Pesado, compacto y contundente.",
		"¡CARTES GANA!",
		Color("#243044"),
		Color("#d2a878"),
		Color("#c62828"),
		2.75
	)


static func _make_fort():
	return _make_stylized(
		"fort",
		"RICARDO FORT",
		"Brillo, drama y cachetada dorada.",
		"¡FORT GANA!",
		Color("#f4f1ea"),
		Color("#f0c848"),
		Color("#7a4cff"),
		2.85
	)


static func _make_pajaro():
	return _make_stylized(
		"pajaro_campana",
		"PÁJARO CAMPANA",
		"Liviano, rápido y con pico.",
		"¡PÁJARO GANA!",
		Color("#f0d246"),
		Color("#ffe27a"),
		Color("#c62828"),
		2.35
	)
