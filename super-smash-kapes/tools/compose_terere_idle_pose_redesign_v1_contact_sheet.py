"""Compose Terere Idle Pose Redesign V1 contact sheet with Pillow.

Rows: Baseline, Pose A, Pose B, Pose C
Columns: Front, 3/4, Side
"""
from __future__ import print_function

import os
import sys

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
SCREEN = os.path.join(ROOT, "docs", "generated", "terere_idle_pose_redesign_v1_screenshots")
OUT = os.path.join(ROOT, "docs", "generated", "TERERE_IDLE_POSE_REDESIGN_V1_CONTACT_SHEET.png")

ROWS = (
    ("BASELINE", "BASELINE"),
    ("POSE_A", "POSE A  RELAXED COMPACT"),
    ("POSE_B", "POSE B  GAME READY"),
    ("POSE_C", "POSE C  CARTOON FIGHTER"),
)
COLS = (
    ("front", "FRONT"),
    ("three_quarter", "3/4 FRONT"),
    ("side", "SIDE"),
)


def font(size):
    for name in ("arial.ttf", "Arial.ttf", "segoeui.ttf"):
        try:
            return ImageFont.truetype(name, size)
        except Exception:
            continue
    return ImageFont.load_default()


def main():
    cell_w, cell_h = 640, 360
    label_h = 36
    row_label_w = 280
    pad = 10
    header_h = 72
    cols_n = len(COLS)
    rows_n = len(ROWS)
    width = row_label_w + cols_n * (cell_w + pad) + pad
    height = header_h + rows_n * (cell_h + label_h + pad) + pad
    sheet = Image.new("RGB", (width, height), (18, 20, 24))
    draw = ImageDraw.Draw(sheet)
    title_font = font(28)
    cell_font = font(18)
    row_font = font(20)
    draw.text((18, 18), "TERERE IDLE POSE REDESIGN V1", font=title_font, fill=(240, 242, 245))
    draw.text((18, 48), "Human silhouette selection. Metrics do not pick a winner.", font=cell_font, fill=(180, 186, 196))
    for col_i, (_key, title) in enumerate(COLS):
        x = row_label_w + col_i * (cell_w + pad)
        draw.text((x + 8, header_h - 28), title, font=cell_font, fill=(210, 214, 220))
    missing = []
    for row_i, (stem, title) in enumerate(ROWS):
        y = header_h + row_i * (cell_h + label_h + pad)
        draw.text((16, y + cell_h * 0.42), title, font=row_font, fill=(230, 232, 236))
        for col_i, (view, _title) in enumerate(COLS):
            x = row_label_w + col_i * (cell_w + pad)
            path = os.path.join(SCREEN, "%s_%s.png" % (stem, view))
            if not os.path.isfile(path):
                missing.append(path)
                draw.rectangle((x, y, x + cell_w, y + cell_h), fill=(32, 36, 42))
                draw.text((x + 16, y + 16), "MISSING", font=cell_font, fill=(220, 80, 80))
                continue
            img = Image.open(path).convert("RGB")
            img = img.resize((cell_w, cell_h), Image.BICUBIC)
            sheet.paste(img, (x, y))
    parent = os.path.dirname(OUT)
    if not os.path.isdir(parent):
        os.makedirs(parent)
    sheet.save(OUT, "PNG")
    print("WROTE", OUT, "bytes", os.path.getsize(OUT), "missing", len(missing))
    if missing:
        for path in missing:
            print("MISSING", path)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
