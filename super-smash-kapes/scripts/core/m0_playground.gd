class_name M0Playground
extends Node3D

signal match_finished(winner_id: int, summary: Dictionary)
signal restart_requested

const FIGHTER_SCENE := preload("res://scenes/fighters/Fighter.tscn")
const BASIC_ATTACK := preload("res://data/attacks/basic_attack.tres")
const IMPACT_VFX := preload("res://scripts/vfx/impact_vfx.gd")
const SmashAudio := preload("res://scripts/core/smash_audio_v1.gd")
const StageCatalog := preload("res://scripts/stages/stage_catalog.gd")
const RESPAWN_DELAY := 1.15
const MATCH_SETUP := preload("res://scripts/core/match_setup.gd")
const FIGHTER_CATALOG := preload("res://scripts/fighters/fighter_catalog.gd")

@onready var hud: CanvasLayer = $HUD
var fighters: Array[Fighter] = []
var respawn_timers: Dictionary = {}
var match_over := false
var debug_enabled := false
var match_stats: Dictionary = {}
var stage_visual: Node3D
var _stage_meta: Dictionary = {}
var audit_elapsed: float = 0.0
var audit_next_heartbeat: float = 1.0
var audit_first_physics_logged: bool = false
var audit_first_input_logged: bool = false
var audit_last_paused: bool = false
var audit_last_match_over: bool = false
var freeze_audit_enabled: bool = OS.get_environment("SSK_FREEZE_AUDIT") == "1"
var combined_runtime_enabled: bool = OS.get_environment("SSK_DISABLE_STAGE_VISUALS") != "1" and OS.get_environment("SSK_DISABLE_HUD") != "1"
var combined_action_logged: Dictionary = {}
var match_setup = MATCH_SETUP.new()
## Read-only MCP snapshot. Does not change match rules.
var jeffrey_match_debug_state: Dictionary = {}

func _ready() -> void:
	_audit("scene ready")
	if match_setup == null:
		match_setup = FIGHTER_CATALOG.default_match_setup()
	_setup_stage()
	match_stats = {
		1: {"kos": 0, "falls": 0, "damage_dealt": 0.0, "damage_taken": 0.0, "attacks_connected": 0},
		2: {"kos": 0, "falls": 0, "damage_dealt": 0.0, "damage_taken": 0.0, "attacks_connected": 0}
	}
	var spawn_p1: Vector3 = _stage_meta.get("spawn_p1", Vector3(-4.0, 1.7, 0.0))
	var spawn_p2: Vector3 = _stage_meta.get("spawn_p2", Vector3(4.0, 1.7, 0.0))
	_spawn_fighter(1, spawn_p1, KapesVisual.P1_COLOR, match_setup.player_1_fighter_id)
	_spawn_fighter(2, spawn_p2, KapesVisual.P2_COLOR, match_setup.player_2_fighter_id)
	var stage_name := str(_stage_meta.get("display_name", ""))
	if stage_name != "" and hud.has_method("set_message"):
		hud.set_message(stage_name)
	hud.set_message("¡DALE!")
	SmashAudio.play_match_start(self)
	if OS.get_environment("SSK_DISABLE_HUD") == "1":
		hud.visible = false
		_audit("HUD disabled by SSK_DISABLE_HUD")
	_audit("fighters spawned; intro started; match active; fighter input enabled")
	_update_hud()
	call_deferred("_audit_combined_battle_focus")

