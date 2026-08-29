extends SceneTree

func _initialize() -> void:
	var script: GDScript = load("res://scripts/fighters/glb_fighter_visual.gd")
	print("glb script=", script)
	if script != null:
		var inst = script.new()
		print("instance=", inst)
	quit()
