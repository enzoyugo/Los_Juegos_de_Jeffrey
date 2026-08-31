extends Node

## H03: production Zombies map/player/door interaction probe.
const MAIN := preload("res://scenes/zombies/ZombiesMain.tscn")
const OUT := "E:/JeffreyAIResearch/outputs/runtime-review/jeffrey_p0_closure_v1/zombies"
var _main: Node

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	_main = MAIN.instantiate()
	add_child(_main)
	await get_tree().create_timer(2.0).timeout
	var map: Node = _main.get("_map") as Node
	var player: Node = _main.get("_player") as Node
	var door: Node = map.get("door") as Node if map != null else null
	_capture("01_door_closed.png")
	var closed := {"locked": bool(door.locked), "collision_disabled": bool(door.get("_col").disabled) if door != null and door.get("_col") != null else false}
	if player != null and player.get("game_state") != null:
		player.get("game_state").add_points(9999)
	var opened: bool = door.try_interact(player) if door != null else false
	await get_tree().process_frame
	_capture("02_door_open.png")
	var open_state := {"opened": opened, "locked": bool(door.locked), "collision_disabled": bool(door.get("_col").disabled), "mesh_visible": bool(door.get("_mesh").visible)}
	if player != null:
		player.global_position = Vector3(0.0, 0.05, 0.0)
	_capture("03_door_passed.png")
	var passable := opened and not bool(door.locked) and bool(door.get("_col").disabled)
	_main.queue_free()
	await get_tree().process_frame
	var reset_main := MAIN.instantiate()
	add_child(reset_main)
	await get_tree().create_timer(1.5).timeout
	var reset_map: Node = reset_main.get("_map") as Node
	var reset_door: Node = reset_map.get("door") as Node if reset_map != null else null
	var reset_locked := reset_door != null and bool(reset_door.get("locked"))
	reset_main.queue_free()
	var payload := {"closed": closed, "open": open_state, "passable": passable, "restart_reset_locked": reset_locked, "pass": passable and reset_locked}
	print("[P0_ZOMBIES_DOOR] %s" % JSON.stringify(payload))
	var f := FileAccess.open("E:/JeffreyAIResearch/outputs/runtime-review/jeffrey_p0_closure_v1/logs/zombies_door_harness.log", FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(payload, "\t")); f.close()
	get_tree().quit(0 if payload.pass else 1)

func _capture(name: String) -> void:
	var image := get_viewport().get_texture().get_image()
	if image != null:
		image.save_png("%s/%s" % [OUT, name])
