"""Zombies vertical slice V1 static locks."""

from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[1]


def _read(rel: str) -> str:
    return (PROJECT_ROOT / rel).read_text(encoding="utf-8")


def test_vertical_slice_files_exist() -> None:
    for rel in (
        "scripts/zombies/zombies_config.gd",
        "scripts/zombies/zombies_player.gd",
        "scripts/zombies/zombies_weapon.gd",
        "scripts/zombies/zombies_weapon_data.gd",
        "scripts/zombies/zombies_enemy.gd",
        "scripts/zombies/zombies_waves.gd",
        "scripts/zombies/zombies_hud.gd",
        "scripts/zombies/zombies_main.gd",
        "scripts/zombies/zombies_interactable.gd",
        "scripts/zombies/zombies_buyable_door.gd",
        "scripts/zombies/zombies_weapon_wall_buy.gd",
        "scripts/zombies/zombies_power_up.gd",
        "scripts/zombies/zombies_map.gd",
        "scripts/zombies/zombies_game_state.gd",
        "data/zombies/pistol.tres",
        "data/zombies/smg.tres",
        "scenes/zombies/ZombiesMain.tscn",
        "scenes/debug/ZombiesSystemsLab.tscn",
        "scripts/debug/zombies_systems_lab.gd",
        "scripts/zombies/zombies_viewmodel.gd",
        "scripts/zombies/zombies_mall_props.gd",
        "scripts/zombies/zombies_parking.gd",
        "scripts/zombies/zombies_shopping_shell.gd",
        "scripts/zombies/zombies_audio.gd",
        "scenes/debug/ShoppingZombiesIntegrationLab.tscn",
        "docs/ZOMBIES_VERTICAL_SLICE_V1_REPORT.md",
    ):
        assert (PROJECT_ROOT / rel).exists(), rel


def test_door_wall_buy_max_ammo_and_round_api() -> None:
    door = _read("scripts/zombies/zombies_buyable_door.gd")
    wall = _read("scripts/zombies/zombies_weapon_wall_buy.gd")
    power = _read("scripts/zombies/zombies_power_up.gd")
    waves = _read("scripts/zombies/zombies_waves.gd")
    config = _read("scripts/zombies/zombies_config.gd")
    lab = _read("scripts/debug/zombies_systems_lab.gd")
    player = _read("scripts/zombies/zombies_player.gd")
    main = _read("scripts/zombies/zombies_main.gd")
    map_src = _read("scripts/zombies/zombies_map.gd")
    assert "try_interact" in door
    assert "locked" in door
    assert "GALERÍA" in config or "DOOR_NAME" in config
    assert "weapon_id" in wall
    assert "ammo_cost" in wall
    assert "MAX AMMO" in power
    assert "apply_to" in power
    assert "func next_count" in waves
    assert "zombies_to_spawn" in waves
    assert "z_interact" in config
    assert "z_reload" in config
    assert "KEY_G" in config
    assert "KEY_E" in config
    assert "intersect_ray" in player
    assert "MOUSE_MODE_CAPTURED" in player
    assert "session_exited" in main
    assert "func setup" in main
    scene = _read("scenes/zombies/ZombiesMain.tscn")
    assert "zombies_main.gd" in scene
    assert "[ZOMBIES_SYSTEMS]" in lab
    assert "ALL_PASS" in lab
    assert "SHOPPING del SOL" in map_src
    assert "parking_spawns" in map_src
    assert "MAIN_ENTRANCE" in config or "MAIN_ENTRANCE_COST" in config
    assert "1500" in config


def test_game_feel_v2_tokens() -> None:
    enemy = _read("scripts/zombies/zombies_enemy.gd")
    player = _read("scripts/zombies/zombies_player.gd")
    hud = _read("scripts/zombies/zombies_hud.gd")
    lab = _read("scripts/debug/zombies_systems_lab.gd")
    view = _read("scripts/zombies/zombies_viewmodel.gd")
    main = _read("scripts/zombies/zombies_main.gd")
    config = _read("scripts/zombies/zombies_config.gd")
    map_src = _read("scripts/zombies/zombies_map.gd")
    door = _read("scripts/zombies/zombies_buyable_door.gd")
    assert "SLOT_COUNT" in enemy
    assert "slot_index" in enemy
    assert "SEPARATION_RADIUS" in enemy
    assert "avoidance_enabled" in enemy
    assert "ZOMBIE_ATTACK_GAP" in enemy
    assert "viewmodel" in player.lower()
    assert "intersect_ray" in player
    assert "play_dry" in view or "play_dry" in player
    assert "vignette" in hud.lower()
    assert "show_hit_marker" in hud
    assert "RECARGANDO" in hud
    assert "[ZOMBIES_CROWD]" in lab
    assert "min_nn" in lab
    assert "ALL_PASS" in lab
    assert "consume_shot" in player
    assert "session_exited" in main
    assert "func setup" in main
    assert "KEY_G" in config
    assert "KEY_E" in config
    assert "TERERÉ MARKET" in map_src
    assert "KAPE SPORT" in map_src
    assert "SOL FOTO" in map_src
    assert "CHIPÁ EXPRESS" in map_src
    assert "parking_spawns" in map_src
    assert "shopping_open" in map_src
    assert "_shutter" in door
    assert "next_count" in lab


def test_systems_lab_scene_points_at_script() -> None:
    scene = _read("scenes/debug/ZombiesSystemsLab.tscn")
    assert "zombies_systems_lab.gd" in scene
    assert "ZombiesSystemsLab" in scene

