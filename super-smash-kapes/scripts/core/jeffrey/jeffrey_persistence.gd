class_name JeffreyPersistence
extends RefCounted

const ProfileScript := preload("res://scripts/core/jeffrey/player_profile.gd")
const SAVE_VERSION := 1
const DEFAULT_DIR := "user://los_juegos_de_jeffrey"

var save_directory: String = DEFAULT_DIR


func save_path() -> String:
	return save_directory.path_join("save.json")


func temp_path() -> String:
	return save_directory.path_join("save.json.tmp")


func backup_path() -> String:
	return save_directory.path_join("save.json.bak")


func load_payload() -> Dictionary:
	DirAccess.make_dir_recursive_absolute(_abs_dir())
	var path := save_path()
	if not FileAccess.file_exists(path):
		return _empty_payload()
	var parsed := _read_json(path)
	if parsed.is_empty() or int(parsed.get("save_version", 0)) < 1:
		_quarantine_corrupt(path)
		var clean := _empty_payload()
		clean["recovered_from_corruption"] = true
		return clean
	return _migrate(parsed)


func save_payload(payload: Dictionary) -> bool:
	DirAccess.make_dir_recursive_absolute(_abs_dir())
	var outgoing := payload.duplicate(true)
	outgoing["save_version"] = SAVE_VERSION
	var json := JSON.stringify(outgoing, "\t")
	var tmp := temp_path()
	var file := FileAccess.open(tmp, FileAccess.WRITE)
	if file == null:
		push_error("[JeffreyPersistence] could not write temp save: %s" % FileAccess.get_open_error())
		return false
	file.store_string(json)
	file.flush()
	file.close()
	var final_path := save_path()
	if FileAccess.file_exists(final_path):
		DirAccess.copy_absolute(_abs(final_path), _abs(backup_path()))
	var err := DirAccess.rename_absolute(_abs(tmp), _abs(final_path))
	if err != OK:
		# Windows fallback: replace in place if rename across the same folder fails.
		var replace_file := FileAccess.open(final_path, FileAccess.WRITE)
		if replace_file == null:
			push_error("[JeffreyPersistence] could not replace save file")
			return false
		replace_file.store_string(json)
		replace_file.flush()
		replace_file.close()
		DirAccess.remove_absolute(_abs(tmp))
	return true


func load_into(store) -> Dictionary:
	var payload := load_payload()
	store.replace_all([])
	for item in payload.get("profiles", []):
		if item is Dictionary:
			var profile = ProfileScript.from_dict(item)
			if not profile.profile_id.is_empty():
				store.add(profile)
	return payload


func save_from(store, global_stats: Dictionary = {}, settings: Dictionary = {}) -> bool:
	return save_payload({
		"save_version": SAVE_VERSION,
		"profiles": store.to_array(),
		"global_stats": global_stats.duplicate(true),
		"settings": settings.duplicate(true),
	})


func _empty_payload() -> Dictionary:
	return {
		"save_version": SAVE_VERSION,
		"profiles": [],
		"global_stats": {
			"smash_matches": 0,
			"racing_matches": 0,
			"zombies_matches": 0,
		},
		"settings": {},
		"recovered_from_corruption": false,
	}


func _migrate(payload: Dictionary) -> Dictionary:
	var migrated := _empty_payload()
	migrated["save_version"] = SAVE_VERSION
	migrated["profiles"] = payload.get("profiles", [])
	var globals = payload.get("global_stats", {})
	if globals is Dictionary:
		for key in migrated["global_stats"].keys():
			if globals.has(key):
				migrated["global_stats"][key] = globals[key]
	if payload.get("settings") is Dictionary:
		migrated["settings"] = payload["settings"]
	return migrated


func _read_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(text) != OK:
		return {}
	var parsed: Variant = json.data
	if parsed is Dictionary:
		return parsed
	return {}


func _quarantine_corrupt(path: String) -> void:
	var stamp := int(Time.get_unix_time_from_system())
	var dest := save_directory.path_join("save.corrupt.%d.json" % stamp)
	DirAccess.copy_absolute(_abs(path), _abs(dest))
	push_error("[JeffreyPersistence] save corrupt — backup written to %s; starting clean" % dest)


func _abs_dir() -> String:
	return ProjectSettings.globalize_path(save_directory)


func _abs(path: String) -> String:
	return ProjectSettings.globalize_path(path)
