"""Deterministic Track car GLB inspect / split / render helpers.

No Blender GUI. Source GLB is never written. Used by the V3 builder and auditor.
"""
from __future__ import annotations

import hashlib
import json
import math
import struct
import zlib
from collections import defaultdict
from pathlib import Path
from typing import Dict, Iterable, List, Optional, Sequence, Tuple

import numpy as np

Vec3 = Tuple[float, float, float]
Tri = Tuple[int, int, int]

COMP = {5120: ("b", 1), 5121: ("B", 1), 5122: ("h", 2), 5123: ("H", 2), 5125: ("I", 4), 5126: ("f", 4)}
TYPE_N = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}

SOURCE_SHA256 = "b1dd649b39b0c701ccb5b11062b7087579702caa930d8a0b436dd4d581e725af"
VISUAL_SCALE = 4.4 / 0.998046875  # ~4.4086; one authority
RUNTIME_WHEEL_RADIUS = 0.35
# Source-space envelope from runtime radius / VisualRoot scale, plus conservative margin.
SOURCE_WHEEL_RADIUS = RUNTIME_WHEEL_RADIUS / VISUAL_SCALE  # ~0.0794
MAX_WHEEL_RADIUS_RUNTIME = 0.42
MAX_WHEEL_RADIUS_SOURCE = MAX_WHEEL_RADIUS_RUNTIME / VISUAL_SCALE  # ~0.0953
MAX_WHEEL_HALF_WIDTH_SOURCE = 0.048
MAX_WHEEL_AABB_AXIS_SOURCE = 0.22  # ~0.97 m after visual scale; body-scale is FAIL
MAX_FACE_EDGE_SOURCE = 0.18
MAX_THIN_ASPECT = 28.0
SPIN_SAMPLES = 24
WHEEL_IDS = ("FL", "FR", "RL", "RR")
WHEEL_NODE = {wid: "Wheel_%s" % wid for wid in WHEEL_IDS}

# Source-space axle guesses (glTF Y-up, documented +Z nose). Independent of V2 labels.
SOURCE_AXLES = {
    "FL": (-0.201, 0.085, 0.285),
    "FR": (0.204, 0.085, 0.285),
    "RL": (-0.202, 0.085, -0.298),
    "RR": (0.203, 0.085, -0.298),
}


def yaw180(p: Vec3) -> Vec3:
    """Canonical source→processed: +Z nose becomes -Z nose, left/right preserved as a 180° Y turn then relabel."""
    return (-p[0], p[1], -p[2])


def processed_axles_from_source() -> Dict[str, Vec3]:
    """After 180° Y, source FL lands at +X/-Z (Godot FR). Relabel so FL stays -X/-Z."""
    mapped = {wid: yaw180(SOURCE_AXLES[wid]) for wid in WHEEL_IDS}
    return {
        "FL": mapped["FR"],
        "FR": mapped["FL"],
        "RL": mapped["RR"],
        "RR": mapped["RL"],
    }


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def dist(a: Vec3, b: Vec3) -> float:
    return math.sqrt((a[0] - b[0]) ** 2 + (a[1] - b[1]) ** 2 + (a[2] - b[2]) ** 2)


def add(a: Vec3, b: Vec3) -> Vec3:
    return (a[0] + b[0], a[1] + b[1], a[2] + b[2])


def sub(a: Vec3, b: Vec3) -> Vec3:
    return (a[0] - b[0], a[1] - b[1], a[2] - b[2])


def mul(a: Vec3, s: float) -> Vec3:
    return (a[0] * s, a[1] * s, a[2] * s)


def hypot3(p: Vec3) -> float:
    return math.sqrt(p[0] * p[0] + p[1] * p[1] + p[2] * p[2])


def cross(a: Vec3, b: Vec3) -> Vec3:
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])


def rot_x(p: Vec3, ang: float) -> Vec3:
    c, s = math.cos(ang), math.sin(ang)
    return (p[0], p[1] * c - p[2] * s, p[1] * s + p[2] * c)


def _pad4(data: bytes, pad: bytes) -> bytes:
    rem = (-len(data)) % 4
    return data + pad * rem


