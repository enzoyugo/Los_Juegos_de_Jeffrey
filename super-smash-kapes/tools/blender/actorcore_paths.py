"""Shared paths for ActorCore rig benchmark (Blender 2.83 + orchestration)."""
import os

BLENDER_EXE = r"C:\Program Files\Blender Foundation\Blender 2.83\blender.exe"

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.normpath(os.path.join(SCRIPT_DIR, "..", ".."))
GENERATED_DIR = os.path.join(PROJECT_ROOT, "docs", "generated")
ANIMATIONS_DIR = os.path.join(PROJECT_ROOT, "assets", "fighters", "animations")
IDLE_FBX = os.path.join(ANIMATIONS_DIR, "Idle.fbx")

CHARACTERS = {
    "terere": {
        "label": "Tereré",
        "source_dir": os.path.join(PROJECT_ROOT, "assets", "fighters", "source_rigged", "terere", "actorcore"),
        "fbx": os.path.join(PROJECT_ROOT, "assets", "fighters", "source_rigged", "terere", "actorcore", "autorig_actor.fbx"),
        "json": os.path.join(PROJECT_ROOT, "assets", "fighters", "source_rigged", "terere", "actorcore", "autorig_actor.json"),
        "fbm_dir": os.path.join(PROJECT_ROOT, "assets", "fighters", "source_rigged", "terere", "actorcore", "autorig_actor.fbm"),
        "rig_dump_txt": os.path.join(GENERATED_DIR, "TERERE_ACTORCORE_RIG_DUMP.txt"),
        "rig_json": os.path.join(GENERATED_DIR, "TERERE_ACTORCORE_RIG.json"),
        "motion_audit": os.path.join(GENERATED_DIR, "TERERE_ACTORCORE_IDLE_MOTION_AUDIT.json"),
        "roundtrip_audit": os.path.join(GENERATED_DIR, "TERERE_ACTORCORE_GLB_ROUNDTRIP_AUDIT.json"),
        "godot_tracks": os.path.join(GENERATED_DIR, "TERERE_ACTORCORE_GODOT_TRACKS.txt"),
        "benchmark_dir": os.path.join(PROJECT_ROOT, "assets", "fighters", "processed", "actorcore_benchmark", "terere"),
        "preview_blend": os.path.join(PROJECT_ROOT, "assets", "fighters", "processed", "actorcore_benchmark", "terere", "terere_actorcore_idle_preview.blend"),
        "output_glb": os.path.join(PROJECT_ROOT, "assets", "fighters", "processed", "actorcore_benchmark", "terere", "terere_actorcore_idle.glb"),
        "canonical_height": 2.40,
        "size_class": "SHORT",
    },
    "jaguarete": {
        "label": "Jaguareté",
        "source_dir": os.path.join(PROJECT_ROOT, "assets", "fighters", "source_rigged", "jaguarete", "actorcore"),
        "fbx": os.path.join(PROJECT_ROOT, "assets", "fighters", "source_rigged", "jaguarete", "actorcore", "autorig_actor.fbx"),
        "json": os.path.join(PROJECT_ROOT, "assets", "fighters", "source_rigged", "jaguarete", "actorcore", "autorig_actor.json"),
        "fbm_dir": os.path.join(PROJECT_ROOT, "assets", "fighters", "source_rigged", "jaguarete", "actorcore", "autorig_actor.fbm"),
        "rig_dump_txt": os.path.join(GENERATED_DIR, "JAGUARETE_ACTORCORE_RIG_DUMP.txt"),
        "rig_json": os.path.join(GENERATED_DIR, "JAGUARETE_ACTORCORE_RIG.json"),
        "motion_audit": os.path.join(GENERATED_DIR, "JAGUARETE_ACTORCORE_IDLE_MOTION_AUDIT.json"),
        "roundtrip_audit": os.path.join(GENERATED_DIR, "JAGUARETE_ACTORCORE_GLB_ROUNDTRIP_AUDIT.json"),
        "godot_tracks": os.path.join(GENERATED_DIR, "JAGUARETE_ACTORCORE_GODOT_TRACKS.txt"),
        "benchmark_dir": os.path.join(PROJECT_ROOT, "assets", "fighters", "processed", "actorcore_benchmark", "jaguarete"),
        "preview_blend": os.path.join(PROJECT_ROOT, "assets", "fighters", "processed", "actorcore_benchmark", "jaguarete", "jaguarete_actorcore_idle_preview.blend"),
        "output_glb": os.path.join(PROJECT_ROOT, "assets", "fighters", "processed", "actorcore_benchmark", "jaguarete", "jaguarete_actorcore_idle.glb"),
        "canonical_height": 3.15,
        "size_class": "TALL",
    },
}

