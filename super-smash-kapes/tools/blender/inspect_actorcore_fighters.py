"""
Phase 2 + 4 + inventory FBX flags + facial audit inputs.
Inspect ActorCore rigs and Mixamo Idle in Blender 2.83.
"""
import json
import os
import sys

import bpy

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
if SCRIPT_DIR not in sys.path:
    sys.path.insert(0, SCRIPT_DIR)

from actorcore_benchmark_lib import (  # noqa: E402
    collect_rig_data,
    dump_rig_text,
    ensure_dir,
    find_armature,
    find_source_action,
    import_fbx,
    motion_audit_for_action,
    reset_scene,
    write_json,
)
from actorcore_paths import (  # noqa: E402
    CHARACTERS,
    FACIAL_AUDIT_MD,
    GENERATED_DIR,
    IDLE_FBX,
    INVENTORY_JSON,
    MIXAMO_IDLE_DUMP,
    MIXAMO_IDLE_JSON,
)


FACIAL_BONE_KEYWORDS = ("Jaw", "Eye", "Tongue", "Teeth", "Facial", "Brow", "Lip", "Cheek", "Nose")
FACIAL_SHAPE_KEYWORDS = ("brow", "eye", "jaw", "mouth", "lip", "cheek", "nose", "blink", "smile", "frown")


def inspect_actorcore_fbx(character_key: str) -> dict:
    cfg = CHARACTERS[character_key]
    reset_scene()
    import_fbx(cfg["fbx"])
    arm = find_armature("Armature")
    if arm is None:
        arm = find_armature()
    if arm is None:
        raise RuntimeError("No armature in %s" % cfg["fbx"])
    rig = collect_rig_data(arm)
    rig["character"] = character_key
    rig["source_fbx"] = cfg["fbx"]
    text = dump_rig_text("%s ActorCore Rig" % cfg["label"], rig)
    ensure_dir(os.path.dirname(cfg["rig_dump_txt"]))
    with open(cfg["rig_dump_txt"], "w", encoding="utf-8") as fh:
        fh.write(text)
    write_json(cfg["rig_json"], rig)
    print("Wrote %s" % cfg["rig_dump_txt"])
    print("Wrote %s" % cfg["rig_json"])
    return rig


MIXAMO_AUDIT_BONES = [
    ("Hips", "Hips"),
    ("Spine", "Spine"),
    ("Spine1", "Spine1"),
    ("Spine2", "Spine2"),
    ("Neck", "Neck"),
    ("Head", "Head"),
    ("LeftShoulder", "LeftShoulder"),
    ("LeftArm", "LeftArm"),
    ("LeftForeArm", "LeftForeArm"),
    ("LeftHand", "LeftHand"),
    ("RightShoulder", "RightShoulder"),
    ("RightArm", "RightArm"),
    ("RightForeArm", "RightForeArm"),
    ("RightHand", "RightHand"),
    ("LeftUpLeg", "LeftUpLeg"),
    ("LeftLeg", "LeftLeg"),
    ("LeftFoot", "LeftFoot"),
    ("RightUpLeg", "RightUpLeg"),
    ("RightLeg", "RightLeg"),
    ("RightFoot", "RightFoot"),
]


def _mixamo_bone_name(arm, suffix: str) -> str:
    for bone in arm.data.bones:
        short = bone.name.split(":")[-1]
        if short == suffix:
            return bone.name
    return suffix


def inspect_mixamo_idle() -> dict:
    reset_scene()
    bpy.context.scene.render.fps = 30
    import_fbx(IDLE_FBX)
    arm = find_armature()
    if arm is None:
        raise RuntimeError("No Mixamo armature in Idle.fbx")
    rig = collect_rig_data(arm)
    action = find_source_action(arm, "mixamo")
    root_motion = []
    if action:
        hip_name = _mixamo_bone_name(arm, "Hips")
        for axis, label in enumerate(("x", "y", "z")):
            path = 'pose.bones["%s"].location' % hip_name
            fc = action.fcurves.find(path, index=axis)
            if fc:
                vals = [kp.co[1] for kp in fc.keyframe_points]
                if vals:
                    root_motion.append({
                        "bone": hip_name,
                        "axis": label,
                        "min": min(vals),
                        "max": max(vals),
                        "keys": len(vals),
                    })
        arm.animation_data_create()
        arm.animation_data.action = action
        named_pairs = [(label, _mixamo_bone_name(arm, suffix)) for label, suffix in MIXAMO_AUDIT_BONES]
        angular = motion_audit_for_action(arm, action, named_pairs)
        rig["angular_motion"] = angular
    else:
        rig["angular_motion"] = {}
    rig["mixamo_action"] = action.name if action else ""
    rig["root_motion"] = root_motion
    text = dump_rig_text("Mixamo Idle", rig)
    text += "\nmixamo_action=%s\n" % rig["mixamo_action"]
    text += "root_motion:\n" + "\n".join("  " + str(x) for x in root_motion)
    text += "\nangular_motion (intra-clip local rotation):\n"
    for label, data in rig.get("angular_motion", {}).get("bones", {}).items():
        text += "  %s: %s\n" % (label, data)
    with open(MIXAMO_IDLE_DUMP, "w", encoding="utf-8") as fh:
        fh.write(text)
    write_json(MIXAMO_IDLE_JSON, rig)
    print("Wrote %s" % MIXAMO_IDLE_DUMP)
    return rig