# ---------------------------------------------------------------------------
# GLB I/O
# ---------------------------------------------------------------------------

def load_glb(path: Path) -> Tuple[dict, bytes]:
    data = path.read_bytes()
    if data[:4] != b"glTF":
        raise RuntimeError("not glTF: %s" % path)
    json_len = struct.unpack_from("<I", data, 12)[0]
    doc = json.loads(data[20 : 20 + json_len])
    off = 20 + json_len
    blob = b""
    if off + 8 <= len(data):
        bin_len = struct.unpack_from("<I", data, off)[0]
        blob = data[off + 8 : off + 8 + bin_len]
    return doc, blob


def accessor_bytes(doc: dict, blob: bytes, acc_i: int) -> bytes:
    acc = doc["accessors"][acc_i]
    bv = doc["bufferViews"][acc["bufferView"]]
    start = bv.get("byteOffset", 0) + acc.get("byteOffset", 0)
    ncomp = TYPE_N[acc["type"]]
    fmt, size = COMP[acc["componentType"]]
    count = acc["count"]
    stride = bv.get("byteStride", ncomp * size)
    if stride == ncomp * size:
        return blob[start : start + count * stride]
    out = bytearray()
    for i in range(count):
        o = start + i * stride
        out.extend(blob[o : o + ncomp * size])
    return bytes(out)


def read_vec3(doc: dict, blob: bytes, acc_i: int) -> List[Vec3]:
    raw = accessor_bytes(doc, blob, acc_i)
    n = len(raw) // 12
    return [struct.unpack_from("<fff", raw, i * 12) for i in range(n)]


def read_vec2(doc: dict, blob: bytes, acc_i: int) -> List[Tuple[float, float]]:
    raw = accessor_bytes(doc, blob, acc_i)
    n = len(raw) // 8
    return [struct.unpack_from("<ff", raw, i * 8) for i in range(n)]


def read_indices(doc: dict, blob: bytes, acc_i: int) -> List[int]:
    acc = doc["accessors"][acc_i]
    raw = accessor_bytes(doc, blob, acc_i)
    fmt, size = COMP[acc["componentType"]]
    n = acc["count"]
    return list(struct.unpack_from("<" + fmt * n, raw, 0))


def node_translation(node: dict) -> Vec3:
    t = node.get("translation")
    if t:
        return (float(t[0]), float(t[1]), float(t[2]))
    m = node.get("matrix")
    if m and len(m) == 16:
        return (float(m[12]), float(m[13]), float(m[14]))
    return (0.0, 0.0, 0.0)


class MeshPart:
    __slots__ = ("name", "positions", "normals", "uvs", "indices", "translation")

    def __init__(self, name: str, positions, normals, uvs, indices, translation=(0.0, 0.0, 0.0)):
        self.name = name
        self.positions: List[Vec3] = positions
        self.normals: List[Vec3] = normals
        self.uvs: List[Tuple[float, float]] = uvs
        self.indices: List[int] = indices
        self.translation: Vec3 = translation


def extract_meshes(path: Path) -> Dict[str, MeshPart]:
    doc, blob = load_glb(path)
    meshes: Dict[str, MeshPart] = {}
    mesh_docs = doc.get("meshes", [])
    for node in doc.get("nodes", []):
        if "mesh" not in node:
            continue
        mi = node["mesh"]
        md = mesh_docs[mi]
        name = str(node.get("name") or md.get("name") or "Mesh_%d" % mi)
        pos: List[Vec3] = []
        nrm: List[Vec3] = []
        uvs: List[Tuple[float, float]] = []
        idx: List[int] = []
        vbase = 0
        for prim in md.get("primitives", []):
            attrs = prim.get("attributes", {})
            p = read_vec3(doc, blob, attrs["POSITION"])
            ncount = len(p)
            if "NORMAL" in attrs:
                n = read_vec3(doc, blob, attrs["NORMAL"])
            else:
                n = [(0.0, 1.0, 0.0)] * ncount
            if "TEXCOORD_0" in attrs:
                uv = read_vec2(doc, blob, attrs["TEXCOORD_0"])
            else:
                uv = [(0.0, 0.0)] * ncount
            if len(n) != ncount:
                n = (n + [(0.0, 1.0, 0.0)] * ncount)[:ncount]
            if len(uv) != ncount:
                uv = (uv + [(0.0, 0.0)] * ncount)[:ncount]
            if "indices" in prim:
                raw_i = read_indices(doc, blob, prim["indices"])
            else:
                raw_i = list(range(ncount))
            pos.extend(p)
            nrm.extend(n)
            uvs.extend(uv)
            idx.extend(vbase + i for i in raw_i)
            vbase += ncount
        meshes[name] = MeshPart(name, pos, nrm, uvs, idx, node_translation(node))
    return meshes