func _physics_process(_delta: float) -> void:
	if freeze_audit_enabled:
		audit_elapsed += _delta
		if not audit_first_physics_logged:
			audit_first_physics_logged = true
			_audit("first physics tick")
		if audit_elapsed >= audit_next_heartbeat:
			audit_next_heartbeat += 1.0
			_audit("HEARTBEAT elapsed=%.2f fps=%.1f paused=%s match_over=%s P1=%s P2=%s" % [audit_elapsed, Engine.get_frames_per_second(), get_tree().paused, match_over, _audit_fighter_state(1), _audit_fighter_state(2)])
		var saw_input := Input.get_axis("p1_left", "p1_right") != 0.0 or Input.is_action_pressed("p1_attack") or Input.is_action_pressed("p1_jump") or Input.get_axis("p2_left", "p2_right") != 0.0 or Input.is_action_pressed("p2_attack") or Input.is_action_pressed("p2_jump")
		if saw_input and not audit_first_input_logged:
			audit_first_input_logged = true
			_audit("first player input received")
			_audit_combined_battle_focus("first gameplay input")
		_audit_combined_actions()
		if get_tree().paused != audit_last_paused:
			audit_last_paused = get_tree().paused
			_audit("paused changed to %s" % audit_last_paused)
		if match_over != audit_last_match_over:
			audit_last_match_over = match_over
			_audit("match state changed to %s" % ("MATCH_LOCKED" if match_over else "ACTIVE"))
	if Input.is_action_just_pressed("restart_match"):
		if get_parent() == get_tree().root:
			get_tree().reload_current_scene()
		else:
			restart_requested.emit()
		return
	if Input.is_action_just_pressed("toggle_debug"):
		debug_enabled = not debug_enabled
		print("M0 debug toggle: ", debug_enabled)
	if match_over:
		_refresh_jeffrey_match_debug_state()
		return
	for fighter in fighters:
		if not is_instance_valid(fighter) or not fighter.is_inside_tree():
			continue
		if fighter.state != Fighter.FighterState.DEAD and _outside_blast_zone(fighter.global_position):
			fighter.ko()
	var expired_respawns: Array[int] = []
	for fighter_id in respawn_timers.keys():
		respawn_timers[fighter_id] -= _delta
		if respawn_timers[fighter_id] <= 0.0:
			expired_respawns.append(fighter_id)
	for fighter_id in expired_respawns:
		var fighter: Fighter = _fighter_by_id(fighter_id)
		respawn_timers.erase(fighter_id)
		if fighter != null and fighter.stocks > 0 and not match_over:
			fighter.respawn()
			SmashAudio.play_respawn(self)
			print("P%d respawned" % fighter.player_id)
	_refresh_jeffrey_match_debug_state()

const GLB_FIGHTER_VISUAL := preload("res://scripts/fighters/glb_fighter_visual.gd")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F3:
		hud.set_performance_debug(not hud.performance_debug_enabled)
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F4:
		GLB_FIGHTER_VISUAL.debug_bounds_enabled = not GLB_FIGHTER_VISUAL.debug_bounds_enabled
		for fighter in fighters:
			var visual = fighter.character_visual
			if visual != null and visual.has_method("_refresh_bounds_debug"):
				visual._refresh_bounds_debug()

func _setup_stage() -> void:
	var stage_id := "defensores"
	if OS.get_environment("SSK_CAPTURE_STAGE_OVERRIDE") == "1" and OS.get_environment("SSK_STAGE_ID") != "":
		stage_id = OS.get_environment("SSK_STAGE_ID")
	elif match_setup != null and str(match_setup.stage_id) != "":
		stage_id = str(match_setup.stage_id)
	elif OS.get_environment("SSK_STAGE_ID") != "":
		stage_id = OS.get_environment("SSK_STAGE_ID")
	_stage_meta = StageCatalog.get_by_id(stage_id)
	if _stage_meta.is_empty():
		_stage_meta = StageCatalog.get_by_id(StageCatalog.DEFENSORES)
	var path := str(_stage_meta.get("scene_path", "res://scenes/stages/DefensoresDelChacoStage.tscn"))
	var packed := load(path) as PackedScene
	if packed == null:
		packed = load("res://scenes/stages/DefensoresDelChacoStage.tscn") as PackedScene
	var stage := packed.instantiate()
	add_child(stage)
	stage_visual = stage as Node3D
	_audit("stage ready id=%s" % str(_stage_meta.get("id", stage_id)))


func _spawn_fighter(id: int, position: Vector3, color: Color, fighter_id: String) -> void:
	var fighter: Fighter = FIGHTER_SCENE.instantiate()
	var definition = FIGHTER_CATALOG.get_by_id(fighter_id)
	fighter.player_id = id
	fighter.fighter_id = fighter_id
	fighter.display_color = color
	var label: String = definition.display_name if definition != null else "P%d" % id
	fighter.stats = _make_stats(label, fighter_id)
	fighter.attack_definition = _make_attack(fighter_id)
	fighter.position = position
	fighter.name = "Fighter" if id == 1 else "Fighter2"
	$FighterManager.add_child(fighter)
	fighters.append(fighter)
	fighter.fighter_ko.connect(_handle_ko)
	fighter.damage_changed.connect(_on_damage_changed)
	fighter.attack_connected.connect(_on_attack_connected)


