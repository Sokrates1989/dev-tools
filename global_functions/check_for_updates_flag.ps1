# -----------------------------------------------------------------------------
# Script: check_for_updates_flag.ps1
# Description: Returns 1 if updates are available, 0 otherwise. No user output.
# -----------------------------------------------------------------------------

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$OriginalDir = Get-Location
Set-Location $ScriptDir

try {
    git fetch | Out-Null
    $diff = git diff HEAD..origin/HEAD
    if ($diff) {
        Write-Output "1"
    } else {
        Write-Output "0"
    }
}
catch {
    # If anything fails (e.g. not a git repo), return 0 to avoid breaking the tool
    Write-Output "0"
}

Set-Location $OriginalDir
