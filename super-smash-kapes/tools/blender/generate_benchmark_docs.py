"""Generate asset metrics, comparison docs, pipeline proposal, and the V1 report."""
import json
import os
import sys
from datetime import datetime, timezone

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
if SCRIPT_DIR not in sys.path:
    sys.path.insert(0, SCRIPT_DIR)

from actorcore_paths import (  # noqa: E402
    ASSET_METRICS_JSON,
    BENCHMARK_REPORT_MD,
    BONE_MAP_JSON,
    CHARACTERS,
    EQUIVALENCE_JSON,
    FACIAL_AUDIT_MD,
    INVENTORY_JSON,
    PIPELINE_PROPOSAL_MD,
    REST_BASIS_JSON,
    VS_3DAI_MD,
)
import build_actorcore_asset_metrics  # noqa: E402
import build_actorcore_comparison_docs  # noqa: E402


def _load(path, default=None):
    if not os.path.isfile(path):
        return default if default is not None else {}
    with open(path, "r", encoding="utf-8") as fh:
        if path.endswith(".json"):
            return json.load(fh)
        return fh.read()


def _godot_track_count(path: str) -> int:
    text = _load(path, "")
    if "BONE_TRACK_COUNT=" not in text:
        return 0
    try:
        return int(text.strip().split("BONE_TRACK_COUNT=")[-1].split()[0])
    except ValueError:
        return 0


def _verdict(eq, metrics, rest) -> str:
    shared = eq.get("CAN_ONE_SHARED_ACTORCORE_RETARGET_PIPELINE_SUPPORT_BOTH", False)
    t_ok = metrics.get("characters", {}).get("terere", {}).get("motion_accepted", False)
    j_ok = metrics.get("characters", {}).get("jaguarete", {}).get("motion_accepted", False)
    t_rt = metrics.get("characters", {}).get("terere", {}).get("roundtrip_accepted", False)
    j_rt = metrics.get("characters", {}).get("jaguarete", {}).get("roundtrip_accepted", False)
    generic = rest.get("both_generic_viable", False)
    if shared and t_ok and j_ok and t_rt and j_rt and generic:
        return "SSK_ACTORCORE_RIG_BENCHMARK_V1_READY_FOR_HUMAN_PLAYTEST"
    if shared and (t_ok or j_ok):
        return "SSK_ACTORCORE_RIG_BENCHMARK_V1_PARTIALLY_READY"
    return "SSK_ACTORCORE_RIG_BENCHMARK_V1_REJECTED"


