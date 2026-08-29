class_name TrackFuelSystem
extends RefCounted

## Fuel is remaining turn budget in seconds, not liters.
## Each participant has their own fuel_remaining (never a session-global scalar).
## initial = expected_time * TrackConfig.FUEL_MULTIPLIER (FUEL_ATTEMPT_MULT alias, provisional 2.75).
## Only the current driver is consumed. Last Dance does not consume or refill.

const Config := preload("res://scripts/track/track_config.gd")


static func allocate(expected_time: float) -> float:
	return Config.initial_fuel(expected_time)
