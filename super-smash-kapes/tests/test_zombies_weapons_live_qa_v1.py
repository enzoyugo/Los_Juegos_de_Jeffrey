"""Regression coverage for the Zombies weapon loop and candidate firewall."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def _read(relative: str) -> str:
    return (ROOT / relative).read_text(encoding="utf-8")


def test_weapon_cycle_is_input_reachable_and_preserves_authority() -> None:
    config = _read("scripts/zombies/zombies_config.gd")
    player = _read("scripts/zombies/zombies_player.gd")
    weapon = _read("scripts/zombies/zombies_weapon.gd")
    assert '"z_weapon_next"' in config
    assert "KEY_Q" in config
    assert "func switch_next_weapon" in player
    assert "ids.sort()" in player
    assert "switch_weapon(ids[(index + 1) % ids.size()])" in player
    assert "gun.data.id" in player
    assert "consume_shot" in weapon
    assert "_finish_reload" in weapon


def test_candidate_firewall_and_selected_roster_are_documented() -> None:
    report = _read("docs/ZOMBIES_WEAPONS_LIVE_QA_V1.md")
    assert "TT pistol" in report
    assert "Colt M4A1" in report
    assert "source GLBs remain immutable" in report
    assert "FBX version 6100" in report
    assert "procedural zombie authority" in report