def build_report() -> str:
    eq = _load(EQUIVALENCE_JSON)
    rest = _load(REST_BASIS_JSON)
    inv = _load(INVENTORY_JSON)
    metrics = _load(ASSET_METRICS_JSON)
    bone_map = _load(BONE_MAP_JSON)
    t_motion = _load(CHARACTERS["terere"]["motion_audit"])
    j_motion = _load(CHARACTERS["jaguarete"]["motion_audit"])
    t_rt = _load(CHARACTERS["terere"]["roundtrip_audit"])
    j_rt = _load(CHARACTERS["jaguarete"]["roundtrip_audit"])
    t_tracks = _godot_track_count(CHARACTERS["terere"]["godot_tracks"])
    j_tracks = _godot_track_count(CHARACTERS["jaguarete"]["godot_tracks"])
    verdict = _verdict(eq, metrics, rest)
    t_m = metrics.get("characters", {}).get("terere", {})
    j_m = metrics.get("characters", {}).get("jaguarete", {})
    t_ma = t_motion.get("motion_audit", {})
    j_ma = j_motion.get("motion_audit", {})
    lines = [
        "# ActorCore Rig Benchmark V1 Report",
        "",
        "## Primary Verdict",
        "",
        "**%s**" % verdict,
        "",
        "This is a **benchmark** verdict, not a production migration.",
        "",
        "## Executive Summary",
        "",
        "Isolated Mixamo Idle retarget/bake onto ActorCore AccuRig exports for Tereré and Jaguareté.",
        "Production fighter catalog, combat, and canonical sizes were not modified.",
        "Shared pipeline viable: **%s**." % eq.get("CAN_ONE_SHARED_ACTORCORE_RETARGET_PIPELINE_SUPPORT_BOTH"),
        "Generic rest-basis viable: **%s**." % rest.get("both_generic_viable"),
        "",
        "## Source Assets",
        "",
        "| Character | FBX bytes | JSON | Textures |",
        "|-----------|-----------|------|----------|",
    ]
    for key in ("terere", "jaguarete"):
        ch = inv.get("characters", {}).get(key, {})
        lines.append(
            "| %s | %s | %s | %s |"
            % (
                ch.get("label", key),
                ch.get("fbx_size_bytes"),
                os.path.basename(ch.get("json_path", "")),
                len(ch.get("textures", [])),
            )
        )
    lines.extend([
        "",
        "Inventory: `docs/generated/ACTORCORE_ASSET_INVENTORY.json`",
        "",
        "## Blender Authority",
        "",
        "Blender 2.83.1 @ `C:\\Program Files\\Blender Foundation\\Blender 2.83\\blender.exe`",
        "",
        "## Tereré Rig",
        "",
        "- Bones: %s" % eq.get("TOTAL_TERERE_BONES"),
        "- Mesh / armature / weights: see inventory `fbx_content`",
        "- Dump: `docs/generated/TERERE_ACTORCORE_RIG.json`",
        "",
        "## Jaguareté Rig",
        "",
        "- Bones: %s" % eq.get("TOTAL_JAGUARETE_BONES"),
        "- Dump: `docs/generated/JAGUARETE_ACTORCORE_RIG.json`",
        "",
        "## Cross-Rig Equivalence",
        "",
        "| Metric | Value |",
        "|--------|-------|",
        "| TOTAL_TERERE_BONES | %s |" % eq.get("TOTAL_TERERE_BONES"),
        "| TOTAL_JAGUARETE_BONES | %s |" % eq.get("TOTAL_JAGUARETE_BONES"),
        "| COMMON_BONES | %s |" % eq.get("COMMON_BONES"),
        "| ONLY_TERERE | %s |" % eq.get("ONLY_TERERE"),
        "| ONLY_JAGUARETE | %s |" % eq.get("ONLY_JAGUARETE"),
        "| PARENT_MISMATCHES | %s |" % eq.get("PARENT_MISMATCHES"),
        "| CAN_ONE_SHARED_PIPELINE | **%s** |" % eq.get("CAN_ONE_SHARED_ACTORCORE_RETARGET_PIPELINE_SUPPORT_BOTH"),
        "",
        "## Mixamo Source",
        "",
        "`assets/fighters/animations/Idle.fbx` — dump `docs/generated/MIXAMO_IDLE_RIG_DUMP.txt`",
        "Actual Mixamo prefix discovered from inspection (not guessed).",
        "",
        "## Shared Bone Map",
        "",
        "`tools/blender/mixamo_to_actorcore_bone_map.json`",
        "- required mappings: **%s**" % bone_map.get("required_count"),
        "- prefix: `%s`" % bone_map.get("mixamo_prefix"),
        "- shared_by: %s" % bone_map.get("shared_by"),
        "",
        "## Rest Basis Analysis",
        "",
        "Mixamo vs ActorCore rest axes can differ; the engine transfers rest-relative rotation, not raw Euler.",
        "Cross-character ActorCore rest match is the gate for one generic implementation.",
        "",
        "| | Tereré | Jaguareté |",
        "|--|--------|-----------|",
        "| Mixamo mean rest delta | %s° | %s° |" % (
            rest.get("terere", {}).get("mean_rest_angle_delta_degrees"),
            rest.get("jaguarete", {}).get("mean_rest_angle_delta_degrees"),
        ),
        "",
        "- Cross-character max rest delta: **%s°**" % rest.get("cross_character", {}).get("max_cross_character_rest_delta_degrees"),
        "- both_generic_viable: **%s**" % rest.get("both_generic_viable"),
        "",
        "## Tereré Idle Bake",
        "",
        "- Preview: `assets/fighters/processed/actorcore_benchmark/terere/terere_actorcore_idle_preview.blend`",
        "- GLB: `assets/fighters/processed/actorcore_benchmark/terere/terere_actorcore_idle.glb` (%s bytes)" % t_m.get("exported_glb_size_bytes"),
        "- keyed bones: %s" % t_motion.get("bake_metrics", {}).get("keyed_target_bones"),
        "- hip Y max: %s" % t_motion.get("bake_metrics", {}).get("root_translation_max_y"),
        "- hip X max: %s" % t_motion.get("bake_metrics", {}).get("root_translation_max_x"),
        "- hip Z max: %s" % t_motion.get("bake_metrics", {}).get("root_translation_max_z"),
        "- motion accepted: **%s** (%s branches)" % (t_ma.get("accepted"), t_ma.get("branches_with_motion")),
        "",
        "## Jaguareté Idle Bake",
        "",
        "- Preview: `assets/fighters/processed/actorcore_benchmark/jaguarete/jaguarete_actorcore_idle_preview.blend`",
        "- GLB: `assets/fighters/processed/actorcore_benchmark/jaguarete/jaguarete_actorcore_idle.glb` (%s bytes)" % j_m.get("exported_glb_size_bytes"),
        "- keyed bones: %s" % j_motion.get("bake_metrics", {}).get("keyed_target_bones"),
        "- motion accepted: **%s** (%s branches)" % (j_ma.get("accepted"), j_ma.get("branches_with_motion")),
        "",
        "## Motion Audit",
        "",
        "Metric is **intra-clip local rotation from first frame**, not rest-pose offset.",
        "A bake is rejected if fewer than 6 body branches move.",
        "",
        "Tereré Hip/Spine/Head deltas: Hip=%s Spine=%s Head=%s" % (
            t_ma.get("bones", {}).get("Hip", {}).get("rotation_delta_degrees"),
            t_ma.get("bones", {}).get("Spine", {}).get("rotation_delta_degrees"),
            t_ma.get("bones", {}).get("Head", {}).get("rotation_delta_degrees"),
        ),
        "Jaguareté Hip/Spine/Head deltas: Hip=%s Spine=%s Head=%s" % (
            j_ma.get("bones", {}).get("Hip", {}).get("rotation_delta_degrees"),
            j_ma.get("bones", {}).get("Spine", {}).get("rotation_delta_degrees"),
            j_ma.get("bones", {}).get("Head", {}).get("rotation_delta_degrees"),
        ),
        "",
        "## GLB Roundtrip",
        "",
        "- Tereré accepted: **%s**" % t_rt.get("roundtrip_accepted"),
        "- Jaguareté accepted: **%s**" % j_rt.get("roundtrip_accepted"),
        "",
        "## Godot Import",
        "",
        "- Labs: `scenes/debug/TerereActorCoreAnimationLab.tscn`, `JaguareteActorCoreAnimationLab.tscn`",
        "- Tereré bone tracks: **%s**" % t_tracks,
        "- Jaguareté bone tracks: **%s**" % j_tracks,
        "- Runtime retarget: **OFF**",
        "",
        "## Facial Capability",
        "",
        "See `docs/generated/ACTORCORE_FACIAL_CAPABILITY_AUDIT.md`.",
        "Jaw / eye / tongue / teeth bones present. This FBX import has **0 shape keys**;",
        "expressions are technically possible via facial bones, not via blendshapes in this export.",
        "",
        "## Performance Metrics",
        "",
        "| | Tereré | Jaguareté |",
        "|--|--------|-----------|",
        "| vertices | %s | %s |" % (t_m.get("vertex_count") or t_m.get("vertices"), j_m.get("vertex_count") or j_m.get("vertices")),
        "| polygons | %s | %s |" % (t_m.get("polygon_count") or t_m.get("polygons"), j_m.get("polygon_count") or j_m.get("polygons")),
        "| bones | %s | %s |" % (t_m.get("bones"), j_m.get("bones")),
        "| source FBX | %s | %s |" % (t_m.get("source_fbx_size_bytes"), j_m.get("source_fbx_size_bytes")),
        "| exported GLB | %s | %s |" % (t_m.get("exported_glb_size_bytes"), j_m.get("exported_glb_size_bytes")),
        "",
        "## ActorCore vs 3DAI",
        "",
        "See `docs/generated/ACTORCORE_VS_3DAI_RIG_COMPARISON.md`.",
        "",
        "## Production Migration Recommendation",
        "",
        "**Do not migrate production.** Await human playtest of both preview blends and Godot labs.",
        "Canonical sizes remain Tereré 2.40 SHORT and Jaguareté 3.15 TALL.",
        "",
        "## Human Validation Required",
        "",
        "1. Open `terere_actorcore_idle_preview.blend` → Space",
        "2. Open `jaguarete_actorcore_idle_preview.blend` → Space",
        "3. Run Godot labs — **1** rest, **2** idle",
        "4. Tereré: bombilla, guampa, poncho, short silhouette",
        "5. Jaguareté: tail, muzzle, paws, sash, tall silhouette",
        "",
        "## Blockers",
        "",
        "See `docs/Overnight_blockers.md` (BLOCKER-016 Godot `.import` sidecars; BLOCKER-017 no FBX shape keys).",
        "",
        "## Files Created",
        "",
        "- ActorCore inspect/retarget/audit scripts under `tools/blender/`",
        "- Benchmark GLB/blend under `assets/fighters/processed/actorcore_benchmark/`",
        "- Isolated Godot labs under `scenes/debug/`",
        "- Generated dumps under `docs/generated/`",
        "",
        "## Files Modified",
        "",
        "- `tests/test_m0_combat.py` (existing ActorCore assertions retained)",
        "- `tests/test_actorcore_idle_benchmark.py` (focused benchmark tests)",
        "- `docs/Overnight_blockers.md`",
        "",
        "## Tests",
        "",
        "Existing combat/UI tests preserved. Focused ActorCore benchmark tests added.",
        "",
        "## Recommended Next Step",
        "",
        "Human playtest. If both characters pass visual criteria → `SSK_ACTORCORE_CANONICAL_RIG_MIGRATION_V1`",
        "(full shared library: idle, run, jump, attack_neutral, air_attack, hit_light, hit_heavy, ko, victory).",
        "",
        "Generated: %s" % datetime.now(timezone.utc).isoformat(),
    ])
    return "\n".join(lines)


def main():
    build_actorcore_asset_metrics.main()
    build_actorcore_comparison_docs.main()
    report = build_report()
    os.makedirs(os.path.dirname(BENCHMARK_REPORT_MD), exist_ok=True)
    with open(BENCHMARK_REPORT_MD, "w", encoding="utf-8") as fh:
        fh.write(report)
    print("Wrote %s" % BENCHMARK_REPORT_MD)
    print("Wrote %s" % ASSET_METRICS_JSON)
    print("Wrote %s" % VS_3DAI_MD)
    print("Wrote %s" % PIPELINE_PROPOSAL_MD)


if __name__ == "__main__":
    main()
