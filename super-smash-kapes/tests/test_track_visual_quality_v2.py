"""Track Visual Quality V2 gates."""

from __future__ import annotations

import os
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
GODOT = Path(os.environ.get("GODOT", r"E:\Godot_v4.7.2-stable_win64.exe"))


def test_vq2_scripts_exist() -> None:
    assert (ROOT / "scripts/track/track_visual_quality_v2.gd").is_file()
    assert (ROOT / "scenes/debug/TrackVisualQualityV2Lab.tscn").is_file()
    assert (ROOT / "scenes/debug/TrackVisualQualityV2Capture.tscn").is_file()


def test_hud_no_debug_residue() -> None:
    text = (ROOT / "scripts/track/track_hud.gd").read_text(encoding="utf-8")
    assert "PRESUPUESTO" not in text
    assert "LAST DANCE" not in text
    assert "CHECKS" not in text
    assert "Pista #" in text
    assert "COMBUSTIBLE" in text
    assert "CONTROL" in text
    main = (ROOT / "scripts/track/track_main.gd").read_text(encoding="utf-8")
    assert "Last Dance = rendición" not in main


def test_road_palette_and_curbs() -> None:
    gen = (ROOT / "scripts/track/track_generator.gd").read_text(encoding="utf-8")
    assert 'kind": "curb"' in gen or "\"kind\": \"curb\"" in gen
    assert "#1c2128" in gen
    race = (ROOT / "scripts/track/track_race.gd").read_text(encoding="utf-8")
    assert "track_visual_quality_v2" in race
    assert "visual_only" in race
    assert "attach_checkpoint_markers" in race


def test_signage_atlas_wired() -> None:
    vq = (ROOT / "scripts/track/track_visual_quality_v2.gd").read_text(encoding="utf-8")
    assert "signage_atlas_v2" in vq
    assert "facade_atlas_v2" in vq
    kit = (ROOT / "scripts/track/track_environment_kit_v1.gd").read_text(encoding="utf-8")
    assert "signage_material" in kit
    assert "building_material" in kit


def test_results_compact_track() -> None:
    text = (ROOT / "scripts/ui/jeffrey/copa_jeffrey_results_screen.gd").read_text(encoding="utf-8")
    assert "offset_top = -200" in text
    assert "make_result_banner" in text


def test_vq2_lab_pass() -> None:
    if not GODOT.is_file():
        return
    log = ROOT / "outputs" / "perf" / "logs" / "track_visual_quality_v2_lab.log"
    log.parent.mkdir(parents=True, exist_ok=True)
    cmd = [
        str(GODOT),
        "--path",
        str(ROOT),
        "--display-driver",
        "windows",
        "--rendering-method",
        "forward_plus",
        "--rendering-driver",
        "d3d12",
        "--gpu-index",
        "0",
        "--audio-driver",
        "Dummy",
        "--resolution",
        "1280x720",
        "--log-file",
        str(log),
        "--quit-after",
        "360",
        "res://scenes/debug/TrackVisualQualityV2Lab.tscn",
    ]
    subprocess.run(cmd, capture_output=True, text=True, timeout=120, check=False)
    body = log.read_text(encoding="utf-8", errors="replace") if log.is_file() else ""
    assert "[TRACK_VISUAL_QUALITY_V2_LAB] PASS" in body, body[-2500:]
