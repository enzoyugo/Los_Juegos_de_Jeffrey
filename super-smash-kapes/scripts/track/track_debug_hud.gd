class_name TrackDebugHud
extends CanvasLayer

## Hidden in normal play. Toggle with F3 in the physics lab.

const Config := preload("res://scripts/track/track_config.gd")

var target: Node
var _label: Label


func _ready() -> void:
	layer = 40
	visible = false
	_label = Label.new()
	_label.position = Vector2(16, 12)
	_label.add_theme_font_size_override("font_size", 15)
	_label.add_theme_color_override("font_color", Color(1, 0.96, 0.78, 0.95))
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_label.add_theme_constant_override("outline_size", 5)
	add_child(_label)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F3:
		visible = not visible
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if not visible or target == null or _label == null:
		return
	_label.text = "\n".join(PackedStringArray([
		"TRACK PHYSICS LAB  V2",
		"speed     %.1f m/s  (%.0f kph)" % [float(target.debug_speed), float(target.debug_speed) * 3.6],
		"forward   %.1f" % float(target.debug_along),
		"lateral   %.1f" % float(target.debug_lateral),
		"slip ang  %.2f" % float(target.debug_slip_angle),
		"steer     %.2f" % float(target.debug_steer),
		"throttle  %.2f" % float(target.debug_throttle),
		"brake     %.2f" % float(target.debug_brake),
		"handbrake %.2f" % float(target.debug_handbrake),
		"drift     %s  %.2f" % [str(target.drift_state), float(target.drift_amount)],
		"grip      %.1f" % float(target.debug_grip),
		"yaw rate  %.2f" % float(target.debug_yaw_rate),
		"grounded  %s" % str(target.debug_grounded),
		"road_w    %.1f m  car_w 2.14  ratio %.1f" % [Config.ROAD_WIDTH, Config.ROAD_WIDTH / 2.14],
		"rails     h=%.2f  thick=%.2f" % [Config.GUARDRAIL_HEIGHT, Config.GUARDRAIL_THICKNESS],
		"F3 hide · F4 collider · WASD · Shift drift",
	]))
