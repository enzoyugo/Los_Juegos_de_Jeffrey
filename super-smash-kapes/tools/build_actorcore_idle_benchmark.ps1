# ActorCore idle benchmark — full pipeline
$ErrorActionPreference = "Stop"

$Blender = "C:\Program Files\Blender Foundation\Blender 2.83\blender.exe"
$Godot = "E:\Godot_v4.7.2-stable_win64_console.exe"
$Project = "E:\SuperSmashKapes\super-smash-kapes"
$Tools = Join-Path $Project "tools\blender"

function Invoke-BlenderPython([string]$Script, [string[]]$ExtraArgs = @()) {
    $blenderArgs = @("--background", "--python", $Script)
    if ($ExtraArgs.Count -gt 0) { $blenderArgs += "--"; $blenderArgs += $ExtraArgs }
    & $Blender @blenderArgs
    if ($LASTEXITCODE -ne 0) { throw "Blender failed: $Script" }
}

Write-Host "=== Blender version ==="
& $Blender --version

Write-Host "=== Phase 1: Inventory ==="
python (Join-Path $Tools "inventory_actorcore_assets.py")

Write-Host "=== Phase 2-4: Inspect ActorCore + Mixamo ==="
Invoke-BlenderPython (Join-Path $Tools "inspect_actorcore_fighters.py")

Write-Host "=== Phase 3: Equivalence ==="
python (Join-Path $Tools "compare_actorcore_equivalence.py")

Write-Host "=== Phase 5: Bone map ==="
python (Join-Path $Tools "build_mixamo_actorcore_map.py")

Write-Host "=== Phase 6: Rest basis ==="
Invoke-BlenderPython (Join-Path $Tools "audit_rest_basis.py")

foreach ($char in @("terere", "jaguarete")) {
    Write-Host "=== Bake $char ==="
    Invoke-BlenderPython (Join-Path $Tools "retarget_mixamo_to_actorcore.py") @("--character", $char)
    Write-Host "=== Roundtrip $char ==="
    Invoke-BlenderPython (Join-Path $Tools "glb_roundtrip_audit.py") @("--character", $char)
}

Write-Host "=== Godot import ==="
& $Godot --path $Project --import --headless
if ($LASTEXITCODE -ne 0) { throw "Godot import failed" }

Write-Host "=== Godot track dump ==="
& $Godot --path $Project --headless --script "res://scripts/debug/dump_actorcore_animation_tracks.gd"
if ($LASTEXITCODE -ne 0) { throw "Godot track dump failed" }

Write-Host "=== Docs/metrics ==="
python (Join-Path $Tools "generate_benchmark_docs.py")

Write-Host "=== Pytest ==="
Push-Location $Project
python -m pytest tests -q --tb=line
$code = $LASTEXITCODE
Pop-Location
if ($code -ne 0) { throw "Pytest failed" }

Write-Host "=== ActorCore benchmark pipeline complete ==="
