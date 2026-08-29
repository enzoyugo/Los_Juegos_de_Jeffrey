"""Jeffrey performance + track diagnostic V1 gates."""

from __future__ import annotations

import json
import os
import subprocess
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[1]
GODOT = Path(os.environ.get("GODOT", r"E:\Godot_v4.7.2-stable_win64_console.exe"))


def test_perf_lab_assets_exist() -> None:
    assert (PROJECT_ROOT / "scripts/debug/jeffrey_perf_sampler.gd").exists()
    assert (PROJECT_ROOT / "scripts/debug/jeffrey_performance_lab.gd").exists()
    assert (PROJECT_ROOT / "scenes/debug/JeffreyPerformanceLab.tscn").exists()
    assert (PROJECT_ROOT / "docs/TRACK_PRESENTATION_GAP_V1.md").exists()
    assert (PROJECT_ROOT / "docs/JEFFREY_PERFORMANCE_TRACK_DIAGNOSTIC_V1_REPORT.md").exists()


def test_track_race_has_environment_and_timing() -> None:
    race = (PROJECT_ROOT / "scripts/track/track_race.gd").read_text(encoding="utf-8")
    assert "_place_environment" in race
    assert "SSK_PERF_DIAG" in race
    assert "TRACK_BUILD" in race
    assert "TONE_MAPPER_FILMIC" in race
    assert "ProceduralSkyMaterial" in race


def test_mode_transition_duration_reduced() -> None:
    definition = (PROJECT_ROOT / "scripts/ui/jeffrey/mode_transition_definition.gd").read_text(encoding="utf-8")
    assert "duration_min = 0.48" in definition
    assert "duration_min = 0.52" in definition
    assert "duration_min = 1.2" not in definition
    controller = (PROJECT_ROOT / "scripts/ui/jeffrey/mode_transition_controller.gd").read_text(encoding="utf-8")
    assert "enum State" in controller
    assert "ACCEPTED" in controller
    assert "ENTERING" in controller
    assert "_busy" not in controller or "is_busy" in controller


def test_track_race_batches_visuals() -> None:
    race = (PROJECT_ROOT / "scripts/track/track_race.gd").read_text(encoding="utf-8")
    assert "MultiMeshInstance3D" in race
    assert "_place_solids_batched" in race
    assert "_place_roadside" in race
    assert "_place_road_markings" in race


def test_car_atlas_import_size_limit_2k() -> None:
    imp = (
        PROJECT_ROOT
        / "assets/vehicles/track/source/track_car_base_v1_Modelo+3D+de+coche+de+carreras_basecolor.jpg.import"
    ).read_text(encoding="utf-8")
    assert "process/size_limit=2048" in imp


def test_shell_transition_duration_snappy() -> None:
    theme = (PROJECT_ROOT / "scripts/ui/jeffrey/system/jeffrey_theme.gd").read_text(encoding="utf-8")
    assert "DURATION_SCREEN := 0.18" in theme
    shell = (PROJECT_ROOT / "scripts/ui/jeffrey/system/jeffrey_shell_transition.gd").read_text(encoding="utf-8")
    assert "_active_tween" in shell


def test_players_today_uses_jeffrey_components() -> None:
    players = (PROJECT_ROOT / "scripts/ui/jeffrey/players_today_screen.gd").read_text(encoding="utf-8")
    assert "JeffreyButton" in players
    assert "JeffreyPlayerChip" in players
    assert "_confirming" in players
    assert "JeffreyCore.profiles" in players

    btn = (PROJECT_ROOT / "scripts/ui/jeffrey/components/jeffrey_button.gd").read_text(encoding="utf-8")
    assert "_paint_key" in btn
    assert "if key == _paint_key" in btn


def test_track_hud_track_accent() -> None:
    hud = (PROJECT_ROOT / "scripts/track/track_hud.gd").read_text(encoding="utf-8")
    assert "TRACK_ACCENT" in hud
    assert "#3db8c9" in hud


def test_godot_perf_lab_empty_scenario() -> None:
    if not GODOT.exists():
        return
    env = os.environ.copy()
    env["SSK_PERF_SCENARIO"] = "EMPTY"
    env["SSK_EXPECTED_GPU"] = "NVIDIA"
    log_path = PROJECT_ROOT / "outputs" / "perf" / "logs" / "pytest_empty.log"
    log_path.parent.mkdir(parents=True, exist_ok=True)
    if log_path.exists():
        log_path.unlink()
    proc = subprocess.run(
        [
            str(GODOT),
            "--path",
            str(PROJECT_ROOT),
            "--display-driver",
            "windows",
            "--rendering-method",
            "forward_plus",
            "--rendering-driver",
            "d3d12",
            "--audio-driver",
            "Dummy",
            "--log-file",
            str(log_path),
            "--quit-after",
            "120",
            "res://scenes/debug/JeffreyPerformanceLab.tscn",
        ],
        cwd=str(PROJECT_ROOT),
        env=env,
        timeout=120,
    )
    text = log_path.read_text(encoding="utf-8", errors="replace") if log_path.exists() else ""
    assert proc.returncode == 0, text
    assert "[JEFFREY_PERF_LAB] PASS" in text
    assert "GPU_AUTHORITY=" in text


def test_gpu_authority_probe_scene_exists() -> None:
    assert (PROJECT_ROOT / "scenes/debug/JeffreyGpuAuthorityProbe.tscn").exists()
    assert (PROJECT_ROOT / "scripts/debug/jeffrey_gpu_authority_probe.gd").exists()


def test_perf_runner_uses_display_driver_windows() -> None:
    runner = (PROJECT_ROOT / "tools/run_jeffrey_perf_lab.py").read_text(encoding="utf-8")
    assert '"--display-driver"' in runner
    assert '"windows"' in runner
    assert "gpu_authority_pass" in runner
    assert "performance_valid" in runner
    assert "capture_output=True" not in runner