def fused_source_mesh(path: Path) -> MeshPart:
    parts = extract_meshes(path)
    if not parts:
        raise RuntimeError("no meshes in %s" % path)
    if len(parts) == 1:
        return next(iter(parts.values()))
    # Concatenate if the importer split unexpectedly.
    pos, nrm, uv, idx = [], [], [], []
    base = 0
    for part in parts.values():
        pos.extend(part.positions)
        nrm.extend(part.normals)
        uv.extend(part.uvs)
        idx.extend(base + i for i in part.indices)
        base += len(part.positions)
    return MeshPart("Body", pos, nrm, uv, idx)


def faces_of(part: MeshPart) -> List[Tri]:
    idx = part.indices
    out = []
    for i in range(0, len(idx) - 2, 3):
        out.append((idx[i], idx[i + 1], idx[i + 2]))
    return out


def write_glb(path: Path, parts: Sequence[MeshPart], empties: Sequence[dict]) -> None:
    """Export geometry-only GLB. No images, no textures."""
    accessors: List[dict] = []
    bin_parts: List[bytes] = []
    cursor = 0

    def push_f32(values: List[float], type_name: str, comps: int) -> int:
        nonlocal cursor
        raw = b"".join(struct.pack("<f", float(v)) for v in values)
        raw = _pad4(raw, b"\x00")
        grouped = [values[i : i + comps] for i in range(0, len(values), comps)]
        mn = [min(g[c] for g in grouped) for c in range(comps)]
        mx = [max(g[c] for g in grouped) for c in range(comps)]
        idx = len(accessors)
        accessors.append({
            "bufferView": 0,
            "byteOffset": cursor,
            "componentType": 5126,
            "count": len(values) // comps,
            "type": type_name,
            "min": mn,
            "max": mx,
        })
        bin_parts.append(raw)
        cursor += len(raw)
        return idx

    def push_u32(values: List[int]) -> int:
        nonlocal cursor
        raw = b"".join(struct.pack("<I", int(v)) for v in values)
        raw = _pad4(raw, b"\x00")
        idx = len(accessors)
        accessors.append({
            "bufferView": 0,
            "byteOffset": cursor,
            "componentType": 5125,
            "count": len(values),
            "type": "SCALAR",
            "min": [0],
            "max": [max(values) if values else 0],
        })
        bin_parts.append(raw)
        cursor += len(raw)
        return idx

    materials = [{
        "name": "TrackCarV3Untextured",
        "pbrMetallicRoughness": {
            "baseColorFactor": [0.55, 0.55, 0.58, 1.0],
            "metallicFactor": 0.0,
            "roughnessFactor": 0.55,
        },
    }]
    mesh_docs = []
    for part in parts:
        pos = [c for p in part.positions for c in p]
        nrm = [c for n in part.normals for c in n]
        uvs = [c for uv in part.uvs for c in uv]
        p_i = push_f32(pos, "VEC3", 3)
        n_i = push_f32(nrm, "VEC3", 3)
        t_i = push_f32(uvs, "VEC2", 2)
        i_i = push_u32(part.indices)
        mesh_docs.append({
            "name": part.name,
            "primitives": [{
                "attributes": {"POSITION": p_i, "NORMAL": n_i, "TEXCOORD_0": t_i},
                "indices": i_i,
                "material": 0,
            }],
        })

    blob = b"".join(bin_parts)
    nodes = [{"name": "ArticulatedRoot", "children": list(range(1, 1 + len(parts) + len(empties)))}]
    for i, part in enumerate(parts):
        node = {"name": part.name, "mesh": i, "scale": [1.0, 1.0, 1.0]}
        if hypot3(part.translation) > 1e-9:
            node["translation"] = [float(v) for v in part.translation]
        nodes.append(node)
    for empty in empties:
        node = {
            "name": empty["name"],
            "translation": [float(v) for v in empty["translation"]],
            "scale": [1.0, 1.0, 1.0],
        }
        nodes.append(node)

    gltf = {
        "asset": {"version": "2.0", "generator": "ssk-track-car-articulated-v3"},
        "scene": 0,
        "scenes": [{"nodes": [0]}],
        "nodes": nodes,
        "meshes": mesh_docs,
        "materials": materials,
        "accessors": accessors,
        "bufferViews": [{"buffer": 0, "byteOffset": 0, "byteLength": len(blob)}],
        "buffers": [{"byteLength": len(blob)}],
    }
    json_bytes = _pad4(json.dumps(gltf, separators=(",", ":")).encode("utf-8"), b" ")
    bin_bytes = _pad4(blob, b"\x00")
    total = 12 + 8 + len(json_bytes) + 8 + len(bin_bytes)
    header = struct.pack("<4sII", b"glTF", 2, total)
    json_chunk = struct.pack("<I4s", len(json_bytes), b"JSON") + json_bytes
    bin_chunk = struct.pack("<I4s", len(bin_bytes), b"BIN\x00") + bin_bytes
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(header + json_chunk + bin_chunk)


