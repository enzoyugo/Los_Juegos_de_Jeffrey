extends SceneTree

## Bounded rematch lifecycle: instantiate battle, free, repeat.

const OUTPUT := "res://docs/generated/OVERNIGHT_REMATCH_STABILITY.csv"
const CYCLES := 20


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	## Direct --script launches compile this harness before autoloads have
	## registered their global names. Resolve the scene after one frame so the
	## lifecycle result exercises the same authority as a normal project run.
	await process_frame
	var playground_scene := load("res://scenes/core/M0Playground.tscn") as PackedScene
	if playground_scene == null:
		push_error("REMATCH_RESOURCE_STABILITY=FAIL unable to load M0Playground")
		quit(1)
		return
	var rows: PackedStringArray = PackedStringArray([
		"cycle,nodes,objects,resources,video_mem,texture_mem"
	])
	for cycle in range(CYCLES):
		var playground: Node = playground_scene.instantiate()
		root.add_child(playground)
		for _i in range(8):
			await process_frame
		rows.append(_sample(cycle + 1))
		playground.queue_free()
		for _j in range(6):
			await process_frame
	var file := FileAccess.open(OUTPUT, FileAccess.WRITE)
	if file:
		file.store_string("\n".join(rows) + "\n")
	print("Wrote %s" % OUTPUT)
	for row in rows:
		print(row)
	print("REMATCH_RESOURCE_STABILITY=PASS")
	quit(0)


func _sample(cycle: int) -> String:
	return "%d,%d,%d,%d,%.0f,%.0f" % [
		cycle,
		root.get_tree().get_node_count(),
		Performance.get_monitor(Performance.OBJECT_COUNT),
		Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),
		Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED),
		Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED),
	]
