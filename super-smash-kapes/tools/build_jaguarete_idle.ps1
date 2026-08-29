# Build Jaguareté offline-baked idle animation pipeline.
$ErrorActionPreference = "Stop"

$Blender = "C:\Program Files\Blender Foundation\Blender 2.83\blender.exe"
$Godot = "E:\Godot_v4.7.2-stable_win64_console.exe"
$Project = "E:\SuperSmashKapes\super-smash-kapes"

if (-not (Test-Path $Blender)) {
    throw "Blender not found: $Blender"
}
if (-not (Test-Path $Godot)) {
    throw "Godot not found: $Godot"
}

Write-Host "=== Blender version ==="
& $Blender --version

Write-Host "=== Phase 1: Inspect rigs ==="
& $Blender --background --python "$Project\tools\blender\inspect_jaguarete_rig.py"
if ($LASTEXITCODE -ne 0) { throw "Inspect failed" }

Write-Host "=== Phase 2-7: Retarget + bake + export ==="
& $Blender --background --python "$Project\tools\blender\retarget_jaguarete_idle.py"
if ($LASTEXITCODE -ne 0) { throw "Retarget/bake failed" }

Write-Host "=== Godot import ==="
& $Godot --path $Project --import --headless
if ($LASTEXITCODE -ne 0) { throw "Godot import failed" }

Write-Host "=== Validate baked GLB in Godot ==="
& $Godot --path $Project --headless --script "res://scripts/debug/validate_baked_idle_glb.gd"
if ($LASTEXITCODE -ne 0) { throw "Godot baked idle validation failed" }

Write-Host "=== Pytest ==="
Push-Location $Project
python -m pytest tests/test_m0_combat.py -q --tb=line
$pytestCode = $LASTEXITCODE
Pop-Location
if ($pytestCode -ne 0) { throw "Pytest failed" }

Write-Host "=== Pipeline complete ==="
