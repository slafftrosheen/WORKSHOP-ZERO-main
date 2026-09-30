#requires -Version 5.1
<#
    Workshop Zero - machine doctor.

    Prints what is installed, which version, and what still needs a human.

    Exit code 0 = ready to code and build.
    Exit code 1 = a tool required for coding/building is missing.

    Roblox Studio and Blender are reported as warnings only: code checks and
    Rojo builds still work without them.
#>

. "$PSScriptRoot\_tools.ps1"

Write-Host ""
Write-Host "=== Workshop Zero : Machine Doctor ===" -ForegroundColor Cyan
Write-Host "Repository: $WorkshopZeroRoot"
Write-Host ""

$rows = @()

function Add-Row {
    param(
        [string]$Tool,
        [bool]$Required,
        [string]$Version,
        [string]$Note = ""
    )

    $script:rows += [pscustomobject]@{
        Tool     = $Tool
        Required = $Required
        Version  = $Version
        Note     = $Note
    }
}

# --- Required for coding and building --------------------------------------

$gitVersion = Get-ToolVersion "git" @("--version")
if ($gitVersion -ne "") {
    Add-Row -Tool "Git" -Required $true -Version $gitVersion
}
else {
    Add-Row -Tool "Git" -Required $true -Version "" -Note "install: winget install --id Git.Git -e --source winget"
}

$lfsVersion = Get-ToolVersion "git" @("lfs", "version")
if ($lfsVersion -like "git-lfs*") {
    Add-Row -Tool "Git LFS" -Required $true -Version $lfsVersion
}
else {
    Add-Row -Tool "Git LFS" -Required $true -Version "" -Note "install: git lfs install"
}

$toolchain = @(
    @{ Title = "Rokit";    Command = "rokit" },
    @{ Title = "Rojo";     Command = "rojo" },
    @{ Title = "Wally";    Command = "wally" },
    @{ Title = "Selene";   Command = "selene" },
    @{ Title = "StyLua";   Command = "stylua" },
    @{ Title = "Luau LSP"; Command = "luau-lsp" }
)

foreach ($tool in $toolchain) {
    $version = Get-ToolVersion $tool.Command
    if ($version -ne "") {
        Add-Row -Tool $tool.Title -Required $true -Version $version
    }
    elseif ($tool.Command -eq "rokit") {
        Add-Row -Tool $tool.Title -Required $true -Version "" -Note "install: see README 'First machine setup'"
    }
    else {
        Add-Row -Tool $tool.Title -Required $true -Version "" -Note "install: rokit install"
    }
}

# --- Helpful but not required to check or build code -----------------------

$blenderPath = Get-ToolPath "blender"
if ($null -eq $blenderPath) {
    $blenderRoot = Join-Path $env:ProgramFiles "Blender Foundation"
    if (Test-Path $blenderRoot) {
        $candidate = Get-ChildItem -Path $blenderRoot -Filter "blender.exe" -Recurse -Depth 2 -ErrorAction SilentlyContinue |
            Select-Object -First 1
        if ($null -ne $candidate) {
            $blenderPath = $candidate.FullName
        }
    }
}

if ($null -ne $blenderPath) {
    $blenderVersion = (& $blenderPath --version 2>&1 | Select-Object -First 1)
    Add-Row -Tool "Blender" -Required $false -Version ([string]$blenderVersion).Trim()
}
else {
    Add-Row -Tool "Blender" -Required $false -Version "" -Note "install: winget install --id BlenderFoundation.Blender -e --source winget"
}

$studioExe = $null
$studioRoot = Join-Path $env:LOCALAPPDATA "Roblox\Versions"
if (Test-Path $studioRoot) {
    $studioExe = Get-ChildItem -Path $studioRoot -Filter "RobloxStudioBeta.exe" -Recurse -Depth 2 -ErrorAction SilentlyContinue |
        Select-Object -First 1
}

if ($null -ne $studioExe) {
    $studioVersion = Split-Path -Leaf (Split-Path -Parent $studioExe.FullName)
    Add-Row -Tool "Roblox Studio" -Required $false -Version $studioVersion
}
else {
    Add-Row -Tool "Roblox Studio" -Required $false -Version "" -Note "manual install: https://create.roblox.com/ then sign in"
}

$pluginFolder = Join-Path $env:LOCALAPPDATA "Roblox\Plugins"
$rojoPlugin = $null
if (Test-Path $pluginFolder) {
    $rojoPlugin = Get-ChildItem -Path $pluginFolder -Filter "Rojo*" -ErrorAction SilentlyContinue |
        Select-Object -First 1
}

if ($null -ne $rojoPlugin) {
    Add-Row -Tool "Rojo plugin" -Required $false -Version $rojoPlugin.Name
}
else {
    Add-Row -Tool "Rojo plugin" -Required $false -Version "" -Note "install: rojo plugin install"
}

# --- Report -----------------------------------------------------------------

Write-Host ("{0,-14} {1,-9} {2}" -f "Tool", "Status", "Version / notes") -ForegroundColor DarkGray
Write-Host ("{0,-14} {1,-9} {2}" -f "----", "------", "---------------") -ForegroundColor DarkGray

$missingRequired = @()
$missingOptional = @()

foreach ($row in $rows) {
    if ($row.Version -ne "") {
        $status = "OK"
        $color = "Green"
        $detail = $row.Version
    }
    elseif ($row.Required) {
        $status = "MISSING"
        $color = "Red"
        $detail = $row.Note
        $missingRequired += $row.Tool
    }
    else {
        $status = "WARN"
        $color = "Yellow"
        $detail = $row.Note
        $missingOptional += $row.Tool
    }

    Write-Host ("{0,-14} {1,-9} " -f $row.Tool, $status) -ForegroundColor $color -NoNewline
    Write-Host $detail
}

Write-Host ""

if ($missingRequired.Count -gt 0) {
    Write-Host "Missing required tools: $($missingRequired -join ', ')" -ForegroundColor Red
    Write-Host "Follow 'First machine setup' in README.md, then run this script again."
    exit 1
}

Write-Host "All required coding/building tools are present." -ForegroundColor Green

if ($missingOptional.Count -gt 0) {
    Write-Host "Warnings only (Studio / art tasks): $($missingOptional -join ', ')" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Recorded status: docs\ENVIRONMENT.md"
exit 0