# ---------------------------------------------------------------------------
# Topology / metrics
# ---------------------------------------------------------------------------

def aabb_of(points: Sequence[Vec3]) -> dict:
    if not points:
        return {"min": [0, 0, 0], "max": [0, 0, 0], "size": [0, 0, 0], "center": [0, 0, 0]}
    xs = [p[0] for p in points]
    ys = [p[1] for p in points]
    zs = [p[2] for p in points]
    mn = [min(xs), min(ys), min(zs)]
    mx = [max(xs), max(ys), max(zs)]
    size = [mx[i] - mn[i] for i in range(3)]
    center = [(mn[i] + mx[i]) * 0.5 for i in range(3)]
    return {"min": mn, "max": mx, "size": size, "center": center}


def used_vertices(part: MeshPart) -> List[int]:
    return sorted(set(part.indices))


def centroid(points: Sequence[Vec3]) -> Vec3:
    if not points:
        return (0.0, 0.0, 0.0)
    n = float(len(points))
    return (sum(p[0] for p in points) / n, sum(p[1] for p in points) / n, sum(p[2] for p in points) / n)


def face_area(a: Vec3, b: Vec3, c: Vec3) -> float:
    cr = cross(sub(b, a), sub(c, a))
    return 0.5 * hypot3(cr)


def max_edge(a: Vec3, b: Vec3, c: Vec3) -> float:
    return max(dist(a, b), dist(b, c), dist(c, a))


def connected_face_components(faces: Sequence[Tri]) -> List[List[int]]:
    """Union-find faces that share an edge (two vertices)."""
    edge_to_faces: Dict[Tuple[int, int], List[int]] = defaultdict(list)
    for fi, (a, b, c) in enumerate(faces):
        for u, v in ((a, b), (b, c), (c, a)):
            key = (u, v) if u < v else (v, u)
            edge_to_faces[key].append(fi)
    parent = list(range(len(faces)))

    def find(x: int) -> int:
        while parent[x] != x:
            parent[x] = parent[parent[x]]
            x = parent[x]
        return x

    def union(a: int, b: int) -> None:
        ra, rb = find(a), find(b)
        if ra != rb:
            parent[rb] = ra

    for group in edge_to_faces.values():
        root = group[0]
        for other in group[1:]:
            union(root, other)
    buckets: Dict[int, List[int]] = defaultdict(list)
    for fi in range(len(faces)):
        buckets[find(fi)].append(fi)
    comps = list(buckets.values())
    comps.sort(key=len, reverse=True)
    return comps


