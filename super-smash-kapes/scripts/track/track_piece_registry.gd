class_name TrackPieceRegistry
extends RefCounted

## piece_id -> generated GLB / sidecar metadata. Not a gameplay ruleset.

const KIT_PATH := "res://data/track/modules/track_kit_v1.json"
const CORE_DIR := "res://assets/track/modules/generated/core/"
const CORE_DIR_V8_15M := "res://assets/track/processed/kit_v8_15m/"
const PIECE_SCENE := "res://scenes/track/modules/TrackPiece.tscn"
const ASPHALT := "res://assets/track/materials/track_asphalt_v1.tres"
const SHOULDER := "res://assets/track/materials/track_shoulder_v1.tres"
const GUARDRAIL := "res://assets/track/materials/track_guardrail_v1.tres"
const MARKER := "res://assets/track/materials/track_marker_v1.tres"
const BOOST := "res://assets/track/materials/track_boost_v1.tres"

const PILOT_IDS := ["start", "straight_medium", "curve_l_45", "curve_r_45", "finish"]
const EXTENDED_PHYSICS_IDS := ["ramp_small", "jump_small", "boost_straight", "landing_straight_long"]
const CLEAN_GAP_IDS := ["ramp_takeoff", "gap_logical"]

const FILENAMES := {
	"start": "track_start_v1.glb",
	"straight_medium": "track_straight_medium_v1.glb",
	"curve_l_45": "track_curve_l_45_v1.glb",
	"curve_r_45": "track_curve_r_45_v1.glb",
	"finish": "track_finish_v1.glb",
	"ramp_small": "track_ramp_small_v1.glb",
	"jump_small": "track_jump_small_v1.glb",
	"boost_straight": "track_boost_straight_v1.glb",
	"landing_straight_long": "track_landing_straight_long_v1.glb",
	"ramp_takeoff": "track_ramp_takeoff_v1.glb",
	"gap_logical": "track_gap_logical_v1.glb",
	"straight_short": "track_straight_short_v1.glb",
	"straight_long": "track_straight_long_v1.glb",
	"curve_l_90": "track_curve_l_90_v1.glb",
	"curve_r_90": "track_curve_r_90_v1.glb",
	"chicane_lr": "track_chicane_lr_v1.glb",
	"chicane_rl": "track_chicane_rl_v1.glb",
	"slope_up_gentle": "track_slope_up_gentle_v1.glb",
	"slope_down_gentle": "track_slope_down_gentle_v1.glb",
	"crest_gentle": "track_crest_gentle_v1.glb",
	"finish_runoff": "track_finish_runoff_v1.glb",
}


static func kit() -> Dictionary:
	if not FileAccess.file_exists(KIT_PATH):
		return {}
	var txt := FileAccess.get_file_as_string(KIT_PATH)
	var parsed = JSON.parse_string(txt)
	if parsed is Dictionary:
		return parsed
	return {}


static func spec(piece_id: String) -> Dictionary:
	for item in kit().get("pieces", []):
		if str(item.get("id", "")) == piece_id:
			return item
	return {}


static func glb_path(piece_id: String, kit_dir: String = "") -> String:
	var root := kit_dir if not kit_dir.is_empty() else CORE_DIR
	return root + str(FILENAMES.get(piece_id, "track_%s_v1.glb" % piece_id))


static func meta_path(piece_id: String, kit_dir: String = "") -> String:
	var path := glb_path(piece_id, kit_dir)
	return path.substr(0, path.length() - 4) + ".json"


static func meta(piece_id: String, kit_dir: String = "") -> Dictionary:
	var path := meta_path(piece_id, kit_dir)
	if not FileAccess.file_exists(path) and not kit_dir.is_empty():
		path = meta_path(piece_id, CORE_DIR)
	if not FileAccess.file_exists(path):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary:
		return parsed
	return {}


static func shared_material_paths() -> PackedStringArray:
	return PackedStringArray([ASPHALT, SHOULDER, GUARDRAIL, MARKER, BOOST])
