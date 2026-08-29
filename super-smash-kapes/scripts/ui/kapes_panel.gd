class_name KapesPanel
extends Control

@export var panel_color: Color = KapesVisual.INK
@export var accent_color: Color = KapesVisual.RED_BRIGHT
@export var mirror: bool = false
@export var stripe_alpha: float = 0.9

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()

func _draw() -> void:
	var w := size.x
	var h := size.y
	var points := PackedVector2Array()
	if mirror:
		points = PackedVector2Array([Vector2(42, 0), Vector2(w, 0), Vector2(w - 8, h), Vector2(0, h)])
	else:
		points = PackedVector2Array([Vector2(8, 0), Vector2(w - 42, 0), Vector2(w, h), Vector2(0, h)])
	draw_colored_polygon(points, Color(panel_color, 0.96))
	draw_polyline(PackedVector2Array([points[0], points[1], points[2], points[3], points[0]]), Color(accent_color, 0.85), 3.0, true)
	var stripe_x: float = w * 0.36
	var stripe_points := PackedVector2Array([Vector2(stripe_x, 0), Vector2(stripe_x + 32, 0), Vector2(stripe_x - 46, h), Vector2(stripe_x - 78, h)])
	draw_colored_polygon(stripe_points, Color(KapesVisual.RED, stripe_alpha * 0.55))
	stripe_points = PackedVector2Array([Vector2(stripe_x + 34, 0), Vector2(stripe_x + 55, 0), Vector2(stripe_x - 23, h), Vector2(stripe_x - 44, h)])
	draw_colored_polygon(stripe_points, Color(KapesVisual.WHITE, stripe_alpha * 0.25))
	stripe_points = PackedVector2Array([Vector2(stripe_x + 57, 0), Vector2(stripe_x + 80, 0), Vector2(stripe_x + 2, h), Vector2(stripe_x - 21, h)])
	draw_colored_polygon(stripe_points, Color(KapesVisual.BLUE, stripe_alpha * 0.55))
