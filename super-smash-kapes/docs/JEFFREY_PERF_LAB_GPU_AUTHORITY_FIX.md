# Jeffrey Perf Lab — GPU Authority Fix

## Problem

`python tools/run_jeffrey_perf_lab.py` reported **Microsoft Basic Render Driver** instead of **NVIDIA GeForce RTX 2060 SUPER**, making FPS metrics invalid for target hardware.

## Root causes identified

1. **Missing `--display-driver windows`** — runner passed only `--rendering-driver d3d12`. Godot 4.7 requires an explicit Windows display driver for physical GPU adapter enumeration in CLI launches.
2. **`subprocess.run(..., capture_output=True)`** — stdout/stderr pipes can interfere with display-backed runtime on Windows; runner now uses **`--log-file`** instead.
3. **Console exe default** — runner defaulted to `Godot_v4.7.2-stable_win64_console.exe`. GPU benchmarks now **prefer `Godot_v4.7.2-stable_win64.exe`** unless `SSK_PERF_USE_CONSOLE=1`.
4. **No `--gpu-index` selection** — when Basic Render Driver is adapter #0, discrete NVIDIA may be #1. Runner now verbose-probes devices and selects NVIDIA index (override with `SSK_GPU_INDEX`).

## Output semantics

```
forward_plus_d3d12
  EXECUTION=PASS|FAIL      # process + lab completed
  GPU=<adapter name>       # from Godot RenderingServer
  GPU_AUTHORITY=PASS|FAIL  # NVIDIA/discrete expected
  PERFORMANCE_VALID=YES|NO # EXECUTION && GPU_AUTHORITY
```

Exit codes: `0` = authority + execution OK, `3` = execution OK but GPU authority fail, `1` = execution fail.

## Outputs

- `outputs/perf/jeffrey_perf_local.json` — canonical local benchmark
- `outputs/perf/logs/*.log` — Godot log files per run
- Previous JSON archived as `*_SOFTWARE_RENDERER_BASELINE_*`

## User command (PowerShell)

```powershell
cd E:\SuperSmashKapes\super-smash-kapes
python tools\run_jeffrey_perf_lab.py
```

Optional overrides:

```powershell
$env:SSK_GPU_INDEX="0"          # force adapter index after verbose probe
$env:SSK_EXPECTED_GPU="NVIDIA"  # authority substring
$env:GODOT="E:\Godot_v4.7.2-stable_win64.exe"
python tools\run_jeffrey_perf_lab.py
```

## Agent environment note

Cursor agent shells may only expose **Microsoft Basic Render Driver** (no NVIDIA in verbose device list). That is an **execution context limitation**, not a project bug. Run the command above in an **interactive desktop PowerShell** for authoritative RTX metrics.
