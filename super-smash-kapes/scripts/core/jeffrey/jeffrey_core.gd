extends Node

const PersistenceScript := preload("res://scripts/core/jeffrey/jeffrey_persistence.gd")
const ProfileStoreScript := preload("res://scripts/core/jeffrey/player_profile_store.gd")
const SessionScript := preload("res://scripts/core/jeffrey/active_session.gd")
const ModeRegistryScript := preload("res://scripts/core/jeffrey/game_mode_registry.gd")
const CharacterRegistryScript := preload("res://scripts/core/jeffrey/character_registry.gd")
const StatsBusScript := preload("res://scripts/core/jeffrey/stats_event_bus.gd")
const CopaSessionScript := preload("res://scripts/core/jeffrey/copa_jeffrey_session.gd")
const CopaScoringScript := preload("res://scripts/core/jeffrey/copa_jeffrey_scoring.gd")

var persistence
var profiles
var session
var copa
var modes
var characters
var stats
var global_stats: Dictionary = {}
var settings: Dictionary = {}
var last_load_recovered: bool = false

## Smash V1 adapter: playground is 2-player only even though the registry
## advertises max_players = 4 for future expansion.
const SMASH_ADAPTER_PLAYERS := 2


func _ready() -> void:
	persistence = PersistenceScript.new()
	profiles = ProfileStoreScript.new()
	session = SessionScript.new()
	copa = CopaSessionScript.new()
	modes = ModeRegistryScript.new()
	characters = CharacterRegistryScript.new()
	stats = StatsBusScript.new()
	_load_save()
	var Probe := load("res://scripts/debug/jeffrey_resource_probe.gd")
	if Probe != null:
		Probe.boot_line()


func _load_save() -> void:
	var payload: Dictionary = persistence.load_into(profiles)
	global_stats = payload.get("global_stats", {})
	settings = payload.get("settings", {})
	last_load_recovered = bool(payload.get("recovered_from_corruption", false))
	if last_load_recovered:
		save()


func save() -> void:
	if not persistence.save_from(profiles, global_stats, settings):
		push_error("[JeffreyCore] save failed")


func apply_logon_roster(selected_ids: Array[String], is_new_session: bool) -> void:
	var was_empty: bool = session.session_id.is_empty()
	session.set_roster(selected_ids)
	if was_empty or is_new_session or not copa.is_active():
		copa.start_new(session.session_id, selected_ids)
	else:
		copa.sync_roster(selected_ids)
	var now := Time.get_unix_time_from_system()
	var names: Array[String] = []
	for profile_id in selected_ids:
		var profile = profiles.get_profile(profile_id)
		if profile == null:
			continue
		profile.last_played_at = now
		if was_empty or is_new_session:
			profile.sessions_played += 1
		names.append(profile.display_name)
	print("[SESSION] Active players: %s" % ", ".join(names))
	save()


func start_new_copa() -> void:
	if session.session_id.is_empty():
		session.ensure_started()
	copa.start_new(session.session_id, session.active_player_ids)


func generate_copa_match_id(mode: String) -> String:
	if session.session_id.is_empty():
		session.ensure_started()
	if not copa.is_active():
		copa.start_new(session.session_id, session.active_player_ids)
	return copa.generate_match_id(mode)


func record_match_result(payload: Dictionary) -> Dictionary:
	return copa.record_match_result(payload)


func record_smash_copa_match(match_id: String, winner_id: int, match_setup) -> Dictionary:
	if match_id.is_empty() or match_setup == null:
		return {}
	var participants: Array = []
	var placements: Array = []
	var p1 := str(match_setup.player_1_profile_id)
	var p2 := str(match_setup.player_2_profile_id)
	if not p1.is_empty():
		participants.append(p1)
	if not p2.is_empty() and p2 != p1:
		participants.append(p2)
	if p1.is_empty() or p2.is_empty():
		return {}
	placements.append({
		"profile_id": p1 if winner_id == 1 else p2,
		"placement": 1,
	})
	placements.append({
		"profile_id": p2 if winner_id == 1 else p1,
		"placement": 2,
	})
	return record_match_result({
		"match_id": match_id,
		"mode": ModeRegistryScript.MODE_SMASH,
		"participants": participants,
		"placements": placements,
	})