def vertex_components(part: MeshPart) -> List[List[int]]:
    parent = {i: i for i in range(len(part.positions))}

    def find(x: int) -> int:
        while parent[x] != x:
            parent[x] = parent[parent[x]]
            x = parent[x]
        return x

    def union(a: int, b: int) -> None:
        ra, rb = find(a), find(b)
        if ra != rb:
            parent[rb] = ra

    for i in range(0, len(part.indices) - 2, 3):
        a, b, c = part.indices[i], part.indices[i + 1], part.indices[i + 2]
        union(a, b)
        union(b, c)
    used = set(part.indices)
    buckets: Dict[int, List[int]] = defaultdict(list)
    for i in used:
        buckets[find(i)].append(i)
    comps = list(buckets.values())
    comps.sort(key=len, reverse=True)
    return comps


def wheel_metrics(part: MeshPart, axle_local: Vec3 = (0.0, 0.0, 0.0)) -> dict:
    faces = faces_of(part)
    used = [part.positions[i] for i in used_vertices(part)]
    rel = [sub(p, axle_local) for p in used]
    r3 = [hypot3(p) for p in rel]
    r_yz = [math.hypot(p[1], p[2]) for p in rel]
    axial = [abs(p[0]) for p in rel]
    box = aabb_of(rel)
    max_r = max(r3) if r3 else 0.0
    long_faces = []
    thin_faces = []
    for fi, (a, b, c) in enumerate(faces):
        pa, pb, pc = part.positions[a], part.positions[b], part.positions[c]
        e = max_edge(pa, pb, pc)
        area = face_area(pa, pb, pc)
        if e > MAX_FACE_EDGE_SOURCE:
            long_faces.append({"face": fi, "max_edge": round(e, 5), "area": round(area, 6)})
        if e > 1e-8 and area > 1e-12:
            aspect = (e * e) / max(area, 1e-12)
            if aspect > MAX_THIN_ASPECT and e > 0.08:
                thin_faces.append({"face": fi, "max_edge": round(e, 5), "aspect": round(aspect, 2)})
    vcomps = vertex_components(part)
    fcomps = connected_face_components(faces) if faces else []
    stray_comps = []
    for ci, verts in enumerate(vcomps):
        pts = [sub(part.positions[i], axle_local) for i in verts]
        c = centroid(pts)
        cr = hypot3(c)
        cbox = aabb_of(pts)
        max_axis = max(cbox["size"])
        if cr > MAX_WHEEL_RADIUS_SOURCE or max_axis > MAX_WHEEL_AABB_AXIS_SOURCE:
            stray_comps.append({
                "component_id": ci,
                "verts": len(verts),
                "centroid": [round(x, 5) for x in c],
                "centroid_r": round(cr, 5),
                "aabb_size": [round(x, 5) for x in cbox["size"]],
            })
    outliers = []
    for i, p in enumerate(rel):
        if hypot3(p) > MAX_WHEEL_RADIUS_SOURCE or abs(p[0]) > MAX_WHEEL_HALF_WIDTH_SOURCE:
            outliers.append({
                "vertex": i,
                "position": [round(x, 5) for x in p],
                "r": round(hypot3(p), 5),
                "axial": round(abs(p[0]), 5),
                "radial_yz": round(math.hypot(p[1], p[2]), 5),
            })
            if len(outliers) >= 32:
                break
    sweep = spin_sweep(rel)
    return {
        "name": part.name,
        "vertices": len(part.positions),
        "used_vertices": len(used),
        "faces": len(faces),
        "aabb": {k: [round(x, 5) for x in v] if isinstance(v, list) else v for k, v in box.items()},
        "centroid": [round(x, 5) for x in centroid(rel)],
        "max_radius": round(max_r, 5),
        "max_radius_yz": round(max(r_yz) if r_yz else 0.0, 5),
        "max_axial": round(max(axial) if axial else 0.0, 5),
        "max_face_edge": round(max((max_edge(part.positions[a], part.positions[b], part.positions[c]) for a, b, c in faces), default=0.0), 5),
        "long_faces": long_faces[:16],
        "thin_faces": thin_faces[:16],
        "vertex_components": len(vcomps),
        "face_components": len(fcomps),
        "dominant_component_faces": len(fcomps[0]) if fcomps else 0,
        "stray_components": stray_comps,
        "outlier_count": len(outliers) if len(outliers) < 32 else len([p for p in rel if hypot3(p) > MAX_WHEEL_RADIUS_SOURCE]),
        "outliers_sample": outliers,
        "spin_sweep": sweep,
        "gates": wheel_gates(box, max_r, max(axial) if axial else 0.0, stray_comps, long_faces, thin_faces, sweep),
    }


