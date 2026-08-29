"""Phase 5: build shared Mixamo -> ActorCore bone map from inspection evidence."""
import json
import os
import sys

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
if SCRIPT_DIR not in sys.path:
    sys.path.insert(0, SCRIPT_DIR)

from actorcore_benchmark_lib import write_json
from actorcore_paths import BONE_MAP_JSON, CHARACTERS, MIXAMO_IDLE_JSON


MIXAMO_SHORT_TO_ACTORCORE = [
    ("Hips", "CC_Base_Hip", True),
    ("Spine", "CC_Base_Waist", False),
    ("Spine1", "CC_Base_Spine01", False),
    ("Spine2", "CC_Base_Spine02", False),
    ("Neck", "CC_Base_NeckTwist01", False),
    ("Head", "CC_Base_Head", False),
    ("LeftShoulder", "CC_Base_L_Clavicle", False),
    ("LeftArm", "CC_Base_L_Upperarm", False),
    ("LeftForeArm", "CC_Base_L_Forearm", False),
    ("LeftHand", "CC_Base_L_Hand", False),
    ("RightShoulder", "CC_Base_R_Clavicle", False),
    ("RightArm", "CC_Base_R_Upperarm", False),
    ("RightForeArm", "CC_Base_R_Forearm", False),
    ("RightHand", "CC_Base_R_Hand", False),
    ("LeftUpLeg", "CC_Base_L_Thigh", False),
    ("LeftLeg", "CC_Base_L_Calf", False),
    ("LeftFoot", "CC_Base_L_Foot", False),
    ("LeftToeBase", "CC_Base_L_ToeBase", False),
    ("RightUpLeg", "CC_Base_R_Thigh", False),
    ("RightLeg", "CC_Base_R_Calf", False),
    ("RightFoot", "CC_Base_R_Foot", False),
    ("RightToeBase", "CC_Base_R_ToeBase", False),
]


def _discover_mixamo_prefix(names: set) -> str:
    for name in names:
        if ":" in name and name.split(":")[-1] == "Hips":
            return name[: name.rfind(":") + 1]
    for name in names:
        if name.startswith("mixamorig") and ":" in name:
            return name.split(":")[0] + ":"
    return "mixamorig:"


def _names_present(rig: dict) -> set:
    return {b["name"] for b in rig.get("bones", [])}


def build_map() -> dict:
    with open(MIXAMO_IDLE_JSON, "r", encoding="utf-8") as fh:
        mixamo = json.load(fh)
    with open(CHARACTERS["terere"]["rig_json"], "r", encoding="utf-8") as fh:
        terere = json.load(fh)
    mixamo_names = _names_present(mixamo)
    actor_names = _names_present(terere)
    prefix = _discover_mixamo_prefix(mixamo_names)
    bones = []
    for short, dst, hip_y in MIXAMO_SHORT_TO_ACTORCORE:
        src = prefix + short
        present = src in mixamo_names and dst in actor_names
        entry = {
            "source": src,
            "target": dst,
            "class": "REQUIRED" if present else "MISSING",
            "allow_location_y": hip_y,
        }
        bones.append(entry)
    unmapped_actor = sorted(actor_names - {b[1] for b in MIXAMO_SHORT_TO_ACTORCORE})
    for name in unmapped_actor:
        cls = "OPTIONAL"
        if any(k in name for k in ("Toe", "Twist", "Finger", "Mid", "Index", "Ring", "Pinky", "Thumb", "BigToe")):
            cls = "OPTIONAL"
        elif name.startswith("CC_Base_"):
            cls = "UNMAPPED"
        bones.append({"target": name, "source": None, "class": cls})
    return {
        "version": 1,
        "shared_by": ["terere", "jaguarete"],
        "mixamo_prefix": prefix,
        "actorcore_prefix": "CC_Base_",
        "bones": bones,
        "required_count": sum(1 for b in bones if b.get("class") == "REQUIRED"),
    }


def main() -> None:
    data = build_map()
    write_json(BONE_MAP_JSON, data)
    print("Wrote %s required=%d" % (BONE_MAP_JSON, data["required_count"]))


if __name__ == "__main__":
    main()
