"""Index the Track block-preview reference zip from filenames only."""

from __future__ import annotations

import csv
import json
import re
import zipfile
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ZIP_PATH = ROOT / "references/track/block_previews/Block Previews.zip"
OUT_DIR = ROOT / "docs/references/track"

FAMILY_RULES = [
    ("checkpoint", "checkpoint", ("Checkpoint", "Multilap")),
    ("start", "start_finish", ("StartLine", "FinishLine", "Start", "Finish")),
    ("boost", "special", ("Boost", "ForceAcceleration", "Turbo")),
    ("loop", "special", ("Looping", "Loop")),
    ("pipe", "special", ("Pipe", "Tube")),
    ("wallride", "special", ("WallRide", "Wallride")),
    ("tunnel", "tunnel", ("Tunnel",)),
    ("bridge", "bridge", ("Bridge", "Viaduc", "Viaduct")),
    ("jump", "ramp", ("Jump",)),
    ("ramp", "ramp", ("Ramp",)),
    ("hairpin", "technical", ("Hairpin",)),
    ("chicane", "technical", ("Chicane",)),
    ("gtcurve", "curve", ("GTCurve", "GTCurve2", "GTCurve3")),
    ("curve", "curve", ("Curve", "Corner", "Bend")),
    ("straight", "straight", ("Straight",)),
    ("platform", "elevation", ("Platform", "Airship")),
    ("slope", "elevation", ("Slope", "Tilt", "Bump", "Hill")),
    ("border", "border", ("Border", "Fence", "Guardrail", "Rail")),
    ("deco", "decorative", ("Deco", "Sign", "Palm", "Tree", "Pub", "Screen", "Grandstand", "Tribune", "Crowd", "Flag")),
]

TURN_TOKENS = (("left", "Left"), ("right", "Right"), ("diag", "Diag"))
ELEV_TOKENS = (("up", "Up"), ("down", "Down"), ("slope", "Slope"), ("tilt", "Tilt"))
CAMEL = re.compile(r"[A-Z][a-z]+|[A-Z]+(?![a-z])|\d+x\d+|\d+")


def classify(rel_path: str) -> dict:
    folder = rel_path.split("/")[0] if "/" in rel_path else ""
    name = Path(rel_path).name
    stem = Path(name).stem
    env = folder if folder in {"Stadium", "Valley"} else "other"
    body = stem[len("Stadium"):] if stem.startswith("Stadium") else stem
    family = "other"
    special = ""
    tags: list[str] = []
    lower = body.lower()
    for key, fam, tokens in FAMILY_RULES:
        if any(tok.lower() in lower for tok in tokens):
            family = fam
            special = key
            tags.append(key)
            break
    if "circuit" in lower:
        tags.append("circuit")
        if family == "other":
            family = "border"
    turn = next((key for key, tok in TURN_TOKENS if tok.lower() in lower), "")
    elev = next((key for key, tok in ELEV_TOKENS if tok.lower() in lower), "")
    return {
        "source_filename": name,
        "folder_family": folder,
        "inferred_environment": env,
        "inferred_piece_family": family,
        "inferred_turn_type": turn,
        "inferred_elevation_type": elev,
        "inferred_special_type": special,
        "notes": " ".join(tags),
    }


def index_zip() -> dict:
    rows = []
    env_counts: Counter = Counter()
    fam_counts: Counter = Counter()
    token_counts: Counter = Counter()
    with zipfile.ZipFile(ZIP_PATH) as zf:
        names = [n for n in zf.namelist() if not n.endswith("/") and n.lower().endswith(".png")]
        for rel in names:
            row = classify(rel)
            env_counts[row["inferred_environment"]] += 1
            fam_counts[row["inferred_piece_family"]] += 1
            stem = Path(rel).stem
            body = stem[len("Stadium"):] if stem.startswith("Stadium") else stem
            for token in CAMEL.findall(body):
                token_counts[token] += 1
            rows.append(row)
    return {
        "rows": rows,
        "file_count": len(rows),
        "environments": dict(env_counts),
        "families": dict(fam_counts),
        "top_tokens": token_counts.most_common(80),
    }


def main() -> int:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    data = index_zip()
    csv_path = OUT_DIR / "block_preview_inventory.csv"
    with csv_path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(data["rows"][0].keys()))
        writer.writeheader()
        writer.writerows(data["rows"])
    summary = {
        "file_count": data["file_count"],
        "environments": data["environments"],
        "families": data["families"],
        "top_tokens": data["top_tokens"],
        "zip_path": "references/track/block_previews/Block Previews.zip",
    }
    (OUT_DIR / "block_preview_frequency.json").write_text(
        json.dumps(summary, indent=2), encoding="utf-8"
    )
    print("files=%d env=%s fam=%s" % (data["file_count"], data["environments"], data["families"]))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
