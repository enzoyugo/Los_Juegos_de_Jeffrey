"""Track debug scene parse cleanup + observational labs. No physics/combat retune."""

from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[1]

BOM_TARGETS = (
    "F6RepeatStabilityLab.tscn",
    "SmokeTrackHotseatV2.tscn",
    "SmokeTrackHudTelemetry.tscn",
    "SmokeTrackLabHudStress.tscn",
    "SmokeTrackRhythmBatch.tscn",
    "TrackCameraLab.tscn",
    "TrackDriftLab.tscn",
    "TrackGenerationRevealLab.tscn",
    "TrackHotseatLab.tscn",
    "TrackSceneryLab.tscn",
    "TrackTurboV7Showcase.tscn",
    "TrackWidthCameraDriftLab.tscn",
)


def test_track_debug_scenes_have_no_utf8_bom() -> None:
    folder = PROJECT_ROOT / "scenes" / "debug"
    for name in BOM_TARGETS:
        data = (folder / name).read_bytes()
        assert not data.startswith(b"\xef\xbb\xbf"), name
        assert data.lstrip().startswith(b"["), name


def test_observability_labs_exist_and_do_not_retune() -> None:
    for rel in (
        "scenes/debug/TrackCrashObserveLab.tscn",
        "scenes/debug/TrackDriftObserveLab.tscn",
        "scenes/debug/SmashKoRespawnObserveLab.tscn",
        "scripts/debug/track_crash_drift_observe_lab.gd",
        "scripts/debug/smash_ko_respawn_observe_lab.gd",
    ):
        assert (PROJECT_ROOT / rel).exists(), rel
    crash = (PROJECT_ROOT / "scripts/debug/track_crash_drift_observe_lab.gd").read_text(encoding="utf-8")
    assert "Does not retune Track physics" in crash
    smash = (PROJECT_ROOT / "scripts/debug/smash_ko_respawn_observe_lab.gd").read_text(encoding="utf-8")
    assert "Does not decrement stocks itself" in smash
    assert "fighter.ko()" not in smash
    playground = (PROJECT_ROOT / "scripts/core/m0_playground.gd").read_text(encoding="utf-8")
    assert "RESPAWN_DELAY := 1.15" in playground
    wheel = (PROJECT_ROOT / "scripts/track/track_wheel_car.gd").read_text(encoding="utf-8")
    assert "basis_forward" in wheel
    assert "REAR_LATERAL_GRIP" in wheel
