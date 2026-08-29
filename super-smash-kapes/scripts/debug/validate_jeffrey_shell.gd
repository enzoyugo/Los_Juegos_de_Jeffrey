extends Node

## Headless / CI validator for the Jeffrey multimode shell.
## Does not change Smash gameplay; instantiates the existing playground to
## confirm spawn/stocks wiring still matches the pre-migration baseline.

const PersistenceScript := preload("res://scripts/core/jeffrey/jeffrey_persistence.gd")
const ProfileStoreScript := preload("res://scripts/core/jeffrey/player_profile_store.gd")
const ModeRegistryScript := preload("res://scripts/core/jeffrey/game_mode_registry.gd")
const UiAssets := preload("res://scripts/ui/jeffrey/global_ui_assets.gd")

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_run")


func _run() -> void:
	var errors: PackedStringArray = PackedStringArray()
	if JeffreyCore == null:
		errors.append("JeffreyCore autoload missing")
		print("[JEFFREY_VALIDATE] FAIL JeffreyCore autoload missing")
		get_tree().quit(1)
		return
	await _check_registries(errors)
	_check_duplicates_and_session(errors)
	await _check_persistence(errors)
	await _check_smash_playground(errors)
	await _check_global_ui(errors)
	if errors.is_empty():
		print("[JEFFREY_VALIDATE] OK")
		get_tree().quit(0)
	else:
		for item in errors:
			push_error("[JEFFREY_VALIDATE] %s" % item)
			print("[JEFFREY_VALIDATE] FAIL %s" % item)
		get_tree().quit(1)


func _check_registries(errors: PackedStringArray) -> void:
	if JeffreyCore.modes.get_mode(ModeRegistryScript.MODE_SMASH) == null:
		errors.append("smash mode missing")
	else:
		var smash = JeffreyCore.modes.get_mode(ModeRegistryScript.MODE_SMASH)
		if smash.display_name != "Smash Kapes" or smash.min_players != 2 or smash.max_players != 4 or not smash.enabled:
			errors.append("smash mode metadata mismatch")
		if not ResourceLoader.exists(smash.scene_path):
			errors.append("smash scene_path missing: %s" % smash.scene_path)
	var racing = JeffreyCore.modes.get_mode(ModeRegistryScript.MODE_RACING)
	if racing == null or racing.enabled or racing.max_players != 10:
		errors.append("racing placeholder metadata mismatch")
	if racing != null and racing.availability != "development":
		errors.append("racing availability should be development")
	if racing != null and racing.status_label() != "EN DESARROLLO":
		errors.append("racing status_label mismatch")
	if racing != null and not ResourceLoader.exists(racing.scene_path):
		errors.append("racing greybox scene missing")
	if racing != null and racing.scene_path.find("TrackMain.tscn") < 0:
		errors.append("racing should point at Track greybox")
	var zombies = JeffreyCore.modes.get_mode(ModeRegistryScript.MODE_ZOMBIES)
	if zombies == null or zombies.enabled or zombies.max_players != 2:
		errors.append("zombies placeholder metadata mismatch")
	if zombies != null and zombies.availability != "development":
		errors.append("zombies availability should be development")
	if zombies != null and zombies.status_label() != "EN DESARROLLO":
		errors.append("zombies status_label mismatch")
	var smash = JeffreyCore.modes.get_mode(ModeRegistryScript.MODE_SMASH)
	if smash != null and smash.availability != "playable":
		errors.append("smash availability should be playable")
	if smash != null and smash.status_label() != "JUGAR":
		errors.append("smash status_label mismatch")
	if zombies != null and not ResourceLoader.exists(zombies.scene_path):
		errors.append("zombies greybox scene missing")
	if zombies != null and zombies.scene_path.find("ZombiesMain.tscn") < 0:
		errors.append("zombies should point at Zombies greybox")
	if JeffreyCore.characters.get_character("terere") == null:
		errors.append("CharacterRegistry missing terere")
	if JeffreyCore.characters.get_character("jaguarete") == null:
		errors.append("CharacterRegistry missing jaguarete")
	var gen = load("res://scripts/track/track_generator.gd")
	if gen == null:
		errors.append("TrackGenerator missing")
	else:
		var a = gen.new().generate(42, "media", "picante")
		var b = gen.new().generate(42, "media", "picante")
		if int(a.get("piece_count", 0)) < 5:
			errors.append("TrackGenerator produced too few pieces")
		if str(a.get("validation_result", "")) != "pass":
			errors.append("TrackGenerator validation_result mismatch")
		if int(a.get("piece_count", -1)) != int(b.get("piece_count", -2)):
			errors.append("TrackGenerator is not deterministic for a fixed seed")
		if absf(float(a.get("estimated_time", 0.0)) - float(b.get("estimated_time", 1.0))) > 0.001:
			errors.append("TrackGenerator estimated_time is not deterministic")
		if str(a.get("signature", "")) != str(b.get("signature", "")) or str(a.get("signature", "")).is_empty():
			errors.append("TrackGenerator signature is not deterministic")
		var unique: Dictionary = {}
		for i in 20:
			var sig := str(gen.new().generate(1000 + i * 17, "media", "picante").get("signature", ""))
			unique[sig] = true
		print("[TRACK_GEN] unique signatures in 20 seeds: %d" % unique.size())
		if unique.size() < 12:
			errors.append("TrackGenerator diversity too low (%d unique / 20)" % unique.size())
	_check_track_handling(errors)
	_check_last_dance_contract(errors)
	_check_per_player_fuel(errors)
	if not ResourceLoader.exists("res://scenes/debug/TrackPhysicsLab.tscn"):
		errors.append("TrackPhysicsLab.tscn missing")
	if not ResourceLoader.exists("res://scenes/debug/TrackWheelPhysicsLab.tscn"):
		errors.append("TrackWheelPhysicsLab.tscn missing")
	if not ResourceLoader.exists("res://scenes/track/TrackCarWheelPhysics.tscn"):
		errors.append("TrackCarWheelPhysics.tscn missing")
	if not ResourceLoader.exists("res://assets/vehicles/track/processed/track_car_base_v2_articulated.glb") and not FileAccess.file_exists("res://assets/vehicles/track/processed/track_car_base_v2_articulated.glb"):
		errors.append("track_car_base_v2_articulated.glb missing")
	_check_four_wheel_rnd(errors)
	if not ResourceLoader.exists("res://scenes/debug/TrackCarIngestLab.tscn"):
		errors.append("TrackCarIngestLab.tscn missing")
	if not ResourceLoader.exists("res://scenes/track/TrackCar.tscn"):
		errors.append("TrackCar.tscn missing")
	if not ResourceLoader.exists("res://assets/vehicles/track/source/track_car_base_v1.glb"):
		errors.append("track_car_base_v1.glb missing")
	_check_track_car_wrapper(errors)
	_check_race_clock_and_ghosts(errors)
	_check_road_and_rails(errors)
	_check_texture_sharing(errors)
	await _check_modular_kit_pilot(errors)
	_check_generator_v2(errors)
	await _check_articulated_extended(errors)
	if not ResourceLoader.exists("res://scenes/zombies/ZombiesMain.tscn"):
		errors.append("ZombiesMain.tscn missing")
	var waves_script = load("res://scripts/zombies/zombies_waves.gd")
	if waves_script == null:
		errors.append("ZombiesWaves missing")
	else:
		var waves = waves_script.new()
		var first: int = waves.next_count()
		if first < 1:
			errors.append("ZombiesWaves produced empty wave")
		if waves.wave != 1:
			errors.append("ZombiesWaves wave index mismatch")
	var zm_src := FileAccess.get_file_as_string("res://scripts/zombies/zombies_main.gd")
	if zm_src.find("session_exited") < 0:
		errors.append("ZombiesMain missing session_exited")
	if zm_src.find("func setup") < 0:
		errors.append("ZombiesMain missing setup")
	var zcfg := FileAccess.get_file_as_string("res://scripts/zombies/zombies_config.gd")
	if zcfg.find("z_interact") < 0 or zcfg.find("z_reload") < 0:
		errors.append("zombies interact/reload actions missing")
	if zcfg.find("GALERÍA") < 0:
		errors.append("zombies door name missing")
	var zpower := FileAccess.get_file_as_string("res://scripts/zombies/zombies_power_up.gd")
	if zpower.find("MAX AMMO") < 0:
		errors.append("MAX AMMO power-up missing")
	var zhud := FileAccess.get_file_as_string("res://scripts/zombies/zombies_hud.gd")
	if zhud.find("RONDA") < 0:
		errors.append("zombies HUD missing RONDA")
	if zhud.find("show_hit_marker") < 0:
		errors.append("zombies HUD missing hit marker")
	if zhud.find("_vignette") < 0:
		errors.append("zombies HUD missing damage vignette")
	if not FileAccess.file_exists("res://scripts/zombies/zombies_viewmodel.gd"):
		errors.append("zombies viewmodel missing")
	var zenemy := FileAccess.get_file_as_string("res://scripts/zombies/zombies_enemy.gd")
	if zenemy.find("slot_index") < 0:
		errors.append("zombies crowd slots missing")
	var zlab := FileAccess.get_file_as_string("res://scripts/debug/zombies_systems_lab.gd")
	if zlab.find("[ZOMBIES_CROWD]") < 0:
		errors.append("zombies crowd lab token missing")
	if not ResourceLoader.exists("res://scenes/debug/ZombiesSystemsLab.tscn"):
		errors.append("ZombiesSystemsLab.tscn missing")
	if load("res://scenes/debug/ZombiesSystemsLab.tscn") == null:
		errors.append("ZombiesSystemsLab failed to load")
	if load("res://data/zombies/pistol.tres") == null:
		errors.append("pistol.tres failed to load")
	if load("res://data/zombies/smg.tres") == null:
		errors.append("smg.tres failed to load")
	print("[ZOMBIES_VALIDATE] slice_tokens_ok")


