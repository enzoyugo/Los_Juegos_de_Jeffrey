"""Inventory raw_models GLB/ZIP candidates. Does not modify source files."""

from __future__ import annotations

import json
import struct
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RAW = ROOT / "assets" / "raw_models"
OUT = ROOT / "docs" / "generated" / "shopping_raw_assets" / "inspect.json"


def _glb_json(path: Path) -> dict | None:
    data = path.read_bytes()
    if len(data) < 12 or data[0:4] != b"glTF":
        return None
    _magic, version, length = struct.unpack_from("<III", data, 0)
    offset = 12
    while offset + 8 <= len(data):
        chunk_len, chunk_type = struct.unpack_from("<II", data, offset)
        offset += 8
        chunk = data[offset : offset + chunk_len]
        offset += chunk_len
        if chunk_type == 0x4E4F534A:  # JSON
            return json.loads(chunk.decode("utf-8"))
    return None


def _accessor_minmax(doc: dict) -> tuple[list[float] | None, list[float] | None]:
    mins: list[float] | None = None
    maxs: list[float] | None = None
    for acc in doc.get("accessors", []):
        if acc.get("type") != "VEC3":
            continue
        mn = acc.get("min")
        mx = acc.get("max")
        if not (isinstance(mn, list) and isinstance(mx, list) and len(mn) >= 3 and len(mx) >= 3):
            continue
        if mins is None:
            mins = [float(mn[0]), float(mn[1]), float(mn[2])]
            maxs = [float(mx[0]), float(mx[1]), float(mx[2])]
        else:
            mins = [min(mins[i], float(mn[i])) for i in range(3)]
            maxs = [max(maxs[i], float(mx[i])) for i in range(3)]
    return mins, maxs


def inspect_glb(path: Path) -> dict:
    doc = _glb_json(path)
    if doc is None:
        return {"path": str(path), "error": "not_glb_or_unreadable"}
    mins, maxs = _accessor_minmax(doc)
    size = None
    if mins and maxs:
        size = [maxs[i] - mins[i] for i in range(3)]
    images = doc.get("images", []) or []
    tex_bytes = 0
    for img in images:
        if "uri" in img and isinstance(img["uri"], str) and img["uri"].startswith("data:"):
            tex_bytes += max(0, len(img["uri"]) * 3 // 4)
    anims = doc.get("animations", []) or []
    return {
        "path": str(path.relative_to(ROOT)).replace("\\", "/"),
        "file_type": "glb",
        "bytes": path.stat().st_size,
        "generator": (doc.get("asset") or {}).get("generator", ""),
        "mesh_count": len(doc.get("meshes", []) or []),
        "primitive_count": sum(len(m.get("primitives", []) or []) for m in (doc.get("meshes") or [])),
        "material_count": len(doc.get("materials", []) or []),
        "texture_count": len(doc.get("textures", []) or []),
        "image_count": len(images),
        "node_count": len(doc.get("nodes", []) or []),
        "animation_count": len(anims),
        "animation_names": [str(a.get("name", "")) for a in anims[:12]],
        "aabb_min": mins,
        "aabb_max": maxs,
        "approx_size": size,
        "scene_names": [str(s.get("name", "")) for s in (doc.get("scenes") or [])],
        "node_names_sample": [str(n.get("name", "")) for n in (doc.get("nodes") or [])[:40]],
        "material_names": [str(m.get("name", "")) for m in (doc.get("materials") or [])[:24]],
        "has_skins": bool(doc.get("skins")),
        "embedded_image_hint_bytes": tex_bytes,
    }


def inspect_zip(path: Path) -> dict:
    names: list[str] = []
    ext_counts: dict[str, int] = {}
    total = 0
    licenses: list[str] = []
    with zipfile.ZipFile(path, "r") as zf:
        for info in zf.infolist():
            names.append(info.filename)
            total += info.file_size
            ext = Path(info.filename).suffix.lower() or "(none)"
            ext_counts[ext] = ext_counts.get(ext, 0) + 1
            low = info.filename.lower()
            if any(k in low for k in ("license", "licence", "readme", "credits", "legal")):
                licenses.append(info.filename)
    return {
        "path": str(path.relative_to(ROOT)).replace("\\", "/"),
        "file_type": "zip",
        "bytes": path.stat().st_size,
        "uncompressed_hint": total,
        "entry_count": len(names),
        "ext_counts": ext_counts,
        "license_or_readme": licenses,
        "entries_sample": names[:60],
    }


def main() -> None:
    rows: list[dict] = []
    for path in sorted(RAW.iterdir()):
        if path.name.startswith(".") or path.name == "_extracted":
            continue
        if path.is_dir():
            continue
        if path.suffix.lower() == ".glb":
            rows.append(inspect_glb(path))
        elif path.suffix.lower() == ".zip":
            rows.append(inspect_zip(path))
        else:
            rows.append(
                {
                    "path": str(path.relative_to(ROOT)).replace("\\", "/"),
                    "file_type": path.suffix.lower() or "unknown",
                    "bytes": path.stat().st_size,
                }
            )
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(rows, indent=2), encoding="utf-8")
    print("wrote", OUT)
    for row in rows:
        print(row.get("path"), row.get("file_type"), row.get("bytes"), row.get("mesh_count"), row.get("approx_size"))


if __name__ == "__main__":
    main()
