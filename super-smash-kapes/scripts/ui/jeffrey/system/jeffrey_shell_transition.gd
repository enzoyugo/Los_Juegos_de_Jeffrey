class_name JeffreyShellTransition
extends RefCounted

const ThemeRef := preload("res://scripts/ui/jeffrey/system/jeffrey_theme.gd")
const Motion := preload("res://scripts/ui/jeffrey/system/jeffrey_ui_motion.gd")

static var _active_tween: Tween = null


static func present(host: Node, screen_root: Control, screen: Control, previous: Control, on_faded: Callable = Callable()) -> void:
	if host == null or screen_root == null:
		return
	if _active_tween != null and is_instance_valid(_active_tween):
		_active_tween.kill()
	_active_tween = null
	if previous != null and is_instance_valid(previous):
		previous.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen_root.modulate.a = 0.0
	screen_root.position.y += 8.0
	var tween := host.create_tween()
	_active_tween = tween
	tween.set_parallel(true)
	tween.tween_property(screen_root, "modulate:a", 1.0, ThemeRef.DURATION_SCREEN)
	tween.tween_property(screen_root, "position:y", screen_root.position.y - 8.0, ThemeRef.DURATION_SCREEN).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if previous != null and is_instance_valid(previous):
		tween.parallel().tween_property(previous, "modulate:a", 0.0, ThemeRef.DURATION_SCREEN)
		tween.tween_callback(func():
			if previous != null and is_instance_valid(previous):
				previous.queue_free()
			_active_tween = null
			if on_faded.is_valid():
				on_faded.call()
		)
	else:
		tween.tween_callback(func():
			_active_tween = null
			if on_faded.is_valid():
				on_faded.call()
		)
	if screen != null:
		Motion.fade_in(screen, ThemeRef.DURATION_FAST, 0.0)
