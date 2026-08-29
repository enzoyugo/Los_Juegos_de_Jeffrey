extends Control

var elapsed: float = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()

func _process(delta: float) -> void:
	elapsed += delta
	queue_redraw()

func _draw() -> void:
	var size := get_viewport_rect().size
	var pulse: float = sin(elapsed * 0.8) * 0.5 + 0.5
	draw_rect(Rect2(Vector2.ZERO, size), KapesVisual.NIGHT)
	draw_colored_polygon(PackedVector2Array([Vector2(0, 0), Vector2(size.x, 0), Vector2(size.x, size.y * 0.42), Vector2(0, size.y * 0.62)]), Color("#0d1830"))
	draw_colored_polygon(PackedVector2Array([Vector2(0, size.y * 0.45), Vector2(size.x, size.y * 0.28), Vector2(size.x, size.y * 0.78), Vector2(0, size.y * 0.88)]), Color("#121426"))
	var slash_y: float = size.y * 0.72 + sin(elapsed * 0.45) * 8.0
	for index in range(3):
		var x: float = -180.0 + index * 170.0 + fmod(elapsed * 18.0, 120.0)
		var points := PackedVector2Array([Vector2(x, slash_y), Vector2(x + 720.0, slash_y - 170.0), Vector2(x + 750.0, slash_y - 132.0), Vector2(x + 30.0, slash_y + 38.0)])
		draw_colored_polygon(points, [KapesVisual.RED, KapesVisual.WHITE, KapesVisual.BLUE][index])
	for index in range(10):
		var x: float = size.x * 0.04 + index * size.x * 0.095
		var height: float = 58.0 + float((index * 37) % 170)
		draw_rect(Rect2(x, size.y * 0.78 - height, 64.0, height), Color("#0a1020"))
		for window in range(3):
			var flicker: float = 0.16 + 0.10 * sin(elapsed * 1.2 + index + window)
			draw_rect(Rect2(x + 14.0, size.y * 0.78 - height + 20.0 + window * 30.0, 8.0, 5.0), Color(1.0, 0.68, 0.28, flicker))
	_draw_palacio(Vector2(size.x * 0.77, size.y * 0.72), pulse)
	for index in range(6):
		var lamp_x: float = size.x * 0.06 + index * size.x * 0.17
		draw_line(Vector2(lamp_x, size.y * 0.78), Vector2(lamp_x, size.y * 0.62), Color("#263451"), 3.0)
		draw_circle(Vector2(lamp_x, size.y * 0.61), 11.0 + pulse * 2.0, Color(1.0, 0.69, 0.31, 0.10))
	for index in range(18):
		var particle_x: float = fmod(index * 147.0 + elapsed * (7.0 + index % 3), size.x)
		var particle_y: float = 90.0 + fmod(index * 61.0, size.y * 0.58)
		draw_circle(Vector2(particle_x, particle_y), 1.5, Color(0.96, 0.82, 0.52, 0.16))

func _draw_palacio(origin: Vector2, pulse: float) -> void:
	var building := Color("#18233a")
	var lit := Color(1.0, 0.69, 0.32, 0.28 + pulse * 0.08)
	draw_colored_polygon(PackedVector2Array([origin + Vector2(-220, 0), origin + Vector2(-170, -110), origin + Vector2(-90, -130), origin + Vector2(-45, -82), origin + Vector2(45, -82), origin + Vector2(90, -130), origin + Vector2(170, -110), origin + Vector2(220, 0)]), building)
	draw_colored_polygon(PackedVector2Array([origin + Vector2(-55, -82), origin + Vector2(-48, -215), origin + Vector2(0, -260), origin + Vector2(48, -215), origin + Vector2(55, -82)]), building)
	draw_colored_polygon(PackedVector2Array([origin + Vector2(-17, -256), origin + Vector2(0, -310), origin + Vector2(17, -256)]), building)
	for index in range(7):
		var x: float = origin.x - 180.0 + index * 60.0
		draw_rect(Rect2(x, origin.y - 65.0, 18.0, 28.0), lit)
	for index in range(3):
		draw_rect(Rect2(origin.x - 20.0 + index * 20.0, origin.y - 164.0, 9.0, 30.0), lit)
