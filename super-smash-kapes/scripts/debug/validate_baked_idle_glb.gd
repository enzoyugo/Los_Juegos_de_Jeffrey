extends SceneTree

const GAME_READY_GLB := "res://assets/fighters/processed/jaguarete/jaguarete_game_ready_idle.glb"

func _initialize() -> void:
	var ok := true
	if not ResourceLoader.exists(GAME_READY_GLB):
		print("FAIL missing %s" % GAME_READY_GLB)
		ok = false
		quit(1)
		return
	var packed: PackedScene = load(GAME_READY_GLB)
	if packed == null:
		print("FAIL load")
		quit(1)
		return
	var root := packed.instantiate()
	var skel := _find_skeleton(root)
	var player := _find_animation_player(root)
	print("SKELETON=%s bones=%d" % [skel != null, skel.get_bone_count() if skel else 0])
	if player == null:
		print("FAIL no AnimationPlayer")
		ok = false
	else:
		var names := player.get_animation_list()
		print("ANIMATIONS=%s" % str(names))
		var idle_name := ""
		for n in names:
			if n.to_lower().contains("idle"):
				idle_name = n
				break
		if idle_name.is_empty() and names.size() > 0:
			idle_name = names[0]
		if idle_name.is_empty():
			print("FAIL no idle clip")
			ok = false
		else:
			var anim: Animation = player.get_animation(idle_name)
			print("IDLE=%s length=%.3f tracks=%d" % [idle_name, anim.length if anim else 0.0, anim.get_track_count() if anim else 0])
			if anim == null or anim.length <= 0.0:
				print("FAIL invalid idle duration")
				ok = false
	root.free()
	print("VALIDATE_BAKED_IDLE=%s" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)


func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for c in node.get_children():
		var f := _find_skeleton(c)
		if f:
			return f
	return null


func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for c in node.get_children():
		var f := _find_animation_player(c)
		if f:
			return f
	return null
