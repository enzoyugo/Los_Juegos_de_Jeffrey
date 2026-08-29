extends Node3D

## Isolated observational KO/respawn lab.
## Places P1 into the existing blast-zone path. Does not decrement stocks itself.
## Does not change damage, stocks, knockback, blast zones, or respawn delay.

const PLAYGROUND := preload("res://scenes/core/M0Playground.tscn")
const BLAST_X := 21.0
const TRIGGER_DELAY := 0.45

var jeffrey_ko_observation: Dictionary = {}
var jeffrey_ko_trace: Array = []
var _playground: Node3D
var _triggered := false
var _before_stocks: int = -1
var _elapsed := 0.0
var _saw_ko := false
var _saw_respawn := false


func _ready() -> void:
	_playground = PLAYGROUND.instantiate()
	_playground.name = "M0Playground"
	add_child(_playground)
	_capture("before_KO")


func _physics_process(delta: float) -> void:
	_elapsed += delta
	if not _triggered and _elapsed >= TRIGGER_DELAY:
		var fighter := _p1()
		if fighter != null:
			_before_stocks = int(fighter.stocks)
			_capture("before_KO")
			fighter.global_position.x = BLAST_X
			_triggered = true
	if _triggered:
		var fighter := _p1()
		if fighter != null:
			if fighter.state == Fighter.FighterState.DEAD and not _saw_ko:
				_saw_ko = true
				_capture("KO")
				_capture("post_stock")
			if _saw_ko and _respawn_pending() and str(jeffrey_ko_observation.get("phase")) != "respawn_pending":
				_capture("respawn_pending")
			if _saw_ko and fighter.state != Fighter.FighterState.DEAD and not _saw_respawn:
				_saw_respawn = true
				_capture("respawned")


func _p1() -> Node:
	if _playground == null:
		return null
	return _playground.get_node_or_null("FighterManager/Fighter")


func _respawn_pending() -> bool:
	if _playground == null:
		return false
	var timers: Variant = _playground.get("respawn_timers")
	if typeof(timers) != TYPE_DICTIONARY:
		return false
	return timers.has(1)


func _capture(phase: String) -> void:
	var fighter := _p1()
	var pos: Variant = "UNAVAILABLE"
	var vel: Variant = "UNAVAILABLE"
	var stocks: Variant = "UNAVAILABLE"
	var damage: Variant = "UNAVAILABLE"
	var state: Variant = "UNAVAILABLE"
	var invuln: Variant = "UNAVAILABLE"
	if fighter != null:
		var gp: Vector3 = fighter.global_position
		pos = [gp.x, gp.y, gp.z]
		var v: Vector3 = fighter.velocity
		vel = [v.x, v.y, v.z]
		stocks = fighter.stocks
		damage = fighter.damage_percent
		state = fighter.state
		invuln = fighter.invulnerability_time
	var match_phase: Variant = "UNAVAILABLE"
	if _playground != null:
		var match_state: Variant = _playground.get("jeffrey_match_debug_state")
		if typeof(match_state) == TYPE_DICTIONARY:
			match_phase = match_state.get("match_phase", "UNAVAILABLE")
	var row := {
		"phase": phase,
		"player_slot": 1,
		"stocks": stocks,
		"damage": damage,
		"position": pos,
		"velocity": vel,
		"state": state,
		"invulnerability": invuln,
		"respawn_pending": _respawn_pending(),
		"match_phase": match_phase,
		"before_stocks": _before_stocks,
		"elapsed": _elapsed,
		"mutating": false,
	}
	jeffrey_ko_trace.append(row)
	jeffrey_ko_observation = row