func _check_track_handling(errors: PackedStringArray) -> void:
	var handling = load("res://scripts/track/track_handling.gd")
	if handling == null:
		errors.append("TrackHandling missing")
		return
	var later := float(handling.damp_lateral(18.0, 16.5, 0.016))
	if later >= 17.8:
		errors.append("lateral grip is not damping")
	var low := float(handling.steer_authority(0.0, 2.55, 0.88, 30.0))
	var high := float(handling.steer_authority(30.0, 2.55, 0.88, 30.0))
	if high >= low:
		errors.append("steering is not speed-sensitive")
	var brake_fast := float(handling.brake_or_reverse_delta(12.0, 1.0, 72.0, 18.0, 1.6, 0.016))
	var reverse_slow := float(handling.brake_or_reverse_delta(0.2, 1.0, 72.0, 18.0, 1.6, 0.016))
	if brake_fast >= 0.0:
		errors.append("brake should reduce forward speed")
	if absf(brake_fast) <= absf(reverse_slow):
		errors.append("high-speed brake should be stronger than reverse")
	if bool(handling.wants_drift(5.0, 1.0, 1.0, 1.0, 14.0, 0.28)):
		errors.append("drift must not start below entry speed")
	if not bool(handling.wants_drift(20.0, 0.5, 0.5, 0.0, 14.0, 0.28)):
		errors.append("brake+steer at speed should enter drift")
	if not bool(handling.is_countersteer(-0.6, 2.0)):
		errors.append("countersteer detection failed")


func _check_last_dance_contract(errors: PackedStringArray) -> void:
	var turns_script = load("res://scripts/track/track_turn_manager.gd")
	if turns_script == null:
		errors.append("TrackTurnManager missing")
		return
	var survive = turns_script.new()
	survive.setup([{"profile_id": "a"}, {"profile_id": "b"}], 10.0)
	survive.best_times["b"] = 20.0
	survive.fuel["a"] = 0.0
	var start: Dictionary = survive.begin_turn()
	if str(start.get("state", "")) != "last_dance":
		errors.append("fuel 0 should enter Last Dance")
	if str(survive.record_finish("a", 15.0)) != "survived":
		errors.append("Last Dance overtake should survive")
	var fail = turns_script.new()
	fail.setup([{"profile_id": "a"}, {"profile_id": "b"}], 10.0)
	fail.best_times["b"] = 10.0
	fail.fuel["a"] = 0.0
	fail.begin_turn()
	if str(fail.record_finish("a", 15.0)) != "eliminated":
		errors.append("Last Dance miss should eliminate")
	var give = turns_script.new()
	give.setup([{"profile_id": "a"}, {"profile_id": "b"}], 10.0)
	give.fuel["a"] = 0.0
	give.begin_turn()
	give.surrender("a")
	if not give.eliminated.has("a"):
		errors.append("Last Dance restart-from-start should eliminate")
	var three = turns_script.new()
	three.setup([{"profile_id": "a"}, {"profile_id": "b"}, {"profile_id": "c"}], 10.0)
	three.best_times["a"] = 10.0
	three.best_times["b"] = 11.0
	three.best_times["c"] = 12.0
	three.fuel["c"] = 0.0
	three.current_index = 2
	three.begin_turn()
	if str(three.record_finish("c", 10.5)) != "survived":
		errors.append("Last Dance 10.5 should pass B")
	if int(three.player_states["c"].last_dances_survived) < 1:
		errors.append("Last Dance survived count should increment")
	if absf(float(three.fuel["c"])) > 0.001:
		errors.append("clutch must not refill fuel")
	if not three.alive.has("c"):
		errors.append("clutch player should stay alive")
	three.begin_turn()
	if str(three.last_dance.get("c", "")) != "active":
		errors.append("fuel 0 should allow another Last Dance")
	var miss = turns_script.new()
	miss.setup([{"profile_id": "a"}, {"profile_id": "b"}, {"profile_id": "c"}], 10.0)
	miss.best_times["a"] = 10.0
	miss.best_times["b"] = 11.0
	miss.best_times["c"] = 12.0
	miss.fuel["c"] = 0.0
	miss.current_index = 2
	miss.begin_turn()
	if str(miss.record_finish("c", 11.5)) != "eliminated":
		errors.append("Last Dance 11.5 should not pass anyone")


func _check_per_player_fuel(errors: PackedStringArray) -> void:
	var turns_script = load("res://scripts/track/track_turn_manager.gd")
	if turns_script == null:
		return
	var turns = turns_script.new()
	turns.setup([{"profile_id": "a"}, {"profile_id": "b"}], 10.0)
	var start_a := float(turns.fuel["a"])
	var start_b := float(turns.fuel["b"])
	if absf(start_a - start_b) > 0.001:
		errors.append("both players should start with the same personal fuel")
	turns.consume_fuel("a", 10.0)
	if absf(float(turns.fuel["a"]) - (start_a - 10.0)) > 0.05:
		errors.append("only driver A fuel should drop by 10")
	if absf(float(turns.fuel["b"]) - start_b) > 0.05:
		errors.append("player B fuel must stay frozen while A drives")
	turns.consume_fuel("b", 6.0)
	if absf(float(turns.fuel["a"]) - (start_a - 10.0)) > 0.05:
		errors.append("player A fuel must stay frozen while B drives")
	if absf(float(turns.fuel["b"]) - (start_b - 6.0)) > 0.05:
		errors.append("only driver B fuel should drop by 6")


