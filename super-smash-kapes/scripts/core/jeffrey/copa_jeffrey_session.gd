class_name LJCopaJeffreySession
extends RefCounted

const Scoring := preload("res://scripts/core/jeffrey/copa_jeffrey_scoring.gd")

var session_id: String = ""
var started_at: float = 0.0
var player_stats: Dictionary = {}
var round_history: Array = []
var games_played: int = 0
var recorded_match_ids: Dictionary = {}
var _join_order: Dictionary = {}
var _next_join_index: int = 0
var last_recorded_result: Dictionary = {}
var _match_counter: int = 0


func start_new(linked_session_id: String, profile_ids: Array[String]) -> void:
	session_id = linked_session_id
	started_at = Time.get_unix_time_from_system()
	player_stats.clear()
	round_history.clear()
	games_played = 0
	recorded_match_ids.clear()
	_join_order.clear()
	_next_join_index = 0
	last_recorded_result = {}
	_match_counter = 0
	for profile_id in profile_ids:
		_ensure_player(profile_id)


func reset_scores() -> void:
	player_stats.clear()
	round_history.clear()
	games_played = 0
	recorded_match_ids.clear()
	last_recorded_result = {}
	_match_counter = 0
	_next_join_index = 0
	_join_order.clear()
	for profile_id in _active_profile_ids_from_stats():
		_ensure_player(profile_id)


func sync_roster(active_ids: Array[String]) -> void:
	for profile_id in active_ids:
		_ensure_player(profile_id)


func generate_match_id(mode: String) -> String:
	_match_counter += 1
	return "%s_%s_%d" % [session_id, mode, _match_counter]


func has_recorded(match_id: String) -> bool:
	return recorded_match_ids.has(match_id)


func record_match_result(payload: Dictionary) -> Dictionary:
	var match_id := str(payload.get("match_id", ""))
	if match_id.is_empty():
		push_error("[CopaJeffrey] record_match_result missing match_id")
		return {}
	if recorded_match_ids.has(match_id):
		return {}
	var mode := str(payload.get("mode", ""))
	var participants: Array = payload.get("participants", [])
	var placements: Array = payload.get("placements", [])
	if mode.is_empty() or placements.is_empty():
		push_error("[CopaJeffrey] record_match_result missing mode or placements")
		return {}
	for profile_id in participants:
		_ensure_player(str(profile_id))
	var awarded: Array = []
	for row in placements:
		if not (row is Dictionary):
			continue
		var profile_id := str(row.get("profile_id", ""))
		if profile_id.is_empty():
			continue
		_ensure_player(profile_id)
		var placement := int(row.get("placement", 0))
		var points := int(row.get("points", Scoring.points_for_placement(placement)))
		if bool(row.get("dnf", false)):
			points = 0
			placement = 0
		var stats: Dictionary = player_stats[profile_id]
		stats["total_points"] = int(stats.get("total_points", 0)) + points
		stats["matches_played"] = int(stats.get("matches_played", 0)) + 1
		if placement == 1:
			stats["wins"] = int(stats.get("wins", 0)) + 1
		if placement >= 1 and placement <= 3:
			stats["podiums"] = int(stats.get("podiums", 0)) + 1
		player_stats[profile_id] = stats
		awarded.append({
			"profile_id": profile_id,
			"placement": placement,
			"points": points,
			"dnf": bool(row.get("dnf", false)),
			"total_points": int(stats.get("total_points", 0)),
		})
	games_played += 1
	var round_entry := {
		"match_id": match_id,
		"mode": mode,
		"timestamp": float(payload.get("timestamp", Time.get_unix_time_from_system())),
		"participants": participants.duplicate(true),
		"placements": awarded.duplicate(true),
	}
	round_history.append(round_entry)
	recorded_match_ids[match_id] = true
	last_recorded_result = {
		"match_id": match_id,
		"mode": mode,
		"awarded": awarded,
		"leaderboard": leaderboard(false),
	}
	return last_recorded_result.duplicate(true)


func get_player_stats(profile_id: String) -> Dictionary:
	if not player_stats.has(profile_id):
		return _empty_player_stats(profile_id)
	return player_stats[profile_id].duplicate(true)


func leaderboard(active_only: bool = true) -> Array:
	var rows: Array = []
	var active: Array[String] = []
	if active_only and JeffreyCore != null and JeffreyCore.session != null:
		active = JeffreyCore.session.active_player_ids
	for profile_id in player_stats.keys():
		if active_only and not active.has(str(profile_id)):
			continue
		var stats: Dictionary = player_stats[profile_id]
		rows.append({
			"profile_id": str(profile_id),
			"total_points": int(stats.get("total_points", 0)),
			"wins": int(stats.get("wins", 0)),
			"podiums": int(stats.get("podiums", 0)),
			"matches_played": int(stats.get("matches_played", 0)),
			"join_order": int(_join_order.get(profile_id, 9999)),
		})
	rows.sort_custom(func(a, b) -> bool:
		if int(a["total_points"]) != int(b["total_points"]):
			return int(a["total_points"]) > int(b["total_points"])
		if int(a["wins"]) != int(b["wins"]):
			return int(a["wins"]) > int(b["wins"])
		return int(a["join_order"]) < int(b["join_order"])
	)
	return rows


func recent_rounds(limit: int = 8) -> Array:
	var start := maxi(round_history.size() - limit, 0)
	var out: Array = []
	for i in range(start, round_history.size()):
		out.append(round_history[i])
	out.reverse()
	return out


func is_active() -> bool:
	return not session_id.is_empty()


func _ensure_player(profile_id: String) -> void:
	if profile_id.is_empty():
		return
	if player_stats.has(profile_id):
		return
	player_stats[profile_id] = _empty_player_stats(profile_id)
	_join_order[profile_id] = _next_join_index
	_next_join_index += 1


func _empty_player_stats(profile_id: String) -> Dictionary:
	return {
		"profile_id": profile_id,
		"total_points": 0,
		"wins": 0,
		"podiums": 0,
		"matches_played": 0,
	}


func _active_profile_ids_from_stats() -> Array[String]:
	var out: Array[String] = []
	if JeffreyCore != null and JeffreyCore.session != null:
		for profile_id in JeffreyCore.session.active_player_ids:
			out.append(profile_id)
	else:
		for profile_id in player_stats.keys():
			out.append(str(profile_id))
	return out
