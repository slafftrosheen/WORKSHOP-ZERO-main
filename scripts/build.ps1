#requires -Version 5.1
<#
    Workshop Zero - build.

    Builds a fresh XML place into build\WorkshopZero.rbxlx.

    The first successful build seeds place\WorkshopZeroPrototype.rbxlx once.
    After that the place file belongs to Roblox Studio and is NEVER overwritten
    by this script - hand-built Workshop geometry must survive every rebuild.
#>

. "$PSScriptRoot\_tools.ps1"

$rojo = Get-ToolPath "rojo"
if ($null -eq $rojo) {
    Write-Host "Rojo is not installed. Run: rokit install" -ForegroundColor Red
    exit 1
}

$buildDir = Join-Path $WorkshopZeroRoot "build"
$outputFile = Join-Path $buildDir "WorkshopZero.rbxlx"
$placeDir = Join-Path $WorkshopZeroRoot "place"
$placeFile = Join-Path $placeDir "WorkshopZeroPrototype.rbxlx"

New-Item -ItemType Directory -Force -Path $buildDir | Out-Null

Write-Host ""
Write-Host "=== Workshop Zero : Build ===" -ForegroundColor Cyan
Write-Host "Project: default.project.json"
Write-Host "Output : build\WorkshopZero.rbxlx"
Write-Host ""

Push-Location $WorkshopZeroRoot

try {
    & $rojo build "default.project.json" --output $outputFile
    $buildExitCode = $LASTEXITCODE
}
finally {
    Pop-Location
}

if ($buildExitCode -ne 0) {
    Write-Host ""
    Write-Host "Build FAILED." -ForegroundColor Red
    exit $buildExitCode
}

Write-Host ""
Write-Host "Built build\WorkshopZero.rbxlx" -ForegroundColor Green

if (-not (Test-Path $placeFile)) {
    New-Item -ItemType Directory -Force -Path $placeDir | Out-Null
    Copy-Item -Path $outputFile -Destination $placeFile
    Write-Host ""
    Write-Host "Seeded place\WorkshopZeroPrototype.rbxlx (this happens once, ever)." -ForegroundColor Yellow
    Write-Host "That file is now the Studio working place: geometry, lighting, meshes."
    Write-Host "This script will not overwrite it again."
}
else {
    Write-Host "place\WorkshopZeroPrototype.rbxlx already exists - left untouched." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Next: .\scripts\dev.ps1   (starts Rojo, leave the window open)" -ForegroundColor Cyan
exit 0
