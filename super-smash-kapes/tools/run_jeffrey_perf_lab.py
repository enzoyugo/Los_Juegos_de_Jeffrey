"""Run Jeffrey Performance Lab with GPU authority validation.

Uses display-backed Windows driver and log-file capture (not stdout pipes).
"""

from __future__ import annotations

import json
import os
import re
import shutil
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_GODOT_DIR = Path("E:/")
SCENE_LAB = "res://scenes/debug/JeffreyPerformanceLab.tscn"
SCENE_BOOT = "res://scenes/core/JeffreyBoot.tscn"
SCENE_GPU_PROBE = "res://scenes/debug/JeffreyGpuAuthorityProbe.tscn"

JSON_RE = re.compile(r"\[JEFFREY_PERF_JSON\] (.+)")
BUILD_RE = re.compile(r"\[TRACK_BUILD\] (.+)")
DEVICE_RE = re.compile(r"^\s*#(\d+):\s*(.+)$", re.MULTILINE)
GPU_AUTHORITY_RE = re.compile(r"GPU_AUTHORITY=(PASS|FAIL)")
GPU_PROBE_RE = re.compile(r"\[GPU_PROBE\] label=(\S+) adapter=(.+?) renderer=(\S+)")
USING_DEVICE_RE = re.compile(
    r"Using Device #\d+:\s*(.+?)(?:\s*$|\s*-)", re.MULTILINE
)

SOFTWARE_GPU_MARKERS = (
    "microsoft basic render driver",
    "llvmpipe",
    "software rasterizer",
    "swiftshader",
    "angle (microsoft, microsoft basic render driver",
)

EXPECTED_GPU_DEFAULT = "NVIDIA,RTX 2060 SUPER"


def resolve_godot_executable() -> tuple[Path, str]:
    """Return (path, source_description). Prefer GUI exe for GPU benchmarks."""
    env_path = os.environ.get("GODOT", "").strip()
    force_console = os.environ.get("SSK_PERF_USE_CONSOLE", "").strip() == "1"
    gui = DEFAULT_GODOT_DIR / "Godot_v4.7.2-stable_win64.exe"
    console = DEFAULT_GODOT_DIR / "Godot_v4.7.2-stable_win64_console.exe"
    if env_path:
        resolved = Path(env_path)
        if resolved.exists():
            if not force_console and resolved.name.endswith("_console.exe") and gui.exists():
                return gui, f"gui_preferred_over_env_console (env was {resolved})"
            return resolved, f"env:GODOT={resolved}"
    if not force_console and gui.exists():
        return gui, "default_gui:Godot_v4.7.2-stable_win64.exe"
    if console.exists():
        return console, "fallback_console:Godot_v4.7.2-stable_win64_console.exe"
    raise FileNotFoundError("No Godot executable found (set GODOT or install under E:/)")


def _software_adapter(adapter: str) -> bool:
    lower = adapter.lower()
    return any(marker in lower for marker in SOFTWARE_GPU_MARKERS)


def gpu_authority_pass(adapter: str, expected: str) -> bool:
    if not adapter or _software_adapter(adapter):
        return False
    upper = adapter.upper()
    for token in expected.split(","):
        needle = token.strip().upper()
        if needle and needle in upper:
            return True
    return False


def parse_devices_verbose(text: str) -> list[tuple[int, str]]:
    devices: list[tuple[int, str]] = []
    for match in DEVICE_RE.finditer(text):
        devices.append((int(match.group(1)), match.group(2).strip()))
    return devices


def pick_nvidia_gpu_index(text: str) -> int | None:
    for index, name in parse_devices_verbose(text):
        lower = name.lower()
        if "nvidia" in lower and "basic render driver" not in lower:
            return index
    return None


def collect_relevant_env() -> dict[str, str]:
    keys = (
        "GODOT",
        "SSK_GPU_INDEX",
        "SSK_EXPECTED_GPU",
        "SSK_PERF_USE_CONSOLE",
        "SSK_PERF_SCENARIO",
        "SSK_PERF_DIAG",
        "DISPLAY",
        "CUDA_VISIBLE_DEVICES",
        "__NV_PRIME_RENDER_OFFLOAD",
        "__GLX_VENDOR_LIBRARY_NAME",
    )
    return {k: os.environ[k] for k in keys if k in os.environ}


def run_godot(
    godot: Path,
    *,
    scene: str,
    rendering_method: str,
    rendering_driver: str,
    log_path: Path,
    quit_after: int = 120,
    gpu_index: int | None = None,
    extra_env: dict[str, str] | None = None,
    probe_label: str | None = None,
) -> tuple[int, str, list[str]]:
    env = os.environ.copy()
    if extra_env:
        env.update(extra_env)
    env.setdefault("SSK_EXPECTED_GPU", EXPECTED_GPU_DEFAULT)
    cmd: list[str] = [
        str(godot),
        "--path",
        str(ROOT),
        "--display-driver",
        "windows",
        "--rendering-method",
        rendering_method,
        "--rendering-driver",
        rendering_driver,
        "--audio-driver",
        "Dummy",
        "--resolution",
        "1920x1080",
        "--log-file",
        str(log_path),
        "--quit-after",
        str(quit_after),
    ]
    if gpu_index is not None:
        cmd.extend(["--gpu-index", str(gpu_index)])
    if probe_label:
        env["SSK_GPU_PROBE_LABEL"] = probe_label
    cmd.append(scene)
    notes = [f"CMD: {' '.join(cmd)}"]
    log_path.parent.mkdir(parents=True, exist_ok=True)
    if log_path.exists():
        log_path.unlink()
    proc = subprocess.run(
        cmd,
        cwd=str(ROOT),
        env=env,
        timeout=300,
    )
    text = log_path.read_text(encoding="utf-8", errors="replace") if log_path.exists() else ""
    return proc.returncode, text, notes