def update_inventory_fbx_flags(terere_rig: dict, jaguarete_rig: dict) -> None:
    if not os.path.isfile(INVENTORY_JSON):
        return
    with open(INVENTORY_JSON, "r", encoding="utf-8") as fh:
        inv = json.load(fh)
    for key, rig in (("terere", terere_rig), ("jaguarete", jaguarete_rig)):
        meshes = rig.get("meshes", [])
        inv["characters"][key]["fbx_content"] = {
            "mesh": len(meshes) > 0,
            "armature": rig.get("bone_count", 0) > 0,
            "skin_weights": any(m.get("vertex_groups", 0) > 0 for m in meshes),
            "animations": len(rig.get("actions", [])) > 0,
            "blendshapes": len(rig.get("shape_keys", [])) > 0,
            "mesh_count": len(meshes),
            "bone_count": rig.get("bone_count", 0),
            "shape_key_count": len(rig.get("shape_keys", [])),
        }
    write_json(INVENTORY_JSON, inv)


def write_facial_audit(terere_rig: dict, jaguarete_rig: dict) -> None:
    lines = ["# ActorCore Facial Capability Audit", ""]
    for key, rig in (("terere", terere_rig), ("jaguarete", jaguarete_rig)):
        label = CHARACTERS[key]["label"]
        lines.append("## %s" % label)
        facial_bones = [b["name"] for b in rig["bones"] if any(k in b["name"] for k in FACIAL_BONE_KEYWORDS)]
        facial_shapes = [sk for sk in rig.get("shape_keys", []) if any(k in sk["name"].lower() for k in FACIAL_SHAPE_KEYWORDS)]
        lines.append("- facial_bones: %d" % len(facial_bones))
        for name in facial_bones[:30]:
            lines.append("  - %s" % name)
        if len(facial_bones) > 30:
            lines.append("  - ... %d more" % (len(facial_bones) - 30))
        lines.append("- facial_shape_keys: %d" % len(facial_shapes))
        if not facial_shapes:
            lines.append("- note: this AccuRig FBX import contains **no shape keys**; facial posing must use bones (jaw/eyes/tongue/teeth).")
        for sk in facial_shapes[:20]:
            lines.append("  - %s (%s)" % (sk["name"], sk["mesh"]))
        bone_ok = bool(facial_bones)
        shape_ok = bool(facial_shapes)
        lines.append("- hurt_expression_possible: %s" % ("yes_via_blendshapes" if shape_ok else ("yes_via_bones" if bone_ok else "unlikely")))
        lines.append("- ko_face_possible: %s" % ("yes_via_blendshapes" if shape_ok else ("yes_via_bones" if bone_ok else "unlikely")))
        lines.append("- victory_expression_possible: %s" % ("yes_via_blendshapes" if shape_ok else ("yes_via_bones" if bone_ok else "unlikely")))
        lines.append("- taunt_possible: %s" % ("yes_via_blendshapes" if shape_ok else ("yes_via_bones" if bone_ok else "unlikely")))
        lines.append("")
    ensure_dir(os.path.dirname(FACIAL_AUDIT_MD))
    with open(FACIAL_AUDIT_MD, "w", encoding="utf-8") as fh:
        fh.write("\n".join(lines))
    print("Wrote %s" % FACIAL_AUDIT_MD)


def main() -> None:
    ensure_dir(GENERATED_DIR)
    terere = inspect_actorcore_fbx("terere")
    jaguarete = inspect_actorcore_fbx("jaguarete")
    mixamo = inspect_mixamo_idle()
    update_inventory_fbx_flags(terere, jaguarete)
    write_facial_audit(terere, jaguarete)
    print("Inspection complete. Mixamo bones=%d" % mixamo["bone_count"])


if __name__ == "__main__":
    main()
