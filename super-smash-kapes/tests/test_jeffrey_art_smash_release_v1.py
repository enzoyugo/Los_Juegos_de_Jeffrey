"""Jeffrey Art + Smash Release V1 gates."""

from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

UI_WAVS = [
    "navigate.wav",
    "confirm.wav",
    "back.wav",
    "error.wav",
    "modal_open.wav",
    "score_gain.wav",
    "result.wav",
    "countdown_tick.wav",
    "countdown_go.wav",
    "finish.wav",
]

SMASH_WAVS = [
    "hit_light.wav",
    "hit_heavy.wav",
    "ko.wav",
    "respawn.wav",
    "match_start.wav",
    "match_end.wav",
]


def test_ui_sfx_pack_present() -> None:
    ui_dir = ROOT / "assets/audio/ui"
    assert ui_dir.is_dir()
    for name in UI_WAVS:
        path = ui_dir / name
        assert path.is_file(), name
        assert path.stat().st_size > 500


def test_smash_sfx_pack_present() -> None:
    smash_dir = ROOT / "assets/audio/smash"
    assert smash_dir.is_dir()
    for name in SMASH_WAVS:
        path = smash_dir / name
        assert path.is_file(), name
        assert path.stat().st_size > 500


def test_global_ui_audio_maps_pack() -> None:
    text = (ROOT / "scripts/ui/jeffrey/global_ui_audio.gd").read_text(encoding="utf-8")
    assert "navigate" in text
    assert "modal_open" in text
    assert "countdown_go" in text
    assert "master_volume" in text
    assert "sfx_volume" in text


def test_smash_audio_wired() -> None:
    audio = (ROOT / "scripts/core/smash_audio_v1.gd").read_text(encoding="utf-8")
    playground = (ROOT / "scripts/core/m0_playground.gd").read_text(encoding="utf-8")
    assert "play_ko" in audio
    assert "SmashAudio" in playground
    assert "play_hit" in playground
    assert "play_match_start" in playground


def test_smash_audio_defers_scene_tree_player_from_ready() -> None:
    audio = (ROOT / "scripts/core/smash_audio_v1.gd").read_text(encoding="utf-8")
    assert "add_child.call_deferred(player)" in audio
    assert 'player.call_deferred("play")' in audio


def test_input_hint_component() -> None:
    hint = (ROOT / "scripts/ui/jeffrey/components/jeffrey_input_hint.gd").read_text(encoding="utf-8")
    assert "class_name JeffreyInputHint" in hint
    assert "KEYBOARD" in hint
    assert "GAMEPAD" in hint
    track = (ROOT / "scripts/track/track_hud.gd").read_text(encoding="utf-8")
    assert "jeffrey_input_hint" in track
    pause = (ROOT / "scripts/ui/kapes_pause_overlay.gd").read_text(encoding="utf-8")
    assert "jeffrey_input_hint" in pause


def test_readme_and_gitignore_release_ready() -> None:
    readme = (ROOT / "README.md").read_text(encoding="utf-8")
    assert "Los Juegos de Jeffrey" in readme
    assert "Godot 4.7.2" in readme
    assert "SMASH" in readme
    assert "TRACK" in readme
    ignore = (ROOT / ".gitignore").read_text(encoding="utf-8")
    assert ".godot/" in ignore
    assert "raw_models" in ignore
    assert ".env" in ignore


def test_smash_visual_audit_doc() -> None:
    path = ROOT / "docs/SMASH_VISUAL_AUDIT_V1.md"
    assert path.is_file()
    text = path.read_text(encoding="utf-8")
    assert "POLISHED INDIE" in text


def test_load_error_fallback_exists() -> None:
    text = (ROOT / "scripts/core/jeffrey/jeffrey_app.gd").read_text(encoding="utf-8")
    assert "ERROR AL CARGAR" in text
    assert "VOLVER AL HUB" in text
