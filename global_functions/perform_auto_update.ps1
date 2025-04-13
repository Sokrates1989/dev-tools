# -----------------------------------------------------------------------------
# Script: perform_auto_update.ps1
# Description: Pulls latest version of Dev Tools from origin using Git.
# -----------------------------------------------------------------------------

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$RootDir = Resolve-Path "$ScriptDir\.." | Select-Object -ExpandProperty Path
$OriginalDir = Get-Location

Write-Host ""
Write-Host "Checking for updates..."
Set-Location $RootDir

try {
    git pull
    Write-Host ""
    Write-Host "Update complete."
}
catch {
    Write-Host "Failed to pull updates: $_"
}

Set-Location $OriginalDir
Write-Host ""
