extends SceneTree

func _initialize() -> void:
	var parent: Variant = load("res://scripts/fighters/actorcore_fighter_visual.gd")
	print("PARENT=%s" % str(parent))
	var child: Variant = load("res://fighters/terere/terere_actorcore_visual.gd")
	print("CHILD=%s" % str(child))
	quit(0 if parent != null and child != null else 1)
