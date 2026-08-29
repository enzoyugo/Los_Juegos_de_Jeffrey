class_name TrackHotseatV2
extends RefCounted

## Last-place-drives Hotseat after qualification. Not round-robin.
## Fuel is remaining attempt time (seconds), per player. TrackMain does not use this.

const PHASE_QUALIFY := "qualify"
const PHASE_LAST_PLACE := "last_place"
const PHASE_DONE := "done"

var players: Array = []
var phase: String = PHASE_QUALIFY
var qualify_index: int = 0
var current_id: String = ""
var expected_time: float = 24.0
var fuel_budget: float = 66.0
var last_chance_id: String = ""
var run_live: bool = false
var result_card: String = ""


func setup(roster: Array, expected: float, fuel_mult: float = 2.75) -> void:
	players.clear()
	phase = PHASE_QUALIFY
	qualify_index = 0
	expected_time = expected
	fuel_budget = expected * fuel_mult
	last_chance_id = ""
	run_live = false
	result_card = ""
	var i := 0
	for row in roster:
		var pid := str(row.get("id", row.get("profile_id", "p%d" % i)))
		players.append({
			"id": pid,
			"name": str(row.get("name", pid)).to_upper(),
			"color": row.get("color", Color(0.9, 0.7, 0.2)),
			"best_ms": -1,
			"last_ms": -1,
			"best_splits": [],
			"last_splits": [],
			"run_splits": [],
			"fuel": fuel_budget,
			"alive": true,
			"used_ultima": false,
			"order": i,
		})
		i += 1
	current_id = str(players[0]["id"]) if not players.is_empty() else ""


func current() -> Dictionary:
	return _by_id(current_id)


func ranking() -> Array:
	var rows: Array = players.duplicate()
	rows.sort_custom(func(a, b) -> bool:
		return _rank_less(a, b)
	)
	return rows


func last_place_id() -> String:
	var last_id := ""
	var worst := -1
	var worst_order := -1
	for p in players:
		if not bool(p["alive"]):
			continue
		var ms: int = int(p["best_ms"])
		if ms < 0:
			if last_id.is_empty():
				last_id = str(p["id"])
			continue
		if worst < 0 or ms > worst or (ms == worst and int(p["order"]) > worst_order):
			worst = ms
			worst_order = int(p["order"])
			last_id = str(p["id"])
	return last_id


func begin_run() -> Dictionary:
	var p := current()
	if p.is_empty():
		return {"ok": false}
	run_live = true
	p["run_splits"] = []
	var ultima := float(p["fuel"]) <= 0.0 or last_chance_id == str(p["id"])
	if ultima:
		p["used_ultima"] = true
		last_chance_id = str(p["id"])
	return {"ok": true, "ultima": ultima, "id": str(p["id"]), "name": str(p["name"])}


func tick_fuel(delta: float) -> void:
	if not run_live:
		return
	var p := current()
	if p.is_empty() or bool(p["used_ultima"]):
		return
	p["fuel"] = maxf(float(p["fuel"]) - delta, 0.0)
	if float(p["fuel"]) <= 0.0:
		last_chance_id = str(p["id"])
		p["used_ultima"] = true


func record_split(elapsed_sec: float) -> Dictionary:
	var p := current()
	if p.is_empty() or not run_live:
		return {"ok": false}
	var splits: Array = p["run_splits"]
	splits.append(float(elapsed_sec))
	p["run_splits"] = splits
	return {"ok": true, "index": splits.size() - 1, "t": float(elapsed_sec)}


func target_split_sec(cp_index: int) -> float:
	var tgt := _target_player()
	if tgt.is_empty():
		return -1.0
	var splits: Array = tgt.get("best_splits", [])
	if cp_index < 0 or cp_index >= splits.size():
		return -1.0
	return float(splits[cp_index])


func target_final_ms() -> int:
	var tgt := _target_player()
	if tgt.is_empty():
		return -1
	return int(tgt.get("best_ms", -1))


