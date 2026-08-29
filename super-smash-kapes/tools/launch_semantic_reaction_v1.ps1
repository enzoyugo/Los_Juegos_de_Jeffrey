# Semantic Reaction V1 isolated lab launcher.
# Uses gl_compatibility + Dummy audio to avoid Editor+F6 Windows commit exhaustion.
#
# Works from any cwd:
#   powershell -ExecutionPolicy Bypass -File "E:\SuperSmashKapes\super-smash-kapes\tools\launch_semantic_reaction_v1.ps1" -Fighter terere
#
# Or from the project root:
#   cd E:\SuperSmashKapes\super-smash-kapes
#   powershell -ExecutionPolicy Bypass -File ".\tools\launch_semantic_reaction_v1.ps1" -Fighter terere
#   powershell -ExecutionPolicy Bypass -File ".\tools\launch_semantic_reaction_v1.ps1" -Fighter jaguarete
param(
    [ValidateSet("terere", "jaguarete")]
    [string]$Fighter = "terere",
    [switch]$SkipImport
)

$ErrorActionPreference = "Stop"
$Godot = "E:\Godot_v4.7.2-stable_win64_console.exe"
$ProjectRoot = Split-Path -Parent $PSScriptRoot
$Scenes = @{
    terere = "res://scenes/debug/TerereSemanticReactionV1Lab.tscn"
    jaguarete = "res://scenes/debug/JaguareteSemanticReactionV1Lab.tscn"
}

if (-not (Test-Path $ProjectRoot)) {
    throw "Project root not found: $ProjectRoot"
}

if (-not $SkipImport) {
    Write-Host "Importing Godot project (headless) at $ProjectRoot ..."
    & $Godot --headless --path $ProjectRoot --import
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "Godot import exit $LASTEXITCODE (continuing to runtime)"
    }
}

Write-Host "Launching $($Scenes[$Fighter]) with gl_compatibility + Dummy audio"
& $Godot --path $ProjectRoot --rendering-method gl_compatibility --audio-driver Dummy $Scenes[$Fighter]
