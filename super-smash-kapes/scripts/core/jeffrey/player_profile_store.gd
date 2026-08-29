class_name PlayerProfileStore
extends RefCounted

const ProfileScript := preload("res://scripts/core/jeffrey/player_profile.gd")

var profiles: Dictionary = {}
var last_error: String = ""


func clear() -> void:
	profiles.clear()
	last_error = ""


static func normalize_display_name(display_name: String) -> String:
	return display_name.strip_edges().to_lower()


func find_normalized(display_name: String):
	var key := normalize_display_name(display_name)
	if key.is_empty():
		return null
	for profile in profiles.values():
		if normalize_display_name(profile.display_name) == key:
			return profile
	return null


func add(profile) -> Variant:
	if profile == null or profile.profile_id.is_empty() or profile.display_name.strip_edges().is_empty():
		push_error("[PlayerProfileStore] refused invalid profile")
		last_error = "invalid"
		return null
	profiles[profile.profile_id] = profile
	last_error = ""
	return profile


func create(display_name: String):
	last_error = ""
	var name := display_name.strip_edges()
	if name.is_empty():
		last_error = "empty"
		return null
	if find_normalized(name) != null:
		last_error = "duplicate"
		return null
	return add(ProfileScript.create(name))


func get_profile(profile_id: String):
	return profiles.get(profile_id, null)


func get_all() -> Array:
	var list: Array = []
	for profile in profiles.values():
		list.append(profile)
	list.sort_custom(func(a, b) -> bool:
		return a.created_at < b.created_at
	)
	return list


func replace_all(list: Array) -> void:
	clear()
	for item in list:
		if item != null and item.has_method("to_dict"):
			add(item)


func to_array() -> Array:
	var packed: Array = []
	for profile in get_all():
		packed.append(profile.to_dict())
	return packed