def run_verbose_device_probe(
    godot: Path,
    *,
    rendering_method: str,
    rendering_driver: str,
    log_path: Path,
) -> tuple[int, str, int | None]:
    env = os.environ.copy()
    cmd = [
        str(godot),
        "--path",
        str(ROOT),
        "--display-driver",
        "windows",
        "--rendering-method",
        rendering_method,
        "--rendering-driver",
        rendering_driver,
        "--audio-driver",
        "Dummy",
        "--verbose",
        "--log-file",
        str(log_path),
        "--quit-after",
        "3",
        SCENE_GPU_PROBE,
    ]
    if log_path.exists():
        log_path.unlink()
    proc = subprocess.run(cmd, cwd=str(ROOT), env=env, timeout=120)
    text = log_path.read_text(encoding="utf-8", errors="replace") if log_path.exists() else ""
    return proc.returncode, text, pick_nvidia_gpu_index(text)


def extract_adapter(text: str) -> str:
    probe = GPU_PROBE_RE.search(text)
    if probe:
        return probe.group(2).strip()
    using = USING_DEVICE_RE.search(text)
    if using:
        return using.group(1).strip()
    for line in text.splitlines():
        if "gpu=" in line and "[JEFFREY_MEM]" in line:
            idx = line.rfind("gpu=")
            return line[idx + 4 :].strip()
    return ""


def run_lab_block(
    godot: Path,
    *,
    rendering_method: str,
    rendering_driver: str,
    label: str,
    log_dir: Path,
    gpu_index: int | None,
    scenario: str = "ALL",
    quit_after: int = 2400,
) -> dict:
    log_path = log_dir / f"{label}.log"
    env_extra = {"SSK_PERF_SCENARIO": scenario, "SSK_PERF_DIAG": "1"}
    exit_code, text, notes = run_godot(
        godot,
        scene=SCENE_LAB,
        rendering_method=rendering_method,
        rendering_driver=rendering_driver,
        log_path=log_path,
        quit_after=quit_after,
        gpu_index=gpu_index,
        extra_env=env_extra,
    )
    adapter = extract_adapter(text)
    expected = os.environ.get("SSK_EXPECTED_GPU", EXPECTED_GPU_DEFAULT)
    authority = gpu_authority_pass(adapter, expected)
    execution = exit_code == 0 and "[JEFFREY_PERF_LAB] PASS" in text
    rows: list[dict] = []
    builds: list[str] = []
    for line in text.splitlines():
        m = JSON_RE.search(line)
        if m:
            rows.append(json.loads(m.group(1)))
        b = BUILD_RE.search(line)
        if b:
            builds.append(b.group(1))
    perf_valid = execution and authority
    return {
        "label": label,
        "renderer": rendering_method,
        "rendering_driver": rendering_driver,
        "display_driver": "windows",
        "gpu_index": gpu_index,
        "exit_code": exit_code,
        "execution_pass": execution,
        "gpu_adapter": adapter,
        "gpu_authority_pass": authority,
        "performance_valid": perf_valid,
        "expected_gpu": expected,
        "metrics": rows if authority else [],
        "track_builds": builds,
        "log_file": str(log_path),
        "command_notes": notes,
        "raw_tail": text.splitlines()[-40:],
    }


def compare_boot_vs_lab(godot: Path, log_dir: Path, gpu_index: int | None) -> dict:
    expected = os.environ.get("SSK_EXPECTED_GPU", EXPECTED_GPU_DEFAULT)
    out: dict = {}
    for name, scene in (("jeffrey_boot", SCENE_BOOT), ("performance_lab_probe", SCENE_GPU_PROBE)):
        log_path = log_dir / f"gpu_compare_{name}.log"
        exit_code, text, _ = run_godot(
            godot,
            scene=scene,
            rendering_method="forward_plus",
            rendering_driver="d3d12",
            log_path=log_path,
            quit_after=30,
            gpu_index=gpu_index,
            extra_env={"SSK_GPU_PROBE_LABEL": name},
            probe_label=name,
        )
        adapter = extract_adapter(text)
        out[name] = {
            "exit_code": exit_code,
            "gpu_adapter": adapter,
            "gpu_authority_pass": gpu_authority_pass(adapter, expected),
            "log_file": str(log_path),
        }
    return out