INVENTORY_JSON = os.path.join(GENERATED_DIR, "ACTORCORE_ASSET_INVENTORY.json")
EQUIVALENCE_JSON = os.path.join(GENERATED_DIR, "ACTORCORE_RIG_EQUIVALENCE.json")
MIXAMO_IDLE_DUMP = os.path.join(GENERATED_DIR, "MIXAMO_IDLE_RIG_DUMP.txt")
MIXAMO_IDLE_JSON = os.path.join(GENERATED_DIR, "MIXAMO_IDLE_RIG.json")
BONE_MAP_JSON = os.path.join(SCRIPT_DIR, "mixamo_to_actorcore_bone_map.json")
REST_BASIS_JSON = os.path.join(GENERATED_DIR, "MIXAMO_ACTORCORE_REST_BASIS_AUDIT.json")
FACIAL_AUDIT_MD = os.path.join(GENERATED_DIR, "ACTORCORE_FACIAL_CAPABILITY_AUDIT.md")
ASSET_METRICS_JSON = os.path.join(GENERATED_DIR, "ACTORCORE_BENCHMARK_ASSET_METRICS.json")
VS_3DAI_MD = os.path.join(GENERATED_DIR, "ACTORCORE_VS_3DAI_RIG_COMPARISON.md")
PIPELINE_PROPOSAL_MD = os.path.join(PROJECT_ROOT, "docs", "FIGHTER_ANIMATION_PIPELINE_V3_PROPOSAL.md")
BENCHMARK_REPORT_MD = os.path.join(PROJECT_ROOT, "docs", "ACTORCORE_RIG_BENCHMARK_V1_REPORT.md")

CRITICAL_BONES = [
    "CC_Base_Hip",
    "CC_Base_Pelvis",
    "CC_Base_Spine01",
    "CC_Base_Spine02",
    "CC_Base_NeckTwist01",
    "CC_Base_Head",
    "CC_Base_L_Clavicle",
    "CC_Base_L_Upperarm",
    "CC_Base_L_Forearm",
    "CC_Base_L_Hand",
    "CC_Base_R_Clavicle",
    "CC_Base_R_Upperarm",
    "CC_Base_R_Forearm",
    "CC_Base_R_Hand",
    "CC_Base_L_Thigh",
    "CC_Base_L_Calf",
    "CC_Base_L_Foot",
    "CC_Base_R_Thigh",
    "CC_Base_R_Calf",
    "CC_Base_R_Foot",
]

MOTION_AUDIT_BONES = [
    ("Hip", "CC_Base_Hip"),
    ("Spine", "CC_Base_Spine01"),
    ("UpperSpine", "CC_Base_Spine02"),
    ("Head", "CC_Base_Head"),
    ("L_Clavicle", "CC_Base_L_Clavicle"),
    ("L_UpperArm", "CC_Base_L_Upperarm"),
    ("L_Forearm", "CC_Base_L_Forearm"),
    ("L_Hand", "CC_Base_L_Hand"),
    ("R_Clavicle", "CC_Base_R_Clavicle"),
    ("R_UpperArm", "CC_Base_R_Upperarm"),
    ("R_Forearm", "CC_Base_R_Forearm"),
    ("R_Hand", "CC_Base_R_Hand"),
    ("L_Thigh", "CC_Base_L_Thigh"),
    ("L_Calf", "CC_Base_L_Calf"),
    ("L_Foot", "CC_Base_L_Foot"),
    ("R_Thigh", "CC_Base_R_Thigh"),
    ("R_Calf", "CC_Base_R_Calf"),
    ("R_Foot", "CC_Base_R_Foot"),
]

HIP_Y_SCALE = 0.001
ROOT_XZ_TOLERANCE = 0.05
EXPORT_ACTION_NAME = "idle"
MOTION_ROTATION_THRESHOLD_DEG = 0.35
MOTION_MIN_BRANCHES = 6