func _check_track_car_wrapper(errors: PackedStringArray) -> void:
	var packed: PackedScene = load("res://scenes/track/TrackCar.tscn") as PackedScene
	if packed == null:
		errors.append("TrackCar.tscn failed to load")
		return
	var car = packed.instantiate()
	add_child(car)
	var col = car.get_node_or_null("CollisionShape3D")
	if col == null or not (col is CollisionShape3D):
		errors.append("TrackCar missing CollisionShape3D")
	else:
		var shape = (col as CollisionShape3D).shape
		if not (shape is BoxShape3D):
			errors.append("TrackCar gameplay collider must be BoxShape3D")
		if shape is ConcavePolygonShape3D:
			errors.append("TrackCar must not use trimesh as gameplay collider")
	if car.get_node_or_null("VisualRoot") == null:
		errors.append("TrackCar missing VisualRoot")
	if car.get_node_or_null("CameraAnchor") == null:
		errors.append("TrackCar missing CameraAnchor")
	if car.get_node_or_null("DriverHeadAnchor") == null:
		errors.append("TrackCar missing DriverHeadAnchor")
	if not car.has_method("set_character_visual") or not car.has_method("set_player_accent"):
		errors.append("TrackCar cosmetic hooks missing")
	if _has_concave_shape(car):
		errors.append("TrackCar tree contains ConcavePolygonShape3D")
	var vis = car.get_node_or_null("VisualRoot")
	if vis != null:
		var imported = vis.get_node_or_null("ImportedCar")
		if imported != null and _has_enabled_collision(imported):
			errors.append("imported car visual must not own gameplay collision")
	car.queue_free()
	var ghost_script = load("res://scripts/track/track_ghost_player.gd")
	if ghost_script == null:
		errors.append("TrackGhostPlayer missing")
	else:
		var ghost = ghost_script.new()
		if ghost is CharacterBody3D:
			errors.append("ghost must not be a physics controller")
		add_child(ghost)
		if _has_enabled_collision(ghost):
			errors.append("ghost visual must not enable collision")
		ghost.queue_free()
	var lab_packed: PackedScene = load("res://scenes/debug/TrackCarIngestLab.tscn") as PackedScene
	if lab_packed == null:
		errors.append("TrackCarIngestLab.tscn failed to load")
	else:
		var lab = lab_packed.instantiate()
		add_child(lab)
		if lab.get_node_or_null("ImportedCar") == null and lab.get_node_or_null("DebugCamera") == null:
			errors.append("TrackCarIngestLab failed to build inspect nodes")
		lab.queue_free()


func _check_race_clock_and_ghosts(errors: PackedStringArray) -> void:
	var clock_script = load("res://scripts/track/track_race_clock.gd")
	if clock_script == null:
		errors.append("TrackRaceClock missing")
		return
	var clock = clock_script.new()
	clock.begin_countdown(3.0)
	clock.tick(1.0)
	if str(clock.state) != "countdown" or absf(float(clock.elapsed)) > 0.001:
		errors.append("countdown t=1 must keep elapsed at 0")
	var ev := str(clock.tick(2.1))
	if ev != "started" or str(clock.state) != "active":
		errors.append("countdown finish must emit started and enter ACTIVE")
	if absf(float(clock.elapsed)) > 0.001:
		errors.append("ACTIVE start elapsed must be 0")
	clock.tick(0.5)
	if absf(float(clock.elapsed) - 0.5) > 0.02:
		errors.append("ACTIVE elapsed should track race time")
	var ghost_script = load("res://scripts/track/track_ghost_player.gd")
	var ghost = ghost_script.new()
	add_child(ghost)
	var a := Transform3D(Basis.IDENTITY, Vector3(0, 0, 0))
	var b := Transform3D(Basis.IDENTITY, Vector3(0, 0, -30))
	var samples: Array = []
	for i in 61:
		samples.append(a.interpolate_with(b, float(i) / 60.0))
	ghost.setup("p", samples)
	if bool(ghost.playing) or bool(ghost.visible):
		errors.append("ghost must stay hidden until ACTIVE")
	var t0: Transform3D = ghost.get_transform_at_time(0.0)
	if t0.origin.distance_to(a.origin) > 0.05:
		errors.append("ghost t=0 must match recorded start")
	ghost.begin_playback()
	if not bool(ghost.playing) or ghost.global_transform.origin.distance_to(a.origin) > 0.05:
		errors.append("ACTIVE first frame must be sample 0")
	ghost.set_elapsed(3.0)
	var t3: Transform3D = ghost.get_transform_at_time(3.0)
	if ghost.global_transform.origin.distance_to(t3.origin) > 0.05:
		errors.append("ghost elapsed lookup mismatch")
	if t3.origin.distance_to(a.origin) < 1.0:
		errors.append("ghost at t=3 must not still be the start sample")
	ghost.queue_free()


func _check_road_and_rails(errors: PackedStringArray) -> void:
	var gen = load("res://scripts/track/track_generator.gd")
	if gen == null:
		return
	var data: Dictionary = gen.new().generate(7, "corta", "picante")
	if absf(float(data.get("road_width", 0.0)) - 11.0) > 0.01:
		errors.append("road_width should be 11")
	var rails := 0
	var roads := 0
	for item in data.get("solids", []):
		var kind := str(item.get("kind", "road"))
		if kind == "rail":
			rails += 1
		if kind == "road":
			roads += 1
			if absf(float(item["size"].x) - 11.0) > 1.6 and absf(float(item["size"].x) - 12.5) > 0.2:
				errors.append("road slab width unexpected: %s" % str(item["size"].x))
				break
	if rails < 4 or roads < 2:
		errors.append("generator should emit road + guardrails")


func _check_texture_sharing(errors: PackedStringArray) -> void:
	var vis_script = load("res://scripts/track/track_car_visual.gd")
	if vis_script == null:
		return
	var cfg = load("res://scripts/track/track_car_visual_config.gd")
	if cfg == null or not ResourceLoader.exists(str(cfg.SHARED_ATLAS)):
		errors.append("canonical shared track car atlas missing")
	if not FileAccess.file_exists("res://assets/stages/defensores_del_chaco/platforms/defensores_platform_kit.png"):
		errors.append("defensores_platform_kit.png missing")
	var a = vis_script.new()
	a.ghost_mode = false
	add_child(a)
	var b = vis_script.new()
	b.ghost_mode = true
	add_child(b)
	var id_a: int = int(vis_script.shared_atlas_id())
	var id_b: int = int(vis_script.shared_atlas_id())
	print("[TRACK_CAR_VISUAL] share_check atlas_id=%d ghost_mat=%d path=%s" % [
		id_a,
		int(vis_script.ghost_material_id()),
		str(vis_script.atlas_resource_path()),
	])
	if id_a == 0 or id_a != id_b:
		errors.append("player and ghost must share the same atlas resource")
	var atlas_path := str(vis_script.atlas_resource_path())
	if atlas_path.find("track_car_base_v1_Modelo") < 0:
		errors.append("runtime atlas must be the canonical extracted source albedo")
	a.queue_free()
	b.queue_free()


