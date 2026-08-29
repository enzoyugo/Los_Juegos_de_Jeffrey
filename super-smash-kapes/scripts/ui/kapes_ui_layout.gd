class_name KapesUILayout
extends RefCounted

const DESIGN_SIZE := Vector2(1920.0, 1080.0)

static func viewport_size(viewport: Viewport) -> Vector2:
	return viewport.get_visible_rect().size

static func safe_rect(viewport: Viewport) -> Rect2:
	var size := viewport_size(viewport)
	var margin_x := size.x * KapesVisual.SAFE_MARGIN_X
	var margin_y := size.y * KapesVisual.SAFE_MARGIN_Y
	return Rect2(margin_x, margin_y, size.x - margin_x * 2.0, size.y - margin_y * 2.0)

static func scale_factor(viewport: Viewport) -> float:
	var size := viewport_size(viewport)
	return minf(size.x / DESIGN_SIZE.x, size.y / DESIGN_SIZE.y)

static func contain_size(source_size: Vector2, max_size: Vector2) -> Vector2:
	if source_size.x <= 0.0 or source_size.y <= 0.0:
		return max_size
	var fit := minf(max_size.x / source_size.x, max_size.y / source_size.y)
	return source_size * fit

static func cover_size(source_size: Vector2, target_size: Vector2) -> Vector2:
	if source_size.x <= 0.0 or source_size.y <= 0.0:
		return target_size
	var fit := maxf(target_size.x / source_size.x, target_size.y / source_size.y)
	return source_size * fit

static func font_size(viewport: Viewport, design_size: float) -> int:
	return maxi(12, int(round(design_size * scale_factor(viewport))))

static func bind_full_rect(control: Control) -> void:
	control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	control.offset_left = 0.0
	control.offset_top = 0.0
	control.offset_right = 0.0
	control.offset_bottom = 0.0
