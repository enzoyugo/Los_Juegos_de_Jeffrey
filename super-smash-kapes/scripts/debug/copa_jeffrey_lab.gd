extends Node

## Headless Copa Jeffrey scoring lab.
## Run: Godot --headless --path project res://scenes/debug/CopaJeffreyLab.tscn

const SessionScript := preload("res://scripts/core/jeffrey/copa_jeffrey_session.gd")
const ScoringScript := preload("res://scripts/core/jeffrey/copa_jeffrey_scoring.gd")

var _failures: Array[String] = []


func _ready() -> void:
	_test_scoring_table()
	_test_session_flow()
	_test_idempotency()
	_test_leaderboard()
	_test_roster_changes()
	_test_nueva_copa_reset()
	if _failures.is_empty():
		print("[COPA_JEFFREY_LAB] PASS")
	else:
		for msg in _failures:
			push_error(msg)
		print("[COPA_JEFFREY_LAB] FAIL count=%d" % _failures.size())
	get_tree().quit()


func _assert_true(condition: bool, label: String) -> void:
	if not condition:
		_failures.append(label)


func _test_scoring_table() -> void:
	_assert_true(ScoringScript.points_for_placement(1) == 5, "1st=5")
	_assert_true(ScoringScript.points_for_placement(2) == 3, "2nd=3")
	_assert_true(ScoringScript.points_for_placement(3) == 2, "3rd=2")
	_assert_true(ScoringScript.points_for_placement(4) == 1, "4th=1")
	_assert_true(ScoringScript.points_for_placement(5) == 0, "5th=0")
	var awards := ScoringScript.award_points_for_count(3)
	_assert_true(awards == [5, 3, 2], "3-player awards")


func _test_session_flow() -> void:
	var session = SessionScript.new()
	var ids: Array[String] = ["p_a", "p_b", "p_c", "p_d"]
	session.start_new("s_test", ids)
	for pid in ids:
		var stats = session.get_player_stats(pid)
		_assert_true(int(stats.get("total_points", -1)) == 0, "new player zero %s" % pid)
	var result = session.record_match_result({
		"match_id": "m1",
		"mode": "track",
		"participants": ids,
		"placements": [
			{"profile_id": "p_a", "placement": 1},
			{"profile_id": "p_b", "placement": 2},
			{"profile_id": "p_c", "placement": 3},
			{"profile_id": "p_d", "placement": 4},
		],
	})
	_assert_true(not result.is_empty(), "record ok")
	_assert_true(int(session.get_player_stats("p_a").get("total_points")) == 5, "enzo +5")
	_assert_true(int(session.get_player_stats("p_d").get("total_points")) == 1, "4th +1")
	_assert_true(session.games_played == 1, "games played")


func _test_idempotency() -> void:
	var session = SessionScript.new()
	var ids: Array[String] = ["p_a", "p_b"]
	session.start_new("s_dup", ids)
	var payload := {
		"match_id": "dup_m",
		"mode": "smash",
		"participants": ids,
		"placements": [
			{"profile_id": "p_a", "placement": 1},
			{"profile_id": "p_b", "placement": 2},
		],
	}
	var first = session.record_match_result(payload)
	var second = session.record_match_result(payload)
	_assert_true(not first.is_empty(), "first record")
	_assert_true(second.is_empty(), "duplicate blocked")
	_assert_true(int(session.get_player_stats("p_a").get("total_points")) == 5, "no double award")


func _test_leaderboard() -> void:
	var session = SessionScript.new()
	var ids: Array[String] = ["p_a", "p_b"]
	session.start_new("s_lb", ids)
	session.record_match_result({
		"match_id": "lb1",
		"mode": "smash",
		"participants": ids,
		"placements": [
			{"profile_id": "p_a", "placement": 1},
			{"profile_id": "p_b", "placement": 2},
		],
	})
	session.record_match_result({
		"match_id": "lb2",
		"mode": "track",
		"participants": ids,
		"placements": [
			{"profile_id": "p_b", "placement": 1},
			{"profile_id": "p_a", "placement": 2},
		],
	})
	var board: Array = session.leaderboard(false)
	_assert_true(board.size() == 2, "two players")
	_assert_true(int(board[0].get("total_points")) == 8, "leader 8 pts")
	_assert_true(int(board[0].get("wins")) >= 1, "wins tracked")


func _test_roster_changes() -> void:
	var session = SessionScript.new()
	var ids: Array[String] = ["p_a", "p_b"]
	session.start_new("s_roster", ids)
	session.record_match_result({
		"match_id": "r1",
		"mode": "smash",
		"participants": ids,
		"placements": [
			{"profile_id": "p_a", "placement": 1},
			{"profile_id": "p_b", "placement": 2},
		],
	})
	session.sync_roster(["p_a", "p_b", "p_c"])
	_assert_true(int(session.get_player_stats("p_c").get("total_points")) == 0, "join at zero")
	_assert_true(int(session.get_player_stats("p_a").get("total_points")) == 5, "existing kept")
	session.sync_roster(["p_a"])
	_assert_true(int(session.get_player_stats("p_b").get("total_points")) == 3, "removed player history kept")


func _test_nueva_copa_reset() -> void:
	var session = SessionScript.new()
	var ids: Array[String] = ["p_a", "p_b"]
	session.start_new("s_reset", ids)
	session.record_match_result({
		"match_id": "x1",
		"mode": "smash",
		"participants": ids,
		"placements": [
			{"profile_id": "p_a", "placement": 1},
			{"profile_id": "p_b", "placement": 2},
		],
	})
	session.reset_scores()
	for pid in ids:
		_assert_true(int(session.get_player_stats(pid).get("total_points")) == 0, "reset %s" % pid)
	_assert_true(session.round_history.is_empty(), "history cleared")
	_assert_true(session.games_played == 0, "games cleared")
