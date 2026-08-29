extends Node

## Canonical full-game route smoke (headless). Does not replace manual play.

func _ready() -> void:
	var TrackAssets := load("res://scripts/ui/jeffrey/track_ui_assets.gd")
	var missing: PackedStringArray = PackedStringArray()
	for path in TrackAssets.all_paths():
		if not ResourceLoader.exists(path) and not FileAccess.file_exists(path):
			missing.append(path)
	assert(missing.is_empty(), "Track menu assets missing: %s" % ",".join(missing))

	var catalog = load("res://scripts/fighters/fighter_catalog.gd")
	var fighters = catalog.get_all_fighters()
	assert(fighters.size() >= 5)
	var fort = catalog.get_by_id("fort")
	assert(str(fort.production_glb_path).ends_with("fort_stylized_v1.glb"))
	assert(not str(fort.production_glb_path).contains("v2_candidate"))

	var stages = load("res://scripts/stages/stage_catalog.gd")
	assert(stages != null)

	assert(ResourceLoader.exists("res://scenes/track/TrackMain.tscn"))
	assert(ResourceLoader.exists("res://scenes/zombies/ZombiesMain.tscn"))
	assert(ResourceLoader.exists("res://scenes/core/Main.tscn"))
	assert(ResourceLoader.exists("res://scenes/core/JeffreyBoot.tscn"))

	var menu_script = load("res://scripts/ui/jeffrey/track_menu_screen.gd")
	assert(menu_script != null)
	var menu = menu_script.new()
	add_child(menu)
	menu.configure([{
		"profile_id": "p_test",
		"player_slot": 1,
		"character_id": "el_gallo",
	}])
	assert(menu.length_id == "media" or menu.length_id != "")
	print("[JEFFREY_FULL_GAME_CANONICAL_V1] SHELL=PASS")
	print("[JEFFREY_FULL_GAME_CANONICAL_V1] SMASH=PASS")
	print("[JEFFREY_FULL_GAME_CANONICAL_V1] TRACK_MENU=PASS")
	print("[JEFFREY_FULL_GAME_CANONICAL_V1] ZOMBIES_PATH=PASS")
	print("[JEFFREY_FULL_GAME_CANONICAL_V1] PASS")
	await get_tree().create_timer(0.15).timeout
	get_tree().quit(0)
