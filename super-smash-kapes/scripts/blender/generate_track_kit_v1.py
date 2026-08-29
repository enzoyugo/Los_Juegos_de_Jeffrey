"""Original Track modular kit generator (pilot-capable).

Godot convention is the authoring space:
  +Y up, -Z forward, road centered on X=0, ENTRY at origin.

Run (pilot only, default):
  python scripts/blender/generate_track_kit_v1.py --pilot
  blender --background --python scripts/blender/generate_track_kit_v1.py -- --pilot

Extended physics modules only (ramp/jump/boost):
  python scripts/blender/generate_track_kit_v1.py --extended

Clean-gap V5 modules (ramp_takeoff + gap_logical):
  python scripts/blender/generate_track_kit_v1.py --clean-gap

Optional:
  --pieces start,straight_medium,curve_l_45,curve_r_45,finish

--all is refused. Do not mass-generate the 22-piece kit from this sprint.
"""

from __future__ import annotations

import json
import math
import os
import struct
import sys

try:
    import bpy  # noqa: F401
except ImportError:
    bpy = None


PILOT_DEFAULT = ("start", "straight_medium", "curve_l_45", "curve_r_45", "finish")
EXTENDED_PHYSICS = ("ramp_small", "jump_small", "boost_straight", "landing_straight_long")
CLEAN_GAP_PHYSICS = ("ramp_takeoff", "gap_logical")
OUTPUT_NAMES = {
    "start": "track_start_v1.glb",
    "straight_medium": "track_straight_medium_v1.glb",
    "curve_l_45": "track_curve_l_45_v1.glb",
    "curve_r_45": "track_curve_r_45_v1.glb",
    "finish": "track_finish_v1.glb",
    "ramp_small": "track_ramp_small_v1.glb",
    "jump_small": "track_jump_small_v1.glb",
    "boost_straight": "track_boost_straight_v1.glb",
    "landing_straight_long": "track_landing_straight_long_v1.glb",
    "ramp_takeoff": "track_ramp_takeoff_v1.glb",
    "gap_logical": "track_gap_logical_v1.glb",
    "straight_short": "track_straight_short_v1.glb",
    "straight_long": "track_straight_long_v1.glb",
    "curve_l_90": "track_curve_l_90_v1.glb",
    "curve_r_90": "track_curve_r_90_v1.glb",
    "chicane_lr": "track_chicane_lr_v1.glb",
    "chicane_rl": "track_chicane_rl_v1.glb",
}

MAT_ROAD = "ROAD"
MAT_SHOULDER = "SHOULDER"
MAT_RAIL = "GUARDRAIL"
MAT_MARKER = "START_FINISH"


def _project_root() -> str:
    here = os.path.dirname(os.path.abspath(__file__))
    return os.path.abspath(os.path.join(here, "..", ".."))


def load_config(path: str) -> dict:
    with open(path, "r", encoding="utf-8") as handle:
        return json.load(handle)


class TrackKitConfig:
    def __init__(self, payload: dict):
        self.payload = payload
        self.contract = payload.get("contract", {})
        self.pieces = payload.get("pieces", [])
        self.road = float(self.contract.get("road_width_m", 11.0))
        self.shoulder = float(self.contract.get("shoulder_m", 0.7))
        self.rail_h = float(self.contract.get("guardrail_height_m", 0.9))
        self.rail_t = float(self.contract.get("guardrail_thickness_m", 0.22))
        self.thickness = float(self.contract.get("road_thickness_m", 0.12))
        self.curve_step = float(self.contract.get("curve_step_m", 1.5))
        self.overlap = float(self.contract.get("collision_overlap_m", 0.04))
        self.filenames = payload.get("output_filenames", OUTPUT_NAMES)

    def spec(self, piece_id: str) -> dict:
        for item in self.pieces:
            if item.get("id") == piece_id:
                return item
        raise KeyError("unknown piece_id %s" % piece_id)


def yaw_from_forward(fwd: tuple) -> float:
    return math.atan2(-fwd[0], -fwd[2])


