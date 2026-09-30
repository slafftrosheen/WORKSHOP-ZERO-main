# ---------------------------------------------------------------------------
# Workshop Zero - shared helpers for the scripts\ PowerShell commands.
#
# Dot-source this file from another script:
#     . "$PSScriptRoot\_tools.ps1"
#
# It is intentionally tiny. These scripts exist to prove the pipeline works,
# not to become a build system of their own.
# ---------------------------------------------------------------------------

# Repository root = the folder that contains this scripts\ folder.
$WorkshopZeroRoot = Split-Path -Parent $PSScriptRoot

function Add-RokitToPath {
    <#
        Rokit installs its tool shims into %USERPROFILE%\.rokit\bin.

        A terminal that was already open when Rokit was installed keeps the
        old PATH, so add the folder here when it is missing. This means the
        scripts work in an old window, a fresh window and CI alike.
    #>
    $rokitBin = Join-Path $env:USERPROFILE ".rokit\bin"
    if (-not (Test-Path $rokitBin)) {
        return
    }

    $entries = $env:Path -split ';'
    if ($entries -notcontains $rokitBin) {
        $env:Path = "$rokitBin;$env:Path"
    }
}

function Get-ToolPath {
    <#
        Returns the full path of a command, or $null when it is missing.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Name
    )

    Add-RokitToPath

    $command = Get-Command $Name -ErrorAction SilentlyContinue
    if ($null -eq $command) {
        return $null
    }

    return $command.Source
}

function Get-ToolVersion {
    <#
        Runs a tool's version flag and returns the first line of output.
        Returns an empty string when the tool is missing.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [string[]]$VersionArgs = @("--version")
    )

    $toolPath = Get-ToolPath $Name
    if ($null -eq $toolPath) {
        return ""
    }

    $line = & $toolPath @VersionArgs 2>&1 | Select-Object -First 1
    if ($null -eq $line) {
        return ""
    }

    return ([string]$line).Trim()
}
