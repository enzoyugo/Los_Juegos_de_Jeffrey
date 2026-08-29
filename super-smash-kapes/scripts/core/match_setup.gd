class_name MatchSetup
extends RefCounted

var player_1_fighter_id: String = "terere"
var player_2_fighter_id: String = "jaguarete"
## Real-person profiles for session/stats. Never used as fighter identity.
var player_1_profile_id: String = ""
var player_2_profile_id: String = ""
## Canonical Smash stage id from StageCatalog.
var stage_id: String = "defensores"

func reset_defaults() -> void:
	player_1_fighter_id = "terere"
	player_2_fighter_id = "jaguarete"
	player_1_profile_id = ""
	player_2_profile_id = ""
	stage_id = "defensores"

func duplicate_setup():
	var copy = get_script().new()
	copy.player_1_fighter_id = player_1_fighter_id
	copy.player_2_fighter_id = player_2_fighter_id
	copy.player_1_profile_id = player_1_profile_id
	copy.player_2_profile_id = player_2_profile_id
	copy.stage_id = stage_id
	return copy
