# Semantic Reaction V1.1 comparison lab launcher.
# Works from any cwd. Project root is the parent of this tools/ folder.
#
# powershell -ExecutionPolicy Bypass -File "E:\SuperSmashKapes\super-smash-kapes\tools\launch_semantic_reaction_v11.ps1" -Fighter terere
# powershell -ExecutionPolicy Bypass -File ".\tools\launch_semantic_reaction_v11.ps1" -Fighter jaguarete
param(
    [ValidateSet("terere", "jaguarete")]
    [string]$Fighter = "terere",
    [switch]$SkipImport
)

$ErrorActionPreference = "Stop"
$Godot = "E:\Godot_v4.7.2-stable_win64_console.exe"
$ProjectRoot = Split-Path -Parent $PSScriptRoot
$Scenes = @{
    terere = "res://scenes/debug/TerereSemanticReactionV11Lab.tscn"
    jaguarete = "res://scenes/debug/JaguareteSemanticReactionV11Lab.tscn"
}

if (-not $SkipImport) {
    Write-Host "Importing Godot project at $ProjectRoot ..."
    & $Godot --headless --path $ProjectRoot --import
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "Godot import exit $LASTEXITCODE (continuing to runtime)"
    }
}

Write-Host "Launching $($Scenes[$Fighter]) with gl_compatibility + Dummy audio"
& $Godot --path $ProjectRoot --rendering-method gl_compatibility --audio-driver Dummy $Scenes[$Fighter]
