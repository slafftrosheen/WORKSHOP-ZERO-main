#requires -Version 5.1
<#
    Workshop Zero - check.

    Everything that must pass before a coding batch is considered done:

        1. StyLua format check      (stylua --check src)
        2. Selene lint              (selene src)
        3. Rojo build validation    (rojo build into a throwaway file)

    Exit code 0 = all green.
    Exit code 1 = something real failed.

    Run this after every batch. See AGENTS.md.
#>

. "$PSScriptRoot\_tools.ps1"

$failures = New-Object System.Collections.ArrayList

Push-Location $WorkshopZeroRoot

try {
    Write-Host ""
    Write-Host "=== Workshop Zero : Check ===" -ForegroundColor Cyan

    # --- 1/3 StyLua ---------------------------------------------------------
    Write-Host ""
    Write-Host "--- 1/3  StyLua format check (src)" -ForegroundColor Cyan
    $stylua = Get-ToolPath "stylua"
    if ($null -eq $stylua) {
        [void]$failures.Add("StyLua is not installed. Run: rokit install")
    }
    else {
        & $stylua --check src
        if ($LASTEXITCODE -ne 0) {
            [void]$failures.Add("StyLua found formatting differences. Fix them with: stylua src")
        }
        else {
            Write-Host "    formatting is clean" -ForegroundColor Green
        }
    }

    # --- 2/3 Selene ---------------------------------------------------------
    Write-Host ""
    Write-Host "--- 2/3  Selene lint (src)" -ForegroundColor Cyan
    $selene = Get-ToolPath "selene"
    if ($null -eq $selene) {
        [void]$failures.Add("Selene is not installed. Run: rokit install")
    }
    else {
        & $selene src
        if ($LASTEXITCODE -ne 0) {
            [void]$failures.Add("Selene reported lint problems in src")
        }
        else {
            Write-Host "    lint is clean" -ForegroundColor Green
        }
    }

    # --- 3/3 Rojo build validation ------------------------------------------
    Write-Host ""
    Write-Host "--- 3/3  Rojo build validation (default.project.json)" -ForegroundColor Cyan
    $rojo = Get-ToolPath "rojo"
    if ($null -eq $rojo) {
        [void]$failures.Add("Rojo is not installed. Run: rokit install")
    }
    else {
        $buildDir = Join-Path $WorkshopZeroRoot "build"
        $validationFile = Join-Path $buildDir "_validation.rbxlx"
        New-Item -ItemType Directory -Force -Path $buildDir | Out-Null

        & $rojo build "default.project.json" --output $validationFile
        if ($LASTEXITCODE -ne 0) {
            [void]$failures.Add("Rojo could not build default.project.json")
        }
        else {
            Write-Host "    project builds (throwaway file removed)" -ForegroundColor Green
        }

        if (Test-Path $validationFile) {
            Remove-Item -Path $validationFile -Force -ErrorAction SilentlyContinue
        }
    }
}
finally {
    Pop-Location
}

Write-Host ""

if ($failures.Count -gt 0) {
    Write-Host "CHECK FAILED" -ForegroundColor Red
    foreach ($failure in $failures) {
        Write-Host "  - $failure" -ForegroundColor Red
    }
    exit 1
}

Write-Host "CHECK PASSED - formatting, lint and Rojo build are all clean." -ForegroundColor Green
exit 0