def spin_sweep(rel_points: Sequence[Vec3], samples: int = SPIN_SAMPLES) -> dict:
    if not rest_ok(rel_points):
        return {"samples": 0, "max_r": 0.0, "min_r": 0.0, "delta_r": 0.0, "aabb_delta": [0, 0, 0], "pass": False}
    rest_r = max(hypot3(p) for p in rel_points)
    rest_box = aabb_of(rel_points)
    max_r = rest_r
    min_r = rest_r
    max_size = rest_box["size"][:]
    min_size = rest_box["size"][:]
    for i in range(samples):
        ang = (2.0 * math.pi) * (i / float(samples))
        spun = [rot_x(p, ang) for p in rel_points]
        r = max(hypot3(p) for p in spun)
        max_r = max(max_r, r)
        min_r = min(min_r, r)
        box = aabb_of(spun)
        for k in range(3):
            max_size[k] = max(max_size[k], box["size"][k])
            min_size[k] = min(min_size[k], box["size"][k])
    delta_r = max_r - min_r
    aabb_delta = [max_size[k] - min_size[k] for k in range(3)]
    # Rotation around X should keep max radius ~constant; AABB Y/Z trade off, X width stable.
    ok = delta_r <= 0.004 and aabb_delta[0] <= 0.004 and max_r <= MAX_WHEEL_RADIUS_SOURCE + 0.002
    return {
        "samples": samples,
        "max_r": round(max_r, 5),
        "min_r": round(min_r, 5),
        "delta_r": round(delta_r, 5),
        "aabb_delta": [round(x, 5) for x in aabb_delta],
        "pass": bool(ok),
    }


def rest_ok(points: Sequence[Vec3]) -> bool:
    return bool(points)


def wheel_gates(box: dict, max_r: float, max_axial: float, stray, long_faces, thin_faces, sweep: dict) -> dict:
    size = box["size"]
    compact = all(s <= MAX_WHEEL_AABB_AXIS_SOURCE for s in size)
    radius_ok = max_r <= MAX_WHEEL_RADIUS_SOURCE and max_axial <= MAX_WHEEL_HALF_WIDTH_SOURCE
    return {
        "aabb_compact": compact,
        "radius": radius_ok,
        "no_stray_component": len(stray) == 0,
        "no_long_face": len(long_faces) == 0,
        "no_thin_sheet": len(thin_faces) == 0,
        "spin_sweep": bool(sweep.get("pass")),
        "pass": compact and radius_ok and not stray and not long_faces and not thin_faces and bool(sweep.get("pass")),
    }


def semantic_orientation_metrics(part: MeshPart) -> dict:
    """Independent of wheel labels: rear wing is the high-Y Z-extreme.

    After canonical 180° Y, wing/high-Y must sit at +Z (rear) and the low-Y
    bumper extreme at -Z (nose). Centroid-Z is not used.
    """
    pts = part.positions
    if not pts:
        return {"pass": False, "reason": "empty"}
    zmin = min(p[2] for p in pts)
    zmax = max(p[2] for p in pts)
    near_min = [p for p in pts if p[2] < zmin + 0.08]
    near_max = [p for p in pts if p[2] > zmax - 0.08]
    y_at_zmin = sum(p[1] for p in near_min) / max(len(near_min), 1)
    y_at_zmax = sum(p[1] for p in near_max) / max(len(near_max), 1)
    ys = sorted(p[1] for p in pts)
    ycut = ys[int(len(ys) * 0.98)] if ys else 0.0
    high = [p for p in pts if p[1] >= ycut]
    high_z = sum(p[2] for p in high) / max(len(high), 1)
    # Nose at -Z: the +Z cap must be higher (wing) than the -Z cap (bumper).
    ok = y_at_zmax > y_at_zmin + 0.02 and high_z > 0.05
    return {
        "z_min": round(zmin, 5),
        "z_max": round(zmax, 5),
        "y_at_zmin": round(y_at_zmin, 5),
        "y_at_zmax": round(y_at_zmax, 5),
        "high_y_mean_z": round(high_z, 5),
        "pass": bool(ok),
    }


