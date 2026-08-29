"""Track texture sharing, wider roads/guardrails, ghost start sync."""

from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[1]


def _read(rel: str) -> str:
    return (PROJECT_ROOT / rel).read_text(encoding="utf-8")


def test_car_visual_preloads_and_shares_atlas() -> None:
    visual = _read("scripts/track/track_car_visual.gd")
    config = _read("scripts/track/track_car_visual_config.gd")
    assert "preload(\"res://assets/vehicles/track/source/track_car_base_v1.glb\")" not in visual
    assert "_ensure_shared_atlas" in visual
    assert "_packed_for_mode" in visual
    assert "get_image(" not in visual
    assert "src.duplicate()" not in visual
    assert "duplicate(true)" not in visual
    assert "_shared_atlas" in visual
    assert "_shared_ghost_mat" in visual
    assert "_make_player_material" in visual
    assert "[TRACK_CAR_VISUAL]" in visual
    assert "SHARED_ATLAS" in config
    assert "track_car_base_v1_Modelo" in config
    assert (PROJECT_ROOT / "docs/TRACK_CAR_TEXTURE_MEMORY_V1_REPORT.md").exists()


def test_road_is_wider_with_guardrails() -> None:
    config = _read("scripts/track/track_config.gd")
    gen = _read("scripts/track/track_generator.gd")
    lab = _read("scripts/track/track_physics_lab.gd")
    assert "ROAD_WIDTH_V1 := 8.0" in config
    assert "ROAD_WIDTH := 11.0" in config
    assert "ROAD_SHOULDER" in config
    assert "GUARDRAIL_HEIGHT := 0.9" in config
    assert "_pack_road" in gen
    assert 'kind": "rail"' in gen or "kind\": \"rail\"" in gen
    assert "has_left_guardrail" in gen
    assert "has_right_guardrail" in gen
    assert "_rails_at" in lab
    assert "_road_box" in lab


def test_ghost_starts_with_race_clock() -> None:
    main = _read("scripts/track/track_main.gd")
    ghost = _read("scripts/track/track_ghost_player.gd")
    clock = _read("scripts/track/track_race_clock.gd")
    assert "TrackRaceClock" in clock or "STATE_COUNTDOWN" in clock
    assert "STATE_ACTIVE" in clock
    assert "_on_race_started" in main
    assert "begin_playback" in main
    assert "begin_playback" in ghost
    assert "set_elapsed" in ghost
    assert "get_transform_at_time" in ghost
    assert "ghost.play()" not in main
    assert "consume_fuel" in main
    assert "_clock.is_active()" in main or "_clock.is_countdown()" in main
    assert (PROJECT_ROOT / "docs/TRACK_TEXTURE_ROAD_GHOST_V1_REPORT.md").exists()
    assert (PROJECT_ROOT / "scripts/track/track_race_clock.gd").exists()
