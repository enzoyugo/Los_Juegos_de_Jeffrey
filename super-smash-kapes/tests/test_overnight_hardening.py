"""Overnight production hardening V1 regressions."""

from pathlib import Path
import json
import struct


PROJECT_ROOT = Path(__file__).resolve().parents[1]


def _read(rel: str) -> str:
    return (PROJECT_ROOT / rel).read_text(encoding="utf-8")


def _glb_json(path: Path) -> dict:
    with path.open("rb") as fh:
        magic = fh.read(4)
        assert magic == b"glTF", path
        _version, _length = struct.unpack("<II", fh.read(8))
        chunk_len, chunk_type = struct.unpack("<I4s", fh.read(8))
        payload = fh.read(chunk_len)
        assert chunk_type in (b"JSON", b"json")
    return json.loads(payload.decode("utf-8"))


def test_clip_relative_retarget_is_default() -> None:
    lib = _read("tools/blender/actorcore_benchmark_lib.py")
    retarget = _read("tools/blender/retarget_mixamo_to_actorcore.py")
    export = _read("tools/blender/export_actorcore_game_ready.py")
    assert "def apply_clip_relative_rotation" in lib
    assert "def capture_clip_reference_quats" in lib
    assert 'default="clip_relative"' in retarget
    assert "apply_clip_relative_rotation" in export
    assert "VOLUME_RATIO_LIMIT = 1.35" in export


def test_v4_bbox_gate_passed() -> None:
    for name in ("TERERE_V4_BBOX_VALIDATION.json", "JAGUARETE_V4_BBOX_VALIDATION.json"):
        data = json.loads(_read("docs/generated/" + name))
        assert data["pass"] is True
        assert data["volume_ratio"] <= 1.35
        assert data["max_axis_ratio"] <= 1.30
        assert data["vertices_over_4_after"] == 0


def test_v4_glb_has_skin_idle_no_mixamo() -> None:
    for rel in (
        "assets/fighters/processed/terere/terere_game_ready_v4.glb",
        "assets/fighters/processed/jaguarete/jaguarete_game_ready_v4.glb",
    ):
        data = _glb_json(PROJECT_ROOT / rel)
        names = [a.get("name", "") for a in data.get("animations", [])]
        assert any("idle" in n.lower() for n in names), names
        assert data.get("skins")
        mixamo = [n.get("name", "") for n in data.get("nodes", []) if "mixamo" in n.get("name", "").lower()]
        assert mixamo == [], mixamo


def test_first_broken_stage_is_retarget() -> None:
    chain = json.loads(_read("docs/generated/PIPELINE_FIRST_BROKEN_STAGE.json"))
    assert chain["FIRST_BROKEN_STAGE_TERERE"].startswith("C_")
    assert chain["FIRST_BROKEN_STAGE_JAGUARETE"].startswith("C_")
    jag = json.loads(_read("docs/generated/JAGUARETE_DEFORMATION_STAGE_CHAIN.json"))
    assert jag["FIRST_BROKEN_STAGE"] == "C_after_retarget_one_frame"


def test_production_points_at_v4_not_exploded_v3() -> None:
    catalog = _read("scripts/fighters/fighter_catalog.gd")
    terere = _read("fighters/terere/terere_actorcore_visual.gd")
    jaguarete = _read("fighters/jaguarete/jaguarete_actorcore_visual.gd")
    for blob in (catalog, terere, jaguarete):
        assert "game_ready_v4.glb" in blob
        assert "game_ready_v3.glb" not in blob
        assert "actorcore_benchmark" not in blob
    assert "ACTORCORE_V4" in catalog


def test_no_runtime_retarget_or_texture_swap_on_hit() -> None:
    visual = _read("scripts/fighters/actorcore_fighter_visual.gd")
    glb = _read("scripts/fighters/glb_fighter_visual.gd")
    assert "runtime_retarget=false" in visual
    assert "duplicate(false)" in glb
    assert "_isolate_fighter_textures" in glb
    assert "albedo_texture =" not in glb.split("func _apply_hit_flash")[1].split("func ")[0]
    assert "emission_enabled" in glb


def test_hud_sockets_include_name_and_mirror() -> None:
    layout = _read("scripts/ui/kapes_hud_layout.gd")
    hud = _read("scripts/ui/kapes_player_hud.gd")
    assert "p1_name_region" in layout
    assert "p2_name_region" in layout
    assert "name_label" in hud
    assert "clip_contents = true" in hud


def test_victory_v6_uses_two_stat_cards() -> None:
    results = _read("scripts/ui/kapes_results_screen.gd")
    assert "_make_stats_card" in results
    assert "WinnerHero" in results
    assert "MAIN_PANEL" not in results
    assert "CAMBIAR KAPES" in results


def test_future_fighter_validator_and_build_script_exist() -> None:
    assert (PROJECT_ROOT / "tools/blender/validate_future_rig.py").is_file()
    assert (PROJECT_ROOT / "tools/build_fighter.ps1").is_file()
    assert (PROJECT_ROOT / "docs/FUTURE_FIGHTER_AUTOMATION_PIPELINE.md").is_file()
    script = _read("tools/build_fighter.ps1")
    assert "-Promote" in script
    assert "will not rewrite fighter_catalog.gd automatically" in script


def test_production_animation_labs_exist() -> None:
    assert (PROJECT_ROOT / "scenes/debug/TerereProductionAnimationLab.tscn").is_file()
    assert (PROJECT_ROOT / "scenes/debug/JaguareteProductionAnimationLab.tscn").is_file()
    shared = _read("scripts/debug/production_animation_lab.gd")
    assert "RUNTIME RETARGET: OFF" in shared
    assert "TARGET HEIGHT" in shared


def test_animation_library_bakes_idle_without_inventing_run() -> None:
    for name in ("TERERE_ANIMATION_LIBRARY_V4.json", "JAGUARETE_ANIMATION_LIBRARY_V4.json"):
        data = json.loads(_read("docs/generated/" + name))
        baked = {item["semantic"] for item in data["baked"]}
        assert "idle" in baked
        assert "run" not in baked
        skipped = {item.get("semantic") for item in data["skipped"]}
        assert "run" in skipped
        assert "victory" in skipped
        assert data["failed"] == []


def test_v4_textures_match_character_source_fbm() -> None:
    data = json.loads(_read("docs/generated/TEXTURE_AUTHORITY_V4.json"))
    v4 = data["production_v4_after_rebind"]
    src = data["source_fbm"]
    assert v4["terere_diffuse"] == src["terere_diffuse"]
    assert v4["jaguarete_diffuse"] == src["jaguarete_diffuse"]
    assert v4["terere_diffuse"] != v4["jaguarete_diffuse"]
    assert "def rebind_actorcore_textures" in _read("tools/blender/actorcore_benchmark_lib.py")


def test_canonical_sizes_unchanged() -> None:
    catalog = _read("scripts/fighters/fighter_catalog.gd")
    assert "target_visual_height = 2.40" in catalog
    assert "target_visual_height = 3.15" in catalog


def test_final_ko_uses_stronger_event_fx() -> None:
    stage = _read("scripts/stages/defensores_stage.gd")
    playground = _read("scripts/core/m0_playground.gd")
    assert "func show_final_ko" in stage
    assert "show_final_ko" in playground
