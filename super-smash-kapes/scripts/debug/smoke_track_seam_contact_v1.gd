extends Node3D

const Assembler := preload("res://scripts/track/track_kit_assembler.gd")
const Registry := preload("res://scripts/track/track_piece_registry.gd")
const Inspector := preload("res://scripts/track/track_seam_contact_inspector.gd")

const SEQ := [
	"start",
	"straight_medium",
	"curve_l_45",
	"straight_short",
	"curve_r_90",
	"chicane_rl",
	"straight_short",
	"curve_r_45",
	"straight_long",
	"finish",
]


func _ready() -> void:
	var built: Dictionary = Assembler.assemble(self, SEQ, Registry.CORE_DIR_V8_15M, true)
	var pieces: Array = built["pieces"]
	for _i in 8:
		await get_tree().physics_frame
	var report: Dictionary = Inspector.inspect(pieces, 7.5)
	var last_id := ""
	if pieces.size() > 0:
		last_id = str(pieces[pieces.size() - 1].piece_id)
	print("[TRACK_SEAM_SMOKE] last=%s runoff=%s ok=%s" % [last_id, str(last_id == "finish_runoff"), str(report.get("ok", false))])
	get_tree().quit(0 if bool(report.get("ok", false)) and last_id == "finish_runoff" else 1)
