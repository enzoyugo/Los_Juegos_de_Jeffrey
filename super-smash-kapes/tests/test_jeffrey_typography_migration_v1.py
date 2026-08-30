from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def test_canonical_jeffrey_fonts_exist():
    expected = [
        "assets/fonts/global/boorsok.ttf",
        "assets/fonts/track/Veter.ttf",
        "assets/fonts/zombies/Super Midnight.ttf",
        "assets/fonts/soco/JUMBOTRON.otf",
        "assets/fonts/soco/Super Crawler.ttf",
    ]
    assert all((ROOT / path).is_file() for path in expected)


def test_typography_authority_maps_all_modes():
    source = (ROOT / "scripts/ui/jeffrey/system/jeffrey_typography.gd").read_text(encoding="utf-8")
    for mode in ("GLOBAL", "TRACK", "ZOMBIES", "SOCO"):
        assert mode in source
    assert "theme_for" in source
    assert "apply_label3d" in source


def test_player_facing_roots_bind_typography_authority():
    bindings = {
        "scripts/core/jeffrey/jeffrey_app.gd": "Typography.GLOBAL",
        "scripts/track/track_hud.gd": "Typography.TRACK",
        "scripts/zombies/zombies_hud.gd": "Typography.ZOMBIES",
        "scripts/ui/kapes_player_hud.gd": "Typography.SOCO",
    }
    for path, token in bindings.items():
        assert token in (ROOT / path).read_text(encoding="utf-8")