func _check_modular_kit_pilot(errors: PackedStringArray) -> void:
	var cfg = load("res://scripts/track/track_config.gd")
	if cfg == null or str(cfg.CONTROLLER_MODE) != "BASELINE":
		errors.append("Track production CONTROLLER_MODE must remain BASELINE")
	if not FileAccess.file_exists("res://data/track/modules/track_kit_v1.json"):
		errors.append("track_kit_v1.json missing")
		return
	var kit = JSON.parse_string(FileAccess.get_file_as_string("res://data/track/modules/track_kit_v1.json"))
	if not (kit is Dictionary):
		errors.append("track_kit_v1.json failed to parse")
		return
	var contract: Dictionary = kit.get("contract", {})
	if absf(float(contract.get("road_width_m", 0.0)) - 11.0) > 0.001:
		errors.append("pilot contract road_width must be 11.0")
	if absf(float(contract.get("shoulder_m", 0.0)) - 0.7) > 0.001:
		errors.append("pilot contract shoulder must be 0.7")
	if absf(float(contract.get("guardrail_height_m", 0.0)) - 0.9) > 0.001:
		errors.append("pilot contract guardrail height must be 0.9")
	var ids: Array = kit.get("pilot_ids", [])
	if ids != ["start", "straight_medium", "curve_l_45", "curve_r_45", "finish"]:
		errors.append("pilot_ids must remain the 5-piece sequence")
	var glbs := {
		"start": "res://assets/track/modules/generated/core/track_start_v1.glb",
		"straight_medium": "res://assets/track/modules/generated/core/track_straight_medium_v1.glb",
		"curve_l_45": "res://assets/track/modules/generated/core/track_curve_l_45_v1.glb",
		"curve_r_45": "res://assets/track/modules/generated/core/track_curve_r_45_v1.glb",
		"finish": "res://assets/track/modules/generated/core/track_finish_v1.glb",
	}
	for piece_id in glbs.keys():
		var path := str(glbs[piece_id])
		if not FileAccess.file_exists(path) and not ResourceLoader.exists(path):
			errors.append("pilot glb missing: %s" % path)
	for mat_path in [
		"res://assets/track/materials/track_asphalt_v1.tres",
		"res://assets/track/materials/track_shoulder_v1.tres",
		"res://assets/track/materials/track_guardrail_v1.tres",
		"res://assets/track/materials/track_marker_v1.tres",
	]:
		if not ResourceLoader.exists(mat_path):
			errors.append("shared track material missing: %s" % mat_path)
	if not ResourceLoader.exists("res://scenes/track/modules/TrackPiece.tscn"):
		errors.append("TrackPiece.tscn missing")
	if not ResourceLoader.exists("res://scenes/debug/TrackModularKitPilotLab.tscn"):
		errors.append("TrackModularKitPilotLab.tscn missing")
	var piece_scene: PackedScene = load("res://scenes/track/modules/TrackPiece.tscn") as PackedScene
	if piece_scene == null:
		errors.append("TrackPiece.tscn failed to load")
		return
	var host := Node3D.new()
	host.name = "PilotHost"
	add_child(host)
	var pieces: Array = []
	var target := Transform3D.IDENTITY
	for piece_id in ids:
		var piece = piece_scene.instantiate()
		piece.piece_id = str(piece_id)
		host.add_child(piece)
		piece.align_entry_to(target)
		pieces.append(piece)
		if piece.get("entry") == null or piece.get("exit") == null:
			errors.append("%s missing ENTRY/EXIT" % piece_id)
		if int(piece.call("collision_count")) < 1:
			errors.append("%s missing generated collision" % piece_id)
		if not bool(piece.call("uses_shared_materials")):
			errors.append("%s did not bind shared materials" % piece_id)
		if absf(float(piece.meta.get("road_width", 0.0)) - 11.0) > 0.001:
			errors.append("%s road_width drifted" % piece_id)
		target = piece.exit_global()
	if pieces.size() != 5:
		errors.append("pilot assembly did not instantiate 5 pieces")
	else:
		if pieces[0].player_spawn == null:
			errors.append("start missing PLAYER_SPAWN")
		if pieces[4].finish_anchor == null:
			errors.append("finish missing FINISH_TRIGGER_ANCHOR")
		if pieces[4].finish_area == null:
			errors.append("finish missing Area3D trigger")
		for i in range(pieces.size() - 1):
			var a: Transform3D = pieces[i].exit_global()
			var b: Transform3D = pieces[i + 1].entry_global()
			var pos: float = a.origin.distance_to(b.origin)
			var yaw: float = absf(rad_to_deg((-a.basis.z).signed_angle_to(-b.basis.z, Vector3.UP)))
			var up: float = rad_to_deg(a.basis.y.angle_to(b.basis.y))
			print("[TRACK_PILOT_VALIDATE] %s->%s pos=%.6f yaw=%.4f up=%.4f" % [
				pieces[i].piece_id, pieces[i + 1].piece_id, pos, yaw, up
			])
			if pos > 0.0005:
				errors.append("connector position delta too large at %s->%s" % [pieces[i].piece_id, pieces[i + 1].piece_id])
			if yaw > 0.05 or up > 0.05:
				errors.append("connector rotation delta too large at %s->%s" % [pieces[i].piece_id, pieces[i + 1].piece_id])
	for _i in 2:
		await get_tree().physics_frame
	var four: PackedScene = load("res://scenes/track/TrackCarWheelPhysics.tscn") as PackedScene
	if four != null and pieces.size() > 0 and pieces[0].player_spawn != null:
		var spawn_xf: Transform3D = pieces[0].player_spawn.global_transform
		var space := host.get_world_3d().direct_space_state
		var ray := PhysicsRayQueryParameters3D.create(
			spawn_xf.origin + Vector3(0.0, 0.4, 0.0),
			spawn_xf.origin + Vector3(0.0, -2.5, 0.0)
		)
		ray.collision_mask = 1
		var hit: Dictionary = space.intersect_ray(ray)
		print("[TRACK_PILOT_VALIDATE] spawn_road_ray hit=%s y=%s" % [
			str(not hit.is_empty()),
			str(hit.get("position", Vector3.ZERO).y),
		])
		if hit.is_empty():
			errors.append("spawn ray did not hit road collision")
		var car = four.instantiate()
		host.add_child(car)
		if car.has_method("reset_to"):
			car.call("reset_to", spawn_xf)
		else:
			car.global_transform = spawn_xf
		for _i in 48:
			await get_tree().physics_frame
		var grounded := 0
		var wheel_n := 0
		if car.has_method("wheels"):
			for w in car.call("wheels"):
				wheel_n += 1
				if w != null and bool(w.is_grounded):
					grounded += 1
		print("[TRACK_PILOT_VALIDATE] 4WHEEL spawn grounded=%d/%d y=%.3f" % [
			grounded, wheel_n, car.global_position.y
		])
		if grounded < 2:
			errors.append("4WHEEL spawn did not find road contact")
		car.queue_free()
	host.queue_free()
	await get_tree().process_frame