def source_topology(part: MeshPart) -> dict:
    faces = faces_of(part)
    vcomps = vertex_components(part)
    box = aabb_of(part.positions)
    comps = []
    for ci, verts in enumerate(vcomps[:40]):
        pts = [part.positions[i] for i in verts]
        cb = aabb_of(pts)
        comps.append({
            "id": ci,
            "verts": len(verts),
            "centroid": [round(x, 5) for x in centroid(pts)],
            "aabb_size": [round(x, 5) for x in cb["size"]],
            "volume_proxy": round(cb["size"][0] * cb["size"][1] * cb["size"][2], 6),
        })
    return {
        "vertices": len(part.positions),
        "faces": len(faces),
        "connected_components": len(vcomps),
        "aabb": box,
        "centroid": [round(x, 5) for x in centroid(part.positions)],
        "components_head": comps,
    }


# ---------------------------------------------------------------------------
# PNG rasterizer
# ---------------------------------------------------------------------------

def write_png(path: Path, w: int, h: int, rgb: bytearray) -> None:
    def chunk(tag: bytes, data: bytes) -> bytes:
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    raw = b"".join(b"\x00" + bytes(rgb[y * w * 3 : (y + 1) * w * 3]) for y in range(h))
    ihdr = struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0)
    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr) + chunk(b"IDAT", zlib.compress(raw, 6)) + chunk(b"IEND", b"")
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(png)


def _project(p: Vec3, view: str) -> Tuple[float, float, float]:
    x, y, z = p
    if view == "FRONT":
        return x, y, -z
    if view == "REAR":
        return -x, y, z
    if view == "LEFT":
        return z, y, -x
    if view == "RIGHT":
        return -z, y, x
    if view == "TOP":
        return x, -z, y
    if view == "Q3_FRONT":
        return x * 0.85 + z * 0.35, y * 0.92 + x * 0.15, -z * 0.85 + x * 0.35
    if view == "Q3_REAR":
        return -x * 0.85 - z * 0.35, y * 0.92, z * 0.85 - x * 0.35
    return x, y, -z


def render_parts(parts: Sequence[MeshPart], path: Path, view: str, size: int = 384, hide: Optional[Iterable[str]] = None, spin_x: float = 0.0) -> None:
    hide_set = set(hide or [])
    tris = []
    for part in parts:
        if part.name in hide_set:
            continue
        world = []
        for p in part.positions:
            q = add(p, part.translation)
            if spin_x:
                q = add(rot_x(sub(q, part.translation), spin_x), part.translation)
            world.append(q)
        idx = part.indices
        for i in range(0, len(idx) - 2, 3):
            a, b, c = world[idx[i]], world[idx[i + 1]], world[idx[i + 2]]
            n = cross(sub(b, a), sub(c, a))
            nl = hypot3(n)
            if nl < 1e-12:
                continue
            n = mul(n, 1.0 / nl)
            shade = max(0.18, min(1.0, 0.25 + 0.75 * abs(n[1] * 0.35 + n[2] * 0.55 + n[0] * 0.25)))
            if part.name.startswith("Wheel_"):
                base = (40, 42, 48)
            elif part.name == "Body":
                base = (196, 48, 54)
            else:
                base = (160, 160, 168)
            col = (int(base[0] * shade), int(base[1] * shade), int(base[2] * shade))
            pa = _project(a, view)
            pb = _project(b, view)
            pc = _project(c, view)
            tris.append((pa, pb, pc, col))
    _blit_tris(tris, path, size)


