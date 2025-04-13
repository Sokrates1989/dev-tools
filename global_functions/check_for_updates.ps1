# -----------------------------------------------------------------------------
# Script: check_for_updates.ps1
# Description: Displays update information in a human-friendly format.
# -----------------------------------------------------------------------------

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$OriginalDir = Get-Location
Set-Location $ScriptDir

try {
    git fetch | Out-Null
    $diff = git diff HEAD..origin/HEAD

    if ($diff) {
        Write-Host ""
        Write-Host "Update available in Dev Tools repository."
        Write-Host "To update, run:"
        Write-Host "   cd `"$ScriptDir`"; git pull; cd -"
        Write-Host ""
    }
}
catch {
    Write-Host "Warning: Unable to check for updates. Git may not be initialized."
}

Set-Location $OriginalDir
