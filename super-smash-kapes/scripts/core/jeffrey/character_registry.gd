class_name CharacterRegistry
extends RefCounted

const FIGHTER_CATALOG := preload("res://scripts/fighters/fighter_catalog.gd")
const SharedChar := preload("res://scripts/core/jeffrey/shared_character_definition.gd")

var _characters: Dictionary = {}


func _init() -> void:
	register_builtin()


func register_builtin() -> void:
	_characters.clear()
	for fighter in FIGHTER_CATALOG.get_all_fighters():
		var definition = SharedChar.new()
		definition.character_id = fighter.id
		definition.display_name = fighter.display_name
		definition.portrait = fighter.portrait_texture
		definition.icon = fighter.portrait_texture
		definition.enabled = true
		definition.smash_fighter_id = fighter.id
		register_character(definition)


func register_character(definition) -> void:
	if definition == null or definition.character_id.is_empty():
		push_error("[CharacterRegistry] refused empty character definition")
		return
	_characters[definition.character_id] = definition


func get_character(character_id: String):
	return _characters.get(character_id, null)


func get_all_characters() -> Array:
	var characters: Array = []
	for key in _characters.keys():
		characters.append(_characters[key])
	characters.sort_custom(func(a, b) -> bool:
		return a.character_id < b.character_id
	)
	return characters


func get_enabled_characters() -> Array:
	var enabled: Array = []
	for character in get_all_characters():
		if character.enabled:
			enabled.append(character)
	return enabled


func pick_random_enabled() -> String:
	var enabled := get_enabled_characters()
	if enabled.is_empty():
		return ""
	var picked = enabled[randi() % enabled.size()]
	return picked.character_id


func smash_fighter_id_for(character_id: String) -> String:
	var character = get_character(character_id)
	if character == null:
		return ""
	if not character.smash_fighter_id.is_empty():
		return character.smash_fighter_id
	return character.character_id
