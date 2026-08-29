class_name AttackDefinition
extends Resource

@export var attack_id: String = "basic_capsule_strike"
@export var display_name: String = "Capsule Strike"
@export var startup_seconds: float = 0.10
@export var active_seconds: float = 0.12
@export var recovery_seconds: float = 0.24
@export var damage: float = 8.0
@export var base_knockback: float = 7.0
@export var knockback_growth: float = 0.105
@export var angle_degrees: float = 42.0
@export var ground_steering: float = 0.55
@export var air_steering: float = 0.70
@export var hitstun_scale: float = 0.018

func total_duration() -> float:
	return startup_seconds + active_seconds + recovery_seconds
