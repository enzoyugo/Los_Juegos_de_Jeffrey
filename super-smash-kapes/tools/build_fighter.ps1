# Super Smash Kapes — one-command fighter build (proposal + guarded implementation).
# Does NOT overwrite production catalog unless -Promote is passed (still does not edit git).

param(
    [Parameter(Mandatory = $true)]
    [string]$Character,
    [switch]$Promote,
    [switch]$SkipGodot,
    [switch]$SkipTests
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
Set-Location $Root

$Blender = "C:\Program Files\Blender Foundation\Blender 2.83\blender.exe"
$Godot = "E:\Godot_v4.7.2-stable_win64_console.exe"
$Fbx = Join-Path $Root "assets\fighters\source_rigged\$Character\actorcore\autorig_actor.fbx"
$ValidatePy = Join-Path $Root "tools\blender\validate_future_rig.py"
$LibraryPy = Join-Path $Root "tools\blender\export_actorcore_animation_library.py"
$ValidJson = Join-Path $Root "docs\generated\$($Character.ToUpper())_FUTURE_RIG_VALIDATION.json"

if (-not (Test-Path $Blender)) { throw "Blender missing: $Blender" }
if (-not (Test-Path $Fbx)) { throw "Source FBX missing: $Fbx" }
if ($Character -notin @("terere", "jaguarete")) {
    Write-Host "Character '$Character' is not a known production id. Validator will still run; bake may fail the bone map."
}

Write-Host "== 1. Rig validator =="
& $Blender --background --python $ValidatePy -- --fbx $Fbx --json $ValidJson
if ($LASTEXITCODE -eq 2) {
    throw "Validator REJECT. Refusing bake. See $ValidJson"
}

Write-Host "== 2. Clip-relative animation library bake =="
& $Blender --background --python $LibraryPy -- --character $Character
if ($LASTEXITCODE -ne 0) { throw "Library bake failed" }

if (-not $SkipGodot) {
    if (-not (Test-Path $Godot)) { throw "Godot missing: $Godot" }
    Write-Host "== 3. Godot import + isolated validators =="
    & $Godot --path $Root --headless --import
    & $Godot --path $Root --headless --script "res://scripts/debug/validate_actorcore_production.gd"
    & $Godot --path $Root --headless --script "res://scripts/debug/dump_fighter_material_graph.gd"
    & $Godot --path $Root --headless --script "res://scripts/debug/dump_godot_bone_poses.gd"
}

if (-not $SkipTests) {
    Write-Host "== 4. Pytest =="
    python -m pytest tests -q --tb=line
    if ($LASTEXITCODE -ne 0) { throw "Pytest failed" }
}

if ($Promote) {
    Write-Host "PROMOTE requested: catalog/visual scripts must still be edited explicitly. This script will not rewrite fighter_catalog.gd automatically."
    Write-Host "Set production_glb_path to assets/fighters/processed/$Character/${Character}_game_ready_v4.glb after human bbox approval."
} else {
    Write-Host "Build artifacts ready. Catalog unchanged (no -Promote). Human must approve deformation before production switch."
}