def print_block_summary(key: str, block: dict) -> None:
    print(key)
    print(f"  EXECUTION={'PASS' if block['execution_pass'] else 'FAIL'}")
    print(f"  GPU={block.get('gpu_adapter') or 'unknown'}")
    print(f"  GPU_AUTHORITY={'PASS' if block['gpu_authority_pass'] else 'FAIL'}")
    print(f"  PERFORMANCE_VALID={'YES' if block['performance_valid'] else 'NO'}")


def archive_previous_results(out_path: Path) -> None:
    if not out_path.exists():
        return
    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    archive = out_path.with_name(f"{out_path.stem}_SOFTWARE_RENDERER_BASELINE_{stamp}{out_path.suffix}")
    shutil.copy2(out_path, archive)
    review_archive = Path(r"E:\JeffreyAIResearch\outputs\runtime-review\jeffrey_perf_track_v1")
    review_archive.mkdir(parents=True, exist_ok=True)
    shutil.copy2(out_path, review_archive / archive.name)


def main() -> int:
    godot, godot_source = resolve_godot_executable()
    if not godot.exists():
        print("GODOT missing:", godot)
        return 2

    print("GODOT_EXECUTABLE", godot)
    print("GODOT_SOURCE", godot_source)
    print("GODOT_CONSOLE_ALSO", DEFAULT_GODOT_DIR / "Godot_v4.7.2-stable_win64_console.exe")
    print("ENV_RELEVANT", json.dumps(collect_relevant_env()))

    out_dir = ROOT / "outputs" / "perf"
    log_dir = out_dir / "logs"
    out_dir.mkdir(parents=True, exist_ok=True)
    review_dir = Path(r"E:\JeffreyAIResearch\outputs\runtime-review\jeffrey_perf_track_v1")
    review_dir.mkdir(parents=True, exist_ok=True)

    local_json = out_dir / "jeffrey_perf_local.json"
    archive_previous_results(local_json)
    archive_previous_results(review_dir / "perf_lab_results.json")

    probe_log = log_dir / "verbose_device_probe.log"
    _, probe_text, nvidia_index = run_verbose_device_probe(
        godot,
        rendering_method="forward_plus",
        rendering_driver="d3d12",
        log_path=probe_log,
    )
    env_gpu = os.environ.get("SSK_GPU_INDEX", "").strip()
    gpu_index = int(env_gpu) if env_gpu.isdigit() else nvidia_index
    devices = parse_devices_verbose(probe_text)
    print("VERBOSE_DEVICES", devices)
    print("SELECTED_GPU_INDEX", gpu_index)

    compare = compare_boot_vs_lab(godot, log_dir, gpu_index)

    results = {
        "timestamp_utc": datetime.now(timezone.utc).isoformat(),
        "godot_version": "4.7.2 stable",
        "godot_executable": str(godot),
        "godot_source": godot_source,
        "resolution": "1920x1080",
        "display_driver": "windows",
        "expected_gpu": os.environ.get("SSK_EXPECTED_GPU", EXPECTED_GPU_DEFAULT),
        "verbose_devices": [{"index": i, "name": n} for i, n in devices],
        "selected_gpu_index": gpu_index,
        "env": collect_relevant_env(),
        "gpu_compare": compare,
        "forward_plus_d3d12": run_lab_block(
            godot,
            rendering_method="forward_plus",
            rendering_driver="d3d12",
            label="forward_plus_d3d12",
            log_dir=log_dir,
            gpu_index=gpu_index,
        ),
        "gl_compatibility": run_lab_block(
            godot,
            rendering_method="gl_compatibility",
            rendering_driver="opengl3",
            label="gl_compatibility",
            log_dir=log_dir,
            gpu_index=gpu_index,
        ),
    }

    for key in ("forward_plus_d3d12", "gl_compatibility"):
        block = results[key]
        if not block["gpu_authority_pass"]:
            block["metrics"] = []
            block["performance_note"] = "INVALID_ON_SOFTWARE_OR_UNEXPECTED_GPU"

    local_json.write_text(json.dumps(results, indent=2), encoding="utf-8")
    review_json = review_dir / "perf_lab_results.json"
    review_json.write_text(json.dumps(results, indent=2), encoding="utf-8")
    print("WROTE", local_json)
    print("WROTE", review_json)

    for key in ("forward_plus_d3d12", "gl_compatibility"):
        print_block_summary(key, results[key])

    boot_ok = compare.get("jeffrey_boot", {}).get("gpu_authority_pass", False)
    lab_ok = compare.get("performance_lab_probe", {}).get("gpu_authority_pass", False)
    if boot_ok and not lab_ok:
        print("DIAGNOSIS lab_launch_differs_from_boot")
    elif not boot_ok and not lab_ok:
        print("DIAGNOSIS subprocess_or_runner_context_lacks_discrete_gpu")
    elif boot_ok and lab_ok:
        print("DIAGNOSIS gpu_authority_ok")

    authority_ok = all(results[k]["gpu_authority_pass"] for k in ("forward_plus_d3d12", "gl_compatibility"))
    execution_ok = all(results[k]["execution_pass"] for k in ("forward_plus_d3d12", "gl_compatibility"))
    if authority_ok and execution_ok:
        return 0
    if execution_ok and not authority_ok:
        return 3
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
