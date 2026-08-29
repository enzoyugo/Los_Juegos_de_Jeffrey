# Isolated Clean Rig V5 lab launcher.
# Uses gl_compatibility + Dummy audio to avoid Editor+F6 Windows commit exhaustion.
param(
    [ValidateSet("terere", "jaguarete", "validate")]
    [string]$Fighter = "terere",
    [switch]$SkipImport
)

$ErrorActionPreference = "Stop"
$Godot = "E:\Godot_v4.7.2-stable_win64_console.exe"
$ProjectRoot = Split-Path -Parent $PSScriptRoot
$Scenes = @{
    terere = "res://scenes/debug/TerereCleanRigV5Lab.tscn"
    jaguarete = "res://scenes/debug/JaguareteCleanRigV5Lab.tscn"
    validate = "res://scenes/debug/ValidateCleanRigV5Labs.tscn"
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
