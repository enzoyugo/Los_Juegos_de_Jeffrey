class_name ZombiesAudio
extends Node

## Placeholder SFX bank. Gameplay code references this node, not raw paths.

const BANK := {
	"pistol": "res://data/zombies/audio/pistol.wav",
	"smg": "res://data/zombies/audio/smg.wav",
	"zombie_attack": "res://data/zombies/audio/zombie_attack.wav",
	"zombie_hurt": "res://data/zombies/audio/zombie_hurt.wav",
	"zombie_death": "res://data/zombies/audio/zombie_death.wav",
	"player_hit": "res://data/zombies/audio/player_hit.wav",
	"door_buy": "res://data/zombies/audio/door_buy.wav",
	"round_start": "res://data/zombies/audio/round_start.wav",
	"max_ammo": "res://data/zombies/audio/max_ammo.wav",
	"shopping_open": "res://data/zombies/audio/shopping_open.wav",
}

var _players: Dictionary = {}


func _ready() -> void:
	for key in BANK.keys():
		var p := AudioStreamPlayer.new()
		p.name = str(key)
		p.bus = "Master"
		var path := str(BANK[key])
		p.stream = _load_stream(path)
		add_child(p)
		_players[key] = p


func _load_stream(path: String) -> AudioStream:
	if ResourceLoader.exists(path):
		var res = load(path)
		if res is AudioStream:
			return res
	if not FileAccess.file_exists(path):
		return null
	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.size() < 44:
		return null
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = 22050
	s.stereo = false
	s.data = bytes.slice(44)
	return s


func play(id: String) -> void:
	if not _players.has(id):
		return
	var p: AudioStreamPlayer = _players[id]
	if p != null and p.stream != null:
		p.play()
