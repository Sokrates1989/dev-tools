# -----------------------------------------------------------------------------
# Script: check_for_updates.ps1
# Description: Displays update information in a human-friendly format.
# -----------------------------------------------------------------------------

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$OriginalDir = Get-Location
Set-Location $ScriptDir

$RootDir = Resolve-Path "$ScriptDir\.." | Select-Object -ExpandProperty Path
Set-Location $RootDir

$CredentialCheckScript = Join-Path $ScriptDir "git_credential_check.ps1"
if (Test-Path $CredentialCheckScript) {
    . $CredentialCheckScript
}

try {
    git fetch | Out-Null
    $diff = git diff HEAD..origin/HEAD

    if ($diff) {
        Write-Host ""
        Write-Host "Updates available in Dev Tools repository! (run 'dev-tools -u' to update)"
        Write-Host ""
    }
}
catch {
    Write-Host "Warning: Unable to check for updates. Git may not be initialized."
}

Set-Location $OriginalDir
