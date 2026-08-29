"""Phase 15 + 18: generate comparison and pipeline proposal docs."""
import json
import os
import sys

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
if SCRIPT_DIR not in sys.path:
    sys.path.insert(0, SCRIPT_DIR)

from actorcore_paths import (
    ASSET_METRICS_JSON,
    CHARACTERS,
    EQUIVALENCE_JSON,
    PIPELINE_PROPOSAL_MD,
    REST_BASIS_JSON,
    VS_3DAI_MD,
)


def _load(path):
    if not os.path.isfile(path):
        return {}
    with open(path, "r", encoding="utf-8") as fh:
        return json.load(fh)


def build_comparison() -> str:
    eq = _load(EQUIVALENCE_JSON)
    rest = _load(REST_BASIS_JSON)
    metrics = _load(ASSET_METRICS_JSON)
    shared = eq.get("CAN_ONE_SHARED_ACTORCORE_RETARGET_PIPELINE_SUPPORT_BOTH", False)
    terere_motion = metrics["characters"]["terere"].get("motion_accepted", False)
    jag_motion = metrics["characters"]["jaguarete"].get("motion_accepted", False)
    both_technical = terere_motion and jag_motion and shared

    if both_technical:
        verdict = "ACTORCORE BETTER (pending human visual confirmation)"
    elif shared:
        verdict = "INCONCLUSIVE — structural match but motion quality unproven"
    else:
        verdict = "CURRENT 3DAI BETTER (ActorCore rigs not equivalent enough)"

    lines = [
        "# ActorCore vs 3DAI Rig Comparison",
        "",
        "**Automated verdict:** %s" % verdict,
        "",
        "## Skeleton Consistency",
        "- ActorCore Tereré bones: %d" % eq.get("TOTAL_TERERE_BONES", 0),
        "- ActorCore Jaguareté bones: %d" % eq.get("TOTAL_JAGUARETE_BONES", 0),
        "- Common bones: %d" % eq.get("COMMON_BONES", 0),
        "- Shared pipeline viable: **%s**" % shared,
        "",
        "## Bone Naming",
        "- ActorCore: `CC_Base_*` AccuRig standard",
        "- 3DAI v2 Jaguareté: custom (`Hip`, `L_Thigh`, …)",
        "- 3DAI Tereré: static mesh / no shared skeleton",
        "",
        "## Bone Count",
        "- ActorCore: ~100+ with fingers/facial",
        "- 3DAI Jaguareté v2: 41",
        "",
        "## Hierarchy Consistency",
        "- Parent mismatches between Tereré/Jaguareté ActorCore: %d" % len(eq.get("PARENT_MISMATCHES", [])),
        "",
        "## T-Pose Quality",
        "- Human validation required in preview `.blend` files",
        "",
        "## Mixamo Retarget Complexity",
        "- ActorCore: one shared `mixamo_to_actorcore_bone_map.json`",
        "- 3DAI: per-character bone names + custom maps",
        "",
        "## Need For Per-Character Hacks",
        "- ActorCore: generic retarget script, same map",
        "- 3DAI Jaguareté: custom `jaguarete_mixamo_bone_map.json`",
        "",
        "## Bone Basis Compatibility",
        "- Tereré mean rest delta: %s°" % rest.get("terere", {}).get("mean_rest_angle_delta_degrees", "?"),
        "- Jaguareté mean rest delta: %s°" % rest.get("jaguarete", {}).get("mean_rest_angle_delta_degrees", "?"),
        "",
        "## Facial Rig Potential",
        "- ActorCore includes jaw/eye/tongue/teeth bones; this FBX has 0 shape keys",
        "- 3DAI v2: no facial rig",
        "",
        "## Godot Import",
        "- Benchmark GLBs under `processed/actorcore_benchmark/`",
        "- Isolated debug labs only — production unchanged",
        "",
        "## Animation Track Quality",
        "- See `*_ACTORCORE_GODOT_TRACKS.txt`",
        "",
        "## Mesh Deformation",
        "- Human validation required",
        "",
        "## Pipeline Reusability",
        "- ActorCore: HIGH if shared pipeline = true",
        "- 3DAI: LOW — per-character retarget",
        "",
        "## Future Fighter Scalability",
        "- ActorCore AccuRig export → shared offline bake is scalable",
        "- 3DAI requires bespoke skeleton mapping per fighter",
        "",
        "## Explicit Answer",
        "",
        verdict,
    ]
    return "\n".join(lines)


def build_proposal(shared: bool) -> str:
    lines = [
        "# Fighter Animation Pipeline V3 Proposal",
        "",
        "> **Status:** BENCHMARK ONLY — do not migrate production without human approval.",
        "",
        "## Proposed Standard (if ActorCore benchmark passes)",
        "",
        "```",
        "REFERENCE IMAGES",
        "        ↓",
        "3D GENERATION",
        "        ↓",
        "ACTORCORE / ACCURIG",
        "        ↓",
        "CANONICAL CC_Base_* SKELETON",
        "        ↓",
        "BLENDER OFFLINE RETARGET + BAKE (Mixamo → ActorCore)",
        "        ↓",
        "game_ready.glb (per fighter / per animation set)",
        "        ↓",
        "GODOT (embedded AnimationPlayer, no runtime retarget)",
        "```",
        "",
        "## Shared Pipeline Components",
        "",
        "- `tools/blender/mixamo_to_actorcore_bone_map.json`",
        "- `tools/blender/retarget_mixamo_to_actorcore.py`",
        "- `tools/build_actorcore_idle_benchmark.ps1`",
        "",
        "## Canonical Sizing (unchanged)",
        "",
        "- Tereré: SHORT, 2.40",
        "- Jaguareté: TALL, 3.15",
        "",
        "## Shared retarget viable: **%s**" % shared,
        "",
        "## Next milestone (NOT this task)",
        "",
        "SSK_ACTORCORE_CANONICAL_RIG_MIGRATION_V1",
        "",
        "Bake full library: idle, run, jump, attack_neutral, hit_light, hit_heavy, ko, victory",
    ]
    return "\n".join(lines)


def main() -> None:
    eq = _load(EQUIVALENCE_JSON)
    shared = eq.get("CAN_ONE_SHARED_ACTORCORE_RETARGET_PIPELINE_SUPPORT_BOTH", False)
    os.makedirs(os.path.dirname(VS_3DAI_MD), exist_ok=True)
    with open(VS_3DAI_MD, "w", encoding="utf-8") as fh:
        fh.write(build_comparison())
    with open(PIPELINE_PROPOSAL_MD, "w", encoding="utf-8") as fh:
        fh.write(build_proposal(shared))
    print("Wrote %s" % VS_3DAI_MD)
    print("Wrote %s" % PIPELINE_PROPOSAL_MD)


if __name__ == "__main__":
    main()
