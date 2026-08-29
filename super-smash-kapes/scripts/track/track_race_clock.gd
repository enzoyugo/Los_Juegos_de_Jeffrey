class_name TrackRaceClock
extends RefCounted

## One time origin for input unlock, timer, fuel, and ghost playback.

const STATE_PREPARE := "prepare"
const STATE_COUNTDOWN := "countdown"
const STATE_ACTIVE := "active"
const STATE_FINISHED := "finished"

var state: String = STATE_PREPARE
var elapsed: float = 0.0
var countdown_left: float = 0.0


func reset() -> void:
	state = STATE_PREPARE
	elapsed = 0.0
	countdown_left = 0.0


func begin_countdown(seconds: float) -> void:
	state = STATE_COUNTDOWN
	countdown_left = maxf(seconds, 0.0)
	elapsed = 0.0


func begin_active() -> void:
	state = STATE_ACTIVE
	elapsed = 0.0
	countdown_left = 0.0


func finish() -> void:
	state = STATE_FINISHED


func is_active() -> bool:
	return state == STATE_ACTIVE


func is_countdown() -> bool:
	return state == STATE_COUNTDOWN


func tick(delta: float) -> String:
	if state == STATE_COUNTDOWN:
		countdown_left -= delta
		if countdown_left <= 0.0:
			begin_active()
			return "started"
		return ""
	if state == STATE_ACTIVE:
		elapsed += delta
	return ""
