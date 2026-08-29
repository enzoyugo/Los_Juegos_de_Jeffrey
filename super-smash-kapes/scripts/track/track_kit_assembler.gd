class_name TrackKitAssembler
extends RefCounted

const PIECE_SCENE := "res://scenes/track/modules/TrackPiece.tscn"


static func assemble(parent: Node, sequence: Array, kit_dir: String = "", append_runoff: bool = false) -> Dictionary:
	var packed: PackedScene = load(PIECE_SCENE) as PackedScene
	var pieces: Array = []
	var target := Transform3D.IDENTITY
	if packed == null:
		return {"pieces": pieces, "spawn": Transform3D(Basis.IDENTITY, Vector3(0, 1.15, -2.6))}
	var ids: Array = []
	for raw_id in sequence:
		ids.append(str(raw_id))
	if append_runoff and ids.size() > 0 and str(ids[ids.size() - 1]) == "finish":
		ids.append("finish_runoff")
	var inst := 0
	for raw_id in ids:
		var piece = packed.instantiate()
		piece.piece_id = str(raw_id)
		piece.kit_dir = kit_dir
		piece.set_meta("track_piece_instance", inst)
		parent.add_child(piece)
		piece.align_entry_to(target)
		pieces.append(piece)
		target = piece.exit_global()
		inst += 1
	var spawn := Transform3D(Basis.IDENTITY, Vector3(0.0, 1.15, -2.6))
	if pieces.size() > 0 and pieces[0].player_spawn != null:
		spawn = pieces[0].player_spawn.global_transform
	return {"pieces": pieces, "spawn": spawn}
