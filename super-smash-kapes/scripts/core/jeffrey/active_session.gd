class_name LJActiveSession
extends RefCounted

var session_id: String = ""
var started_at: float = 0.0
var active_player_ids: Array[String] = []


func ensure_started() -> void:
	if not session_id.is_empty():
		return
	started_at = Time.get_unix_time_from_system()
	session_id = "s_%d_%d" % [int(started_at), randi() % 100000]


func reset() -> void:
	session_id = ""
	started_at = 0.0
	active_player_ids.clear()


func set_roster(profile_ids: Array[String]) -> void:
	ensure_started()
	active_player_ids.clear()
	for profile_id in profile_ids:
		add_player(profile_id)


func add_player(profile_id: String) -> void:
	if profile_id.is_empty():
		return
	ensure_started()
	if not active_player_ids.has(profile_id):
		active_player_ids.append(profile_id)


func remove_player(profile_id: String) -> void:
	active_player_ids.erase(profile_id)


func has_player(profile_id: String) -> bool:
	return active_player_ids.has(profile_id)


func count() -> int:
	return active_player_ids.size()
