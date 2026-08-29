extends Node

func _ready() -> void:
	var glb: Script = load("res://scripts/fighters/glb_fighter_visual.gd")
	var actor: Script = load("res://scripts/fighters/actorcore_fighter_visual.gd")
	var terere: Script = load("res://fighters/terere/terere_actorcore_visual.gd")
	var candidate: Script = load("res://fighters/terere/terere_semantic_v2_battle_candidate.gd")
	print("glb=", glb, " can=", glb.can_instantiate() if glb else false)
	print("actor=", actor, " can=", actor.can_instantiate() if actor else false)
	print("terere=", terere, " can=", terere.can_instantiate() if terere else false)
	print("candidate=", candidate, " can=", candidate.can_instantiate() if candidate else false)
	get_tree().quit(0)