func _make_stats(label: String, fighter_id: String = "") -> FighterStats:
	var stats := FighterStats.new()
	stats.fighter_name = label
	var profile: Dictionary = FIGHTER_CATALOG.gameplay_profile(fighter_id)
	if profile.has("walk_speed"):
		stats.walk_speed = float(profile["walk_speed"])
	if profile.has("jump_velocity"):
		stats.jump_velocity = float(profile["jump_velocity"])
	if profile.has("double_jump_velocity"):
		stats.double_jump_velocity = float(profile["double_jump_velocity"])
	if profile.has("weight"):
		stats.weight = float(profile["weight"])
	if profile.has("attack_damage"):
		stats.attack_damage = float(profile["attack_damage"])
	if profile.has("attack_base_knockback"):
		stats.attack_base_knockback = float(profile["attack_base_knockback"])
	if profile.has("attack_knockback_growth"):
		stats.attack_knockback_growth = float(profile["attack_knockback_growth"])
	return stats


func _make_attack(fighter_id: String) -> AttackDefinition:
	var attack: AttackDefinition = BASIC_ATTACK.duplicate(true) as AttackDefinition
	if attack == null:
		attack = BASIC_ATTACK
	var profile: Dictionary = FIGHTER_CATALOG.gameplay_profile(fighter_id)
	if profile.has("attack_damage"):
		attack.damage = float(profile["attack_damage"])
	if profile.has("attack_base_knockback"):
		attack.base_knockback = float(profile["attack_base_knockback"])
	if profile.has("attack_knockback_growth"):
		attack.knockback_growth = float(profile["attack_knockback_growth"])
	if profile.has("startup_seconds"):
		attack.startup_seconds = float(profile["startup_seconds"])
	if profile.has("active_seconds"):
		attack.active_seconds = float(profile["active_seconds"])
	if profile.has("recovery_seconds"):
		attack.recovery_seconds = float(profile["recovery_seconds"])
	return attack

func _handle_ko(fighter: Fighter) -> void:
	print("KO: P%d | stocks remaining: %d | damage: %.0f%%" % [fighter.player_id, fighter.stocks, fighter.damage_percent])
	match_stats[fighter.player_id]["falls"] += 1
	SmashAudio.play_ko(self)
	if hud.has_method("show_ko_flash"):
		hud.show_ko_flash(fighter.player_id, KapesVisual.player_color(fighter.player_id))
	else:
		hud.set_message("KO")
	if stage_visual != null:
		if fighter.stocks <= 0 and stage_visual.has_method("show_final_ko"):
			stage_visual.show_final_ko()
		elif stage_visual.has_method("show_ko"):
			stage_visual.show_ko()
	if fighter.stocks <= 0:
		fighter.eliminate()
		match_over = true
		for other in fighters:
			if is_instance_valid(other) and other.is_inside_tree():
				other.lock_match()
		var winner := 1 if fighter.player_id == 2 else 2
		var winner_fighter := _fighter_by_id(winner)
		var winner_name := winner_fighter.get_display_name() if winner_fighter != null else "P%d" % winner
		hud.set_message("%s GANA" % winner_name)
		SmashAudio.play_match_end(self)
		match_stats[winner]["kos"] += 1
		match_finished.emit(winner, _build_match_summary())
	else:
		respawn_timers[fighter.player_id] = RESPAWN_DELAY

func _on_damage_changed(fighter: Fighter) -> void:
	hud.update_fighter(fighter)

func _on_attack_connected(attacker: Fighter, victim: Fighter, knockback: float) -> void:
	print("P%d hit P%d: %.0f%% damage, %.2f knockback" % [attacker.player_id, victim.player_id, victim.damage_percent, knockback])
	match_stats[attacker.player_id]["damage_dealt"] += BASIC_ATTACK.damage
	match_stats[victim.player_id]["damage_taken"] += BASIC_ATTACK.damage
	match_stats[attacker.player_id]["attacks_connected"] += 1
	var impact: ImpactVFX = IMPACT_VFX.new()
	impact.tint = Color("#f5c66b") if knockback < 12.0 else Color("#f05a3c")
	impact.strength = clampf(knockback, 1.0, 18.0)
	impact.position = victim.global_position + Vector3(0.0, 1.2, 0.0)
	add_child(impact)
	SmashAudio.play_hit(self, knockback >= 12.0)

