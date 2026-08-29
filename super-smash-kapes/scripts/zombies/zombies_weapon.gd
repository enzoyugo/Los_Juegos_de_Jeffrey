class_name ZombiesWeapon
extends RefCounted

## Hitscan weapon instance. Mag + reserve, fire cooldown, reload.
## Starter pistol and wall SMG share this controller.

const DataScript := preload("res://scripts/zombies/zombies_weapon_data.gd")

var data
var mag: int = 0
var reserve: int = 0
var fire_cd: float = 0.0
var reload_left: float = 0.0


func setup(weapon_data) -> void:
	data = weapon_data
	if data == null:
		data = DataScript.new()
	mag = data.mag_size
	reserve = data.reserve_ammo
	fire_cd = 0.0
	reload_left = 0.0


func tick(delta: float) -> void:
	fire_cd = maxf(fire_cd - delta, 0.0)
	if reload_left > 0.0:
		reload_left -= delta
		if reload_left <= 0.0:
			reload_left = 0.0
			_finish_reload()


func is_reloading() -> bool:
	return reload_left > 0.0


func can_fire() -> bool:
	if data == null:
		return false
	if is_reloading():
		return false
	if mag <= 0:
		return false
	if fire_cd > 0.0:
		return false
	return true


func consume_shot() -> bool:
	if not can_fire():
		return false
	mag -= 1
	var rate: float = data.fire_rate
	if rate <= 0.01:
		rate = 4.0
	fire_cd = 1.0 / rate
	return true


func begin_reload() -> bool:
	if data == null:
		return false
	if is_reloading():
		return false
	if mag >= data.mag_size:
		return false
	if reserve <= 0:
		return false
	reload_left = data.reload_time
	return true


func refill(fill_mag: bool = true) -> void:
	if data == null:
		return
	reserve = data.reserve_ammo
	if fill_mag:
		mag = data.mag_size
		reload_left = 0.0


func display_name() -> String:
	if data == null:
		return "—"
	return data.display_name


func _finish_reload() -> void:
	if data == null:
		return
	var need: int = data.mag_size - mag
	var take: int = mini(need, reserve)
	mag += take
	reserve -= take
