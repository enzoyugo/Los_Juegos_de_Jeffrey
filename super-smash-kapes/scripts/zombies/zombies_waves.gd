class_name ZombiesWaves
extends RefCounted

const Config := preload("res://scripts/zombies/zombies_config.gd")

var wave: int = 0
var zombies_to_spawn: int = 0
var spawn_interval: float = Config.SPAWN_INTERVAL


func next_count() -> int:
	wave += 1
	zombies_to_spawn = mini(4 + wave * 2, 16)
	return zombies_to_spawn


func zombie_health() -> float:
	var n: int = maxi(wave, 1)
	return Config.ZOMBIE_HP * pow(Config.HEALTH_SCALE, float(n - 1))
