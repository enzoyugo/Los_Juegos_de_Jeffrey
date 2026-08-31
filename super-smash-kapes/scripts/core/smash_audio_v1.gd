class_name SmashAudioV1
extends RefCounted

## First-party Smash combat/match SFX under res://assets/audio/smash/

const DIR := "res://assets/audio/smash/"

static var _cache: Dictionary = {}
static var _cooldown: Dictionary = {}


static func play_hit(from: Node, heavy: bool = false) -> void:
	_play(from, "hit_heavy" if heavy else "hit_light", 0.05)


static func play_ko(from: Node) -> void:
	_play(from, "ko", 0.2)


static func play_respawn(from: Node) -> void:
	_play(from, "respawn", 0.15)


static func play_match_start(from: Node) -> void:
	_play(from, "match_start", 0.3)


static func play_match_end(from: Node) -> void:
	_play(from, "match_end", 0.3)


static func _play(from: Node, stem: String, cooldown: float) -> void:
	if from == null or not is_instance_valid(from):
		return
	var now := Time.get_ticks_msec() / 1000.0
	if float(_cooldown.get(stem, 0.0)) > now:
		return
	_cooldown[stem] = now + cooldown
	var path := DIR + stem + ".wav"
	if not ResourceLoader.exists(path):
		return
	var stream = _cache.get(stem)
	if stream == null:
		stream = load(path)
		_cache[stem] = stream
	if stream == null:
		return
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = "Master"
	player.volume_db = _volume_db()
	## Match hosts can emit the intro SFX from their own _ready(). Adding a
	## player directly during that callback makes SceneTree reject the child
	## and leaves play() outside the tree. Defer both operations as one ordered
	## scene-tree handoff; gameplay callers remain fire-and-forget.
	from.get_tree().root.add_child.call_deferred(player)
	player.finished.connect(player.queue_free)
	player.call_deferred("play")


static func _volume_db() -> float:
	var master := 1.0
	var sfx := 1.0
	if JeffreyCore != null and JeffreyCore.settings is Dictionary:
		master = float(JeffreyCore.settings.get("master_volume", 1.0))
		sfx = float(JeffreyCore.settings.get("sfx_volume", 1.0))
	var linear := clampf(master * sfx, 0.0, 1.0)
	if linear <= 0.001:
		return -80.0
	return linear_to_db(linear) - 1.5
