extends Node

## Non-authoritative Smash content expansion lab.
## Prints roster/stage inventory and optionally boots a playground with env overrides.

const FIGHTER_CATALOG := preload("res://scripts/fighters/fighter_catalog.gd")
const STAGE_CATALOG := preload("res://scripts/stages/stage_catalog.gd")


func _ready() -> void:
	print("[SMASH_CONTENT_V1] fighters=")
	for fighter in FIGHTER_CATALOG.get_all_fighters():
		print("  - %s (%s)" % [fighter.id, fighter.display_name])
	print("[SMASH_CONTENT_V1] stages=")
	for stage in STAGE_CATALOG.get_all_stages():
		print("  - %s (%s)" % [stage.get("id"), stage.get("display_name")])
	print("[SMASH_CONTENT_V1] PASS")
	await get_tree().create_timer(0.35).timeout
	get_tree().quit()
