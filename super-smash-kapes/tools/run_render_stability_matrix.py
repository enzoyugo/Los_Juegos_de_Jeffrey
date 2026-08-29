"""Run RenderStabilityHarness cases under a chosen renderer and capture logs."""

from __future__ import annotations

import argparse
import os
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
GODOT = Path(os.environ.get("GODOT", r"E:\Godot_v4.7.2-stable_win64_console.exe"))
CASES = list("ABCDEFGHIJKL")
FATAL_RE = re.compile(
    r"CreateResource failed|0x8007000e|uninitialized RID|Texture binding is not valid|"
    r"uniform_set is null|Could not preload resource file|Parser Error",
    re.I,
)


def run_case(case: str, method: str, driver: str, frames: int, windowed: bool) -> dict:
    env = os.environ.copy()
    env["SSK_STABILITY_CASE"] = case
    env["SSK_STABILITY_FRAMES"] = str(frames)
    cmd = [str(GODOT), "--path", str(ROOT), "--verbose", "--audio-driver", "Dummy"]
    if not windowed:
        cmd.extend(["--headless", "--display-driver", "headless"])
    if driver:
        cmd.extend(["--rendering-driver", driver])
    cmd.extend(
        [
            "--rendering-method",
            method,
            "--quit-after",
            str(max(frames + 30, 60)),
            "res://scenes/debug/RenderStabilityHarness.tscn",
        ]
    )
    log_dir = ROOT / "docs" / "generated"
    log_dir.mkdir(parents=True, exist_ok=True)
    log_path = log_dir / f"STABILITY_{method}_{driver or 'default'}_{case}.log"
    print("RUN", " ".join(cmd), "case", case)
    proc = subprocess.run(
        cmd,
        cwd=str(ROOT),
        env=env,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
        timeout=180,
    )
    text = (proc.stdout or "") + "\n" + (proc.stderr or "")
    log_path.write_text(text, encoding="utf-8")
    first = ""
    create = False
    for line in text.splitlines():
        if FATAL_RE.search(line):
            if not first:
                first = line.strip()
            if "CreateResource" in line or "0x8007000e" in line:
                create = True
    status = "PASS"
    if proc.returncode not in (0, None) and FATAL_RE.search(text):
        status = "FAIL"
    elif first:
        status = "FAIL"
    elif "STABILITY] CASE=%s END" % case not in text and f"CASE={case} END" not in text:
        if proc.returncode != 0:
            status = "FAIL"
            first = first or "exit %s" % proc.returncode
    return {
        "case": case,
        "status": status,
        "exit": proc.returncode,
        "first_error": first,
        "create_resource": create,
        "log": str(log_path.relative_to(ROOT)).replace("\\", "/"),
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--cases", default="A,B,C,D,E,F,G,H")
    parser.add_argument("--method", default="forward_plus")
    parser.add_argument("--driver", default="d3d12")
    parser.add_argument("--frames", type=int, default=90)
    parser.add_argument("--headless", action="store_true")
    args = parser.parse_args()
    if not GODOT.exists():
        print("GODOT missing:", GODOT)
        return 2
    results = []
    for case in [item.strip().upper() for item in args.cases.split(",") if item.strip()]:
        results.append(run_case(case, args.method, args.driver, args.frames, windowed=not args.headless))
        print(
            "CASE %s %s create=%s first=%s"
            % (case, results[-1]["status"], results[-1]["create_resource"], results[-1]["first_error"][:180])
        )
    out = ROOT / "docs" / "generated" / f"STABILITY_MATRIX_{args.method}_{args.driver or 'default'}.txt"
    lines = ["case\tstatus\tcreate_resource\texit\tfirst_error\tlog"]
    for row in results:
        lines.append(
            "%s\t%s\t%s\t%s\t%s\t%s"
            % (row["case"], row["status"], row["create_resource"], row["exit"], row["first_error"], row["log"])
        )
    out.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print("wrote", out)
    return 0 if all(row["status"] == "PASS" for row in results) else 1


if __name__ == "__main__":
    sys.exit(main())