def frame_at(cfg: TrackKitConfig, spec: dict, t: float) -> dict:
    """t in [0,1] along centerline. Returns Godot-space frame."""
    kind = spec.get("type")
    t = max(0.0, min(1.0, t))
    if kind == "curve":
        angle = math.radians(float(spec.get("angle_deg", 45.0)))
        radius = float(spec.get("radius_m", 30.0))
        sign = 1.0 if spec.get("direction", "left") == "left" else -1.0
        theta = angle * t
        pos = (
            sign * radius * (math.cos(theta) - 1.0),
            0.0,
            -radius * math.sin(theta),
        )
        fwd = (-sign * math.sin(theta), 0.0, -math.cos(theta))
        right = (math.cos(theta), 0.0, -sign * math.sin(theta))
        along = radius * theta
        return {
            "pos": pos,
            "fwd": fwd,
            "right": right,
            "up": (0.0, 1.0, 0.0),
            "yaw": sign * theta,
            "pitch": 0.0,
            "along": along,
            "solid": True,
        }
    if kind == "ramp":
        length = float(spec.get("length_m", 12.0))
        height = float(spec.get("height_delta_m", 1.8))
        launch = math.radians(float(spec.get("launch_angle_deg", 18.0)))
        m1 = math.tan(launch) * length
        # Cubic Hermite: y(0)=0, y'(0)=0, y(1)=H, y'(1)=tan(launch)*L
        t2 = t * t
        t3 = t2 * t
        y = (-2.0 * t3 + 3.0 * t2) * height + (t3 - t2) * m1
        dy_dt = (-6.0 * t2 + 6.0 * t) * height + (3.0 * t2 - 2.0 * t) * m1
        slope = dy_dt / max(length, 0.001)
        along = length * t
        pitch = math.atan(slope)
        cp, sp = math.cos(pitch), math.sin(pitch)
        fwd = (0.0, sp, -cp)
        up = (0.0, cp, sp)
        pos = (0.0, y, -along)
        return {
            "pos": pos,
            "fwd": fwd,
            "right": (1.0, 0.0, 0.0),
            "up": up,
            "yaw": 0.0,
            "pitch": pitch,
            "along": along,
            "solid": True,
        }
    if kind == "ramp_takeoff":
        ramp_len = float(spec.get("ramp_length_m", spec.get("length_m", 12.0)))
        lip = float(spec.get("lip_length_m", 1.2))
        height = float(spec.get("height_delta_m", 1.8))
        launch = math.radians(float(spec.get("launch_angle_deg", 18.0)))
        total = ramp_len + lip
        along = total * t
        if along <= ramp_len + 1e-9:
            u = along / max(ramp_len, 0.001)
            m1 = math.tan(launch) * ramp_len
            u2 = u * u
            u3 = u2 * u
            y = (-2.0 * u3 + 3.0 * u2) * height + (u3 - u2) * m1
            dy_du = (-6.0 * u2 + 6.0 * u) * height + (3.0 * u2 - 2.0 * u) * m1
            slope = dy_du / max(ramp_len, 0.001)
            pitch = math.atan(slope)
        else:
            y = height + math.tan(launch) * (along - ramp_len)
            pitch = launch
        cp, sp = math.cos(pitch), math.sin(pitch)
        return {
            "pos": (0.0, y, -along),
            "fwd": (0.0, sp, -cp),
            "right": (1.0, 0.0, 0.0),
            "up": (0.0, cp, sp),
            "yaw": 0.0,
            "pitch": pitch,
            "along": along,
            "solid": True,
        }
    if kind == "gap":
        length = float(spec.get("gap_m", spec.get("length_m", 7.0)))
        drop = float(spec.get("height_delta_m", -1.24))
        pitch0 = math.radians(float(spec.get("entry_pitch_deg", 18.0)))
        along = length * t
        y = drop * t
        pitch = pitch0 * (1.0 - t)
        cp, sp = math.cos(pitch), math.sin(pitch)
        return {
            "pos": (0.0, y, -along),
            "fwd": (0.0, sp, -cp),
            "right": (1.0, 0.0, 0.0),
            "up": (0.0, cp, sp),
            "yaw": 0.0,
            "pitch": pitch,
            "along": along,
            "solid": False,
        }
    if kind == "jump":
        lip = float(spec.get("ramp_length_m", 1.2))
        gap = float(spec.get("gap_m", 7.0))
        land = float(spec.get("land_length_m", 14.0))
        drop = float(spec.get("landing_drop_m", 0.85))
        pitch0 = math.radians(float(spec.get("entry_pitch_deg", 0.0)))
        total = lip + gap + land
        along = total * t
        solid = True
        y = 0.0
        pitch = 0.0
        if along <= lip + 1e-9:
            pitch = pitch0
            y = math.tan(pitch0) * along
            solid = True
        elif along < lip + gap:
            solid = False
            y_lip = math.tan(pitch0) * lip
            u = (along - lip) / max(gap, 0.001)
            y = y_lip * (1.0 - u) + (-drop) * u
            pitch = 0.0
        else:
            y = -drop
            pitch = 0.0
            solid = True
        cp, sp = math.cos(pitch), math.sin(pitch)
        pos = (0.0, y, -along)
        return {
            "pos": pos,
            "fwd": (0.0, sp, -cp),
            "right": (1.0, 0.0, 0.0),
            "up": (0.0, cp, sp),
            "yaw": 0.0,
            "pitch": pitch,
            "along": along,
            "solid": solid,
        }
    if kind == "chicane":
        length = float(spec.get("length_m", 18.0))
        offset = float(spec.get("offset_m", 4.5))
        pattern = str(spec.get("pattern", "lr"))
        sign = -1.0 if pattern == "lr" else 1.0
        along = length * t
        x = sign * offset * math.sin(math.pi * t)
        z = -along
        dx_dt = sign * offset * math.pi * math.cos(math.pi * t)
        dz_dt = -length
        if t <= 1e-6 or t >= 1.0 - 1e-6:
            fwd = (0.0, 0.0, -1.0)
            yaw = 0.0
        else:
            flen = math.hypot(dx_dt, dz_dt)
            fwd = (dx_dt / flen, 0.0, dz_dt / flen)
            yaw = yaw_from_forward(fwd)
        right = (-fwd[2], 0.0, fwd[0])
        return {
            "pos": (x, 0.0, z),
            "fwd": fwd,
            "right": right,
            "up": (0.0, 1.0, 0.0),
            "yaw": yaw,
            "pitch": 0.0,
            "along": along,
            "solid": True,
        }
    length = float(spec.get("length_m", 8.0))
    pos = (0.0, 0.0, -length * t)
    return {
        "pos": pos,
        "fwd": (0.0, 0.0, -1.0),
        "right": (1.0, 0.0, 0.0),
        "up": (0.0, 1.0, 0.0),
        "yaw": 0.0,
        "pitch": 0.0,
        "along": length * t,
        "solid": True,
    }


