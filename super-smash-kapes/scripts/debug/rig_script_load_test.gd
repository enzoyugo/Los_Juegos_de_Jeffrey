extends SceneTree

func _initialize() -> void:
	for path in [
		"res://fighters/jaguarete/jaguarete_rigged_visual.gd",
		"res://scripts/fighters/glb_fighter_visual.gd",
	]:
		var script: Variant = load(path)
		print("LOAD %s => %s" % [path, script])
		if script == null:
			print("  FAILED")
			continue
		if script is GDScript and script.can_instantiate():
			var inst = script.new()
			print("  instance=%s" % inst)
	quit()