def _blit_tris(tris, path: Path, size: int) -> None:
    if not tris:
        rgb = bytearray([210, 212, 216]) * (size * size)
        write_png(path, size, size, rgb)
        return
    xs, ys = [], []
    for a, b, c, _ in tris:
        xs.extend((a[0], b[0], c[0]))
        ys.extend((a[1], b[1], c[1]))
    minx, maxx = min(xs), max(xs)
    miny, maxy = min(ys), max(ys)
    span = max(maxx - minx, maxy - miny, 1e-4) * 1.18
    cx = (minx + maxx) * 0.5
    cy = (miny + maxy) * 0.5
    margin = size * 0.08
    usable = size - 2 * margin

    def to_px(p):
        u = margin + ((p[0] - cx) / span + 0.5) * usable
        v = margin + (0.5 - (p[1] - cy) / span) * usable
        return u, v, p[2]

    zbuf = np.full((size, size), -1.0e30, dtype=np.float32)
    img = np.full((size, size, 3), 210, dtype=np.uint8)
    img[:, :, 1] = 212
    img[:, :, 2] = 216
    for a, b, c, col in tris:
        a = to_px(a)
        b = to_px(b)
        c = to_px(c)
        min_i = max(0, int(math.floor(min(a[0], b[0], c[0]))))
        max_i = min(size - 1, int(math.ceil(max(a[0], b[0], c[0]))))
        min_j = max(0, int(math.floor(min(a[1], b[1], c[1]))))
        max_j = min(size - 1, int(math.ceil(max(a[1], b[1], c[1]))))
        if max_i < min_i or max_j < min_j:
            continue
        area = (b[0] - a[0]) * (c[1] - a[1]) - (b[1] - a[1]) * (c[0] - a[0])
        if abs(area) < 1e-8:
            continue
        xs = np.arange(min_i, max_i + 1, dtype=np.float32)
        ys = np.arange(min_j, max_j + 1, dtype=np.float32)
        xx, yy = np.meshgrid(xs, ys)
        w0 = (b[0] - xx) * (c[1] - yy) - (b[1] - yy) * (c[0] - xx)
        w1 = (c[0] - xx) * (a[1] - yy) - (c[1] - yy) * (a[0] - xx)
        w2 = (a[0] - xx) * (b[1] - yy) - (a[1] - yy) * (b[0] - xx)
        den = -area if area < 0 else area
        if area < 0:
            w0, w1, w2 = -w0, -w1, -w2
        mask = (w0 >= 0) & (w1 >= 0) & (w2 >= 0)
        if not mask.any():
            continue
        z = (w0 * a[2] + w1 * b[2] + w2 * c[2]) / den
        sl = zbuf[min_j:max_j + 1, min_i:max_i + 1]
        better = mask & (z >= sl)
        sl[better] = z[better]
        patch = img[min_j:max_j + 1, min_i:max_i + 1]
        patch[better] = col
    rgb = bytearray(img.tobytes())
    write_png(path, size, size, rgb)


def transformed_copy(part: MeshPart, fn) -> MeshPart:
    pos = [fn(p) for p in part.positions]
    nrm = [fn(n) for n in part.normals]
    return MeshPart(part.name, pos, nrm, list(part.uvs), list(part.indices), fn(part.translation) if part.translation != (0, 0, 0) else (0.0, 0.0, 0.0))


def remap_part(part: MeshPart, face_indices: Sequence[Tri], origin: Vec3, name: str) -> MeshPart:
    used = sorted({i for tri in face_indices for i in tri})
    remap = {old: new for new, old in enumerate(used)}
    pos = [sub(part.positions[i], origin) for i in used]
    nrm = [part.normals[i] if i < len(part.normals) else (0.0, 1.0, 0.0) for i in used]
    uv = [part.uvs[i] if i < len(part.uvs) else (0.0, 0.0) for i in used]
    idx = []
    for a, b, c in face_indices:
        idx.extend((remap[a], remap[b], remap[c]))
    return MeshPart(name, pos, nrm, uv, idx, origin)
