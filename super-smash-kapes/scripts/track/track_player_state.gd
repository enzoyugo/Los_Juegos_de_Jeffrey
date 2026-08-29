class_name TrackPlayerState
extends RefCounted

## Per-participant Hotseat state. Fuel is never a session-global scalar.

var profile_id: String = ""
var slot: int = 1
var character_id: String = ""
var best_time: float = -1.0
var last_time: float = -1.0
var fuel_remaining: float = 0.0
var alive: bool = true
var last_dance_state: String = "none"
var last_dances_survived: int = 0
var attempt_count: int = 0
