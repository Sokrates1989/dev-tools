<#
.SYNOPSIS
    Safely fast-forwards Dev Tools from its official configured upstream.

.DESCRIPTION
    Refuses dirty, ahead, diverged, detached, unexpected-branch, and
    unexpected-origin checkouts. This script is the compatibility entrypoint
    used by explicit update workflows.
#>

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$RootDir = Resolve-Path (Join-Path $ScriptDir "..") | Select-Object -ExpandProperty Path

. (Join-Path $ScriptDir "update_manager.ps1")
Initialize-DevToolsUpdateMessages -RootDir $RootDir

if (-not (Invoke-DevToolsUpdate -RootDir $RootDir)) {
    $host.SetShouldExit(1)
}
