class_name StatsEventBus
extends RefCounted

signal event_recorded(event_id: String, payload: Dictionary)

const MATCH_STARTED := "match_started"
const MATCH_FINISHED := "match_finished"
const PLAYER_WON := "player_won"
const PLAYER_LOST := "player_lost"
const KO_REGISTERED := "ko_registered"
const RACING_ELIMINATED := "racing_eliminated"
const LAST_DANCE_STARTED := "last_dance_started"
const LAST_DANCE_SURVIVED := "last_dance_survived"
const ZOMBIE_KILLED := "zombie_killed"
const PLAYER_REVIVED := "player_revived"
const WAVE_COMPLETED := "wave_completed"


func record(event_id: String, payload: Dictionary = {}) -> void:
	if event_id.is_empty():
		push_error("[StatsEventBus] refused empty event_id")
		return
	event_recorded.emit(event_id, payload.duplicate(true))
