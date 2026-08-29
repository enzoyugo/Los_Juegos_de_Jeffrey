class_name TrackHandling
extends RefCounted

## Isolated arcade handling math. Tunables live in TrackConfig.


static func steer_authority(speed: float, steer_low: float, steer_high: float, speed_ref: float) -> float:
	var t := clampf(absf(speed) / maxf(speed_ref, 0.001), 0.0, 1.0)
	t = t * t * (3.0 - 2.0 * t)
	return lerpf(steer_low, steer_high, t)


static func smooth_axis(current: float, target: float, response: float, delta: float) -> float:
	var alpha := 1.0 - exp(-maxf(response, 0.001) * delta)
	return lerpf(current, target, alpha)


static func damp_lateral(lateral: float, grip: float, delta: float) -> float:
	if grip <= 0.0:
		return lateral
	return lateral * exp(-grip * delta)


static func accel_delta(along: float, throttle: float, accel: float, max_speed: float, high_scale: float, delta: float) -> float:
	if throttle <= 0.0:
		return 0.0
	var t := clampf(absf(along) / maxf(max_speed, 0.001), 0.0, 1.0)
	var scale := lerpf(1.0, high_scale, t)
	return accel * scale * throttle * delta


static func brake_or_reverse_delta(along: float, brake: float, brake_force: float, reverse_force: float, reverse_enter: float, delta: float) -> float:
	if brake <= 0.0:
		return 0.0
	if along > reverse_enter:
		return -brake_force * brake * delta
	return -reverse_force * brake * delta


static func slip_ratio(along: float, lateral: float) -> float:
	var speed := sqrt(along * along + lateral * lateral)
	if speed < 0.35:
		return 0.0
	return clampf(absf(lateral) / speed, 0.0, 1.0)


static func slip_angle(along: float, lateral: float) -> float:
	if absf(along) < 0.15 and absf(lateral) < 0.15:
		return 0.0
	return atan2(lateral, maxf(absf(along), 0.15))


static func wants_drift(speed: float, steer: float, brake: float, handbrake: float, min_speed: float, steer_threshold: float) -> bool:
	if speed < min_speed:
		return false
	if absf(steer) < steer_threshold:
		return false
	return brake >= 0.28 or handbrake >= 0.35


static func is_countersteer(steer: float, lateral: float) -> bool:
	if absf(steer) < 0.08 or absf(lateral) < 0.35:
		return false
	return signf(steer) != signf(lateral)


static func clamp_slip_lateral(along: float, lateral: float, max_angle: float) -> float:
	var angle := slip_angle(along, lateral)
	if absf(angle) <= max_angle:
		return lateral
	var limited := tan(max_angle) * maxf(absf(along), 0.15)
	return clampf(lateral, -limited, limited)