func _check_generator_v2(errors: PackedStringArray) -> void:
	var cfg = load("res://scripts/track/track_config.gd")
	if cfg == null or str(cfg.CONTROLLER_MODE) != "BASELINE":
		errors.append("Track production CONTROLLER_MODE must remain BASELINE")
	var race_src := FileAccess.get_file_as_string("res://scripts/track/track_race.gd")
	if race_src.find("track_generator.gd") < 0:
		errors.append("TrackMain race path missing V1 TrackGenerator")
	if race_src.find("track_generator_v2") >= 0:
		errors.append("TrackMain must not switch to generator V2")
	if not ResourceLoader.exists("res://scenes/debug/TrackGeneratorV2Lab.tscn"):
		errors.append("TrackGeneratorV2Lab.tscn missing")
	if not ResourceLoader.exists("res://scenes/debug/TrackTurboV8Showcase.tscn"):
		errors.append("TrackTurboV8Showcase.tscn missing")
	if not ResourceLoader.exists("res://scenes/debug/ShoppingBlenderEnvironmentV1Lab.tscn"):
		errors.append("ShoppingBlenderEnvironmentV1Lab.tscn missing")
	if not ResourceLoader.exists("res://scenes/debug/TrackBoostResetLab.tscn"):
		errors.append("TrackBoostResetLab.tscn missing")
	if not ResourceLoader.exists("res://scenes/debug/TrackBoostDeltaLab.tscn"):
		errors.append("TrackBoostDeltaLab.tscn missing")
	var tcfg_src := FileAccess.get_file_as_string("res://scripts/track/track_config.gd")
	if tcfg_src.find("BOOST_OVERSPEED := 1.22") < 0:
		errors.append("BOOST_OVERSPEED missing")
	if tcfg_src.find("BOOST_DURATION := 0.85") < 0:
		errors.append("BOOST_DURATION missing")
	var baseline_boost := FileAccess.get_file_as_string("res://scripts/track/track_car_controller.gd")
	if baseline_boost.find("MAX_SPEED * Config.BOOST_OVERSPEED") < 0:
		errors.append("BASELINE boost overspeed cap missing")
	var ext_cam := FileAccess.get_file_as_string("res://scripts/track/track_extended_debug_camera.gd")
	if ext_cam.find("MODE_LANDING_CLOSE") < 0:
		errors.append("LANDING_CLOSE camera missing")
	for v3_glb in [
		"res://assets/track/modules/generated/core/track_straight_short_v1.glb",
		"res://assets/track/modules/generated/core/track_straight_long_v1.glb",
		"res://assets/track/modules/generated/core/track_curve_l_90_v1.glb",
		"res://assets/track/modules/generated/core/track_curve_r_90_v1.glb",
		"res://assets/track/modules/generated/core/track_chicane_lr_v1.glb",
		"res://assets/track/modules/generated/core/track_chicane_rl_v1.glb",
	]:
		if not FileAccess.file_exists(v3_glb) and not ResourceLoader.exists(v3_glb):
			errors.append("v3 kit glb missing: %s" % v3_glb)
	if not FileAccess.file_exists("res://data/track/generator_v2_showcases.json"):
		errors.append("generator_v2_showcases.json missing")
		return
	var piece_src := FileAccess.get_file_as_string("res://scripts/track/track_piece.gd")
	if piece_src.find("rearm_boost_trigger") < 0:
		errors.append("boost rearm missing on TrackPiece")
	var asphalt := FileAccess.get_file_as_string("res://assets/track/materials/track_asphalt_v1.tres")
	if asphalt.find("NoiseTexture2D") < 0:
		errors.append("asphalt missing NoiseTexture2D")
	var gen_script = load("res://scripts/track/track_generator_v2.gd")
	if gen_script == null:
		errors.append("TrackGeneratorV2 missing")
		return
	var show_raw = JSON.parse_string(FileAccess.get_file_as_string("res://data/track/generator_v2_showcases.json"))
	if not (show_raw is Dictionary):
		errors.append("generator_v2_showcases.json failed to parse")
		return
	var show: Dictionary = show_raw
	var union_ids: Dictionary = {}
	var gen = gen_script.new()
	for key in ["SHORT_SHOWCASE", "MEDIUM_SHOWCASE", "LONG_SHOWCASE"]:
		if not show.has(key):
			errors.append("showcase %s missing" % key)
			continue
		var row = show[key]
		if not (row is Dictionary):
			errors.append("showcase %s is not a dictionary" % key)
			continue
		var seed_v: int = int(row.get("seed", 0))
		var length_v: String = str(row.get("length", ""))
		var diff_v: String = str(row.get("difficulty", ""))
		var seq = row.get("piece_sequence", [])
		if seq is Array:
			for pid in seq:
				union_ids[str(pid)] = true
		var result = gen.generate(seed_v, length_v, diff_v)
		if not (result is Dictionary):
			errors.append("showcase %s generate returned non-dict" % key)
			continue
		if not bool(result.get("accepted", false)):
			errors.append("showcase %s not accepted" % key)
	if not union_ids.has("straight_short") or not union_ids.has("straight_long"):
		errors.append("showcases missing short/long straights")
	if not union_ids.has("boost_straight"):
		errors.append("showcases missing boost_straight")
	if not (union_ids.has("curve_l_90") or union_ids.has("curve_r_90")):
		errors.append("showcases missing 90 curve")
	if not (union_ids.has("chicane_lr") or union_ids.has("chicane_rl")):
		errors.append("showcases missing chicane")
	var lab_src := FileAccess.get_file_as_string("res://scripts/track/track_generator_v2_lab.gd")
	if lab_src.find("KEY_F2") < 0:
		errors.append("TrackGeneratorV2Lab missing F2 controller toggle")
	if lab_src.find("TrackCarWheelPhysics.tscn") < 0:
		errors.append("TrackGeneratorV2Lab missing 4WHEEL scene path")
	if lab_src.find("MODE_FOUR_WHEEL") < 0:
		errors.append("TrackGeneratorV2Lab missing 4WHEEL mode")
	if not ResourceLoader.exists("res://scenes/debug/ShoppingZombiesIntegrationLab.tscn"):
		errors.append("ShoppingZombiesIntegrationLab.tscn missing")
	var lab_packed = load("res://scenes/debug/TrackGeneratorV2Lab.tscn")
	if lab_packed == null:
		errors.append("TrackGeneratorV2Lab failed to load")
	var boost_packed = load("res://scenes/debug/TrackBoostResetLab.tscn")
	if boost_packed == null:
		errors.append("TrackBoostResetLab failed to load")
	var delta_packed = load("res://scenes/debug/TrackBoostDeltaLab.tscn")
	if delta_packed == null:
		errors.append("TrackBoostDeltaLab failed to load")


