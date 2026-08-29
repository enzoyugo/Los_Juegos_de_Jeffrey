class_name JeffreyFocusRing
extends Control

const ThemeRef := preload("res://scripts/ui/jeffrey/system/jeffrey_theme.gd")
const Layout := preload("res://scripts/ui/jeffrey/global_ui_layout.gd")

var _target: Control
var _ring: ColorRect


func bind(target: Control) -> void:
	_target = target
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ring = ColorRect.new()
	_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ring.color = Color(0, 0, 0, 0)
	add_child(_ring)
	Layout.bind_full(_ring)
	if _target != null:
		_target.focus_entered.connect(_refresh)
		_target.focus_exited.connect(_refresh)
		_target.mouse_entered.connect(_refresh)
		_target.mouse_exited.connect(_refresh)
		_target.resized.connect(_refresh)


func _refresh() -> void:
	if _target == null or _ring == null:
		return
	var lit := _target.has_focus() or _target.is_hovered()
	var accent := ThemeRef.mode_accent("")
	_ring.color = Color(accent.r, accent.g, accent.b, 0.22 if lit else 0.0)
