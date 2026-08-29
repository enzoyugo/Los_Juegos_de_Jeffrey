class_name ZombiesGameState
extends RefCounted

signal points_changed(value: int)
signal points_gained(amount: int)
signal kills_changed(value: int)
signal game_over_changed

var points: int = 0
var kills: int = 0
var round_number: int = 0
var game_over: bool = false
var _pacing_marks: Dictionary = {}


func add_points(amount: int) -> void:
	if amount == 0:
		return
	points = maxi(points + amount, 0)
	if amount > 0:
		points_gained.emit(amount)
	points_changed.emit(points)
	_log_pacing()


func _log_pacing() -> void:
	for mark in [750, 1000, 1250, 1500]:
		if points >= int(mark) and not bool(_pacing_marks.get(mark, false)):
			_pacing_marks[mark] = true
			print("[ZOMBIES_PACING] mark=%d points=%d round=%d" % [int(mark), points, round_number])


func spend(amount: int) -> bool:
	if amount < 0 or points < amount:
		return false
	points -= amount
	points_changed.emit(points)
	return true


func add_kill() -> void:
	kills += 1
	kills_changed.emit(kills)


func mark_game_over() -> void:
	if game_over:
		return
	game_over = true
	game_over_changed.emit()


func reset() -> void:
	points = 0
	kills = 0
	round_number = 0
	game_over = false
	_pacing_marks.clear()
	points_changed.emit(points)
	kills_changed.emit(kills)