func _check_articulated_extended(errors: PackedStringArray) -> void:
	if not ResourceLoader.exists("res://scenes/debug/Track4WheelExtendedPhysicsLab.tscn"):
		errors.append("Track4WheelExtendedPhysicsLab.tscn missing")
	for path in [
		"res://assets/track/modules/generated/core/track_ramp_small_v1.glb",
		"res://assets/track/modules/generated/core/track_jump_small_v1.glb",
		"res://assets/track/modules/generated/core/track_boost_straight_v1.glb",
		"res://assets/track/modules/generated/core/track_landing_straight_long_v1.glb",
		"res://assets/track/modules/generated/core/track_ramp_takeoff_v1.glb",
		"res://assets/track/modules/generated/core/track_gap_logical_v1.glb",
	]:
		if not FileAccess.file_exists(path) and not ResourceLoader.exists(path):
			errors.append("extended glb missing: %s" % path)
	var vis_cfg = load("res://scripts/track/track_car_visual_config.gd")
	if vis_cfg == null:
		errors.append("TrackCarVisualConfig missing")
		return
	if absf(float(vis_cfg.ARTICULATED_BODY_YAW_DEGREES)) > 0.01:
		errors.append("articulated Body yaw must be 0 (processed mesh is already -Z-nose)")
	if absf(float(vis_cfg.ARTICULATED_VISUAL_YAW_DEGREES)) > 0.01:
		errors.append("articulated VisualRoot yaw must be 0")
	if absf(float(vis_cfg.SOURCE_VISUAL_YAW_DEGREES) - 180.0) > 0.01:
		errors.append("source visual yaw must stay 180")
	var v3_path := "res://assets/vehicles/track/processed/track_car_base_v3_articulated_clean.glb"
	if not ResourceLoader.exists(v3_path) and not FileAccess.file_exists(v3_path):
		errors.append("track_car_base_v3_articulated_clean.glb missing")
	if str(vis_cfg.PROCESSED_ARTICULATED_GLB).find("v3_articulated_clean") < 0:
		errors.append("4WHEEL visual candidate must be V3 clean GLB")
	if not ResourceLoader.exists("res://scenes/debug/TrackCarSemanticOrientationLab.tscn"):
		errors.append("TrackCarSemanticOrientationLab.tscn missing")
	if not ResourceLoader.exists("res://scenes/debug/TrackCarArticulatedIntegrityLab.tscn"):
		errors.append("TrackCarArticulatedIntegrityLab.tscn missing")
	for node in get_tree().get_nodes_in_group("track_runtime_car"):
		if node.get_parent() != null:
			node.get_parent().remove_child(node)
		node.free()
	await get_tree().process_frame
	var packed: PackedScene = load("res://scenes/track/TrackCarWheelPhysics.tscn") as PackedScene
	if packed == null:
		errors.append("TrackCarWheelPhysics.tscn failed to load for articulated check")
		return
	var car = packed.instantiate()
	add_child(car)
	if car is RigidBody3D:
		(car as RigidBody3D).freeze = true
		(car as RigidBody3D).linear_velocity = Vector3.ZERO
		(car as RigidBody3D).angular_velocity = Vector3.ZERO
	await get_tree().process_frame
	await get_tree().process_frame
	var vis = car.get_node_or_null("VisualRoot")
	if vis == null:
		errors.append("articulated VisualRoot missing")
		car.free()
		return
	var chassis_f: Vector3 = vis.chassis_forward()
	var visual_f: Vector3 = vis.visual_forward()
	var geo_f: Vector3 = vis.geometric_forward()
	var nose_f: Vector3 = vis.body_model_nose()
	var sem_f: Vector3 = vis.semantic_forward() if vis.has_method("semantic_forward") else nose_f
	var track_f := Vector3(0, 0, -1)
	print("[TRACK_4WHEEL_ORIENT] chassis=%s visual=%s geometric=%s nose=%s semantic=%s track=%s" % [
		str(chassis_f), str(visual_f), str(geo_f), str(nose_f), str(sem_f), str(track_f)
	])
	if chassis_f.dot(track_f) < 0.92:
		errors.append("chassis forward does not align with track -Z")
	if visual_f.dot(chassis_f) < 0.92:
		errors.append("articulated visual forward does not align with chassis -Z")
	if geo_f.dot(track_f) < 0.92:
		errors.append("geometric axle forward does not align with track -Z")
	if nose_f.dot(geo_f) < 0.92:
		errors.append("body mesh nose does not agree with front axle geometry")
	if sem_f.dot(track_f) < 0.92:
		errors.append("NOSE_MARKER-REAR_MARKER semantic forward is not -Z")
	const CENTER_TOL := 0.001
	for wid in ["FL", "FR", "RL", "RR"]:
		var rest: Vector3 = vis.wheel_mesh_rest_local(wid)
		print("[TRACK_4WHEEL_REST] %s rest=%s" % [wid, str(rest)])
		if rest.length() > 0.08:
			errors.append("%s wheel mesh rest is not near axle (possible double translate)" % wid)
		var c0: Vector3 = vis.wheel_center_global(wid)
		vis.debug_apply_wheel_pose(wid, 0.436332, 0.0, 0.0)
		var c_steer: Vector3 = vis.wheel_center_global(wid)
		var spin_fail := false
		for ang in [0.0, PI * 0.5, PI, PI * 1.5, TAU]:
			vis.debug_apply_wheel_pose(wid, 0.0, ang, 0.0)
			if c0.distance_to(vis.wheel_center_global(wid)) > CENTER_TOL:
				spin_fail = true
		vis.debug_apply_wheel_pose(wid, 0.0, 0.0, 0.08)
		var c_susp: Vector3 = vis.wheel_center_global(wid)
		vis.debug_apply_wheel_pose(wid, 0.436332, 1.2, 0.08)
		var c_full: Vector3 = vis.wheel_center_global(wid)
		vis.debug_apply_wheel_pose(wid, 0.0, 0.0, 0.0)
		print("[TRACK_4WHEEL_CENTER] %s d_steer=%.6f d_spin_fail=%s d_susp=%s d_full_vs_susp=%.6f" % [
			wid,
			c0.distance_to(c_steer),
			str(spin_fail),
			str(c_susp - c0),
			c_full.distance_to(c_susp),
		])
		if c0.distance_to(c_steer) > CENTER_TOL:
			errors.append("%s STEER_ONLY moved wheel center" % wid)
		if spin_fail:
			errors.append("%s SPIN_ONLY moved wheel center" % wid)
		var susp_delta: Vector3 = c_susp - c0
		if absf(susp_delta.x) > 0.02 or absf(susp_delta.z) > 0.02:
			errors.append("%s SUSPENSION_ONLY moved off suspension axis" % wid)
		if absf(susp_delta.y) < 0.01:
			errors.append("%s SUSPENSION_ONLY did not translate along Y" % wid)
		if c_full.distance_to(c_susp) > CENTER_TOL:
			errors.append("%s FULL articulation drifted off suspension path" % wid)
		vis.set_articulation_mode(1)
		vis.apply_wheel_states([{
			"id": wid, "steer": 0.45, "spin": 0.0, "length": 0.12, "rest": 0.12,
		}], 0.016)
		if not str(wid).begins_with("F"):
			var steer_p: Node3D = vis.wheel_bind(wid).get("steer")
			if steer_p != null and absf(steer_p.rotation.y) > 0.0001:
				errors.append("%s STEER_ONLY applied rear steer transform" % wid)
		vis.set_articulation_mode(4)
		vis.debug_apply_wheel_pose(wid, 0.0, 0.0, 0.0)
		if vis.has_method("wheel_max_radius_local"):
			var rloc: float = vis.wheel_max_radius_local(wid)
			var rworld: float = rloc * float(vis_cfg.VISUAL_SCALE)
			print("[TRACK_4WHEEL_RADIUS] %s local=%.4f world=%.4f" % [wid, rloc, rworld])
			if rworld > 0.45:
				errors.append("%s wheel max radius not compact (%.3f m world)" % [wid, rworld])
	if car.get_parent() != null:
		remove_child(car)
	car.free()
	var car2 = packed.instantiate()
	add_child(car2)
	await get_tree().process_frame
	var live := get_tree().get_nodes_in_group("track_runtime_car").size()
	print("[TRACK_4WHEEL_LIVE] live_track_car_count=%d" % live)
	if live != 1:
		errors.append("live_track_car_count expected 1 after toggle, got %d" % live)
	if car2.get_parent() != null:
		remove_child(car2)
	car2.free()
	var piece_scene: PackedScene = load("res://scenes/track/modules/TrackPiece.tscn") as PackedScene
	if piece_scene == null:
		errors.append("TrackPiece.tscn failed to load for boost check")
		return
	var host := Node3D.new()
	add_child(host)
	var boost = piece_scene.instantiate()
	boost.piece_id = "boost_straight"
	host.add_child(boost)
	await get_tree().process_frame
	if boost.boost_area == null:
		errors.append("boost_straight missing BoostTrigger Area3D")
	else:
		if boost.boost_area.collision_layer != 0:
			errors.append("boost Area3D must not physically block")
		if boost.boost_area.collision_mask != 2:
			errors.append("boost Area3D mask should detect the car layer")
		var fwd: Vector3 = -boost.global_transform.basis.z
		if fwd.dot(Vector3(0, 0, -1)) < 0.92:
			errors.append("boost piece forward is not -Z at identity")
	var four_src := FileAccess.get_file_as_string("res://scripts/track/track_wheel_car.gd")
	if four_src.find("TRACK_4WHEEL_LANDING") < 0:
		errors.append("landing telemetry window missing")
	if four_src.find("SPAWN_SETTLE") < 0:
		errors.append("airborne reason SPAWN_SETTLE missing")
	if four_src.find("AIR_DEBOUNCE_FRAMES") < 0:
		errors.append("airborne debounce missing")
	var wheel_src := FileAccess.get_file_as_string("res://scripts/track/track_arcade_wheel.gd")
	if wheel_src.find("compression_m") < 0:
		errors.append("compression_m authority missing")
	var lab_src := FileAccess.get_file_as_string("res://scripts/track/track_4wheel_extended_physics_lab.gd")
	if lab_src.find("TAKEOFF_ZONE") < 0 or lab_src.find("VALID_TAKEOFF") < 0:
		errors.append("jump takeoff/landing zones missing")
	if lab_src.find("KEY_K") < 0:
		errors.append("extended lab camera cycle KEY_K missing")
	if lab_src.find("landing_straight_long") < 0:
		errors.append("extended lab missing landing_straight_long deck")
	if lab_src.find("LANDING_TARGET_ZONE") < 0:
		errors.append("extended lab missing LANDING_TARGET_ZONE")
	if not ResourceLoader.exists("res://scenes/debug/Track4WheelStationaryStabilityLab.tscn"):
		errors.append("Track4WheelStationaryStabilityLab.tscn missing")
	var cfg_src := FileAccess.get_file_as_string("res://scripts/track/track_wheel_physics_config.gd")
	if cfg_src.find("LOW_SPEED_STABILITY_BEGIN_MPS") < 0 or cfg_src.find("lateral_tire_force_slip") < 0:
		errors.append("low-speed tire blend missing")
	var slip20: float = float(load("res://scripts/track/track_wheel_physics_config.gd").lateral_tire_force(8.0, 20.0, 1100.0, 9200.0))
	var slip20_only: float = float(load("res://scripts/track/track_wheel_physics_config.gd").lateral_tire_force_slip(8.0, 20.0, 1100.0, 9200.0))
	if absf(slip20 - slip20_only) > 0.01:
		errors.append("low-speed blend leaked into 20 m/s tire force")
	if four_src.find("TRACK_RESET") < 0 or four_src.find("reset_generation_id") < 0:
		errors.append("reset generation telemetry missing")
	if four_src.find("NO_VALID_CONTACT") < 0:
		errors.append("landing contact sanity missing")
	if four_src.find("_apply_rest_stabilization") < 0:
		errors.append("rest stabilization missing")
	var jump = piece_scene.instantiate()
	jump.piece_id = "jump_small"
	host.add_child(jump)
	await get_tree().process_frame
	if int(jump.call("collision_count")) < 1:
		errors.append("jump_small missing landing/lip collision")
	if not bool(jump.meta.get("has_gap", false)):
		errors.append("jump_small metadata must mark has_gap")
	var deck = piece_scene.instantiate()
	deck.piece_id = "landing_straight_long"
	host.add_child(deck)
	await get_tree().process_frame
	if int(deck.call("collision_count")) < 1:
		errors.append("landing_straight_long missing road collision")
	if not ResourceLoader.exists("res://scenes/debug/TrackCleanGapLandingLab.tscn"):
		errors.append("TrackCleanGapLandingLab.tscn missing")
	var gap_lab := FileAccess.get_file_as_string("res://scripts/track/track_clean_gap_landing_lab.gd")
	for token in [
		"TRACK_TAKEOFF_TRANSFORM_INVARIANCE",
		"TRACK_GAP_COLLISION_EMPTY",
		"TRACK_FIRST_CONTACT_LANDING_DECK",
		"TRACK_NO_BODY_PRECONTACT",
		"TRACK_CLEAN_JUMP_SETTLE",
		"TRACK_RECOVERY_BEFORE_CURVE",
		"FAIL_FIRST_CONTACT_WRONG_PIECE",
		"FAIL_BODY_CONTACT_BEFORE_WHEEL",
		"PASS_SETTLED",
		"ramp_takeoff",
		"gap_logical",
		"use_scripted_input",
	]:
		if gap_lab.find(token) < 0:
			errors.append("clean-gap lab missing %s" % token)
	if wheel_src.find("contact_piece_id") < 0:
		errors.append("wheel contact piece_id missing")
	var ramp_to = piece_scene.instantiate()
	ramp_to.piece_id = "ramp_takeoff"
	host.add_child(ramp_to)
	await get_tree().process_frame
	if int(ramp_to.call("collision_count")) < 1:
		errors.append("ramp_takeoff missing road collision")
	var gap_p = piece_scene.instantiate()
	gap_p.piece_id = "gap_logical"
	host.add_child(gap_p)
	await get_tree().process_frame
	if int(gap_p.call("collision_count")) != 0:
		errors.append("gap_logical must own zero road collision")
	if not bool(gap_p.meta.get("has_gap", false)):
		errors.append("gap_logical metadata must mark has_gap")
	if not ResourceLoader.exists("res://scenes/debug/TrackJumpTrajectoryLandingLab.tscn"):
		errors.append("TrackJumpTrajectoryLandingLab.tscn missing")
	var v6_lab := FileAccess.get_file_as_string("res://scripts/track/track_jump_trajectory_lab.gd")
	for token in [
		"TRACK_TAKEOFF_LATERAL_STATE",
		"TRACK_TAKEOFF_YAW_STATE",
		"TRACK_BALLISTIC_PREDICTION",
		"TRACK_LANDING_CAPTURE_MARGIN",
		"TRACK_APPROACH_FORCE_BALANCE",
		"TRACK_RAMP_NORMAL_SYMMETRY",
		"TRACK_NOMINAL_3X_SETTLE",
		"V6 HUMAN REVIEW",
		"NOT V6 HUMAN REVIEW CONFIG",
		"_is_human_review_config",
		"rearm_boost_trigger",
	]:
		if v6_lab.find(token) < 0:
			errors.append("jump-v6 lab missing %s" % token)
	if four_src.find("v6_audit_enabled") < 0:
		errors.append("4WHEEL missing V6 force/torque audit")
	host.queue_free()


