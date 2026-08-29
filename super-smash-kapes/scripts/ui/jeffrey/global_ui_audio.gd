class_name GlobalUiAudio
extends RefCounted

## Shared UI SFX — first-party pack under res://assets/audio/ui/

const EXPECTED_DIR := "res://assets/audio/ui/"

## Canonical basename → file stem (without extension).
const MAP := {
	"navigate": "navigate",
	"confirm": "confirm",
	"back": "back",
	"error": "error",
	"modal": "modal_open",
	"score": "score_gain",
	"result": "result",
	"countdown": "countdown_tick",
	"countdown_go": "countdown_go",
	"finish": "finish",
	"join": "player_join",
	"leave": "player_leave",
}

static var _inventory_done: bool = false
static var _available: Dictionary = {}
static var _cooldown: Dictionary = {}


static func inventory() -> Dictionary:
	_scan_once()
	return _available.duplicate()


static func has_pack() -> bool:
	_scan_once()
	return not _available.is_empty()


static func play_focus(from: Node = null) -> void:
	_play("navigate", from, 0.04)


static func play_select(from: Node = null) -> void:
	_play("confirm", from, 0.08)


static func play_confirm(from: Node = null) -> void:
	_play("confirm", from, 0.08)


static func play_back(from: Node = null) -> void:
	_play("back", from, 0.08)


static func play_soco_impact(from: Node = null) -> void:
	_play("confirm", from, 0.1)


static func play_track_whoosh(from: Node = null) -> void:
	_play("result", from, 0.12)


static func play_zombies_hit(from: Node = null) -> void:
	_play("error", from, 0.08)


static func play_copa_emphasis(from: Node = null) -> void:
	_play("score", from, 0.1)


static func play_modal_open(from: Node = null) -> void:
	_play("modal", from, 0.12)


static func play_error(from: Node = null) -> void:
	_play("error", from, 0.1)


static func play_countdown(from: Node = null) -> void:
	_play("countdown", from, 0.05)


static func play_countdown_go(from: Node = null) -> void:
	_play("countdown_go", from, 0.1)


static func play_finish(from: Node = null) -> void:
	_play("finish", from, 0.15)


static func play_result(from: Node = null) -> void:
	_play("result", from, 0.15)


static func _scan_once() -> void:
	if _inventory_done:
		return
	_inventory_done = true
	_available.clear()
	for key in MAP.keys():
		var stem: String = str(MAP[key])
		for ext in [".wav", ".ogg"]:
			var path: String = EXPECTED_DIR + stem + ext
			if ResourceLoader.exists(path):
				_available[key] = path
				break


static func _play(key: String, from: Node, cooldown: float) -> void:
	_scan_once()
	if not _available.has(key):
		return
	var now := Time.get_ticks_msec() / 1000.0
	if float(_cooldown.get(key, 0.0)) > now:
		return
	_cooldown[key] = now + cooldown
	if from == null or not is_instance_valid(from):
		return
	var path: String = str(_available[key])
	var stream = load(path)
	if stream == null:
		return
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = "Master"
	player.volume_db = _volume_db()
	from.get_tree().root.add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


static func _volume_db() -> float:
	var master := 1.0
	var sfx := 1.0
	if JeffreyCore != null and JeffreyCore.settings is Dictionary:
		master = float(JeffreyCore.settings.get("master_volume", 1.0))
		sfx = float(JeffreyCore.settings.get("sfx_volume", 1.0))
	var linear := clampf(master * sfx, 0.0, 1.0)
	if linear <= 0.001:
		return -80.0
	return linear_to_db(linear) - 2.0