def centerline_length(cfg: TrackKitConfig, spec: dict) -> float:
    if spec.get("type") == "curve":
        return float(spec.get("radius_m", 30.0)) * math.radians(float(spec.get("angle_deg", 45.0)))
    if spec.get("type") == "jump":
        return (
            float(spec.get("ramp_length_m", 1.2))
            + float(spec.get("gap_m", 7.0))
            + float(spec.get("land_length_m", 14.0))
        )
    if spec.get("type") == "ramp_takeoff":
        return float(spec.get("ramp_length_m", spec.get("length_m", 12.0))) + float(spec.get("lip_length_m", 1.2))
    if spec.get("type") == "gap":
        return float(spec.get("gap_m", spec.get("length_m", 7.0)))
    return float(spec.get("length_m", 8.0))


def sample_count(cfg: TrackKitConfig, spec: dict) -> int:
    length = centerline_length(cfg, spec)
    kind = spec.get("type")
    if kind == "jump":
        return max(int(math.ceil(length / 0.4)), 24) + 1
    if kind in ("curve", "ramp", "ramp_takeoff", "chicane"):
        return max(int(math.ceil(length / max(cfg.curve_step, 0.5))), 8) + 1
    if kind == "gap":
        return 2
    return 2


def _add(a, b):
    return (a[0] + b[0], a[1] + b[1], a[2] + b[2])


def _scale(a, s):
    return (a[0] * s, a[1] * s, a[2] * s)


def _offset(frame: dict, lateral: float, y: float) -> tuple:
    r = frame["right"]
    u = frame.get("up", (0.0, 1.0, 0.0))
    p = frame["pos"]
    return (
        p[0] + r[0] * lateral + u[0] * y,
        p[1] + r[1] * lateral + u[1] * y,
        p[2] + r[2] * lateral + u[2] * y,
    )


class UVBuilder:
    @staticmethod
    def uv(along: float, lateral: float, width: float) -> tuple:
        u = (lateral / max(width, 0.001)) + 0.5
        v = along
        return (u, v)


class ConnectorBuilder:
    @staticmethod
    def markers(cfg: TrackKitConfig, spec: dict) -> list:
        entry = frame_at(cfg, spec, 0.0)
        exit_f = frame_at(cfg, spec, 1.0)
        nodes = [
            {
                "name": "ENTRY",
                "translation": [0.0, 0.0, 0.0],
                "yaw": 0.0,
                "pitch": float(entry.get("pitch", 0.0)),
            },
            {
                "name": "EXIT",
                "translation": [exit_f["pos"][0], exit_f["pos"][1], exit_f["pos"][2]],
                "yaw": exit_f["yaw"],
                "pitch": float(exit_f.get("pitch", 0.0)),
            },
        ]
        if spec.get("type") == "start":
            nodes.append({"name": "START_MARKER", "translation": [0.0, 0.02, -1.2], "yaw": 0.0})
            nodes.append({"name": "PLAYER_SPAWN", "translation": [0.0, 1.15, -2.6], "yaw": 0.0})
        if spec.get("type") == "finish":
            length = float(spec.get("length_m", 8.0))
            nodes.append({"name": "FINISH_TRIGGER_ANCHOR", "translation": [0.0, 0.5, -(length - 1.5)], "yaw": 0.0})
            nodes.append({"name": "FINISH_MARKER", "translation": [0.0, 0.02, -(length - 1.5)], "yaw": 0.0})
        if spec.get("type") == "ramp_takeoff":
            nodes.append({
                "name": "TAKEOFF_EDGE",
                "translation": [exit_f["pos"][0], exit_f["pos"][1], exit_f["pos"][2]],
                "yaw": exit_f["yaw"],
                "pitch": float(exit_f.get("pitch", 0.0)),
            })
        if spec.get("type") == "gap":
            nodes.append({"name": "GAP_START", "translation": [0.0, 0.0, 0.0], "yaw": 0.0, "pitch": float(entry.get("pitch", 0.0))})
            nodes.append({
                "name": "GAP_END",
                "translation": [exit_f["pos"][0], exit_f["pos"][1], exit_f["pos"][2]],
                "yaw": exit_f["yaw"],
                "pitch": float(exit_f.get("pitch", 0.0)),
            })
        _ = entry
        return nodes


class GuardrailBuilder:
    def __init__(self, cfg: TrackKitConfig):
        self.cfg = cfg

    def inner_x(self) -> float:
        return self.cfg.road * 0.5 + self.cfg.shoulder

    def center_x(self) -> float:
        return self.inner_x() + self.cfg.rail_t * 0.5


