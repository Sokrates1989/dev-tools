<#
.SYNOPSIS
    Reports safe Dev Tools update state without modifying the checkout.

.DESCRIPTION
    Uses the shared update manager and successful-check cache. This compatibility
    entrypoint remains non-prompting because the top-level dispatcher owns the
    once-per-launch update prompt.
#>

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$RootDir = Resolve-Path (Join-Path $ScriptDir "..") | Select-Object -ExpandProperty Path

. (Join-Path $ScriptDir "update_manager.ps1")
Initialize-DevToolsUpdateMessages -RootDir $RootDir

if (-not (Test-DevToolsInteractiveSession)) {
    return
}

$state = Get-DevToolsUpdateState -RootDir $RootDir -UseCache $true
if ($state.State -eq "behind") {
    $oldShortCommit = $state.LocalCommit.Substring(0, [Math]::Min(7, $state.LocalCommit.Length))
    $newShortCommit = $state.RemoteCommit.Substring(0, [Math]::Min(7, $state.RemoteCommit.Length))
    Write-Host (Get-DevToolsUpdateMessage -Key "updates.available" -Arguments $oldShortCommit, $newShortCommit) -ForegroundColor Cyan
}
else {
    Write-DevToolsUpdateStateNotice -State $state
}
