"""Scan .gd/.tscn for hardcoded res:// paths and report missing files."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SKIP_DIRS = {".godot", ".git", "__pycache__", ".pytest_cache", "block_previews"}
PATH_RE = re.compile(r'(?:preload|load)\(\s*"((?:res://)[^"]+)"')
TSCN_RE = re.compile(r'path="((?:res://)[^"]+)"')
OPTIONAL_MARKERS = ("optional", "event-only", "debug_only")
REQUIRED_ALWAYS = {
    "res://assets/stages/defensores_del_chaco/platforms/defensores_platform_kit.png",
    "res://assets/stages/defensores_del_chaco/background/defensores_bg_main.png",
    "res://assets/vehicles/track/source/track_car_base_v1.glb",
    "res://assets/vehicles/track/processed/track_car_base_v2_articulated.glb",
    "res://assets/vehicles/track/source/track_car_base_v1_Modelo+3D+de+coche+de+carreras_basecolor.jpg",
    "res://scenes/track/TrackCar.tscn",
    "res://scenes/track/TrackMain.tscn",
    "res://data/track/modules/track_kit_v1.json",
    "res://assets/track/modules/generated/core/track_start_v1.glb",
    "res://assets/track/modules/generated/core/track_straight_medium_v1.glb",
    "res://assets/track/modules/generated/core/track_curve_l_45_v1.glb",
    "res://assets/track/modules/generated/core/track_curve_r_45_v1.glb",
    "res://assets/track/modules/generated/core/track_finish_v1.glb",
    "res://assets/track/modules/generated/core/track_ramp_small_v1.glb",
    "res://assets/track/modules/generated/core/track_jump_small_v1.glb",
    "res://assets/track/modules/generated/core/track_boost_straight_v1.glb",
    "res://assets/track/modules/generated/core/track_landing_straight_long_v1.glb",
    "res://assets/track/modules/generated/core/track_ramp_takeoff_v1.glb",
    "res://assets/track/modules/generated/core/track_gap_logical_v1.glb",
    "res://assets/track/modules/generated/core/track_straight_short_v1.glb",
    "res://assets/track/modules/generated/core/track_straight_long_v1.glb",
    "res://assets/track/modules/generated/core/track_curve_l_90_v1.glb",
    "res://assets/track/modules/generated/core/track_curve_r_90_v1.glb",
    "res://assets/track/modules/generated/core/track_chicane_lr_v1.glb",
    "res://assets/track/modules/generated/core/track_chicane_rl_v1.glb",
    "res://assets/track/materials/track_boost_v1.tres",
    "res://scenes/debug/TrackCleanGapLandingLab.tscn",
    "res://scenes/debug/TrackJumpTrajectoryLandingLab.tscn",
    "res://scenes/debug/TrackGeneratorV2Lab.tscn",
    "res://scenes/debug/TrackBoostResetLab.tscn",
    "res://scenes/debug/TrackBoostDeltaLab.tscn",
    "res://data/track/generator_v2_showcases.json",
    "res://scripts/track/track_generator_v2.gd",
    "res://assets/track/materials/track_asphalt_v1.tres",
    "res://assets/track/materials/track_shoulder_v1.tres",
    "res://assets/track/materials/track_guardrail_v1.tres",
    "res://scenes/track/modules/TrackPiece.tscn",
    "res://scenes/debug/TrackModularKitPilotLab.tscn",
    "res://scenes/debug/Track4WheelExtendedPhysicsLab.tscn",
    "res://assets/vehicles/track/materials/track_car_atlas.tres",
    "res://assets/vehicles/track/materials/track_car_player_v1.tres",
    "res://scenes/debug/TrackCarMinimalAtlasLab.tscn",
    "res://scenes/debug/TrackCarTextureLoadOnly.tscn",
    "res://scenes/zombies/ZombiesMain.tscn",
    "res://scenes/debug/ZombiesSystemsLab.tscn",
    "res://scripts/zombies/zombies_viewmodel.gd",
    "res://data/zombies/pistol.tres",
    "res://data/zombies/smg.tres",
}


def iter_source_files() -> list[Path]:
    out: list[Path] = []
    for folder in ("scripts", "scenes", "fighters", "data"):
        base = ROOT / folder
        if not base.exists():
            continue
        for path in base.rglob("*"):
            if not path.is_file():
                continue
            if any(part in SKIP_DIRS for part in path.parts):
                continue
            if path.suffix.lower() in {".gd", ".tscn", ".tres"}:
                out.append(path)
    return out


def to_disk(res_path: str) -> Path:
    rel = res_path.replace("res://", "")
    return ROOT / rel


def scan() -> dict:
    missing: list[dict] = []
    found = 0
    checked: set[str] = set()
    for file in iter_source_files():
        text = file.read_text(encoding="utf-8", errors="replace")
        paths = PATH_RE.findall(text) if file.suffix == ".gd" else []
        if file.suffix in {".tscn", ".tres"}:
            paths.extend(TSCN_RE.findall(text))
        for res_path in paths:
            if res_path in checked:
                continue
            checked.add(res_path)
            disk = to_disk(res_path)
            found += 1
            if not disk.exists():
                missing.append(
                    {
                        "path": res_path,
                        "file": str(file.relative_to(ROOT)).replace("\\", "/"),
                        "required": res_path in REQUIRED_ALWAYS,
                    }
                )
    required_missing = [item for item in missing if item["required"] or item["path"] in REQUIRED_ALWAYS]
    return {
        "checked": found,
        "unique_paths": len(checked),
        "missing": missing,
        "required_missing": required_missing,
        "defensores_platform_kit_exists": (
            ROOT / "assets/stages/defensores_del_chaco/platforms/defensores_platform_kit.png"
        ).exists(),
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()
    result = scan()
    if args.json:
        print(json.dumps(result, indent=2))
    else:
        print("checked_refs=%d unique=%d missing=%d required_missing=%d" % (
            result["checked"],
            result["unique_paths"],
            len(result["missing"]),
            len(result["required_missing"]),
        ))
        for item in result["missing"]:
            flag = "REQUIRED" if item["required"] else "optional?"
            print("MISSING %s %s  (from %s)" % (flag, item["path"], item["file"]))
        print("defensores_platform_kit_exists=%s" % result["defensores_platform_kit_exists"])
    return 1 if result["required_missing"] else 0


if __name__ == "__main__":
    raise SystemExit(main())
