class_name LJPlayerProfile
extends RefCounted

var profile_id: String = ""
var display_name: String = ""
var created_at: float = 0.0
var last_played_at: float = 0.0
var sessions_played: int = 0
var total_playtime: float = 0.0
var smash_stats: Dictionary = {}
var racing_stats: Dictionary = {}
var zombies_stats: Dictionary = {}
var portrait_path: String = ""


static func empty_smash_stats() -> Dictionary:
	return {
		"matches_played": 0,
		"wins": 0,
		"losses": 0,
		"kos": 0,
		"deaths": 0,
	}


static func empty_racing_stats() -> Dictionary:
	return {
		"matches_played": 0,
		"wins": 0,
		"last_dances": 0,
		"last_dances_survived": 0,
		"eliminations": 0,
		"photo_finishes": 0,
	}


static func empty_zombies_stats() -> Dictionary:
	return {
		"matches_played": 0,
		"best_wave": 0,
		"kills": 0,
		"revives": 0,
		"downs": 0,
	}


static func create(display_name: String):
	var profile = new()
	var now := Time.get_unix_time_from_system()
	profile.profile_id = "p_%d_%d" % [int(now), randi() % 100000]
	profile.display_name = display_name.strip_edges()
	profile.created_at = now
	profile.last_played_at = now
	profile.smash_stats = empty_smash_stats()
	profile.racing_stats = empty_racing_stats()
	profile.zombies_stats = empty_zombies_stats()
	return profile


func to_dict() -> Dictionary:
	return {
		"profile_id": profile_id,
		"display_name": display_name,
		"created_at": created_at,
		"last_played_at": last_played_at,
		"sessions_played": sessions_played,
		"total_playtime": total_playtime,
		"smash_stats": smash_stats.duplicate(true),
		"racing_stats": racing_stats.duplicate(true),
		"zombies_stats": zombies_stats.duplicate(true),
		"portrait_path": portrait_path,
	}


static func from_dict(data: Dictionary):
	var profile = new()
	profile.profile_id = str(data.get("profile_id", ""))
	profile.display_name = str(data.get("display_name", ""))
	profile.created_at = float(data.get("created_at", 0.0))
	profile.last_played_at = float(data.get("last_played_at", 0.0))
	profile.sessions_played = int(data.get("sessions_played", 0))
	profile.total_playtime = float(data.get("total_playtime", 0.0))
	profile.smash_stats = _merge_stats(empty_smash_stats(), data.get("smash_stats", {}))
	profile.racing_stats = _merge_stats(empty_racing_stats(), data.get("racing_stats", {}))
	profile.zombies_stats = _merge_stats(empty_zombies_stats(), data.get("zombies_stats", {}))
	profile.portrait_path = str(data.get("portrait_path", ""))
	return profile


static func _merge_stats(defaults: Dictionary, incoming) -> Dictionary:
	var merged := defaults.duplicate(true)
	if incoming is Dictionary:
		for key in incoming.keys():
			merged[key] = incoming[key]
	return merged
