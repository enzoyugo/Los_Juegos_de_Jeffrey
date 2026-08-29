class_name TrackTurnManager
extends RefCounted

## Hotseat owner. Fuel, times, Last Dance, and rank are per profile_id.

const Config := preload("res://scripts/track/track_config.gd")
const StateScript := preload("res://scripts/track/track_player_state.gd")

var participants: Array = []
var player_states: Dictionary = {}
var alive: Array[String] = []
var eliminated: Array[String] = []
var current_index: int = 0
var round_number: int = 1
var best_times: Dictionary = {}
var last_times: Dictionary = {}
var fuel: Dictionary = {}
var last_dance: Dictionary = {}
var expected_time: float = 20.0


func setup(roster: Array, expected: float) -> void:
	participants = roster.duplicate(true)
	player_states.clear()
	alive.clear()
	eliminated.clear()
	best_times.clear()
	last_times.clear()
	fuel.clear()
	last_dance.clear()
	expected_time = expected
	current_index = 0
	round_number = 1
	var budget := Config.initial_fuel(expected)
	for row in participants:
		var pid := str(row.get("profile_id", ""))
		if pid.is_empty():
			continue
		var state = StateScript.new()
		state.profile_id = pid
		state.slot = int(row.get("player_slot", alive.size() + 1))
		state.character_id = str(row.get("character_id", ""))
		state.fuel_remaining = budget
		state.alive = true
		player_states[pid] = state
		alive.append(pid)
		_publish(pid)


func current_profile_id() -> String:
	if alive.is_empty():
		return ""
	if current_index < 0 or current_index >= alive.size():
		current_index = 0
	return alive[current_index]


func current_row() -> Dictionary:
	var pid := current_profile_id()
	for row in participants:
		if str(row.get("profile_id", "")) == pid:
			return row
	return {}


func current_state():
	return player_states.get(current_profile_id(), null)


func rank_list() -> Array:
	_ingest()
	var rows: Array = []
	for pid in alive:
		rows.append({"profile_id": pid, "best": float(best_times.get(pid, -1.0)), "alive": true})
	for pid in eliminated:
		rows.append({"profile_id": pid, "best": float(best_times.get(pid, -1.0)), "alive": false})
	rows.sort_custom(func(a, b) -> bool:
		return _rank_less(a, b)
	)
	return rows


func alive_rank(pid: String) -> int:
	var rows: Array = []
	for other in alive:
		rows.append({"profile_id": other, "best": float(best_times.get(other, -1.0)), "alive": true})
	rows.sort_custom(func(a, b) -> bool:
		return _rank_less(a, b)
	)
	var rank := 1
	for row in rows:
		if str(row["profile_id"]) == pid:
			return rank
		rank += 1
	return rank


func consume_fuel(pid: String, dt: float) -> void:
	_ingest()
	if not player_states.has(pid):
		return
	var state = player_states[pid]
	if str(state.last_dance_state) == "active":
		_publish(pid)
		return
	state.fuel_remaining = maxf(state.fuel_remaining - dt, 0.0)
	_publish(pid)


func begin_turn() -> Dictionary:
	_ingest()
	var pid := current_profile_id()
	var state_name := "racing"
	if pid.is_empty():
		return {"profile_id": "", "state": "done"}
	var state = player_states.get(pid, null)
	if state != null:
		state.attempt_count += 1
		if state.fuel_remaining <= 0.0:
			state.last_dance_state = "active"
			state_name = "last_dance"
	_publish(pid)
	return {"profile_id": pid, "state": state_name}


func record_finish(pid: String, time_sec: float) -> String:
	_ingest()
	if not player_states.has(pid):
		return "ok"
	var state = player_states[pid]
	var previous_rank := alive_rank(pid)
	state.last_time = time_sec
	if state.best_time < 0.0 or time_sec < state.best_time:
		state.best_time = time_sec
	_publish(pid)
	if str(state.last_dance_state) != "active":
		return "ok"
	var new_rank := alive_rank(pid)
	if _overtook_someone(pid, previous_rank, new_rank):
		state.last_dance_state = "survived"
		state.last_dances_survived += 1
		_publish(pid)
		return "survived"
	_eliminate(pid)
	return "eliminated"


func fail_last_dance(pid: String) -> void:
	_ingest()
	if not player_states.has(pid):
		return
	if str(player_states[pid].last_dance_state) != "active":
		return
	_eliminate(pid)


func surrender(pid: String) -> void:
	if not player_states.has(pid):
		_ingest()
	if not player_states.has(pid):
		return
	if str(player_states[pid].last_dance_state) == "active":
		fail_last_dance(pid)


func advance() -> void:
	if alive.is_empty():
		return
	current_index += 1
	if current_index >= alive.size():
		current_index = 0
		round_number += 1


func session_over() -> bool:
	return alive.size() <= 1 and participants.size() > 1 or alive.is_empty()


func _overtook_someone(pid: String, previous_rank: int, new_rank: int) -> bool:
	## Survival = rank improved. Exact tie does not count as a pass.
	if pid.is_empty():
		return false
	return new_rank < previous_rank


func _eliminate(pid: String) -> void:
	var state = player_states.get(pid, null)
	if state != null:
		state.alive = false
		state.last_dance_state = "eliminated"
	if not eliminated.has(pid):
		eliminated.append(pid)
	alive.erase(pid)
	if current_index >= alive.size():
		current_index = 0
	_publish(pid)


func _rank_less(a: Dictionary, b: Dictionary) -> bool:
	var ta := float(a["best"])
	var tb := float(b["best"])
	if ta < 0.0 and tb < 0.0:
		return str(a["profile_id"]) < str(b["profile_id"])
	if ta < 0.0:
		return false
	if tb < 0.0:
		return true
	if ta == tb:
		return str(a["profile_id"]) < str(b["profile_id"])
	return ta < tb


func _ingest() -> void:
	for pid in player_states.keys():
		var state = player_states[pid]
		if fuel.has(pid):
			state.fuel_remaining = float(fuel[pid])
		if best_times.has(pid):
			state.best_time = float(best_times[pid])
		if last_times.has(pid):
			state.last_time = float(last_times[pid])
		if last_dance.has(pid):
			state.last_dance_state = str(last_dance[pid])


func _publish(pid: String) -> void:
	if not player_states.has(pid):
		return
	var state = player_states[pid]
	fuel[pid] = state.fuel_remaining
	best_times[pid] = state.best_time
	last_times[pid] = state.last_time
	last_dance[pid] = state.last_dance_state
