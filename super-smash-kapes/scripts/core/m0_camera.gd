extends Camera3D

@export var minimum_distance: float = 26.0
@export var maximum_distance: float = 36.0
@export var follow_smoothing: float = 5.0

func _process(delta: float) -> void:
	var manager := get_parent().get_node_or_null("FighterManager")
	if manager == null:
		return
	var active_positions: Array[Vector3] = []
	for child in manager.get_children():
		if child is Fighter and is_instance_valid(child) and child.is_inside_tree() and child.state != Fighter.FighterState.DEAD:
			active_positions.append(child.global_position)
	if active_positions.is_empty():
		return
	var left: float = active_positions[0].x
	var right: float = active_positions[0].x
	for fighter_position in active_positions:
		left = minf(left, fighter_position.x)
		right = maxf(right, fighter_position.x)
	var midpoint: float = clampf((left + right) * 0.5, -5.0, 5.0)
	var separation: float = right - left
	var target_distance: float = clampf(minimum_distance + separation * 0.42, minimum_distance, maximum_distance)
	position.x = lerpf(position.x, midpoint, minf(delta * follow_smoothing, 1.0))
	position.z = lerpf(position.z, target_distance, minf(delta * follow_smoothing, 1.0))