func record_track_copa_match(match_id: String, turn_manager) -> Dictionary:
	if match_id.is_empty() or turn_manager == null:
		return {}
	var participants: Array = []
	for row in turn_manager.participants:
		var pid := str(row.get("profile_id", ""))
		if not pid.is_empty():
			participants.append(pid)
	var placements: Array = []
	var rank := 1
	for row in turn_manager.rank_list():
		var pid := str(row.get("profile_id", ""))
		var best := float(row.get("best", -1.0))
		if pid.is_empty():
			continue
		if best < 0.0:
			placements.append({"profile_id": pid, "placement": 0, "dnf": true, "points": 0})
		else:
			placements.append({"profile_id": pid, "placement": rank})
			rank += 1
	if placements.is_empty():
		return {}
	return record_match_result({
		"match_id": match_id,
		"mode": ModeRegistryScript.MODE_RACING,
		"participants": participants,
		"placements": placements,
	})


func record_zombies_copa_match(match_id: String, roster: Array, team_cleared: bool) -> Dictionary:
	if match_id.is_empty():
		return {}
	var participants: Array = []
	for row in roster:
		var pid := str(row.get("profile_id", ""))
		if not pid.is_empty():
			participants.append(pid)
	if participants.is_empty():
		return {}
	var placements: Array = []
	if team_cleared:
		for pid in participants:
			placements.append({"profile_id": pid, "placement": 0, "points": 3})
	else:
		for pid in participants:
			placements.append({"profile_id": pid, "placement": 0, "dnf": true, "points": 0})
	return record_match_result({
		"match_id": match_id,
		"mode": ModeRegistryScript.MODE_ZOMBIES,
		"participants": participants,
		"placements": placements,
	})


func record_smash_match(winner_id: int, summary: Dictionary, match_setup) -> void:
	stats.record(StatsBusScript.MATCH_FINISHED, {
		"mode": ModeRegistryScript.MODE_SMASH,
		"winner_id": winner_id,
		"summary": summary.duplicate(true),
	})
	global_stats["smash_matches"] = int(global_stats.get("smash_matches", 0)) + 1
	if match_setup == null:
		save()
		return
	_apply_smash_profile_result(match_setup.player_1_profile_id, winner_id == 1, 1, summary)
	_apply_smash_profile_result(match_setup.player_2_profile_id, winner_id == 2, 2, summary)
	save()


func _apply_smash_profile_result(profile_id: String, won: bool, slot: int, summary: Dictionary) -> void:
	if profile_id.is_empty():
		return
	var profile = profiles.get_profile(profile_id)
	if profile == null:
		return
	var smash: Dictionary = profile.smash_stats
	smash["matches_played"] = int(smash.get("matches_played", 0)) + 1
	if won:
		smash["wins"] = int(smash.get("wins", 0)) + 1
		stats.record(StatsBusScript.PLAYER_WON, {"profile_id": profile_id, "slot": slot})
	else:
		smash["losses"] = int(smash.get("losses", 0)) + 1
		stats.record(StatsBusScript.PLAYER_LOST, {"profile_id": profile_id, "slot": slot})
	var slot_stats = summary.get(slot, {})
	if slot_stats is Dictionary:
		smash["kos"] = int(smash.get("kos", 0)) + int(slot_stats.get("kos", 0))
		smash["deaths"] = int(smash.get("deaths", 0)) + int(slot_stats.get("falls", 0))
		if int(slot_stats.get("kos", 0)) > 0:
			stats.record(StatsBusScript.KO_REGISTERED, {"profile_id": profile_id, "count": slot_stats.get("kos", 0)})
	profile.smash_stats = smash