func splits_valid(p: Dictionary, final_sec: float, cp_count: int) -> bool:
	var splits: Array = p.get("run_splits", [])
	if splits.size() != cp_count:
		return false
	var prev := -0.0001
	for t in splits:
		if float(t) < prev:
			return false
		prev = float(t)
	if splits.is_empty():
		return false
	return float(splits[splits.size() - 1]) <= final_sec + 0.05


func _target_player() -> Dictionary:
	if phase == PHASE_QUALIFY:
		return {}
	var mine := current()
	var worst_id := last_place_id()
	var rows: Array = ranking()
	if mine.is_empty() or rows.is_empty():
		return {}
	if str(mine.get("id", "")) == worst_id and rows.size() >= 2:
		return rows[rows.size() - 2]
	for row in rows:
		if str(row.get("id", "")) == worst_id:
			return row
	return {}


func record_finish(time_sec: float) -> Dictionary:
	run_live = false
	var p := current()
	if p.is_empty():
		return {"ok": false}
	var ms := _ms(time_sec)
	p["last_ms"] = ms
	var prev_rank := _rank_of(str(p["id"]))
	if int(p["best_ms"]) < 0 or ms < int(p["best_ms"]):
		p["best_ms"] = ms
		p["best_splits"] = (p["run_splits"] as Array).duplicate()
	p["last_splits"] = (p["run_splits"] as Array).duplicate()
	var new_rank := _rank_of(str(p["id"]))
	var improved := new_rank < prev_rank
	if phase == PHASE_QUALIFY:
		qualify_index += 1
		if qualify_index >= players.size():
			phase = PHASE_LAST_PLACE
	_retire_if_needed(p)
	_pick_next()
	var nxt := current()
	result_card = "%s\n%s\n\n%s AL %d°\n\n%s, TE TOCA" % [
		str(p["name"]),
		format_ms(ms),
		"SUBE" if improved else "SIGUE",
		new_rank,
		str(nxt.get("name", "")),
	]
	return {
		"ok": true,
		"id": str(p["id"]),
		"name": str(p["name"]),
		"color": p.get("color", Color.WHITE),
		"prev_rank": prev_rank,
		"rank": new_rank,
		"improved": improved,
		"card": result_card,
		"next_id": current_id,
		"phase": phase,
		"splits": p.get("last_splits", []),
	}


static func format_ms(ms: int) -> String:
	if ms < 0:
		return "--:--.---"
	var sec := float(ms) / 1000.0
	var m := int(sec / 60.0)
	var s := sec - float(m * 60)
	return "%02d:%06.3f" % [m, s]


func _pick_next() -> void:
	if phase == PHASE_QUALIFY:
		if qualify_index < players.size():
			current_id = str(players[qualify_index]["id"])
			return
		phase = PHASE_LAST_PLACE
	var cand := last_place_id()
	if cand.is_empty() or not _can_drive(cand):
		phase = PHASE_DONE
		current_id = ""
		return
	current_id = cand


func _can_drive(pid: String) -> bool:
	var p := _by_id(pid)
	if p.is_empty() or not bool(p["alive"]):
		return false
	if float(p["fuel"]) > 0.0:
		return true
	return not bool(p["used_ultima"])


func _retire_if_needed(p: Dictionary) -> void:
	if float(p["fuel"]) > 0.0:
		return
	if bool(p["used_ultima"]) and str(p["id"]) == last_place_id():
		p["alive"] = false


func _rank_of(pid: String) -> int:
	var n := 1
	for row in ranking():
		if str(row["id"]) == pid:
			return n
		n += 1
	return n


func _rank_less(a, b) -> bool:
	var ta: int = int(a["best_ms"])
	var tb: int = int(b["best_ms"])
	if ta < 0 and tb < 0:
		return int(a["order"]) < int(b["order"])
	if ta < 0:
		return false
	if tb < 0:
		return true
	if ta == tb:
		return int(a["order"]) < int(b["order"])
	return ta < tb


func _by_id(pid: String) -> Dictionary:
	for p in players:
		if str(p["id"]) == pid:
			return p
	return {}


func _ms(time_sec: float) -> int:
	return int(round(time_sec * 1000.0))
