# Normalize untouched AccuRIG FBX into clean_rig_v1 blend+glb+validation JSON.
# Does not overwrite original AccuRIG FBX. Does not touch production V4.
param(
    [ValidateSet("terere", "jaguarete", "both")]
    [string]$Character = "both"
)

$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path -Parent $PSScriptRoot
if (-not (Test-Path (Join-Path $ProjectRoot "project.godot"))) {
    $ProjectRoot = "E:\SuperSmashKapes\super-smash-kapes"
}
$Blender = "C:\Program Files\Blender Foundation\Blender 2.83\blender.exe"
$Script = Join-Path $ProjectRoot "tools\blender\normalize_accurig_game_rig.py"

if (-not (Test-Path $Blender)) {
    throw "Blender 2.83 not found: $Blender"
}

$chars = @()
if ($Character -eq "both") {
    $chars = @("terere", "jaguarete")
} else {
    $chars = @($Character)
}

$failed = $false
foreach ($c in $chars) {
    Write-Host "============================================================"
    Write-Host "NORMALIZE AccuRIG clean_rig_v1: $c"
    Write-Host "============================================================"
    & $Blender --background --python $Script -- --character $c
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Blender exited $LASTEXITCODE for $c"
        $failed = $true
    }
}

if ($failed) {
    exit 2
}
exit 0
