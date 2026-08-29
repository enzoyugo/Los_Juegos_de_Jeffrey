"""Phase 12: GLB roundtrip motion audit."""
import argparse
import json
import os
import sys

import bpy

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
if SCRIPT_DIR not in sys.path:
    sys.path.insert(0, SCRIPT_DIR)

from actorcore_benchmark_lib import find_armature, import_gltf, motion_audit_for_action, reset_scene, write_json
from actorcore_paths import CHARACTERS, MOTION_AUDIT_BONES


def parse_args():
    argv = sys.argv
    if "--" in argv:
        argv = argv[argv.index("--") + 1:]
    else:
        argv = []
    parser = argparse.ArgumentParser()
    parser.add_argument("--character", required=True, choices=["terere", "jaguarete"])
    return parser.parse_args(argv)


def main():
    args = parse_args()
    cfg = CHARACTERS[args.character]
    reset_scene()
    import_gltf(cfg["output_glb"])
    arm = find_armature()
    action = None
    if arm and arm.animation_data and arm.animation_data.action:
        action = arm.animation_data.action
    if action is None:
        for act in bpy.data.actions:
            if "idle" in act.name.lower() or act.name == "idle":
                action = act
                if arm.animation_data is None:
                    arm.animation_data_create()
                arm.animation_data.action = act
                break
    if action is None and bpy.data.actions:
        action = bpy.data.actions[0]
        arm.animation_data_create()
        arm.animation_data.action = action
    motion = motion_audit_for_action(arm, action, MOTION_AUDIT_BONES)
    report = {
        "character": args.character,
        "glb": cfg["output_glb"],
        "armature": arm.name if arm else "",
        "action": action.name if action else "",
        "motion_audit": motion,
        "roundtrip_accepted": motion.get("accepted", False),
    }
    write_json(cfg["roundtrip_audit"], report)
    print("Roundtrip %s accepted=%s" % (args.character, report["roundtrip_accepted"]))


if __name__ == "__main__":
    main()