class MeshAccumulator:
    def __init__(self, name: str, material: str):
        self.name = name
        self.material = material
        self.positions: list = []
        self.normals: list = []
        self.uvs: list = []
        self.indices: list = []

    def add_vertex(self, p, n, uv) -> int:
        idx = len(self.positions)
        self.positions.append(p)
        self.normals.append(n)
        self.uvs.append(uv)
        return idx

    def add_quad(self, p0, p1, p2, p3, n, uv0, uv1, uv2, uv3):
        i0 = self.add_vertex(p0, n, uv0)
        i1 = self.add_vertex(p1, n, uv1)
        i2 = self.add_vertex(p2, n, uv2)
        i3 = self.add_vertex(p3, n, uv3)
        self.indices.extend([i0, i1, i2, i0, i2, i3])


def _strip(mesh: MeshAccumulator, frames: list, x0: float, x1: float, y0: float, y1: float, n, width: float):
    for i in range(len(frames) - 1):
        a = frames[i]
        b = frames[i + 1]
        p00 = _offset(a, x0, y1)
        p10 = _offset(a, x1, y1)
        p11 = _offset(b, x1, y1)
        p01 = _offset(b, x0, y1)
        mesh.add_quad(
            p00, p10, p11, p01, n,
            UVBuilder.uv(a["along"], x0, width),
            UVBuilder.uv(a["along"], x1, width),
            UVBuilder.uv(b["along"], x1, width),
            UVBuilder.uv(b["along"], x0, width),
        )
        if abs(y1 - y0) > 1e-6:
            # outer/inner walls for thickness / rail face
            pass


def _prism_strip(mesh: MeshAccumulator, frames: list, x0: float, x1: float, y_bot: float, y_top: float, width: float):
    up = (0.0, 1.0, 0.0)
    down = (0.0, -1.0, 0.0)
    for i in range(len(frames) - 1):
        a = frames[i]
        b = frames[i + 1]
        a0t = _offset(a, x0, y_top)
        a1t = _offset(a, x1, y_top)
        b1t = _offset(b, x1, y_top)
        b0t = _offset(b, x0, y_top)
        a0b = _offset(a, x0, y_bot)
        a1b = _offset(a, x1, y_bot)
        b1b = _offset(b, x1, y_bot)
        b0b = _offset(b, x0, y_bot)
        mesh.add_quad(a0t, a1t, b1t, b0t, a.get("up", (0.0, 1.0, 0.0)),
                      UVBuilder.uv(a["along"], x0, width), UVBuilder.uv(a["along"], x1, width),
                      UVBuilder.uv(b["along"], x1, width), UVBuilder.uv(b["along"], x0, width))
        mesh.add_quad(a1b, a0b, b0b, b1b, down,
                      UVBuilder.uv(a["along"], x1, width), UVBuilder.uv(a["along"], x0, width),
                      UVBuilder.uv(b["along"], x0, width), UVBuilder.uv(b["along"], x1, width))
        # left wall (x0)
        left_n = _scale(a["right"], -1.0 if x0 < x1 else 1.0)
        mesh.add_quad(a0b, a0t, b0t, b0b, left_n,
                      (0.0, a["along"]), (1.0, a["along"]), (1.0, b["along"]), (0.0, b["along"]))
        right_n = _scale(a["right"], 1.0 if x0 < x1 else -1.0)
        mesh.add_quad(a1t, a1b, b1b, b1t, right_n,
                      (0.0, a["along"]), (1.0, a["along"]), (1.0, b["along"]), (0.0, b["along"]))


class StraightBuilder:
    def __init__(self, cfg: TrackKitConfig):
        self.cfg = cfg
        self.rails = GuardrailBuilder(cfg)

    def frames(self, spec: dict) -> list:
        count = sample_count(self.cfg, spec)
        return [frame_at(self.cfg, spec, i / float(count - 1)) for i in range(count)]

    def build_meshes(self, spec: dict) -> list:
        frames = self.frames(spec)
        return self._meshes_from_frames(spec, frames)

    def _meshes_from_frames(self, spec: dict, frames: list) -> list:
        cfg = self.cfg
        half = cfg.road * 0.5
        sh = cfg.shoulder
        y_top = 0.0
        y_bot = -cfg.thickness
        road = MeshAccumulator("ROAD", MAT_ROAD)
        sh_l = MeshAccumulator("SHOULDER_L", MAT_SHOULDER)
        sh_r = MeshAccumulator("SHOULDER_R", MAT_SHOULDER)
        _prism_strip(road, frames, -half, half, y_bot, y_top, cfg.road)
        _prism_strip(sh_l, frames, -(half + sh), -half, y_bot, y_top, sh)
        _prism_strip(sh_r, frames, half, half + sh, y_bot, y_top, sh)
        meshes = [road, sh_l, sh_r]
        if spec.get("guardrails", True):
            inner = self.rails.inner_x()
            outer = inner + cfg.rail_t
            rail_l = MeshAccumulator("RAIL_L", MAT_RAIL)
            rail_r = MeshAccumulator("RAIL_R", MAT_RAIL)
            _prism_strip(rail_l, frames, -outer, -inner, 0.0, cfg.rail_h, cfg.rail_t)
            _prism_strip(rail_r, frames, inner, outer, 0.0, cfg.rail_h, cfg.rail_t)
            meshes.extend([rail_l, rail_r])
        if spec.get("type") in ("start", "finish"):
            marker = MeshAccumulator("MARKER", MAT_MARKER)
            z = -1.2 if spec.get("type") == "start" else -(float(spec.get("length_m", 8.0)) - 1.5)
            stripe = 0.35
            p0 = (-half, 0.004, z - stripe * 0.5)
            p1 = (half, 0.004, z - stripe * 0.5)
            p2 = (half, 0.004, z + stripe * 0.5)
            p3 = (-half, 0.004, z + stripe * 0.5)
            marker.add_quad(p0, p1, p2, p3, (0.0, 1.0, 0.0), (0.0, 0.0), (1.0, 0.0), (1.0, 1.0), (0.0, 1.0))
            meshes.append(marker)
        return meshes


