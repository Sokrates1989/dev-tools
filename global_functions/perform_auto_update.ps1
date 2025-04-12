# -----------------------------------------------------------------------------
# Script: perform_auto_update.ps1
# Description: Pulls latest version of Dev Tools from origin using Git.
# -----------------------------------------------------------------------------

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$RootDir = Resolve-Path "$ScriptDir\.." | Select-Object -ExpandProperty Path
$OriginalDir = Get-Location

Write-Host ""
Write-Host "🔄 Performing Dev Tools update..."
Set-Location $RootDir
git pull
Set-Location $OriginalDir
Write-Host ""
Write-Host "✅ Update complete."
Write-Host ""