func _build_match_summary() -> Dictionary:
	var summary := match_stats.duplicate(true)
	summary["fighter_ids"] = {
		1: match_setup.player_1_fighter_id,
		2: match_setup.player_2_fighter_id,
	}
	summary["fighter_names"] = {}
	for id in [1, 2]:
		var fighter := _fighter_by_id(id)
		if fighter != null:
			summary["fighter_names"][id] = fighter.get_display_name()
	return summary

func _update_hud() -> void:
	for fighter in fighters:
		hud.update_fighter(fighter)

func _fighter_by_id(id: int) -> Fighter:
	for fighter in fighters:
		if fighter.player_id == id:
			return fighter
	return null


func _refresh_jeffrey_match_debug_state() -> void:
	var ids: Array = []
	var stocks_map: Dictionary = {}
	var damage_map: Dictionary = {}
	var ko_map: Dictionary = {}
	var winner: Variant = "UNAVAILABLE"
	for fighter in fighters:
		if not is_instance_valid(fighter):
			continue
		ids.append(fighter.fighter_id)
		stocks_map[fighter.player_id] = fighter.stocks
		damage_map[fighter.player_id] = fighter.damage_percent
		ko_map[fighter.player_id] = fighter.state == Fighter.FighterState.DEAD
	if match_over:
		for fighter in fighters:
			if is_instance_valid(fighter) and fighter.stocks > 0:
				winner = fighter.player_id
				break
	var phase := "match_over" if match_over else "active"
	if not respawn_timers.is_empty() and not match_over:
		phase = "respawn"
	jeffrey_match_debug_state = {
		"scene": "res://scenes/core/M0Playground.tscn",
		"active_players": fighters.size(),
		"fighter_ids": ids,
		"stocks": stocks_map,
		"damage": damage_map,
		"match_phase": phase,
		"ko_state": ko_map,
		"winner": winner,
		"mutating": false,
	}


func _audit(message: String) -> void:
	if freeze_audit_enabled:
		print("[FREEZE_AUDIT] t=%.3f %s" % [audit_elapsed, message])

func _audit_combined_battle_focus(context: String = "battle start") -> void:
	if not combined_runtime_enabled or not freeze_audit_enabled:
		return
	var focus_owner := get_viewport().gui_get_focus_owner()
	if focus_owner == null:
		print("[FREEZE_AUDIT] t=%.3f combined focus (%s): null" % [audit_elapsed, context])
	else:
		print("[FREEZE_AUDIT] t=%.3f combined focus (%s): %s" % [audit_elapsed, context, focus_owner.get_path()])

func _audit_combined_actions() -> void:
	if not combined_runtime_enabled or not freeze_audit_enabled:
		return
	var actions := {
		"P1 left": Input.is_action_just_pressed("p1_left"),
		"P1 right": Input.is_action_just_pressed("p1_right"),
		"P1 jump": Input.is_action_just_pressed("p1_jump"),
		"P1 attack": Input.is_action_just_pressed("p1_attack"),
		"P2 left": Input.is_action_just_pressed("p2_left"),
		"P2 right": Input.is_action_just_pressed("p2_right"),
		"P2 jump": Input.is_action_just_pressed("p2_jump"),
		"P2 attack": Input.is_action_just_pressed("p2_attack"),
	}
	for action_name in actions:
		if actions[action_name] and not combined_action_logged.has(action_name):
			combined_action_logged[action_name] = true
			print("[FREEZE_AUDIT] t=%.3f combined first action: %s" % [audit_elapsed, action_name])
			_audit_combined_battle_focus("first %s" % action_name)

func _audit_fighter_state(id: int) -> String:
	var fighter := _fighter_by_id(id)
	if fighter == null:
		return "MISSING"
	return "%s locked=%s" % [Fighter.FighterState.keys()[fighter.state], fighter.match_locked]

func _outside_blast_zone(position: Vector3) -> bool:
	var bmin: Vector3 = _stage_meta.get("blast_min", Vector3(-19.0, -10.0, -8.0))
	var bmax: Vector3 = _stage_meta.get("blast_max", Vector3(19.0, 18.0, 8.0))
	return position.x < bmin.x or position.x > bmax.x or position.y < bmin.y or position.y > bmax.y