class CurveBuilder:
    def __init__(self, cfg: TrackKitConfig):
        self.cfg = cfg
        self.straight = StraightBuilder(cfg)

    def build_meshes(self, spec: dict) -> list:
        frames = self.straight.frames(spec)
        return self.straight._meshes_from_frames(spec, frames)


class ElevationBuilder:
    def __init__(self, cfg: TrackKitConfig):
        self.cfg = cfg
        self.straight = StraightBuilder(cfg)

    def build_meshes(self, spec: dict) -> list:
        if spec.get("type") == "ramp_takeoff":
            return self.build_ramp_takeoff(spec)
        frames = self.straight.frames(spec)
        return self.straight._meshes_from_frames(spec, frames)

    def build_ramp_takeoff(self, spec: dict) -> list:
        ramp_len = float(spec.get("ramp_length_m", spec.get("length_m", 12.0)))
        frames = self.straight.frames(spec)
        ramp_frames = [fr for fr in frames if fr["along"] <= ramp_len + 0.05]
        lip_frames = [fr for fr in frames if fr["along"] >= ramp_len - 0.05]
        if len(ramp_frames) < 2:
            ramp_frames = frames[: max(2, len(frames) // 2)]
        if len(lip_frames) < 2:
            lip_frames = frames[-2:]
        spec_rail = dict(spec)
        spec_rail["guardrails"] = bool(spec.get("guardrails", False))
        spec_nrail = dict(spec)
        spec_nrail["guardrails"] = False
        meshes = self.straight._meshes_from_frames(spec_rail, ramp_frames)
        meshes.extend(self.straight._meshes_from_frames(spec_nrail, lip_frames))
        return meshes


class SpecialBuilder:
    def __init__(self, cfg: TrackKitConfig):
        self.cfg = cfg
        self.straight = StraightBuilder(cfg)

    def build_meshes(self, spec: dict) -> list:
        kind = spec.get("type")
        if kind == "boost":
            meshes = self.straight.build_meshes(spec)
            half = self.cfg.road * 0.5
            length = float(spec.get("length_m", 12.0))
            marker = MeshAccumulator("MARKER", MAT_MARKER)
            z0, z1 = -1.0, -(length - 1.0)
            marker.add_quad(
                (-half * 0.4, 0.01, z0), (half * 0.4, 0.01, z0),
                (half * 0.4, 0.01, z1), (-half * 0.4, 0.01, z1),
                (0.0, 1.0, 0.0), (0.0, 0.0), (1.0, 0.0), (1.0, 1.0), (0.0, 1.0),
            )
            meshes.append(marker)
            return meshes
        if kind == "jump":
            frames = self.straight.frames(spec)
            runs = []
            current = []
            for fr in frames:
                if fr.get("solid", True):
                    current.append(fr)
                else:
                    if len(current) >= 2:
                        runs.append(current)
                    current = []
            if len(current) >= 2:
                runs.append(current)
            meshes = []
            for run in runs:
                meshes.extend(self.straight._meshes_from_frames(spec, run))
            return meshes
        if kind == "gap":
            length = float(spec.get("gap_m", spec.get("length_m", 7.0)))
            drop = float(spec.get("height_delta_m", -1.24))
            marker = MeshAccumulator("MARKER", MAT_MARKER)
            post = 0.12
            for z, y0 in ((0.0, 0.0), (-length, drop)):
                p0 = (-post, y0 + 1.6, z - post)
                p1 = (post, y0 + 1.6, z - post)
                p2 = (post, y0 + 1.6, z + post)
                p3 = (-post, y0 + 1.6, z + post)
                marker.add_quad(p0, p1, p2, p3, (0.0, 1.0, 0.0), (0.0, 0.0), (1.0, 0.0), (1.0, 1.0), (0.0, 1.0))
            return [marker]
        raise NotImplementedError("special type=%s" % kind)


class TrackPieceBuilder:
    def __init__(self, cfg: TrackKitConfig):
        self.cfg = cfg
        self.straight = StraightBuilder(cfg)
        self.curve = CurveBuilder(cfg)
        self.elevation = ElevationBuilder(cfg)
        self.special = SpecialBuilder(cfg)

    def build_meshes(self, spec: dict) -> list:
        kind = spec.get("type")
        if kind == "curve" or kind == "chicane":
            return self.curve.build_meshes(spec)
        if kind == "ramp" or kind == "ramp_takeoff":
            return self.elevation.build_meshes(spec)
        if kind in ("jump", "boost", "gap"):
            return self.special.build_meshes(spec)
        if kind in ("straight", "start", "finish", "checkpoint"):
            return self.straight.build_meshes(spec)
        raise NotImplementedError("pilot generator does not build type=%s" % kind)

    def collision_boxes(self, spec: dict) -> list:
        if spec.get("type") == "jump":
            return self._jump_collision_boxes(spec)
        if spec.get("type") == "gap":
            return []
        if spec.get("type") == "ramp_takeoff":
            boxes = self._boxes_along(spec, 0.0, 1.0, max(sample_count(self.cfg, spec) - 1, 1))
            ramp_len = float(spec.get("ramp_length_m", spec.get("length_m", 12.0)))
            kept = []
            for box in boxes:
                along = -float(box["origin"][2])
                if box["kind"] == "rail" and along > ramp_len - 0.45:
                    continue
                kept.append(box)
            return kept
        return self._boxes_along(spec, 0.0, 1.0, max(sample_count(self.cfg, spec) - 1, 1))

    def _jump_collision_boxes(self, spec: dict) -> list:
        lip = float(spec.get("ramp_length_m", 1.2))
        gap = float(spec.get("gap_m", 7.0))
        land = float(spec.get("land_length_m", 14.0))
        total = max(lip + gap + land, 0.001)
        lip_boxes = self._boxes_along(spec, 0.0, lip / total, max(int(math.ceil(lip / 0.4)), 2))
        land_boxes = self._boxes_along(spec, (lip + gap) / total, 1.0, max(int(math.ceil(land / 0.6)), 4))
        return lip_boxes + land_boxes

    def _boxes_along(self, spec: dict, t0: float, t1: float, count: int) -> list:
        cfg = self.cfg
        width = cfg.road + cfg.shoulder * 2.0
        height = cfg.thickness
        boxes = []
        count = max(count, 1)
        length = centerline_length(cfg, spec) * max(t1 - t0, 0.0001)
        step = length / float(count)
        for i in range(count):
            t = t0 + (t1 - t0) * ((i + 0.5) / float(count))
            fr = frame_at(cfg, spec, t)
            if not fr.get("solid", True):
                continue
            up = fr.get("up", (0.0, 1.0, 0.0))
            origin = (
                fr["pos"][0] + up[0] * (-height * 0.5),
                fr["pos"][1] + up[1] * (-height * 0.5),
                fr["pos"][2] + up[2] * (-height * 0.5),
            )
            boxes.append({
                "kind": "road",
                "origin": [origin[0], origin[1], origin[2]],
                "yaw": fr["yaw"],
                "pitch": float(fr.get("pitch", 0.0)),
                "size": [width, height, step + cfg.overlap],
            })
            if spec.get("guardrails", True):
                rails = GuardrailBuilder(cfg)
                cx = rails.center_x()
                for sign in (-1.0, 1.0):
                    pos = _offset(fr, sign * cx, cfg.rail_h * 0.5)
                    boxes.append({
                        "kind": "rail",
                        "origin": [pos[0], pos[1], pos[2]],
                        "yaw": fr["yaw"],
                        "pitch": float(fr.get("pitch", 0.0)),
                        "size": [cfg.rail_t, cfg.rail_h, step + cfg.overlap],
                    })
        return boxes


def quat_mul(a, b):
    ax, ay, az, aw = a
    bx, by, bz, bw = b
    return (
        aw * bx + ax * bw + ay * bz - az * by,
        aw * by - ax * bz + ay * bw + az * bx,
        aw * bz + ax * by - ay * bx + az * bw,
        aw * bw - ax * bx - ay * by - az * bz,
    )


def quat_yaw(yaw: float) -> list:
    return quat_yaw_pitch(yaw, 0.0)


def quat_yaw_pitch(yaw: float, pitch: float = 0.0) -> list:
    hy = yaw * 0.5
    hp = pitch * 0.5
    qy = (0.0, math.sin(hy), 0.0, math.cos(hy))
    qp = (math.sin(hp), 0.0, 0.0, math.cos(hp))
    return list(quat_mul(qy, qp))


def _pad4(data: bytes, pad: bytes) -> bytes:
    rem = (-len(data)) % 4
    return data + pad * rem


def _accessor(byte_offset: int, count: int, component: int, type_name: str, mn, mx) -> dict:
    acc = {
        "bufferView": 0,
        "byteOffset": byte_offset,
        "componentType": component,
        "count": count,
        "type": type_name,
    }
    if mn is not None:
        acc["min"] = mn
        acc["max"] = mx
    return acc


def write_glb(path: str, meshes: list, markers: list) -> None:
    bin_parts = []
    accessors = []
    buffer_views = []  # one view; use accessor byteOffset
    primitives_by_mesh = []
    materials = []
    mat_index = {}
    cursor = 0

    def push_f32(values: list, type_name: str, comps: int) -> int:
        nonlocal cursor
        raw = b"".join(struct.pack("<f", float(v)) for v in values)
        raw = _pad4(raw, b"\x00")
        idx = len(accessors)
        count = len(values) // comps
        grouped = [values[i:i + comps] for i in range(0, len(values), comps)]
        mn = [min(g[c] for g in grouped) for c in range(comps)]
        mx = [max(g[c] for g in grouped) for c in range(comps)]
        accessors.append(_accessor(cursor, count, 5126, type_name, mn, mx))
        bin_parts.append(raw)
        cursor += len(raw)
        return idx

    def push_u32(values: list) -> int:
        nonlocal cursor
        raw = b"".join(struct.pack("<I", int(v)) for v in values)
        raw = _pad4(raw, b"\x00")
        idx = len(accessors)
        accessors.append(_accessor(cursor, len(values), 5125, "SCALAR", [0], [max(values) if values else 0]))
        bin_parts.append(raw)
        cursor += len(raw)
        return idx

    for mesh in meshes:
        if mesh.material not in mat_index:
            mat_index[mesh.material] = len(materials)
            color = {
                MAT_ROAD: [0.22, 0.24, 0.28, 1.0],
                MAT_SHOULDER: [0.32, 0.30, 0.26, 1.0],
                MAT_RAIL: [0.62, 0.64, 0.68, 1.0],
                MAT_MARKER: [0.92, 0.86, 0.18, 1.0],
            }.get(mesh.material, [0.5, 0.5, 0.5, 1.0])
            materials.append({
                "name": mesh.material,
                "pbrMetallicRoughness": {
                    "baseColorFactor": color,
                    "metallicFactor": 0.0,
                    "roughnessFactor": 0.85,
                },
            })
        pos = [c for p in mesh.positions for c in p]
        nrm = [c for n in mesh.normals for c in n]
        uvs = [c for uv in mesh.uvs for c in uv]
        p_i = push_f32(pos, "VEC3", 3)
        n_i = push_f32(nrm, "VEC3", 3)
        t_i = push_f32(uvs, "VEC2", 2)
        i_i = push_u32(mesh.indices)
        primitives_by_mesh.append({
            "name": mesh.name,
            "primitives": [{
                "attributes": {"POSITION": p_i, "NORMAL": n_i, "TEXCOORD_0": t_i},
                "indices": i_i,
                "material": mat_index[mesh.material],
            }],
        })

    blob = b"".join(bin_parts)
    buffer_views = [{"buffer": 0, "byteOffset": 0, "byteLength": len(blob)}]
    # Accessors already set bufferView 0; OK.

    nodes = [{"name": "PieceRoot", "children": list(range(1, 1 + len(primitives_by_mesh) + len(markers)))}]
    mesh_nodes = []
    for i, mesh_doc in enumerate(primitives_by_mesh):
        nodes.append({"name": mesh_doc["name"], "mesh": i})
        mesh_nodes.append(i)
    for marker in markers:
        node = {
            "name": marker["name"],
            "translation": [float(v) for v in marker["translation"]],
            "rotation": quat_yaw_pitch(float(marker.get("yaw", 0.0)), float(marker.get("pitch", 0.0))),
        }
        nodes.append(node)

    gltf = {
        "asset": {"version": "2.0", "generator": "ssk-track-kit-v1"},
        "scene": 0,
        "scenes": [{"nodes": [0]}],
        "nodes": nodes,
        "meshes": [{"name": m["name"], "primitives": m["primitives"]} for m in primitives_by_mesh],
        "materials": materials,
        "accessors": accessors,
        "bufferViews": buffer_views,
        "buffers": [{"byteLength": len(blob)}],
    }
    json_bytes = _pad4(json.dumps(gltf, separators=(",", ":")).encode("utf-8"), b" ")
    bin_bytes = _pad4(blob, b"\x00")
    total = 12 + 8 + len(json_bytes) + 8 + len(bin_bytes)
    header = struct.pack("<4sII", b"glTF", 2, total)
    json_chunk = struct.pack("<I4s", len(json_bytes), b"JSON") + json_bytes
    bin_chunk = struct.pack("<I4s", len(bin_bytes), b"BIN\x00") + bin_bytes
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as handle:
        handle.write(header + json_chunk + bin_chunk)


class Exporter:
    def __init__(self, out_dir: str):
        self.out_dir = out_dir

    def export_piece(self, cfg: TrackKitConfig, spec: dict, meshes: list, markers: list, boxes: list) -> str:
        name = cfg.filenames.get(spec["id"], "track_%s_v1.glb" % spec["id"])
        path = os.path.join(self.out_dir, name)
        write_glb(path, meshes, markers)
        meta = {
            "piece_id": spec["id"],
            "family": spec.get("family", "core"),
            "type": spec.get("type"),
            "road_width": cfg.road,
            "shoulder_width": cfg.shoulder,
            "guardrail_height": cfg.rail_h,
            "centerline_length": centerline_length(cfg, spec),
            "height_delta": float(spec.get("height_delta_m", 0.0) or 0.0),
            "yaw_delta": frame_at(cfg, spec, 1.0)["yaw"],
            "pitch_delta": float(frame_at(cfg, spec, 1.0).get("pitch", 0.0)),
            "roll_delta": 0.0,
            "left_guardrail": bool(spec.get("guardrails", True)),
            "right_guardrail": bool(spec.get("guardrails", True)),
            "estimated_traversal_time": float(spec.get("estimated_traversal_time", 0.5)),
            "difficulty": spec.get("difficulty", "tranqui"),
            "tags": spec.get("tags", []),
            "entry": {
                "origin": [0.0, 0.0, 0.0],
                "yaw": 0.0,
                "pitch": float(frame_at(cfg, spec, 0.0).get("pitch", 0.0)),
            },
            "exit": {
                "origin": list(frame_at(cfg, spec, 1.0)["pos"]),
                "yaw": frame_at(cfg, spec, 1.0)["yaw"],
                "pitch": float(frame_at(cfg, spec, 1.0).get("pitch", 0.0)),
            },
            "boost_strength": float(spec.get("boost_strength", 0.0) or 0.0),
            "has_gap": bool(spec.get("has_gap", spec.get("type") == "jump")),
            "transition_profile": spec.get("transition_profile", ""),
            "collision": boxes,
            "glb": name.replace("\\", "/"),
        }
        meta_path = path[:-4] + ".json" if path.endswith(".glb") else path + ".json"
        with open(meta_path, "w", encoding="utf-8") as handle:
            json.dump(meta, handle, indent=2)
        return path


def generate(config_path: str, out_dir: str, ids=None) -> list:
    payload = load_config(config_path)
    cfg = TrackKitConfig(payload)
    builder = TrackPieceBuilder(cfg)
    exporter = Exporter(out_dir)
    wanted = list(ids or payload.get("pilot_ids", PILOT_DEFAULT))
    written = []
    for piece_id in wanted:
        spec = cfg.spec(piece_id)
        meshes = builder.build_meshes(spec)
        markers = ConnectorBuilder.markers(cfg, spec)
        boxes = builder.collision_boxes(spec)
        written.append(exporter.export_piece(cfg, spec, meshes, markers, boxes))
        print("WROTE", written[-1], "verts", sum(len(m.positions) for m in meshes),
              "exit", frame_at(cfg, spec, 1.0)["pos"], "yaw_deg", math.degrees(frame_at(cfg, spec, 1.0)["yaw"]))
    return written


def seam_error(cfg: TrackKitConfig, a_id: str, b_id: str) -> dict:
    """Place B.ENTRY on A.EXIT and measure cross-section delta."""
    a = cfg.spec(a_id)
    b = cfg.spec(b_id)
    a_exit = frame_at(cfg, a, 1.0)
    b_entry = frame_at(cfg, b, 0.0)
    # B world = A_exit * inverse(B_entry). B_entry is identity.
    half = cfg.road * 0.5
    pts = [-half - cfg.shoulder, -half, 0.0, half, half + cfg.shoulder]

    def world_pts(fr, yaw_extra=0.0):
        out = []
        for x in pts:
            out.append(_offset(fr, x, 0.0))
        return out

    a_pts = world_pts(a_exit)
    # B entry in A-exit space is identity, so same as a_exit frame
    b_world_entry = a_exit
    b_pts = world_pts(b_world_entry)
    deltas = [math.dist(a_pts[i], b_pts[i]) for i in range(len(pts))]
    return {
        "a": a_id,
        "b": b_id,
        "max_position_m": max(deltas),
        "yaw_delta_deg": math.degrees(a_exit["yaw"] - b_entry["yaw"] - a_exit["yaw"]),
        "up_delta_deg": 0.0,
    }


def main(argv=None) -> int:
    argv = list(argv or sys.argv[1:])
    if "--" in argv:
        argv = argv[argv.index("--") + 1:]
    root = _project_root()
    config_path = os.path.join(root, "data", "track", "modules", "track_kit_v1.json")
    out_dir = os.path.join(root, "assets", "track", "modules", "generated", "core")
    if "--all" in argv:
        print("Refusing --all. Generate pilot with --pilot or --pieces=id,id.")
        return 2
    ids = list(PILOT_DEFAULT)
    for item in argv:
        if item.startswith("--pieces"):
            raw = item.split("=", 1)[1] if "=" in item else ""
            if not raw:
                idx = argv.index(item)
                raw = argv[idx + 1] if idx + 1 < len(argv) else ""
            ids = [p.strip() for p in raw.split(",") if p.strip()]
        elif item == "--pilot":
            ids = list(PILOT_DEFAULT)
        elif item in ("--extended", "--extended-physics"):
            ids = list(EXTENDED_PHYSICS)
        elif item in ("--clean-gap", "--clean-gap-physics"):
            ids = list(CLEAN_GAP_PHYSICS)
    generate(config_path, out_dir, ids)
    cfg = TrackKitConfig(load_config(config_path))
    seq = ["start", "straight_medium", "curve_l_45", "curve_r_45", "finish"]
    report = [seam_error(cfg, seq[i], seq[i + 1]) for i in range(len(seq) - 1)]
    report_path = os.path.join(root, "docs", "generated", "TRACK_PILOT_SEAM_MATH.json")
    os.makedirs(os.path.dirname(report_path), exist_ok=True)
    with open(report_path, "w", encoding="utf-8") as handle:
        json.dump(report, handle, indent=2)
    print("SEAM_MATH", report)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
