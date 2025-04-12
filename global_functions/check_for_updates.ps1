# check_for_updates.ps1

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
Push-Location $ScriptDir

try {
    git fetch | Out-Null
    $diff = git diff HEAD..origin/HEAD
    if ($diff) {
        Write-Host ""
        Write-Host "📦 Updates available in Dev Tools repository!"
        Write-Host "💡 To update, run:"
        Write-Host "   cd '$ScriptDir'; git pull; cd -"
    }
} catch {
    Write-Host "⚠️ Git update check failed: $_"
}

Pop-Location
