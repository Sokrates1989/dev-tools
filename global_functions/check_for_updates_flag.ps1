<#
.SYNOPSIS
    Returns whether Dev Tools is safely eligible for an automatic update.

.OUTPUTS
    System.String. "1" only for a clean main branch strictly behind the
    official configured upstream; otherwise "0".
#>

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$RootDir = Resolve-Path (Join-Path $ScriptDir "..") | Select-Object -ExpandProperty Path

. (Join-Path $ScriptDir "update_manager.ps1")
$state = Get-DevToolsUpdateState -RootDir $RootDir -UseCache $false
if ($state.State -eq "behind") {
    Write-Output "1"
}
else {
    Write-Output "0"
}
