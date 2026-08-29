class_name JeffreyUiMotion
extends RefCounted

const ThemeRef := preload("res://scripts/ui/jeffrey/system/jeffrey_theme.gd")


static func bind_focus_scale(control: Control) -> void:
	if control == null:
		return
	control.pivot_offset = control.size * 0.5
	control.resized.connect(func(): control.pivot_offset = control.size * 0.5)
	if control is BaseButton:
		var btn := control as BaseButton
		btn.focus_entered.connect(func(): pulse_scale(control, Vector2.ONE * ThemeRef.HOVER_SCALE, ThemeRef.DURATION_FAST))
		btn.focus_exited.connect(func(): pulse_scale(control, Vector2.ONE, ThemeRef.DURATION_FAST))
		btn.mouse_entered.connect(func(): pulse_scale(control, Vector2.ONE * ThemeRef.HOVER_SCALE, ThemeRef.DURATION_FAST))
		btn.mouse_exited.connect(func(): pulse_scale(control, Vector2.ONE, ThemeRef.DURATION_FAST))
		btn.button_down.connect(func(): pulse_scale(control, Vector2.ONE * ThemeRef.PRESS_SCALE, ThemeRef.DURATION_FAST * 0.75))
		btn.button_up.connect(func(): pulse_scale(control, Vector2.ONE * ThemeRef.HOVER_SCALE if btn.is_hovered() or btn.has_focus() else Vector2.ONE, ThemeRef.DURATION_FAST))


static func pulse_scale(control: Control, target: Vector2, duration: float) -> void:
	if control == null or not is_instance_valid(control):
		return
	control.pivot_offset = control.size * 0.5
	if control.has_meta("_jeffrey_scale_tween"):
		var prev: Variant = control.get_meta("_jeffrey_scale_tween")
		if prev is Tween and is_instance_valid(prev):
			(prev as Tween).kill()
	var tween := control.create_tween()
	control.set_meta("_jeffrey_scale_tween", tween)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(control, "scale", target, duration)


static func fade_in(control: Control, duration: float = ThemeRef.DURATION_NORMAL, delay: float = 0.0) -> void:
	if control == null:
		return
	control.modulate.a = 0.0
	var tween := control.create_tween()
	if delay > 0.0:
		tween.tween_interval(delay)
	tween.tween_property(control, "modulate:a", 1.0, duration)


static func slide_fade_in(control: Control, offset_y: float = 24.0, duration: float = ThemeRef.DURATION_SCREEN) -> void:
	if control == null:
		return
	var start_y := control.position.y + offset_y
	control.modulate.a = 0.0
	control.position.y = start_y
	var tween := control.create_tween()
	tween.set_parallel(true)
	tween.tween_property(control, "modulate:a", 1.0, duration)
	tween.tween_property(control, "position:y", start_y - offset_y, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


static func modal_pop(panel: Control) -> void:
	if panel == null:
		return
	panel.modulate.a = 0.0
	panel.scale = Vector2(0.94, 0.94)
	panel.pivot_offset = panel.size * 0.5
	panel.resized.connect(func(): panel.pivot_offset = panel.size * 0.5)
	var tween := panel.create_tween()
	tween.set_parallel(true)
	tween.tween_property(panel, "modulate:a", 1.0, ThemeRef.DURATION_NORMAL)
	tween.tween_property(panel, "scale", Vector2.ONE, ThemeRef.DURATION_NORMAL).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


static func emphasize_points(label: Control) -> void:
	if label == null:
		return
	var tween := label.create_tween()
	tween.tween_property(label, "scale", Vector2(1.08, 1.08), 0.12)
	tween.tween_property(label, "scale", Vector2.ONE, 0.18)