func _check_four_wheel_rnd(errors: PackedStringArray) -> void:
	var cfg = load("res://scripts/track/track_config.gd")
	if cfg == null or str(cfg.CONTROLLER_MODE) != "BASELINE":
		errors.append("Track production CONTROLLER_MODE must remain BASELINE")
	var baseline_src := FileAccess.get_file_as_string("res://scripts/track/track_car_controller.gd")
	if baseline_src.find("BASELINE_TRACK_CONTROLLER") < 0:
		errors.append("baseline controller marker missing")
	if baseline_src.find("class_name TrackCarController") < 0:
		errors.append("TrackCarController must remain loadable")
	var four_src := FileAccess.get_file_as_string("res://scripts/track/track_wheel_physics_config.gd")
	if four_src.find("FRONT_LATERAL_GRIP := 9200.0") < 0:
		errors.append("FRONT_LATERAL_GRIP drifted")
	if four_src.find("SPRING_STRENGTH := 32000.0") < 0:
		errors.append("SPRING_STRENGTH drifted")
	if four_src.find("YAW_ASSIST_TORQUE := 420.0") < 0:
		errors.append("YAW_ASSIST_TORQUE drifted")
	if four_src.find("ENGINE_FORCE := 6200.0") < 0:
		errors.append("ENGINE_FORCE drifted")
	if four_src.find("CENTER_OF_MASS_OFFSET := Vector3(0.0, -0.12, 0.06)") < 0:
		errors.append("CENTER_OF_MASS_OFFSET drifted")
	if four_src.find("SUSPENSION_TRAVEL := 0.14") < 0:
		errors.append("SUSPENSION_TRAVEL drifted")
	if four_src.find("MAX_SUSPENSION_FORCE := 18000.0") < 0:
		errors.append("MAX_SUSPENSION_FORCE drifted")
	var four = load("res://scripts/track/track_wheel_physics_config.gd")
	if four == null:
		errors.append("TrackWheelPhysicsConfig missing")
		return
	var lat_pos := float(four.lateral_tire_force(8.0, 20.0, 1200.0, 9000.0))
	var lat_neg := float(four.lateral_tire_force(-8.0, 20.0, 1200.0, 9000.0))
	if lat_pos >= 0.0 or lat_neg <= 0.0:
		errors.append("tire force must oppose lateral slip")
	var brake_fast := float(four.brake_or_reverse_force(20.0, 1.0, 7800.0, 2400.0, 1.8))
	var reverse_slow := float(four.brake_or_reverse_force(0.2, 1.0, 7800.0, 2400.0, 1.8))
	if brake_fast >= 0.0:
		errors.append("4wheel high-speed brake should not drive forward")
	if absf(brake_fast) <= absf(reverse_slow):
		errors.append("4wheel high-speed brake should be stronger than reverse")
	if not bool(four.is_driven("AWD", true)) or not bool(four.is_driven("AWD", false)):
		errors.append("AWD must drive all wheels")
	if bool(four.is_driven("FWD", false)) or not bool(four.is_driven("FWD", true)):
		errors.append("FWD must drive front only")
	if bool(four.is_driven("RWD", true)) or not bool(four.is_driven("RWD", false)):
		errors.append("RWD must drive rear only")
	if absf(float(four.drive_force(1.0, 0.0, 1000.0, 50.0, 0.4))) < 1.0:
		errors.append("throttle should produce drive force")
	if absf(float(four.lateral_tire_force(8.0, 20.0, 0.0, 9000.0))) > 0.001:
		errors.append("no tire force without load / airborne")
	var packed: PackedScene = load("res://scenes/track/TrackCarWheelPhysics.tscn") as PackedScene
	if packed == null:
		errors.append("TrackCarWheelPhysics.tscn failed to load")
		return
	var car = packed.instantiate()
	add_child(car)
	if not (car is RigidBody3D):
		errors.append("4wheel chassis must be RigidBody3D")
	var extra_rb := 0
	for child in car.get_children():
		if child is RigidBody3D:
			extra_rb += 1
	if extra_rb != 0:
		errors.append("wheels must not be separate RigidBody3D objects")
	for name in ["WheelPhysicsFL", "WheelPhysicsFR", "WheelPhysicsRL", "WheelPhysicsRR"]:
		if car.get_node_or_null(name) == null:
			errors.append("missing %s" % name)
	if car.get_node_or_null("CameraAnchor") == null or car.get_node_or_null("CharacterMount") == null:
		errors.append("4wheel anchors missing")
	if car.get_node_or_null("VisualRoot") == null:
		errors.append("4wheel VisualRoot missing")
	car.queue_free()
	var lab_packed: PackedScene = load("res://scenes/debug/TrackWheelPhysicsLab.tscn") as PackedScene
	if lab_packed == null:
		errors.append("TrackWheelPhysicsLab.tscn failed to load")
	else:
		var lab = lab_packed.instantiate()
		add_child(lab)
		lab.queue_free()
	var ghost_script = load("res://scripts/track/track_ghost_player.gd")
	var ghost_src := FileAccess.get_file_as_string("res://scripts/track/track_ghost_player.gd")
	if ghost_src.find("TrackWheelCar") >= 0 or ghost_src.find("TrackArcadeWheel") >= 0:
		errors.append("ghost must not run wheel physics")
	if ghost_script != null:
		var ghost = ghost_script.new()
		if ghost is RigidBody3D:
			errors.append("ghost must not be a RigidBody")
		ghost.queue_free()
	var main_src := FileAccess.get_file_as_string("res://scripts/track/track_main.gd")
	if main_src.find("res://scenes/track/TrackCar.tscn") < 0:
		errors.append("TrackMain must still reference baseline TrackCar.tscn")
	var vis = load("res://scripts/track/track_car_visual.gd")
	if vis != null:
		var a = vis.new()
		a.ghost_mode = false
		add_child(a)
		var four_vis = vis.new()
		four_vis.set("use_articulated", true)
		four_vis.ghost_mode = false
		add_child(four_vis)
		if int(vis.shared_atlas_id()) == 0:
			errors.append("articulated visual lost shared atlas")
		a.queue_free()
		four_vis.queue_free()


