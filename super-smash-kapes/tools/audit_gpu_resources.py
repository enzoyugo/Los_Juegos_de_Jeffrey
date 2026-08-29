"""Inventory battle textures and apply VRAM-safe Godot import settings."""
from __future__ import annotations

from pathlib import Path
import struct

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "assets"

# Class B/D decorative and event textures: VRAM-compressed, no extra UI mip chain.
VRAM_COMPRESS = [
    "assets/stages/defensores_del_chaco/background/defensores_bg_main.png",
    "assets/stages/defensores_del_chaco/platforms/defensores_platform_kit.png",
    "assets/stages/defensores_del_chaco/crowd/crowd_strips.png",
    "assets/stages/defensores_del_chaco/crowd/crowd_loop_variants.png",
    "assets/stages/defensores_del_chaco/mosaics/mosaic_variants.png",
    "assets/stages/defensores_del_chaco/props/tifo_atlas.png",
    "assets/stages/defensores_del_chaco/props/scoreboard_sheet.png",
    "assets/stages/defensores_del_chaco/foreground/foreground_overlay.png",
    "assets/stages/defensores_del_chaco/fx/stadium_light_confetti_overlay.png",
    "assets/ui/menu/main_menu_bg.png",
    "assets/ui/menu/local_battle_panel.png",
    "assets/ui/victory/common/victory_bg_defensores.png",
    "assets/ui/victory/common/victory_stats_panel.png",
    "assets/ui/victory/common/victory_btn_rematch.png",
    "assets/ui/victory/common/victory_btn_menu.png",
    "assets/ui/victory/common/victory_title_banner.png",
    "assets/ui/victory/common/victory_main_panel.png",
    "assets/ui/victory/terere/terere_victory.png",
    "assets/ui/victory/jaguarete/jaguarete_victory.png",
]

# 3D hero background benefits from mips; UI does not.
GENERATE_MIPS = {
    "assets/stages/defensores_del_chaco/background/defensores_bg_main.png",
    "assets/stages/defensores_del_chaco/platforms/defensores_platform_kit.png",
}

KEEP_LOSSLESS = [
    "assets/ui/hud/hud_p1.png",
    "assets/ui/hud/hud_p2.png",
    "assets/ui/portraits/terere_portrait.png",
    "assets/ui/portraits/jaguarete_portrait.png",
    "assets/ui/menu/smash_kapes_logo.png",
]


def png_size(path: Path) -> tuple[int, int] | None:
    try:
        with path.open("rb") as fh:
            sig = fh.read(8)
            if sig != b"\x89PNG\r\n\x1a\n":
                return None
            _len, ctype = struct.unpack(">I4s", fh.read(8))
            if ctype != b"IHDR":
                return None
            w, h = struct.unpack(">II", fh.read(8))
            return int(w), int(h)
    except OSError:
        return None


def rgba8_bytes(w: int, h: int, mips: bool) -> int:
    total = w * h * 4
    if mips:
        total = int(total * 1.333333)
    return total


def patch_import(rel: str) -> bool:
    import_path = ROOT / (rel + ".import")
    if not import_path.is_file():
        return False
    text = import_path.read_text(encoding="utf-8")
    original = text
    text = text.replace("compress/mode=0", "compress/mode=2")
    text = text.replace("compress/mode=1", "compress/mode=2")
    if rel in GENERATE_MIPS:
        text = text.replace("mipmaps/generate=false", "mipmaps/generate=true")
    else:
        text = text.replace("mipmaps/generate=true", "mipmaps/generate=false")
    if text != original:
        import_path.write_text(text, encoding="utf-8")
        return True
    return False


def glb_stats(path: Path) -> dict:
    with path.open("rb") as fh:
        magic = fh.read(4)
        if magic != b"glTF":
            return {}
        fh.read(8)
        chunk_len, chunk_type = struct.unpack("<I4s", fh.read(8))
        payload = fh.read(chunk_len)
    import json
    data = json.loads(payload.decode("utf-8"))
    images = data.get("images", [])
    meshes = data.get("meshes", [])
    prims = 0
    for mesh in meshes:
        prims += len(mesh.get("primitives", []))
    skins = data.get("skins", [])
    joints = 0
    if skins:
        joints = len(skins[0].get("joints", []))
    anims = [a.get("name", "") for a in data.get("animations", [])]
    materials = data.get("materials", [])
    return {
        "bytes": path.stat().st_size,
        "meshes": len(meshes),
        "primitives": prims,
        "materials": len(materials),
        "images": len(images),
        "joints": joints,
        "animations": anims,
        "image_names": [i.get("name", i.get("uri", "?")) for i in images],
    }


def main() -> None:
    changed = []
    for rel in VRAM_COMPRESS:
        if patch_import(rel):
            changed.append(rel)
    print("patched_imports=%d" % len(changed))
    for rel in changed:
        print("  ", rel)

    rows = []
    for png in sorted(ASSETS.rglob("*.png")):
        if "source_raw" in png.parts or "raw_design" in png.parts:
            continue
        size = png_size(png)
        if not size:
            continue
        rel = png.relative_to(ROOT).as_posix()
        mips = rel in GENERATE_MIPS
        w, h = size
        rows.append((rel, w, h, mips, rgba8_bytes(w, h, mips)))
    rows.sort(key=lambda r: -r[4])
    out = ROOT / "docs/generated/GPU_TEXTURE_INVENTORY.csv"
    out.parent.mkdir(parents=True, exist_ok=True)
    lines = ["path,width,height,mips,rgba8_bytes"]
    for rel, w, h, mips, nbytes in rows:
        lines.append("%s,%d,%d,%s,%d" % (rel, w, h, str(mips).lower(), nbytes))
    out.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print("wrote", out)

    for rel in (
        "assets/fighters/processed/terere/terere_game_ready_v4.glb",
        "assets/fighters/processed/jaguarete/jaguarete_game_ready_v4.glb",
    ):
        stats = glb_stats(ROOT / rel)
        print(rel, stats)


if __name__ == "__main__":
    main()
