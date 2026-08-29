class_name FighterSizeClass
extends RefCounted

## Canonical presentation size classes for fighters.
## Gameplay colliders are independent — these affect VisualRoot only.

const TINY := "TINY"
const SHORT := "SHORT"
const MEDIUM := "MEDIUM"
const TALL := "TALL"
const HUGE := "HUGE"

const DEFAULT_HEIGHTS := {
	TINY: 1.95,
	SHORT: 2.40,
	MEDIUM: 2.75,
	TALL: 3.15,
	HUGE: 3.60,
}

const HEIGHT_RANGES := {
	TINY: Vector2(1.8, 2.1),
	SHORT: Vector2(2.3, 2.5),
	MEDIUM: Vector2(2.6, 2.9),
	TALL: Vector2(3.0, 3.3),
	HUGE: Vector2(3.4, 3.8),
}

static func default_height(size_class: String) -> float:
	return float(DEFAULT_HEIGHTS.get(size_class, DEFAULT_HEIGHTS[MEDIUM]))

static func is_valid(size_class: String) -> bool:
	return DEFAULT_HEIGHTS.has(size_class)
