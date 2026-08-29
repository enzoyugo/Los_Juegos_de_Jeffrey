class_name ZombiesInteractable
extends StaticBody3D

## Generic interact target. Ray mask uses LAYER_INTERACT (16).
## Door also stays on world layer 1 so it blocks player and zombies.

func get_prompt() -> String:
	return ""


func try_interact(_player: Node) -> bool:
	return false


func is_usable() -> bool:
	return true
