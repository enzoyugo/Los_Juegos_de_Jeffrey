class_name FighterAnimationSet
extends Resource

## Semantic clip contract for gameplay <-> animation.
## Gameplay never references Mixamo/FBX filenames.

@export var idle: String = ""
@export var run: String = ""
@export var jump_start: String = ""
@export var jump_loop: String = ""
@export var fall: String = ""
@export var attack_neutral: String = ""
@export var attack_air: String = ""
@export var hit_light: String = ""
@export var hit_heavy: String = ""
@export var tumble: String = ""
@export var ko: String = ""
@export var victory: String = ""

## Source resource paths keyed by semantic name (for audit / binding).
@export var source_paths: Dictionary = {}

## Playback speed overrides keyed by semantic name.
@export var playback_speeds: Dictionary = {}


func semantic_names() -> PackedStringArray:
	return PackedStringArray([
		"idle", "run", "jump_start", "jump_loop", "fall",
		"attack_neutral", "attack_air", "hit_light", "hit_heavy",
		"tumble", "ko", "victory"
	])


func clip_for(semantic: String) -> String:
	match semantic:
		"idle":
			return idle
		"run":
			return run if not run.is_empty() else idle
		"jump_start", "jump", "jump_loop":
			if semantic == "jump_loop" and not jump_loop.is_empty():
				return jump_loop
			return jump_start if not jump_start.is_empty() else idle
		"fall":
			return fall if not fall.is_empty() else (jump_start if not jump_start.is_empty() else idle)
		"attack_neutral", "attack":
			return attack_neutral
		"attack_air":
			return attack_air if not attack_air.is_empty() else attack_neutral
		"hit_light", "hit":
			return hit_light
		"hit_heavy":
			return hit_heavy if not hit_heavy.is_empty() else hit_light
		"tumble":
			return tumble if not tumble.is_empty() else (ko if not ko.is_empty() else hit_light)
		"ko":
			return ko
		"victory":
			return victory if not victory.is_empty() else idle
	return ""


func has_clip(semantic: String) -> bool:
	return not clip_for(semantic).is_empty()


func playback_speed_for(semantic: String, default_speed: float = 1.0) -> float:
	if playback_speeds.has(semantic):
		return float(playback_speeds[semantic])
	return default_speed


static func make_jaguarete_prototype() -> FighterAnimationSet:
	var set := FighterAnimationSet.new()
	set.idle = "idle"
	set.jump_start = "jump"
	set.attack_neutral = "attack_neutral"
	set.hit_light = "hit_light"
	set.ko = "ko"
	set.tumble = "ko"
	set.source_paths = {
		"idle": "res://assets/fighters/animations/Idle.fbx",
		"jump": "res://assets/fighters/animations/Unarmed Jump.fbx",
		"attack_neutral": "res://assets/fighters/animations/Mutant Punch.fbx",
		"hit_light": "res://assets/fighters/animations/Reaction.fbx",
		"ko": "res://assets/fighters/animations/Falling Back Death.fbx",
	}
	## Attack total = 0.10 + 0.12 + 0.24 = 0.46s; Mutant Punch ~1.1s -> ~2.39x
	set.playback_speeds = {
		"idle": 1.0,
		"jump": 1.15,
		"attack_neutral": 2.35,
		"hit_light": 1.25,
		"ko": 1.0,
	}
	return set
