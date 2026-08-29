class_name TrackBoostFeedback
extends Node

## Arcade boost juice for BASELINE and 4WHEEL. Does not change handling.

var car: Node
var cam: Node
var _was_boost: bool = false
var _flash: OmniLight3D
var _flash_t: float = 0.0


func setup(p_car: Node, p_cam: Node) -> void:
	car = p_car
	cam = p_cam
	_ensure_flash()


func hud_line() -> String:
	if car == null or not is_instance_valid(car):
		return "BOOST READY"
	if bool(car.get("boost_active")):
		var left := 0.0
		if car.has_method("boost_time_left"):
			left = float(car.call("boost_time_left"))
		return "BOOST ACTIVE %.1fs" % left
	return "BOOST READY"


func _process(delta: float) -> void:
	if car == null or not is_instance_valid(car):
		return
	var active := bool(car.get("boost_active"))
	if active and not _was_boost:
		if cam != null and cam.has_method("boost_punch"):
			cam.call("boost_punch", 0.28)
		_flash_t = 0.22
	_was_boost = active
	if _flash == null:
		return
	if _flash_t > 0.0:
		_flash_t = maxf(_flash_t - delta, 0.0)
		_flash.light_energy = 5.5 * (_flash_t / 0.22)
		_flash.visible = true
	else:
		_flash.light_energy = 0.0
		_flash.visible = false


func _ensure_flash() -> void:
	if _flash != null or car == null or not (car is Node3D):
		return
	_flash = OmniLight3D.new()
	_flash.name = "BoostFlash"
	_flash.light_color = Color(0.35, 0.85, 1.0)
	_flash.omni_range = 8.0
	_flash.light_energy = 0.0
	_flash.visible = false
	_flash.position = Vector3(0.0, 1.1, -0.4)
	(car as Node3D).add_child(_flash)
