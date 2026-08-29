extends Node

## Fast parse/load gate for Jeffrey shell static dependencies.
## Run: Godot --headless --path project res://scenes/debug/ValidateJeffreyShellParse.tscn

const SHELL_SCRIPTS: Array[String] = [
	"res://scripts/core/jeffrey/jeffrey_core.gd",
	"res://scripts/core/jeffrey/jeffrey_app.gd",
	"res://scripts/ui/jeffrey/boot_screen.gd",
	"res://scripts/ui/jeffrey/players_today_screen.gd",
	"res://scripts/ui/jeffrey/hub_screen.gd",
	"res://scripts/ui/jeffrey/edit_players_screen.gd",
	"res://scripts/ui/jeffrey/mode_player_select_screen.gd",
	"res://scripts/ui/jeffrey/character_select_screen.gd",
	"res://scripts/ui/jeffrey/mode_transition_controller.gd",
	"res://scripts/ui/jeffrey/coming_soon_screen.gd",
	"res://scripts/ui/jeffrey/zombies_menu_screen.gd",
	"res://scripts/ui/jeffrey/zombies_loading_screen.gd",
	"res://scripts/ui/jeffrey/options_screen.gd",
	"res://scripts/ui/jeffrey/copa_jeffrey_results_screen.gd",
	"res://scripts/ui/jeffrey/copa_jeffrey_scoreboard_screen.gd",
	"res://scripts/ui/jeffrey/copa_jeffrey_confirm_dialog.gd",
	"res://scripts/ui/jeffrey/copa_jeffrey_hub_panel.gd",
	"res://scripts/ui/jeffrey/copa_jeffrey_podium_v1.gd",
	"res://scripts/ui/jeffrey/zombies_result_banner_v1.gd",
	"res://scripts/ui/jeffrey/global_ui_audio.gd",
	"res://scripts/track/track_visual_quality_v2.gd",
	"res://scripts/ui/jeffrey/system/jeffrey_shell_transition.gd",
	"res://scripts/ui/jeffrey/components/jeffrey_modal.gd",
	"res://scripts/ui/jeffrey/components/jeffrey_button.gd",
]


func _ready() -> void:
	var failures: PackedStringArray = PackedStringArray()
	for path in SHELL_SCRIPTS:
		var script: Variant = load(path)
		if script == null:
			failures.append("load failed: %s" % path)
			continue
		if not (script is Script):
			failures.append("not a script: %s" % path)
	var boot: PackedScene = load("res://scenes/core/JeffreyBoot.tscn") as PackedScene
	if boot == null:
		failures.append("JeffreyBoot.tscn failed to load")
	if failures.is_empty():
		print("[JEFFREY_SHELL_PARSE] PASS count=%d" % SHELL_SCRIPTS.size())
		get_tree().quit(0)
	else:
		for item in failures:
			push_error(item)
			print("[JEFFREY_SHELL_PARSE] FAIL %s" % item)
		get_tree().quit(1)
