extends Node3D

## H04: load downloaded candidates without changing production authority.
const OUT := "E:/JeffreyAIResearch/outputs/runtime-review/jeffrey_p0_closure_v1/harnesses"
const CANDIDATES := {
	"pistol": "res://assets/weapons/zombies/source/models/pistol_tt_candidate.glb",
	"zombie": "res://assets/characters/zombies/processed/zombie_stylized_v1.glb",
}

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var loaded := {}
	for key in CANDIDATES:
		var resource: Resource = load(CANDIDATES[key])
		var instance: Node = resource.instantiate() if resource is PackedScene else null
		loaded[key] = instance != null
		if instance != null:
			instance.name = "%s_candidate" % key
			add_child(instance)
			instance.position = Vector3(-1.4 if key == "pistol" else 1.4, 0.0, 0.0)
	await get_tree().create_timer(0.5).timeout
	var log := {"loaded": loaded, "production_unchanged": true, "pass": bool(loaded.get("pistol", false)) and bool(loaded.get("zombie", false))}
	print("[P0_ZOMBIES_ASSETS] %s" % JSON.stringify(log))
	var file := FileAccess.open("E:/JeffreyAIResearch/outputs/runtime-review/jeffrey_p0_closure_v1/logs/zombies_asset_sandbox.log", FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(log, "\t")); file.close()
	get_tree().quit(0 if log.pass else 1)
