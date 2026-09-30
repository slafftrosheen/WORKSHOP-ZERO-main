#requires -Version 5.1
<#
    Workshop Zero - dev.

    Starts the Rojo sync server and explains, in plain words, what a human has
    to do inside Roblox Studio.

    Keep this window open while building in Studio. Ctrl+C stops Rojo.
#>

. "$PSScriptRoot\_tools.ps1"

$rojo = Get-ToolPath "rojo"
if ($null -eq $rojo) {
    Write-Host "Rojo is not installed. Run: rokit install" -ForegroundColor Red
    exit 1
}

$placeFile = Join-Path $WorkshopZeroRoot "place\WorkshopZeroPrototype.rbxlx"
if (-not (Test-Path $placeFile)) {
    Write-Host ""
    Write-Host "place\WorkshopZeroPrototype.rbxlx does not exist yet." -ForegroundColor Yellow
    Write-Host "Run .\scripts\build.ps1 first - it creates that place exactly once." -ForegroundColor Yellow
    Write-Host ""
}

Write-Host ""
Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host " Rojo is starting." -ForegroundColor Cyan
Write-Host ""
Write-Host " 1. Open place\WorkshopZeroPrototype.rbxlx in Roblox Studio."
Write-Host " 2. Open the Rojo plugin (Plugins tab)."
Write-Host " 3. Connect to the local server (127.0.0.1:34872)."
Write-Host " 4. Press Play."
Write-Host ""
Write-Host " You should see both of these lines in Studio's Output window:"
Write-Host "   [WorkshopZero] Server bootstrap 0.0.1-dev"
Write-Host "   [WorkshopZero] Client bootstrap 0.0.1-dev"
Write-Host ""
Write-Host " Keep this window open. Press Ctrl+C to stop Rojo." -ForegroundColor Yellow
Write-Host " Do not enable Studio Script Sync: Rojo owns the code." -ForegroundColor Yellow
Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host ""

Push-Location $WorkshopZeroRoot

try {
    & $rojo serve "default.project.json"
}
finally {
    Pop-Location
}
