class_name KapesFlagWipe
extends Control

var progress: float = 0.0
var cover_action: Callable
var action_called: bool = false

func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func play(callback: Callable) -> void:
	cover_action = callback
	if OS.get_environment("SSK_FREEZE_AUDIT") == "1":
		print("[FREEZE_AUDIT] flag wipe tween started")
	var tween := create_tween()
	tween.tween_method(_set_progress, 0.0, 1.0, 0.34)
	tween.tween_callback(func():
		if OS.get_environment("SSK_FREEZE_AUDIT") == "1":
			print("[FREEZE_AUDIT] flag wipe tween finished")
		var parent_layer := get_parent()
		queue_free()
		if parent_layer is CanvasLayer:
			parent_layer.queue_free()
	)

func _set_progress(value: float) -> void:
	progress = value
	if progress >= 0.47 and not action_called:
		action_called = true
		if cover_action.is_valid():
			cover_action.call()
	queue_redraw()

func _draw() -> void:
	var viewport_size := get_viewport_rect().size
	var travel: float = -viewport_size.x + progress * viewport_size.x * 2.0
	var colors := [KapesVisual.RED, KapesVisual.WHITE, KapesVisual.BLUE]
	for index in range(3):
		var center_x: float = travel + float(index - 1) * 220.0
		var points := PackedVector2Array([
			Vector2(center_x - 260.0, 0),
			Vector2(center_x + 260.0, 0),
			Vector2(center_x + viewport_size.y + 260.0, viewport_size.y),
			Vector2(center_x + viewport_size.y - 260.0, viewport_size.y)
		])
		draw_colored_polygon(points, colors[index])
