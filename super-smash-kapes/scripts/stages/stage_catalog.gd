class_name StageCatalog
extends RefCounted

## Canonical Smash stage registry.

const DEFENSORES := "defensores"
const PALACIO := "palacio"
const COSTANERA := "costanera"

static var _loaded: bool = false
static var _stages: Dictionary = {}


static func get_all_stages() -> Array:
	_ensure()
	var out: Array = []
	for key in _stages.keys():
		out.append(_stages[key])
	out.sort_custom(func(a, b) -> bool: return str(a.get("id", "")) < str(b.get("id", "")))
	return out


static func get_by_id(stage_id: String) -> Dictionary:
	_ensure()
	return _stages.get(stage_id, {}).duplicate(true)


static func default_stage_id() -> String:
	var env := OS.get_environment("SSK_STAGE_ID").strip_edges()
	if not env.is_empty() and _stages.has(env):
		return env
	return DEFENSORES


static func scene_path_for(stage_id: String) -> String:
	var row := get_by_id(stage_id)
	if row.is_empty():
		row = get_by_id(DEFENSORES)
	return str(row.get("scene_path", "res://scenes/stages/DefensoresDelChacoStage.tscn"))


static func _ensure() -> void:
	if _loaded:
		return
	_loaded = true
	_stages[DEFENSORES] = {
		"id": DEFENSORES,
		"display_name": "DEFENSORES DEL CHACO",
		"scene_path": "res://scenes/stages/DefensoresDelChacoStage.tscn",
		"spawn_p1": Vector3(-4.0, 1.7, 0.0),
		"spawn_p2": Vector3(4.0, 1.7, 0.0),
		"blast_min": Vector3(-19.0, -10.0, -8.0),
		"blast_max": Vector3(19.0, 18.0, 8.0),
	}
	_stages[PALACIO] = {
		"id": PALACIO,
		"display_name": "PALACIO DE LÓPEZ",
		"scene_path": "res://scenes/stages/PalacioDeLopezStage.tscn",
		"spawn_p1": Vector3(-4.0, 1.7, 0.0),
		"spawn_p2": Vector3(4.0, 1.7, 0.0),
		"blast_min": Vector3(-19.0, -10.0, -8.0),
		"blast_max": Vector3(19.0, 18.0, 8.0),
	}
	_stages[COSTANERA] = {
		"id": COSTANERA,
		"display_name": "COSTANERA DE ASUNCIÓN",
		"scene_path": "res://scenes/stages/CostaneraDeAsuncionStage.tscn",
		"spawn_p1": Vector3(-6.0, 1.7, 0.0),
		"spawn_p2": Vector3(6.0, 1.7, 0.0),
		"blast_min": Vector3(-26.0, -10.0, -8.0),
		"blast_max": Vector3(26.0, 18.0, 8.0),
	}
