"""Shared path resolution for SSK Blender tooling (Blender 2.83)."""
import os

BLENDER_EXE = r"C:\Program Files\Blender Foundation\Blender 2.83\blender.exe"

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.normpath(os.path.join(SCRIPT_DIR, "..", ".."))

JAGUARETE_V2_GLB = os.path.join(
    PROJECT_ROOT, "assets", "fighters", "models", "jaguarete", "jaguarete_v2.glb"
)
IDLE_FBX = os.path.join(PROJECT_ROOT, "assets", "fighters", "animations", "Idle.fbx")
BONE_MAP_JSON = os.path.join(SCRIPT_DIR, "jaguarete_mixamo_bone_map.json")
RIG_DUMP_TXT = os.path.join(PROJECT_ROOT, "docs", "generated", "JAGUARETE_BLENDER_RIG_DUMP.txt")
BAKE_METRICS_JSON = os.path.join(PROJECT_ROOT, "docs", "generated", "JAGUARETE_IDLE_BAKE_METRICS.json")
PROCESSED_DIR = os.path.join(PROJECT_ROOT, "assets", "fighters", "processed", "jaguarete")
PREVIEW_BLEND = os.path.join(PROCESSED_DIR, "jaguarete_idle_preview.blend")
GAME_READY_GLB = os.path.join(PROCESSED_DIR, "jaguarete_game_ready_idle.glb")
TARGET_ACTION_NAME = "jaguarete_idle"
EXPORT_ANIM_NAME = "idle"
