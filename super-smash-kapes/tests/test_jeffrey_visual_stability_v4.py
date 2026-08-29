"""Track + Zombies visual/stability V4 static locks."""

from pathlib import Path
import json

PROJECT_ROOT = Path(__file__).resolve().parents[1]


def _read(rel: str) -> str:
    return (PROJECT_ROOT / rel).read_text(encoding="utf-8")


def test_v4_files_exist() -> None:
    for rel in (
        "assets/reference/.gdignore",
        "docs/SHOPPING_REFERENCE_COVERAGE_AND_VISUAL_AUTHORITY_V1.md",
        "docs/JEFFREY_D3D12_INTERMITTENT_RESOURCE_EXHAUSTION_V1_REPORT.md",
        "docs/TRACK_4WHEEL_HUMAN_CLOSURE_V5_REPORT.md",
        "docs/ZOMBIES_SHOPPING_VISUAL_REFERENCE_RECONSTRUCTION_V4_REPORT.md",
        "docs/JEFFREY_TRACK_ZOMBIES_VISUAL_STABILITY_V4_REPORT.md",
        "scripts/debug/jeffrey_resource_probe.gd",
        "scripts/debug/d3d12_repeat_launch_harness.gd",
        "scenes/debug/D3D12RepeatLaunchLab.tscn",
        "scripts/zombies/zombies_visual_kit.gd",
        "scripts/debug/smoke_track_boost_wrong_way.gd",
        "scripts/debug/smoke_track_elevation_contact.gd",
        "tools/run_d3d12_repeat_rendered.py",
    ):
        assert (PROJECT_ROOT / rel).exists(), rel


def test_reference_not_imported() -> None:
    ignore = _read("assets/reference/.gdignore")
    assert "*" in ignore
    parking = _read("scripts/zombies/zombies_parking.gd")
    assert "ZombiesVisualKit" in parking or "zombies_visual_kit.gd" in parking
    assert "add_palm" in parking
    assert "add_skyline" in _read("scripts/zombies/zombies_visual_kit.gd")


def test_boost_wrong_way_gate() -> None:
    wheel = _read("scripts/track/track_wheel_car.gd")
    baseline = _read("scripts/track/track_car_controller.gd")
    cfg = _read("scripts/track/track_config.gd")
    assert "SKIP_WRONG_WAY" in wheel
    assert "SKIP_WRONG_WAY" in baseline
    assert "BOOST_MIN_FORWARD_DOT := 0.25" in cfg
    assert "BOOST_DIRECTION_NEGATIVE" not in wheel
    assert "push_error" not in wheel.split("func apply_track_boost")[1].split("func speed_kph")[0]


def test_crest_is_smooth() -> None:
    data = json.loads(_read("assets/track/modules/generated/core/track_crest_gentle_v1.json"))
    roads = [b for b in data["collision"] if b.get("kind") == "road"]
    assert len(roads) >= 6
    pitches = [float(b["pitch"]) for b in roads]
    deltas = [abs(pitches[i + 1] - pitches[i]) for i in range(len(pitches) - 1)]
    assert max(deltas) < 0.06
    assert max(abs(p) for p in pitches) < 0.06
    assert float(data["entry"]["pitch"]) == 0.0
    assert float(data["exit"]["pitch"]) == 0.0
    assert float(data["height_delta"]) == 0.0


def test_trackmain_stays_baseline() -> None:
    config = _read("scripts/track/track_config.gd")
    main = _read("scripts/track/track_main.gd")
    lab = _read("scripts/track/track_generator_v2_lab.gd")
    assert 'CONTROLLER_MODE := "BASELINE"' in config
    assert "track_generator_v2" not in main
    assert "_mode: String = MODE_FOUR_WHEEL" in lab
    assert "grounded wheels" in lab


def test_zombies_gameplay_preserved() -> None:
    cfg = _read("scripts/zombies/zombies_config.gd")
    mmap = _read("scripts/zombies/zombies_map.gd")
    enemy = _read("scripts/zombies/zombies_enemy.gd")
    view = _read("scripts/zombies/zombies_viewmodel.gd")
    assert "MAIN_ENTRANCE_COST := 1500" in cfg
    assert "player_spawn: Vector3 = Vector3(0, 0.05, 28.5)" in mmap
    assert "TERERÉ MARKET" in mmap
    assert "WINDUP" in enemy
    assert "_speed_mul" in enemy
    assert "_head" in enemy
    assert "slide" in view.lower() or "0.016" in view
    assert "ZOMBIES_PACING" in _read("scripts/zombies/zombies_game_state.gd")
    assert "1.15" in mmap and "1.35" in mmap
