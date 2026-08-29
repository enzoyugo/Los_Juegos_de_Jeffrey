class_name KapesHudLayout
extends RefCounted

const PLATE_SOURCE_SIZE := Vector2(2172.0, 724.0)

static func region(card_size: Vector2, rect_ratio: Rect2) -> Rect2:
	return Rect2(
		card_size.x * rect_ratio.position.x,
		card_size.y * rect_ratio.position.y,
		card_size.x * rect_ratio.size.x,
		card_size.y * rect_ratio.size.y
	)

## Mirrored normalized zones — only horizontal mirroring differs between P1/P2.

static func p1_portrait_region() -> Rect2:
	return Rect2(0.028, 0.12, 0.22, 0.64)

static func p1_name_region() -> Rect2:
	return Rect2(0.255, 0.12, 0.28, 0.22)

static func p1_damage_region() -> Rect2:
	return Rect2(0.50, 0.28, 0.46, 0.48)

static func p1_stock_region() -> Rect2:
	return Rect2(0.255, 0.72, 0.32, 0.20)

static func p2_portrait_region() -> Rect2:
	return Rect2(0.752, 0.12, 0.22, 0.64)

static func p2_name_region() -> Rect2:
	return Rect2(0.465, 0.12, 0.28, 0.22)

static func p2_damage_region() -> Rect2:
	return Rect2(0.04, 0.28, 0.46, 0.48)

static func p2_stock_region() -> Rect2:
	return Rect2(0.425, 0.72, 0.32, 0.20)

static func stock_socket_offsets(player_id: int) -> PackedFloat32Array:
	# Identical baselines for both players.
	return PackedFloat32Array([0.0, 0.34, 0.68])