func _has_concave_shape(node: Node) -> bool:
	if node is CollisionShape3D:
		if (node as CollisionShape3D).shape is ConcavePolygonShape3D:
			return true
	for child in node.get_children():
		if _has_concave_shape(child):
			return true
	return false


func _has_enabled_collision(node: Node) -> bool:
	if node is CollisionObject3D:
		var body := node as CollisionObject3D
		if body.collision_layer != 0 or body.collision_mask != 0:
			return true
	if node is CollisionShape3D and not (node as CollisionShape3D).disabled:
		if node.get_parent() is CollisionObject3D:
			var parent_body := node.get_parent() as CollisionObject3D
			if parent_body.collision_layer != 0:
				return true
	for child in node.get_children():
		if _has_enabled_collision(child):
			return true
	return false


func _check_duplicates_and_session(errors: PackedStringArray) -> void:
	var store = ProfileStoreScript.new()
	if store.create("Enzo") == null:
		errors.append("could not create Enzo")
		return
	if store.create("enzo") != null or store.last_error != "duplicate":
		errors.append("duplicate names should be rejected case-insensitively")
	if store.create("  ") != null or store.last_error != "empty":
		errors.append("empty names should be rejected")
	var session_script = load("res://scripts/core/jeffrey/active_session.gd")
	var session = session_script.new()
	session.add_player("a")
	session.add_player("b")
	session.add_player("a")
	if session.count() != 2:
		errors.append("session should not duplicate ids")
	session.remove_player("a")
	if session.count() != 1 or session.has_player("a"):
		errors.append("session remove_player failed")


func _check_persistence(errors: PackedStringArray) -> void:
	var persist = PersistenceScript.new()
	persist.save_directory = "user://los_juegos_de_jeffrey_ci"
	var store = ProfileStoreScript.new()
	var profile = store.create("EnzoCI")
	if profile == null:
		errors.append("could not create profile")
		return
	if not persist.save_from(store):
		errors.append("save_from failed")
		return
	var reloaded = ProfileStoreScript.new()
	persist.load_into(reloaded)
	var loaded = reloaded.get_profile(profile.profile_id)
	if loaded == null or loaded.display_name != "EnzoCI":
		errors.append("profile did not survive save/load")
	var corrupt := FileAccess.open(persist.save_path(), FileAccess.WRITE)
	if corrupt:
		corrupt.store_string("{not json")
		corrupt.close()
	var recovered_store = ProfileStoreScript.new()
	var payload: Dictionary = persist.load_into(recovered_store)
	if not bool(payload.get("recovered_from_corruption", false)):
		errors.append("corrupt save was not recovered")
	await get_tree().process_frame


func _check_smash_playground(errors: PackedStringArray) -> void:
	if not ResourceLoader.exists("res://scenes/core/M0Playground.tscn"):
		errors.append("M0Playground.tscn missing")
		return
	var playground = load("res://scenes/core/M0Playground.tscn").instantiate()
	add_child(playground)
	await get_tree().create_timer(0.35).timeout
	if playground.fighters.size() != 2:
		errors.append("expected 2 fighters, got %d" % playground.fighters.size())
	else:
		var p1 = playground.fighters[0]
		var p2 = playground.fighters[1]
		if p1.player_id != 1 or p2.player_id != 2:
			errors.append("fighter player_id mismatch")
		if p1.stocks != 3 or p2.stocks != 3:
			errors.append("stocks are not 3")
		if p1.spawn_position.distance_to(Vector3(-4.0, 1.7, 0.0)) > 0.05:
			errors.append("P1 spawn moved: %s" % p1.spawn_position)
		if p2.spawn_position.distance_to(Vector3(4.0, 1.7, 0.0)) > 0.05:
			errors.append("P2 spawn moved: %s" % p2.spawn_position)
		if p1.fighter_id != "terere" or p2.fighter_id != "jaguarete":
			errors.append("default fighter ids changed")
	playground.queue_free()
	await get_tree().process_frame


func _check_global_ui(errors: PackedStringArray) -> void:
	for path in UiAssets.expected_paths():
		if not UiAssets.file_present(path):
			errors.append("GLOBAL_UI_ASSET_MISSING %s" % path)
	var persist = PersistenceScript.new()
	persist.save_directory = "user://los_juegos_de_jeffrey_ui_v1"
	var store = ProfileStoreScript.new()
	var created = store.create("TEST_UI_PLAYER")
	if created == null:
		errors.append("could not create TEST_UI_PLAYER")
		return
	if not persist.save_from(store):
		errors.append("UI V1 isolated save failed")
		return
	var reloaded = ProfileStoreScript.new()
	persist.load_into(reloaded)
	if reloaded.find_normalized("TEST_UI_PLAYER") == null:
		errors.append("TEST_UI_PLAYER did not persist in isolated save")
	var scripts := [
		"res://scripts/ui/jeffrey/boot_screen.gd",
		"res://scripts/ui/jeffrey/players_today_screen.gd",
		"res://scripts/ui/jeffrey/hub_screen.gd",
		"res://scripts/ui/jeffrey/edit_players_screen.gd",
		"res://scripts/ui/jeffrey/mode_player_select_screen.gd",
		"res://scripts/ui/jeffrey/character_select_screen.gd",
		"res://scripts/ui/jeffrey/mode_transition_controller.gd",
		"res://scripts/ui/jeffrey/zombies_menu_screen.gd",
		"res://scripts/ui/jeffrey/zombies_loading_screen.gd",
		"res://scripts/track/track_main.gd",
		"res://scripts/ui/jeffrey/texture_fit_host.gd",
	]
	for path in scripts:
		var loaded = load(path)
		if loaded == null:
			errors.append("failed to load %s" % path)
			continue
		var screen = loaded.new()
		if screen == null:
			errors.append("%s.new() returned null" % path)
			continue
		add_child(screen)
		await get_tree().process_frame
		if not is_instance_valid(screen):
			errors.append("%s died after ready" % path)
		else:
			screen.queue_free()
		await get_tree().process_frame
