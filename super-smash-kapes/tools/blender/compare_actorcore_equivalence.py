"""Phase 3: compare Tereré vs Jaguareté ActorCore rig equivalence."""
import json
import os
import sys

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
if SCRIPT_DIR not in sys.path:
    sys.path.insert(0, SCRIPT_DIR)

from actorcore_benchmark_lib import write_json
from actorcore_paths import CHARACTERS, CRITICAL_BONES, EQUIVALENCE_JSON


def _bone_map(rig: dict) -> dict:
    return {b["name"]: b for b in rig.get("bones", [])}


def _depth(bone_name: str, bones: dict) -> int:
    depth = 0
    current = bone_name
    seen = set()
    while current and current in bones and current not in seen:
        seen.add(current)
        parent = bones[current].get("parent")
        if not parent:
            break
        depth += 1
        current = parent
    return depth


def compare() -> dict:
    with open(CHARACTERS["terere"]["rig_json"], "r", encoding="utf-8") as fh:
        terere = json.load(fh)
    with open(CHARACTERS["jaguarete"]["rig_json"], "r", encoding="utf-8") as fh:
        jaguarete = json.load(fh)
    t_bones = _bone_map(terere)
    j_bones = _bone_map(jaguarete)
    t_names = set(t_bones)
    j_names = set(j_bones)
    common = sorted(t_names & j_names)
    only_terere = sorted(t_names - j_names)
    only_jaguarete = sorted(j_names - t_names)
    parent_mismatches = []
    bone_details = []
    for name in common:
        t_parent = t_bones[name].get("parent")
        j_parent = j_bones[name].get("parent")
        same_parent = t_parent == j_parent
        if not same_parent:
            parent_mismatches.append({
                "bone": name,
                "terere_parent": t_parent,
                "jaguarete_parent": j_parent,
            })
        t_depth = _depth(name, t_bones)
        j_depth = _depth(name, j_bones)
        bone_details.append({
            "bone": name,
            "exists_terere": True,
            "exists_jaguarete": True,
            "same_parent": same_parent,
            "same_semantic_role": True,
            "similar_hierarchy_depth": t_depth == j_depth,
            "terere_parent": t_parent,
            "jaguarete_parent": j_parent,
            "terere_depth": t_depth,
            "jaguarete_depth": j_depth,
        })
    for name in only_terere:
        bone_details.append({"bone": name, "exists_terere": True, "exists_jaguarete": False})
    for name in only_jaguarete:
        bone_details.append({"bone": name, "exists_terere": False, "exists_jaguarete": True})
    critical = {}
    for bone in CRITICAL_BONES:
        critical[bone] = {
            "terere": bone in t_names,
            "jaguarete": bone in j_names,
            "same_parent": bone in common and t_bones[bone].get("parent") == j_bones[bone].get("parent"),
            "same_semantic_role": bone in common,
            "similar_hierarchy_depth": bone in common and _depth(bone, t_bones) == _depth(bone, j_bones),
            "terere_parent": t_bones.get(bone, {}).get("parent"),
            "jaguarete_parent": j_bones.get(bone, {}).get("parent"),
        }
    critical_ok = all(v["terere"] and v["jaguarete"] and v["same_parent"] for v in critical.values())
    hierarchy_ok = len(parent_mismatches) == 0
    shared_pipeline = critical_ok and hierarchy_ok
    return {
        "TOTAL_TERERE_BONES": len(t_names),
        "TOTAL_JAGUARETE_BONES": len(j_names),
        "COMMON_BONES": len(common),
        "ONLY_TERERE": only_terere,
        "ONLY_JAGUARETE": only_jaguarete,
        "PARENT_MISMATCHES": parent_mismatches,
        "CRITICAL_BONES": critical,
        "CAN_ONE_SHARED_ACTORCORE_RETARGET_PIPELINE_SUPPORT_BOTH": shared_pipeline,
        "bone_details": bone_details,
    }


def main() -> None:
    data = compare()
    write_json(EQUIVALENCE_JSON, data)
    print("Wrote %s" % EQUIVALENCE_JSON)
    print("SHARED_PIPELINE=%s" % data["CAN_ONE_SHARED_ACTORCORE_RETARGET_PIPELINE_SUPPORT_BOTH"])


if __name__ == "__main__":
    main()
